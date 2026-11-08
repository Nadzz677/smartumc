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
- `lib/core/authentication/` contains the authentication models/service, centralized matric normalization and alias mapping, and a concrete Firebase Auth/Firestore profile repository.
- `lib/core/constants/user_role.dart` defines exactly `student`, `lecturer`, and `super_admin` canonical claims.
- `lib/features/authentication/` contains the login UI and authorization gate. The gate routes only after claims and profile are resolved; this client routing does not replace Firebase Rules.
- The root screen is now the authentication experience rather than the original Firebase counter. Lecturer and Super Admin destinations remain limited placeholder experiences.
- Firestore profile access is implemented by rules; no other application collection access, attendance, QR, or location workflow is implemented.

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

### Mission 06 authentication and authorization

- **Implemented:** Student matric input is trimmed/lowercased and validated as 4–20 ASCII letters, digits, or hyphens, then mapped to `{normalized}@students.smartumc.invalid`. The alias is never shown as an input and is not treated as a recovery channel. The example `DIT2026001` maps to `dit2026001@students.smartumc.invalid`.
- **Implemented:** Lecturer and provisioned Super Admin login use Firebase Auth email/password. All login failures from Firebase Auth use a generic credential message to avoid exposing account existence.
- **Implemented:** Firebase Auth UID is canonical. `role` and `active` Custom Claims are the trusted authorization values. On sign-in and first session restoration the client force-refreshes its ID token, then server-reads `users/{uid}` and requires exact canonical role agreement, matching profile/Auth email, and `status: active`. For students, the Auth email must also equal the alias derived from the profile matric number. Missing/malformed claims, missing profile, inactive status, or mismatched identity fails closed and signs out. An account-disabled/token-expired response also signs out.
- **Claim refresh behavior:** Admin SDK claim changes do not rewrite an already-issued ID token. A subsequent sign-in or forced token refresh obtains the new claims; the app listens to `idTokenChanges` so refreshed token states are re-evaluated. The repository's `getCurrentUser()` forces a refresh. Do not treat a profile role field as a replacement for Custom Claims.
- **Implemented, local trusted process only:** `functions/scripts/provision-demo-user.cjs` provisions an Auth account, claims, and a matching profile. It only runs when both emulator endpoints are loopback and the active project is `demo-smartumc`; it accepts credentials via process environment, removes the password variable from the process environment before provisioning, and never prints the password. Student aliases are generated centrally. Staff/Super Admin demo emails must use the reserved `.invalid` domain.
- **Local use:** Build with `npm --prefix functions run build`, set `SMARTUMC_DEMO_ROLE`, `SMARTUMC_DEMO_DISPLAY_NAME`, and `SMARTUMC_DEMO_PASSWORD`, then provide `SMARTUMC_DEMO_MATRIC` for a student or `SMARTUMC_DEMO_EMAIL` for lecturer/Super Admin and run `npm --prefix functions run provision:demo-user` inside `firebase emulators:exec --only auth,firestore --project demo-smartumc "..."`. Use synthetic values and do not put passwords in command arguments or source files.
- **Provisioning safety:** Provisioning validates role and identity, refuses conflicting profiles or disabled existing accounts, safely reconciles consistent partial/existing records, merges profile fields, and rolls back claims/profile/Auth creation when later steps fail. Automated tests cover idempotent retry and rollback. This is not a public endpoint and no production bootstrap mechanism exists.
- **Implemented rules:** only authenticated `get` on `users/{uid}` is allowed when the path UID matches the caller and the trusted token has `active: true` plus one of the three canonical roles. List, create, update, delete, role changes, and all non-`users` collection access remain denied.
- **Implemented emulator isolation:** Flutter connects to local Auth and Firestore only when `SMARTUMC_USE_FIREBASE_EMULATORS=true` is explicitly supplied in a debug build. Android Emulator uses `10.0.2.2`; web and desktop use `127.0.0.1`. No production Firebase options were changed.
- **Passed:** Functions TypeScript validation and 8 focused Node tests; Auth/Firestore Emulator integration test (provisioning, custom claims, anonymous denial, own-profile allow, cross-user denial, profile create/update denial, and role-change denial); the emulator-only provisioning CLI smoke test; Flutter analyzer; and 8 Flutter tests covering matric mapping/profile identity binding, malformed claims, and unauthenticated/authenticated role transitions and logout.
- **Passed:** Final Flutter web debug build (`flutter build web --no-pub`) and Android debug APK build (`flutter build apk --debug --no-pub`). These verify compilation only, not deployed lecturer workflows or Android UI sign-in.
- **Android build alignment:** The approved compatibility change updates the Kotlin Gradle plugin from 2.2.20 to 2.4.21 and migrates the Android JVM target from deprecated `kotlinOptions` to typed `compilerOptions`, retaining JVM 17. The existing Android Gradle Plugin 8.11.1 and Gradle 8.14 are within Kotlin's documented supported ranges. On this Windows setup, the Pub source cache is mirrored under ignored `.dart_tool/pub-cache` on the project drive to avoid cross-volume Kotlin incremental-cache failures; `pubspec.lock` and dependency versions are unchanged.
- **Not exercised:** Flutter app sign-in through platform Firebase plugins, Android emulator UI flow, lecturer web deployment, role claim revocation on a live client, production Auth/Firestore, recovery, and real devices. No production account or data was used.
- **Pending:** The formal institutional matric-number format (current accepted pattern is an implementation constraint based on the approved example), production staff identity/provisioning policy, and password-recovery channel. Recovery is explicitly out of scope; `.invalid` addresses cannot receive mail.

## Proposed design

Use a feature-oriented Flutter structure with clear presentation, application/domain, and data boundaries. Keep shared code in the same repository while isolating Android-specific location/camera capabilities from web UI. Use Firebase Auth for identity, Firestore repositories for approved application data, and trusted backend operations for account/role provisioning, session integrity, QR secrets, and attendance writes. Enforce access in Firestore Security Rules and backend validation, not just in the UI.

Keep the Super Admin interface limited to approved synthetic demonstration data operations. Design only the minimal Firestore entities required for users/roles, DIT semesters/courses/offerings/enrollments, attendance sessions, and records; the exact schema remains a proposal pending review. Do not adopt the historical 22-collection design wholesale.

## Pending approval

- Whether the lecturer web interface is separately deployed from the Android app using the shared repository, or maintained as a separate project.
- Specific trusted backend runtime/services and billing constraints.
- Formal matric-number validation format and production staff identity/provisioning policy.
- Detailed Firestore schema, including exact collection/document names and access matrix.
- Location thresholds/result fields, while preserving approved UI indicator semantics.
