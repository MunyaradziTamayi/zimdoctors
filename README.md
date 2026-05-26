# Zim Doctors

Zim Doctors is a Flutter app that connects patients in Zimbabwe with doctors. Patients can register, search for doctors, get location-based recommendations, ask an AI health assistant for guidance, and book appointments. Doctors can register, verify their profile, manage availability, receive booking notifications, and update their public profile.

## What the project does

- Provides separate patient and doctor flows using Firebase Authentication.
- Stores doctors, bookings, notifications, and verification records in Cloud Firestore.
- Lets patients browse and search doctors by name, specialty, and location.
- Uses the device location to highlight nearby doctors where location permission is available.
- Helps patients choose a suitable specialist through the AI chat and recommendation flow.
- Supports appointment booking with slot conflict checks so the same doctor slot is not double-booked.
- Sends booking and confirmation notifications between patients and doctors.
- Gives doctors a dashboard for bookings, profile editing, consultation fees, profile images, and available dates or time slots.
- Includes payment integration hooks for EcoCash direct, Paynow OneMoney, and Pesepay-backed payments through the backend API.
- Supports text-to-speech and backend Shona TTS audio generation when a TTS endpoint is configured.
- Verifies doctor registration through a local MDPCZ registry collection and optional Firecrawl-backed registry scraping.

## Main screens

- `welcome_screen.dart` - first screen and entry point into login or registration.
- `login_screen.dart` and `registration_screen.dart` - authentication and account creation.
- `home_screen.dart` - patient home screen with search, nearby doctors, recommendations, and booking entry points.
- `doctors_screen.dart` - searchable doctor directory with nearby doctor suggestions.
- `doctor_detail_screen.dart` - doctor profile details and appointment booking flow.
- `ai_chat_screen.dart` - AI health assistant and doctor matching experience.
- `doctor_dashboard_screen.dart` - doctor booking, profile, notification, and stats area.
- `doctor_availability_allocation_screen.dart` - doctor availability management.
- `mdpcz_registry_sync_debug_screen.dart` - debug screen for syncing or checking doctor registry data.

## Tech stack

- Flutter and Dart
- Firebase Core, Firebase Auth, Cloud Firestore, and Firebase Storage
- `flutter_dotenv` for runtime configuration
- `geolocator` and `geocoding` for location-aware doctor matching
- `http` for backend API calls
- `ecocash` for payment model support
- `image_picker` for doctor profile images
- `stts`, `just_audio`, and backend TTS support for speech features
- `excel` for registry import support

## Backend and integrations

The Flutter app expects a backend API for AI diagnosis/recommendations, payment endpoints, and optional TTS. The base URL is read from `.env` or passed through `--dart-define`.

Important backend paths used by the app include:

- `POST /session/start` - starts an AI chat or diagnosis session.
- `POST /ask` - sends general health questions to the AI backend.
- `POST /recommend` - returns disease/specialist recommendations and optional doctor IDs.
- `POST /predict/text` - predicts from symptom text.
- `POST /tts` - generates WAV audio for backend TTS.
- `POST /payments/ecocash/direct` - starts direct EcoCash payment.
- `POST /payments/paynow/initiate-mobile` - starts OneMoney mobile payment.
- `POST /payments/pesepay/initiate` - starts Pesepay payment.

## Environment setup

Create a `.env` file from `.env.example` and configure the values for your backend and registry tools.

```bash
cp .env.example .env
```

Common values:

```env
DISEASE_API_BASE_URL=http://10.0.2.2:8000
TTS_API_BASE_URL=http://10.0.2.2:8000
FIRECRAWL_API_KEY=
DOCTOR_REGISTRY_SEARCH_URL=
FIRECRAWL_API_BASE_URL=
```

For Android emulator development, `http://10.0.2.2:8000` points to a backend running on your computer. For a physical device, use your computer's LAN IP address, for example `http://192.168.x.x:8000`.

You can also override the backend URL at run time:

```bash
flutter run --dart-define=DISEASE_API_BASE_URL=http://192.168.x.x:8000
```

## Firebase setup

This project uses Firebase for authentication, Firestore, and storage. Make sure the Firebase project is configured for the platforms you want to run:

- Android: `android/app/google-services.json`
- iOS: Firebase configuration in the iOS runner project
- Web: Firebase configuration in the web project if web support is used

The app reads and writes collections such as:

- `doctors`
- `bookings`
- `notifications`
- `doctor_verifications`
- `mdpcz_registry`

## Running the app

Install dependencies:

```bash
flutter pub get
```

Run on the selected device:

```bash
flutter run
```

Run with an explicit backend URL:

```bash
flutter run --dart-define=DISEASE_API_BASE_URL=http://10.0.2.2:8000
```

## Testing

Run unit and widget tests:

```bash
flutter test
```

Run integration tests:

```bash
flutter test integration_test
```

Analyze the project:

```bash
flutter analyze
```

## Project structure

```text
lib/
  Screens/             App screens for auth, home, doctors, AI chat, and dashboards
  models/              Doctor, booking, diagnosis, notification, and registry models
  services/            Firebase, backend API, payment, TTS, location, and verification services
  utils/               Availability, date, location, WhatsApp, and recommendation helpers
  widgets/             Shared form and TTS widgets
  reusableWidgets/     Older shared UI widgets
assets/
  images/              App images
test/                  Unit and widget tests
integration_test/      Integration and smoke tests
```

## Current development focus

The project is building toward a full doctor-patient appointment platform for Zimbabwe. The core work centers on reliable doctor discovery, verified doctor onboarding, AI-assisted doctor matching, booking and rescheduling, payment initiation, and doctor availability management.
