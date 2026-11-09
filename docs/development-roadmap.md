# Development Roadmap

This sequence is a **Proposed design** based on confirmed scope and code-verified gaps. It does not claim that any phase is implemented.

## Code-verified starting point before Mission 06

Firebase Core initialization/options, basic authentication abstractions, role constants, route helpers/placeholders, and a starter counter test exist. Concrete authentication, Firestore workflows/rules, dashboards, synthetic DIT data, attendance, geolocation, and QR behavior were not found in the inspected source.

## Mission 05 status

- **Implemented, not yet fully tested:** Node.js 22 TypeScript Functions scaffold and Firebase Admin initialization; module boundaries for authentication, authorization, academics, and attendance; deny-all Firestore rules; Auth/Functions/Firestore emulator configuration with a `demo-smartumc` CLI project alias; and additional local-secret/build-output exclusions in `.gitignore`.
- No authentication or attendance workflow has been implemented. The deny-all rules deliberately block all client Firestore access until reviewed rules are added.
- The initial Mission 05 environment lacked the configured Node.js 22 runtime and Java 21+ required by the current Firebase CLI. Mission 05.3 added checksum-verified, user-scoped Node.js 22.23.4 and Temurin JDK 21.0.13 without changing system installations.

## Mission 05.1 and 05.3 validation status

- **Passed:** With process-scoped Node.js 22.23.4, `npm run validate` completed the TypeScript build and the Functions Emulator started, loaded the scaffold, ran a harmless local probe, and shut down. With Temurin JDK 21.0.13, the Firestore Emulator started under `demo-smartumc`; `functions/scripts/verify-firestore-rules.mjs` confirmed that an unauthenticated read is denied; `emulators:exec` shut the emulator down.
- **Not exercised:** No actual Functions handlers, authentication, attendance, QR workflows, or production resources were used. The Firestore result covers only the current deny-all rules.
- **Dependency audit:** A read-only `npm audit --json` against the existing lockfile reports 8 moderate vulnerable package entries (all production graph): `@google-cloud/firestore@7.11.6` via `google-gax@4.6.1`/`uuid@9.0.1`; `@google-cloud/storage@7.22.0` via `retry-request@7.0.2`/`teeny-request@9.0.0`/`uuid@9.0.1`; `firebase-admin@13.10.0`; and transitive packages `gaxios@6.7.1`, `google-gax@4.6.1`, `retry-request@7.0.2`, `teeny-request@9.0.0`, and `uuid@9.0.1`. The installed `firebase-functions@6.6.0` depends on the affected Admin SDK. Advisory GHSA-w5hq-g745-h8pq describes missing buffer bounds checks for uuid v3/v5/v6 when caller-provided buffers are used. npm's suggested tree remediation requires a major `firebase-admin@14.5.0` upgrade; SDKs were left unchanged and no audit fix/override was applied. Earlier npm 12 installation also blocked `@firebase/util` and `protobufjs` postinstall scripts; neither was executed.
- **CLI warning:** Firebase CLI reports the pinned `firebase-functions` package as outdated during Functions Emulator startup. Review SDK compatibility and the moderate audit findings in a separately approved dependency-maintenance task.
- **Mission 05.1 status at that checkpoint:** Authentication and attendance workflows, schema operations, and collection-specific client rules were not implemented. Mission 06 supersedes the authentication/profile-rule status below.
- **Repeatable local check:** `npm run test:rules` probes that an unauthenticated Firestore read is denied while the local Firestore Emulator is running. See `functions/scripts/verify-firestore-rules.mjs`.

## Mission 06 authentication status

- **Implemented:** Student matric normalization and deterministic `.invalid` email alias; lecturer/staff email login; Firebase Auth session observation and restoration; canonical Custom Claims role/active validation against the user's Firestore profile; inactive and malformed authorization rejection; role-aware gate; logout; and generic credential errors.
- **Implemented:** Emulator-only trusted synthetic account provisioning with Auth creation, Custom Claims, profile creation, input validation, retry/reconciliation, and rollback handling. No callable/public provisioning endpoint or first-Super-Admin self-registration exists.
- **Implemented:** Own-profile-only Firestore `get`; profile listing and all client writes denied; all other collections remain default-denied.
- **Passed:** `functions` TypeScript validation and eight focused Node tests; Auth/Firestore emulator provisioning and rules integration; Flutter analyzer; and eight Flutter tests. The emulator integration used only synthetic records and the `demo-smartumc` project.
- **Not exercised:** Actual Flutter Firebase plugin sign-in on Android/web, production services, identity verification for real staff, account recovery, attendance, location, and QR workflows.
- **Android build:** After project director approval, the Kotlin Gradle plugin was aligned to 2.4.21 and the deprecated Kotlin target DSL migrated to `compilerOptions` with JVM 17 retained. `flutter build apk --debug --no-pub` then succeeded. The existing Pub cache was mirrored under ignored `.dart_tool/pub-cache` on the project drive to prevent cross-volume incremental-cache errors; `pubspec.lock` and dependency versions were unchanged.
- **Pending:** Final formal matric-number format, production staff provisioning/verification procedure, and password-recovery provider/policy. The `.invalid` alias is not a recovery address. The existing npm moderate security findings also remain unresolved; do not remediate them without separate review/approval.

## Proposed phases

1. **Resolve remaining scope details.** Confirm lecturer web deployment boundary, synthetic semester/course dataset, formal matric format, production staff provisioning, and location result thresholds. These choices affect data and platform design.
2. **Approve minimal schema and security model.** Define entities, ownership, read/write boundaries, rules, and trusted backend responsibilities before client data flows are built.
3. **Prepare isolated development/test path.** (Environment readiness is verified for Functions and Firestore emulators.) Before implementation, define emulator fixtures and tests for Auth and collection-specific rules. Do not alter production configuration or deploy without explicit approval.
4. **Authentication foundation (Mission 06 implemented).** Before using production identities, approve the formal matric format and staff verification/provisioning process. Android build alignment is verified; next test role refresh and disabled-account behavior on target clients.
5. **Create limited synthetic DIT data management.** Extend the trusted local provisioning foundation only after approval of semester/course/enrollment data fields; keep all test data synthetic.
6. **Mission 08 backend implemented:** Callable session lifecycle, static/dynamic QR signing, enrolled student submission, location evidence validation, lecturer roster retrieval, private Firestore attendance collections, and emulator coverage. Student/lecturer UI integration remains future work.
7. **Next:** Confirm official class occurrence sources, semester dates, and schedule exceptions before treating synthetic template-based occurrence snapshots as official.
8. **Next:** Integrate backend calls in the Android student and lecturer web experiences only after director review; preserve online/physical indicator semantics and no-GPS denial rules.
9. **Next:** Resolve location/privacy retention, clock-skew and QR expiry grace policy, and lecturer judgement workflow before production use.

## Pending approval

Backend runtime/billing, semester dates and official course/offering details, formal matric format, production staff provisioning, lecturer deployment boundary, and password-recovery policy.

## Mission 07 — academic data foundation

- **Implemented:** Minimal academic collections, guarded synthetic seeder,
  read-only Flutter models/repository, and scoped Firestore read rules.
- **Passed:** Functions TypeScript validation and 10 Functions unit tests.
- **Passed:** Auth/Firestore Emulator integration verified seed create/retry
  counts, enrollment uniqueness, student and lecturer read boundaries, client
  write denial, unauthenticated denial, and preserved own-profile access. The
  CLI seed smoke test created its 32-document dataset and emulators shut down.
  Flutter analyzer and all 12 Flutter tests passed; Functions build and all 10
  Functions unit tests passed.
- **Next:** Review the final diff and obtain project-director checkpoint
  approval before progressing to attendance or bulletin work. Do not deploy.
- **Pending facts:** Semester dates, course codes/credits for Computer
  Forensic, SULAM and Projek 1, plus official offering, lecturer, group and
  timetable assignments. Current fixtures remain explicitly synthetic.

### Mission 07 access/query sequence

1. Preserve authentication profile and trusted claims.
2. Query student enrollments using `studentUid == auth.uid`.
3. Fetch only the offering IDs referenced by those enrollments.
4. Read semester and course references by document ID.
5. Let lecturers query with `lecturerUid == auth.uid`.
6. Add no composite index unless a later approved query requires one.

## Mission 07.2 production and attendance quality gate

- **Confirmed requirement:** Production begins with empty application data;
  automatic synthetic seeding is prohibited. Seed scripts remain local
  emulator/development tools only.
- **Confirmed requirement:** Super Admin's future trusted workflow creates
  student accounts and profile data separately from enrollment and timetable
  assignment. No assignment is automatic. Empty states must be handled
  gracefully. Super Admin manages academic records and bulletins; the UI and
  production workflow are not implemented yet.
- **Confirmed Mission 08 design:** Minimize fraud and support lecturer
  judgement without claiming zero proxy attendance. A QR scan is evidence,
  not proof of presence. No initial fixed geofence radius. Physical location
  evidence is captured when available; online sessions may omit precise
  location. GPS denial, unavailable location, or poor reliability alone must
  not auto-reject a submission.
- Preserve the established indicators and keep detailed location evidence,
  submission state, GPS reliability, and lecturer judgement separate.
- Mission 07.2 does not start Mission 08 implementation.

### Mission 07.2 engineering verification

- **Passed:** Functions TypeScript validation and 10 unit tests under
  Node.js 24.21.0. The required Node.js 22.23.4 runtime was not located, so
  these checks remain unverified under the configured Functions runtime.
- **Passed:** Auth/Firestore Emulator suite on `demo-smartumc`, 2/2 tests;
  local emulators shut down after execution.
- **Passed:** Flutter analyzer, 21 Flutter tests, and Flutter web build.
- **Passed:** Android debug assembly using the Gradle wrapper with a
  process-local Temurin 17 selection. Flutter's normal APK command selected
  Android Studio JBR 25.0.4 and failed in the project's Kotlin tooling; this
  environment incompatibility remains unresolved.
- No dependencies, Firebase configuration, or production services were
  changed or used for these checks.
- **Mission 07.3 waiver:** The project director approved continuing despite
  Node.js 22.23.4 being unavailable. Available Functions checks used Node.js
  24.21.0. Do not claim Node.js 22 compatibility was verified.

## Mission 08 attendance backend status

- **Implemented:** Six callable Functions for session create/open/close, QR
  issue, attendance submit, and assigned lecturer roster retrieval.
- **Passed:** Functions TypeScript validation and 17 Functions unit tests on
  Node.js 24.21.0. Emulator integration passed 3/3 test files across Auth,
  Firestore rules, academic regression, and attendance callable behavior.
- **Passed:** Emulator run used the exact `demo-smartumc` project, loopback
  Auth/Firestore/Functions endpoints, a temporary synthetic local secret
  override, and JDK 25.0.4 from Android Studio. CLI used host Node.js 24 for
  Functions despite configured Node.js 22. No deployment or production data
  was used.
- **Pending:** Node.js 22 runtime compatibility remains unverified under the
  approved Mission 07.3 waiver. Official class schedules/dates, clock-skew or
  expiry grace, location data retention/privacy, and lecturer judgement are
  unresolved. The lecturer-attested occurrence snapshot is not proof of an
  official scheduled class.
- **Not implemented:** Flutter attendance UI, location permission/device
  capture, bulletin workflows, or production deployment.
- The Functions Emulator selected host Node.js 24.21.0 because Node.js
  22.23.4 was unavailable. The test result does not verify Node.js 22 runtime
  compatibility. No Flutter tests were needed or run because this mission did
  not change Flutter source.
