# System test checklist (manual)

This file is a lightweight “system test” checklist you can run before a release.

## Setup

- `flutter doctor` passes on your machine
- Firebase project configured (Auth + Firestore + Storage)
- `.env` present (optional, only needed for Firecrawl fallback)

## MDPCZ registry sync

1. Run a one-time sync from an admin-only/debug entry point that calls:
   - `MdpczRegistrySyncService().syncAll()`
2. In Firestore, confirm collection `mdpcz_registry` exists and contains documents keyed by normalized registration numbers.
3. Pick a known doctor from `https://mdpcz.co.zw/public_register` and confirm the stored fields look correct:
   - `fullName`, `registrationNumber`, `specialty`, `sourceUrl`, `scrapedAt`

## Doctor registration verification (happy path)

1. Sign up as Doctor using:
   - Full Name + Registration Number that exists in the MDPCZ register
2. Confirm the app allows navigating to `DoctorDashboardScreen`.
3. In Firestore `doctors/{uid}`, confirm:
   - `isVerified == true`
   - `verificationProvider == "mdpcz_registry"`
   - `verificationUrl` points to MDPCZ register page

## Doctor registration verification (reject path)

1. Sign up as Doctor with an invalid/unknown registration number.
2. Confirm the app blocks dashboard creation with a clear error message.

## UI sanity

- Welcome screen renders without overflow on small heights (e.g. landscape phone / small emulator)
- “Sign Up” and “Sign In” buttons are visible and tappable

## Automated checks

- Unit/widget tests: `flutter test`
- Integration smoke test: `flutter test integration_test/app_smoke_test.dart`

