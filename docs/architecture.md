# SmartUMC Architecture

## Confirmed requirements

- One shared Flutter/Dart repository and Firebase backend, with Cloud Firestore as the primary database.
- Student Android application, separate lecturer web interface, and a limited Super Admin role for synthetic data.
- Trusted identity verification and privileged-role assignment; clients may not assign roles.
- DIT demonstration scope, three representative semesters in 2026/2027, synthetic data only.
- Attendance requires geolocation verification; lecturer-controlled dynamic QR is optional and refreshes every minute when enabled.
- Green/yellow/red display definitions are fixed by the approved requirements; detailed location verification results are separate.

## Code-verified implementation

- `lib/main.dart` initializes Firebase and starts a counter/test page.
- `lib/firebase_options.dart` contains Android and web options for the configured Firebase project.
- `lib/core/authentication/` contains authentication model/state/service abstractions and an abstract repository, but no Firebase implementation.
- `lib/core/constants/user_role.dart` defines student, lecturer, and admin roles.
- `lib/core/routing/` defines destinations/access helper and placeholder pages. These client-side helpers do not enforce backend authorization.
- Source inspection found no concrete Firestore access, security-rules file, trusted functions, dashboards, attendance, QR, or location implementation.

### Mission 05 backend foundation status

- **Implemented, not yet fully tested:** `functions/` TypeScript scaffold targeting Node.js 22, Firebase Admin initialization, module boundaries for authentication, authorization, academics, and attendance, and Firebase Emulator configuration for Auth, Functions, and Firestore.
- **Local project selection:** `.firebaserc` defaults Firebase CLI commands to the emulator-only `demo-smartumc` project ID. Flutter’s generated client options still point at the configured Firebase project, so the app must be explicitly connected to emulators before any client integration test.
- **Implemented, conservative baseline:** `firestore.rules` denies all client reads and writes until collection-specific authorization rules are reviewed and tested. The Admin SDK bypasses these rules; future backend operations must perform their own authorization checks.
- **Not implemented:** Authentication workflows, role assignment, Firestore schema/operations, attendance, location verification, QR issuance/validation, or callable functions.
- **Environment limitation:** Node.js 24.21.0 is installed, while the Functions runtime is configured for supported Node.js 22. `java` resolves through an Oracle `java8path` launcher, but a usable Java 11+ runtime could not be verified, so Java-based emulators cannot currently be verified. Firebase CLI 15.35.0 is present, but its update check reported that its local config store is inaccessible.

## Proposed design

Use a feature-oriented Flutter structure with clear presentation, application/domain, and data boundaries. Keep shared code in the same repository while isolating Android-specific location/camera capabilities from web UI. Use Firebase Auth for identity, Firestore repositories for approved application data, and trusted backend operations for account/role provisioning, session integrity, QR secrets, and attendance writes. Enforce access in Firestore Security Rules and backend validation, not just in the UI.

Keep the Super Admin interface limited to approved synthetic demonstration data operations. Design only the minimal Firestore entities required for users/roles, DIT semesters/courses/offerings/enrollments, attendance sessions, and records; the exact schema remains a proposal pending review. Do not adopt the historical 22-collection design wholesale.

## Pending approval

- Whether the lecturer web interface is separately deployed from the Android app using the shared repository, or maintained as a separate project.
- Specific trusted backend runtime/services and billing constraints.
- Identity mapping details and staff login identifier.
- Detailed Firestore schema, including exact collection/document names and access matrix.
- Location thresholds/result fields, while preserving approved UI indicator semantics.
