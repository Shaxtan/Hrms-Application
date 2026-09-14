# HRMS — Employee Onboarding App

Flutter mobile app for HR supervisors to onboard employees.

## Quick Start

### Prerequisites
- Flutter SDK 3.16+
- Dart 3.2+
- Android Studio / VS Code with Flutter plugin

### Setup

```bash
# 1. Install dependencies
flutter pub get

# 2. Run in Chrome (web)
flutter run -d chrome

# 3. Run on Android emulator
flutter run -d emulator-5554

# 4. Run on iOS simulator
flutter run -d iPhone
```

### API Configuration
Edit `lib/core/network/api_client.dart` and set `_baseUrl` to your backend:
- **Android emulator:** `http://10.0.2.2:8083`
- **iOS simulator / Web:** `http://localhost:8083`
- **Production:** `https://your-api.com`

### Architecture
```
lib/
├── core/
│   ├── theme/         → Design tokens, colors, typography
│   ├── constants/     → Employment requirements matrix, routes
│   └── network/       → Dio client with auth interceptors
├── features/
│   └── onboarding/
│       ├── data/      → API layer (mirrors employeeApi.js)
│       ├── domain/    → Models
│       └── presentation/
│           ├── controllers/  → GetX state management
│           └── pages/        → Dashboard + Add Employee
└── shared/
    └── widgets/       → Shared UI components
```

### Screens
- **Dashboard** — Supervisor ops: pipeline stats, KPIs, recent onboarding
- **Add Employee** — 6-section accordion form with live validation,
  Aadhaar dedup, document uploads, step-result ledger

### Notes
- Dashboard uses **mock data** by default for development.
  Swap `DashboardController.mock` → `DashboardController()` to use live API.
- The employment-requirements matrix in `lib/core/constants/employment_requirements.dart`
  mirrors the backend `EmploymentRequirements.java` exactly.
