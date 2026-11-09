# SmartUMC Architecture

## Confirmed requirements

- One shared Flutter/Dart repository and Firebase backend, with Cloud Firestore as the primary database.
- Student Android application, separate lecturer web interface, and a limited Super Admin role for synthetic data.
- Trusted identity verification and privileged-role assignment; clients may not assign roles.
- DIT demonstration scope, three representative semesters in 2026/2027, synthetic data only.
- Attendance evidence is intended to minimize fraud and support lecturer review, not guarantee zero proxy attendance. QR is optional, lecturer-controlled and refreshes every minute when enabled; a scan is not proof of physical presence.
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

Keep the Super Admin interface limited to approved synthetic demonstration data operations. The Mission 07 academic schema uses only `users`, `semesters`, `courses`, `courseOfferings`, and `enrollments`; attendance sessions and records remain reserved for later implementation. Do not adopt the historical 22-collection design wholesale.

## Pending approval

- Whether the lecturer web interface is separately deployed from the Android app using the shared repository, or maintained as a separate project.
- Specific trusted backend runtime/services and billing constraints.
- Formal matric-number validation format and production staff identity/provisioning policy.
- Official semester dates, pending subject details, and official offering/lecturer/group/timetable assignments; current academic fixtures are synthetic and the access matrix is implemented for approved reads.
- Mission 08 evidence-handling details must follow the confirmed policy below; no initial fixed geofence radius is approved.

## Mission 07 academic data implementation

This section supersedes earlier statements that the academic schema and
collection access matrix were pending. It does not change authentication.

- **Implemented:** Minimal `semesters`, `courses`, `courseOfferings`, and
  `enrollments` model/seed support. Existing `users` profiles are reused; no
  attendance or bulletin collections/workflows were added.
- **Implemented:** Trusted local seeding composes with the Mission 06
  synthetic-user helper. The command checks exact emulator project ID and
  loopback Auth/Firestore endpoints before initializing Admin. Create-only
  writes accept exact records on retry and reject conflicts instead of
  overwriting them.
- **Implemented:** Rules preserve `users/{uid}` own-profile `get`. Active
  trusted identities can read catalogs; students can query only their own
  enrollments and get offerings only through the deterministic matching
  enrollment; lecturers can query only assigned offerings. Clients cannot
  modify academic data. Other collections remain default-denied.
- **Implemented:** Flutter models validate academic fields and time formats.
  `FirebaseAcademicRepository` uses current Auth UID and trusted role claims,
  reads own enrollments/assigned offerings and referenced records, and returns
  loading/empty/data/error outcomes. No academic UI changed.
- **Implemented in Mission 07.2:** Offering mapping rejects an embedded
  timetable entry whose group or lecturer UID differs from its parent
  offering. Student retrieval also checks enrollment course, semester, and
  group relationships before returning an offering. Direct repository tests
  use injected identity/data-source fakes; Firebase rules queries remain
  covered by the emulator tests.
- **Synthetic fixture design:** 3 representative semesters (dates unset), 5
  DIT course docs (2 supplied references, 3 pending), 12 group offerings,
  and 12 enrollments. Weekly templates are synthetic, not dated occurrences
  or official timetables.
- **Queries/indexes:** Student enrollment ownership query; direct gets for
  student offerings/catalog records; lecturer assignment query. Optional
  semester filtering is client-side after authorized reads. Automatic
  single-field indexes suffice; no index file was added.
- **Passed:** Functions TypeScript build and 10 Functions unit tests, including
  dataset shape, deterministic IDs, retry behavior and conflict refusal.
- **Passed:** Auth/Firestore Emulator integration verified exact seed counts
  (32 created, then 32 already present), deterministic duplicate prevention,
  student-owned enrollment/offering access, assigned/unassigned lecturer
  access, academic client-write denial (including lecturer self-assignment),
  unauthenticated denial, and existing profile access. The CLI seeder smoke
  test created 32 records with an ephemeral synthetic password; emulators
  shut down cleanly.
- **Passed:** Flutter analyzer (no issues), 12 Flutter tests, Functions
  TypeScript build and 10 Functions tests. Current shell Node.js was 24.21.0
  for Functions build/tests although `functions/package.json` still requires
  Node.js 22. Android Studio JBR OpenJDK 21.0.10 ran emulators. No Functions
  Emulator, production resources, or deployment were used.
- **Pending academic facts:** Official dates, pending subject details, and
  official lecturer/group/timetable assignments.

## Mission 07.2 production data and Mission 08 boundaries

### Confirmed requirement

- Production application data starts empty. Synthetic users and academic
  records are local development/emulator fixtures only; there is no automatic
  production seeding. Account creation and academic enrollment remain
  separate trusted operations. Creating a student account does not create an
  enrollment or timetable assignment.
- Super Admin is responsible for future trusted student account/profile
  creation and management of semesters, offerings, timetable assignments,
  and university/club bulletins. No Super Admin dashboard or production
  provisioning workflow was implemented in Mission 07.2.
- Empty states are intentional. Student clients cannot modify trusted
  academic data.
- Attendance aims to minimize fraud, not promise zero proxy attendance. QR
  scans and location readings are evidence for lecturer review, not proof of
  physical presence.
- No fixed geofence radius is planned for the initial attendance workflow.
  Physical-class evidence can include latitude, longitude, reported accuracy,
  and timestamp when available. Permission denial, unavailable location, and
  unreliable readings must be distinguished; GPS limitations alone do not
  automatically reject submission. Online attendance mode may be submitted
  without precise location, and the lecturer configures the mode.
- Preserve indicators exactly: green means location successfully traced
  when scanned; yellow means scanned but did not open location; red means did
  not scan. Detailed location evidence remains separate from submission
  status, GPS reliability, and lecturer judgement.

### Not implemented

Mission 07.2 does not add QR issuance/rotation, attendance sessions or
records, GPS collection or validation, attendance submission, bulletins, a
Super Admin dashboard, or production account provisioning. These remain
future work with the above design boundaries.

### Mission 07.2 verification record

- **Passed:** Functions TypeScript validation and 10 Functions unit tests
  under Node.js 24.21.0. The package continues to declare Node.js 22; Node.js
  22.23.4 was not found in the targeted user-scoped runtime locations, so the
  Functions checks were not repeated under the configured runtime.
- **Passed:** Auth/Firestore Emulator tests against `demo-smartumc` (2/2),
  run locally; emulator processes shut down after the tests.
- **Passed:** Flutter analyzer and 21 Flutter tests.
- **Passed:** Flutter web build.
- **Passed:** Android debug assembly through the project Gradle wrapper with
  an explicit process-local Temurin 17 JDK selection. The ordinary Flutter
  APK command encountered the installed Android Studio JBR 25.0.4, which the
  project's current Kotlin tooling cannot parse. No Java or project runtime
  configuration was changed.
- **Not verified:** Node.js 22.23.4 Functions validation. Do not treat the
  Node.js 24 result as runtime-equivalent evidence.

## Mission 08 attendance backend

### Code-verified implementation

- Cloud Functions v2 callable endpoints implement session creation, opening,
  closure, QR retrieval, student submission, and lecturer roster retrieval.
  Authorization verifies the callable identity, active trusted claim, current
  Auth account enabled state/claims, and active matching Firestore profile.
- Attendance collections are private to trusted backend execution. Firestore
  rules explicitly deny all client reads/writes to sessions and records.
- QR tokens use HMAC-SHA256 with a Firebase Functions secret parameter.
  Static tokens are session-bound and usable until closure; dynamic tokens
  rotate on the exact UTC 60-second bucket and expire at the bucket boundary.
  No raw tokens or signing secret are stored in Firestore. Records retain a
  token digest for audit and use a transactionally deterministic record ID.
- Physical and online modes are explicit. Location outcomes and input
  validation are detailed in `requirements.md`; no geofence, accuracy
  threshold, or maximum location age is applied. Submitted location is
  client-reported evidence, not proof of presence.
- The lecturer roster derives red only for enrolled students with no record
  after session closure. Green and yellow keep their approved definitions;
  physical outcomes without a corresponding approved indicator and online
  attendance return no color with an explicit context. No absence records or
  lecturer judgement UI are created.
- A session contains a dated occurrence snapshot derived from a selected
  recurring template. Because Mission 07 has only synthetic weekly templates
  and null semester dates, the lecturer attests the date; official occurrence
  verification remains limited pending confirmed schedules and date bounds.

### Runtime and verification limitation

- TypeScript validation and Functions tests use Node.js 24.21.0. The package
  and Firebase configuration still require Node.js 22; compatibility with
  Node.js 22.23.4 remains unverified under the Mission 07.3 waiver.
- Local emulators use a synthetic secret override in ignored
  `functions/.secret.local`. No production Firebase resources or deployment
  are used.
- **Passed:** `npm run validate`; 17/17 Functions unit tests; and 3/3
  emulator integration test files (authentication/profile regression,
  academic rules regression, and attendance callable/rules flow). The
  Functions Emulator also started and loaded all six callables.
- The available Node executable was
  `C:\Program Files\nodejs\node.exe` (v24.21.0). Firebase CLI used the
  Android Studio JBR at
  `C:\Program Files\Android\Android Studio\jbr\bin\java.exe` (25.0.4).
- **Not run:** Flutter analyzer/build/widget tests; Mission 08 adds no Flutter
  source or UI integration.
- On the first emulator attempt, Firebase CLI tried to resolve the absent
  secret for the demo project and received HTTP 403. The successful run used
  a generated ephemeral test secret supplied through ignored
  `functions/.secret.local`; no production secret was configured.

### Mission 07.3 verification waiver

- **Project director approved continuing:** Node.js 22.23.4 is unavailable in
  the current environment. The available Functions validation and tests used
  Node.js 24.21.0. Node.js 22 compatibility has not been verified; this is an
  explicit limitation, not a passing runtime check.

## Mission 09.1 shared UI foundation and authentication presentation

### Code-verified implementation

- `AppTheme`, `AppColors`, `AppSpacing`, and `AppRadii` provide shared Flutter
  theme and design tokens. Reusable `AppCard` and `AppTextField` widgets are
  under `lib/core/design_system/`.
- The login screen follows the approved Figma student layout and keeps the
  existing `AuthService` as its authentication boundary. Students enter a
  matric number; staff use provisioned email credentials. Password recovery
  is visibly unavailable and does not call Firebase reset APIs.
- `RoleApplicationShell` provides responsive student and lecturer placeholder
  experiences with logout. Super Admin sees an out-of-scope notice, not an
  administrative application. Trusted auth and role resolution are unchanged.
- Local login assets include the Figma artwork and Inter font. `flutter_svg`
  renders the supplied SVG assets; it reports unsupported `<filter>` elements
  from the wave artwork. Flutter blur wraps those wave assets as a fallback.
- **Passed:** Flutter analyzer, 29 Flutter tests, and Flutter web build. Login
  widget tests cover the 393x852 design viewport and a narrow viewport. An
  automated golden was attempted but removed because asynchronous asset decode
  made it nondeterministic in the full suite.
- **Failed:** Android debug APK build with the selected Android Studio JDK
  25.0.4 due to existing Gradle/Kotlin toolchain incompatibility. Build
  configuration was not changed.
- `flutter_svg` 2.3.2 was added after project director approval. Firebase
  package versions and backend behavior were not changed. Dependency
  resolution now records Flutter >=3.41.0 in `pubspec.lock` (local SDK:
  3.41.7); contributors using an older Flutter SDK cannot resolve this lock.

### Proposed design

- Continue student screens with the shared tokens and reusable components,
  then implement the separate lecturer web experience on those primitives.
  UI should consume existing repositories and callables rather than own
  Firebase access.

### Pending approval / limitations

- Password recovery for the `.invalid` student alias remains undecided; no
  recovery provider or reset flow is implemented.
- Academic progress must not show invented grades or GPA. Events remain empty
  or presentation-only until a backend requirement is approved.
- Mission 09.1 does not implement attendance or bulletin UI or a Super Admin
  dashboard. Android build verification remains blocked by the selected JDK.
