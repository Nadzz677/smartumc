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
6. **Implement lecturer sessions and optional QR.** Add session lifecycle and lecturer control; when enabled, issue protected QR tokens with one-minute refresh/expiry. Student check-in consumes an active session.
7. **Implement student attendance and location verification.** Capture location as mandatory input and validate it through trusted logic. Keep detailed verification separate from the approved green/yellow/red indicators.
8. **Implement lecturer attendance review.** Display the three approved indicators and relevant detailed verification outcomes with appropriate access restrictions.
9. **Verify end-to-end behavior and security.** Test Android and web flows, rules, backend validation, negative cases, QR expiry/replay, and synthetic dataset consistency before any deployment.

## Pending approval

Backend runtime/billing, semester dates and seed dataset, geofence/accuracy thresholds, formal matric format, production staff provisioning, lecturer deployment boundary, and password-recovery policy.
