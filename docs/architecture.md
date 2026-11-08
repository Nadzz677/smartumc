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
- **Environment baseline before Mission 05.3:** Node.js 24.21.0 and JDK 17 were the system-provided runtimes; Firebase CLI 15.35.0 requires Java 21+ for emulator startup. These system installations were left unchanged.

### Mission 05.1 and 05.3 validation results

- **Passed in Mission 05.1:** Project-local dependencies installed; `functions/package-lock.json` generated; the TypeScript build and Firebase configuration JSON parsing passed.
- **Passed in Mission 05.3:** User-scoped Node.js 22.23.4 and Eclipse Temurin JDK 21.0.13 were checksum-verified from official distributions. Process-scoped `node --version`, `npm --version` (10.9.9), and `java -version` checks passed. The Functions TypeScript validation passed on Node 22. The Firestore Emulator started on `demo-smartumc`; the unauthenticated read probe returned the expected denial; `emulators:exec` shut it down. The Functions Emulator started using host Node 22, loaded the scaffold, ran a harmless local probe, and shut down successfully.
- **Not tested:** No function handlers, authentication, attendance, QR, or production operations were introduced or exercised. Emulator startup does not validate unimplemented workflows.
- **Install notes:** The previous npm 12 dependency install reported 9 moderate audit findings at that time and blocked postinstall scripts for `@firebase/util` and `protobufjs`; those scripts were not run. A read-only audit against the current lockfile on Node 22/npm 10.9.9 reports 8 moderate vulnerable package entries, all in the production dependency graph. The uuid advisory is GHSA-w5hq-g745-h8pq; the automated suggested fix requires a major Firebase Admin SDK upgrade. No dependency changes or audit remediation were made.
- **Safe rule probe:** `functions/scripts/verify-firestore-rules.mjs`, run through `npm run test:rules`, now passed against the local emulator. This verifies only that unauthenticated reads remain denied by the current deny-all rules.
- **Runtime warning:** Firebase CLI warned that the installed `firebase-functions` version is outdated. The approved SDK versions were preserved; assess compatibility before any upgrade.

## Proposed design

Use a feature-oriented Flutter structure with clear presentation, application/domain, and data boundaries. Keep shared code in the same repository while isolating Android-specific location/camera capabilities from web UI. Use Firebase Auth for identity, Firestore repositories for approved application data, and trusted backend operations for account/role provisioning, session integrity, QR secrets, and attendance writes. Enforce access in Firestore Security Rules and backend validation, not just in the UI.

Keep the Super Admin interface limited to approved synthetic demonstration data operations. Design only the minimal Firestore entities required for users/roles, DIT semesters/courses/offerings/enrollments, attendance sessions, and records; the exact schema remains a proposal pending review. Do not adopt the historical 22-collection design wholesale.

## Pending approval

- Whether the lecturer web interface is separately deployed from the Android app using the shared repository, or maintained as a separate project.
- Specific trusted backend runtime/services and billing constraints.
- Identity mapping details and staff login identifier.
- Detailed Firestore schema, including exact collection/document names and access matrix.
- Location thresholds/result fields, while preserving approved UI indicator semantics.
