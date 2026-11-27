import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import '../network/api_client.dart';
import '../theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SESSION MANAGER — keep an ACTIVE session alive, end an IDLE one
//
// The access token lives 15 minutes (login returns expiresIn: 900). Until now
// the only thing that renewed it was the 401 interceptor, which by definition
// runs AFTER a request has already failed. For someone part-way through the
// Add Employee form that failing request is their save, so the session died
// exactly when it cost the most — and it died on the clock, not on idleness,
// because nothing was watching whether the person was actually using the app.
//
// This flips both halves:
//   • ACTIVE  → the token is renewed shortly BEFORE it expires, indefinitely.
//               The user never meets a 401, so nothing is ever lost.
//   • IDLE    → after `idleTimeout` with no touch, the session is ended
//               deliberately, with a message saying why.
//
// Every pointer-down in the app records activity (see the Listener in
// main.dart), so scrolling, typing and tapping all count — including the long
// stretches of typing that make no network calls at all.
// ═══════════════════════════════════════════════════════════════════════════════
class SessionManager extends GetxService with WidgetsBindingObserver {
  static SessionManager get to => Get.find();

  /// How long the app may sit untouched before the session is ended.
  static const Duration idleTimeout = Duration(minutes: 15);

  /// Renew this far ahead of expiry. Comfortably longer than one tick, so a
  /// token is never left to die between checks.
  static const Duration renewBefore = Duration(minutes: 4);

  /// How often idleness and token age are re-examined.
  static const Duration _tick = Duration(seconds: 30);

  /// Secure-storage key for the last interaction, so the idle clock survives
  /// the app being killed. Cleared by logout's deleteAll().
  static const _lastActivityKey = 'last_activity_at';

  /// Writing on every touch would hit secure storage dozens of times a minute
  /// for no benefit — the value only matters at minute granularity.
  static const _persistEvery = Duration(seconds: 60);

  static const _storage = FlutterSecureStorage();

  DateTime _lastActivity = DateTime.now();
  DateTime? _lastPersisted;
  Timer? _timer;
  bool _refreshing = false;
  bool _running = false;

  /// Set once when a proactive refresh has been attempted and could not run
  /// for want of a credential. Read by [refreshUnavailable] for diagnostics.
  final refreshUnavailable = false.obs;

  /// Seconds since the last interaction — handy when debugging.
  int get idleSeconds => DateTime.now().difference(_lastActivity).inSeconds;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.onClose();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Begin watching. Called on a successful login and on a restored session.
  ///
  /// [restored] marks a session rehydrated at cold start rather than a fresh
  /// login. Only then is the PERSISTED last-activity honoured: a phone closed
  /// for three hours must come back signed out, which an in-memory clock
  /// starting at "now" would never notice. A fresh login is activity by
  /// definition, so its clock starts clean.
  Future<void> start({bool restored = false}) async {
    _running = true;
    refreshUnavailable.value = false;

    if (restored) {
      final previous = await _readPersistedActivity();
      if (previous != null) {
        if (DateTime.now().difference(previous) >= idleTimeout) {
          await _endForInactivity();
          return;
        }
        _lastActivity = previous;
      } else {
        _lastActivity = DateTime.now();
      }
    } else {
      _lastActivity = DateTime.now();
    }
    await _persistActivity();

    _timer?.cancel();
    _timer = Timer.periodic(_tick, (_) => _evaluate());
    // Don't wait a full tick to find out the token is nearly dead.
    await _evaluate();
  }

  /// Stop watching. Called on logout so a signed-out app does no work.
  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Record a user interaction. Cheap by design — this runs on every pointer
  /// event in the app, so it moves a timestamp and, at most once a minute,
  /// writes it through so the idle clock survives the app being killed.
  void recordActivity() {
    _lastActivity = DateTime.now();
    if (!_running) return;
    final last = _lastPersisted;
    if (last == null || _lastActivity.difference(last) >= _persistEvery) {
      // Fire-and-forget: a pointer event must never wait on storage.
      _persistActivity();
    }
  }

  Future<void> _persistActivity() async {
    _lastPersisted = _lastActivity;
    try {
      await _storage.write(
          key: _lastActivityKey,
          value: _lastActivity.toUtc().toIso8601String());
    } catch (_) {
      // Storage unavailable — the in-memory clock still governs this run.
    }
  }

  Future<DateTime?> _readPersistedActivity() async {
    try {
      final raw = await _storage.read(key: _lastActivityKey);
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw)?.toLocal();
    } catch (_) {
      return null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed) return;
    // Timers are frozen in the background, so time spent there is never seen
    // by the tick above. Re-examine the moment we come back: a phone left
    // locked overnight must come back signed out, not signed in.
    _evaluate();
  }

  // ── The decision ──────────────────────────────────────────────────────────

  Future<void> _evaluate() async {
    if (!_running) return;

    final idle = DateTime.now().difference(_lastActivity);
    if (idle >= idleTimeout) {
      await _endForInactivity();
      return;
    }

    // Still in use — keep the token ahead of its own expiry.
    await _renewIfDue();
  }

  Future<void> _renewIfDue() async {
    if (_refreshing) return;

    final token = await _readToken();
    if (token == null || token.isEmpty) return;

    final expiry = ApiClient.accessTokenExpiry(token);
    // No readable `exp` means we cannot tell when it dies; leave it to the 401
    // path rather than hammering the refresh endpoint every 30 seconds.
    if (expiry == null) return;

    final dueIn = expiry.difference(DateTime.now());
    if (dueIn > renewBefore) return;

    _refreshing = true;
    try {
      if (!await ApiClient.hasRefreshCredential()) {
        // Nothing to refresh WITH. The session cannot outlive the token no
        // matter what this class does — that is a backend/cookie problem, so
        // flag it rather than silently retrying every tick.
        refreshUnavailable.value = true;
        return;
      }
      final fresh = await ApiClient.refreshAccessToken();
      if (fresh != null && fresh.isNotEmpty) {
        refreshUnavailable.value = false;
        // A renewed token starts a healthy session again: clear the 401 latch
        // so a genuine expiry later is still acted on.
        ApiClient.resetSessionExpiry();
      }
      // A failed renewal is deliberately NOT a logout. It is usually a blip,
      // and the token is still valid for a few more minutes; the next tick
      // tries again, and the 401 interceptor remains the single place that
      // declares a session dead.
    } catch (_) {
      // Same reasoning — never sign someone out because a refresh threw.
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _endForInactivity() async {
    stop();
    Get.snackbar(
      'Signed out',
      'You were signed out after '
          '${idleTimeout.inMinutes} minutes of inactivity.',
      backgroundColor: AppColors.warning,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 5),
      margin: const EdgeInsets.all(16),
    );
    await _logout();
  }

  // ── Indirection so this file need not import the auth page ────────────────
  // SessionManager lives in core/ and the AuthController in features/; wiring
  // these in from main.dart keeps core from depending on a feature.

  /// Reads the stored access token. Injected by main.dart.
  Future<String?> Function()? tokenReader;

  /// Ends the session. Injected by main.dart.
  Future<void> Function()? logoutHandler;

  Future<String?> _readToken() async =>
      tokenReader == null ? null : await tokenReader!();

  Future<void> _logout() async {
    if (logoutHandler != null) await logoutHandler!();
  }
}
