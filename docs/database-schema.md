# Database Schema Planning

## Confirmed requirements

- Cloud Firestore is the primary database.
- Data is limited to a synthetic DIT demonstration with three representative semesters in 2026/2027.
- Keep the schema minimal and add collections only when justified. Do not automatically use the historical 22-collection proposal.
- Client-provided roles are untrusted; privileged writes require trusted validation. Passwords must never be stored in Firestore.
- Physical-class workflows collect location evidence when available; online sessions may omit precise location. Preserve display indicators separately from detailed verification results.
- Production application data starts empty; synthetic users and academic records are emulator/development fixtures only and must not be seeded into production.

## Code-verified implementation before Mission 06

No Firestore collection reads/writes, schema models/repositories, rules, indexes, or seed data were found in the inspected source. Firebase Firestore dependency/configuration exists, but this does not establish a deployed or implemented schema.

### Mission 05 and 06 security foundation status

- Mission 05 introduced deny-all rules and no application profile schema or client access policy existed at that checkpoint.
- Mission 06 implements only `users/{uid}`. Provisioning writes `role`, `status`, `email`, `displayName`, optional student `matricNumber`, and `createdAt`/`updatedAt` timestamps. Firebase Auth UID is the document ID.
- Active users with a supported trusted role claim may `get` only their own profile. Listing and all client profile writes are denied. All other collections remain denied; no indexes, academic seed data, or attendance data are implemented.
- Trusted backend code will bypass Firestore Rules when using the Admin SDK, so each future privileged operation must validate caller identity, role, ownership, and request data itself.
- Mission 05.3 verified unauthenticated denial against the then-current deny-all rules. Mission 06 verified the final profile rules against Auth and Firestore emulators, including unauthenticated denial, own-profile allow, cross-user denial, and denial of client profile creation, profile updates, and role changes. This does not validate other collections because they remain denied and unimplemented.

## Proposed design (not an approved schema)

The demonstration will likely need data representing:

- User identity/profile and trusted role mapping.
- DIT academic semesters, course definitions/offerings, and synthetic enrollments.
- Attendance sessions and attendance records, including the approved indicator and separately stored location verification details.

These are logical data needs, not approved Firestore collection names or a finalized structure. Prefer stable IDs, explicit ownership, minimal personal fields, and backend-controlled integrity fields. Keep QR secrets inaccessible to clients. Define access rules alongside each schema decision.

## Pending approval

- Additional collection/document structure, field names, retention, and access matrix beyond the minimal `users/{uid}` profile.
- Semester identifiers/date boundaries and synthetic course/enrollment dataset.
- Attendance collections, evidence lifecycle, and access rules remain unimplemented; the initial design has no fixed geofence radius.
- Which attendance/session operations are client-readable versus backend-only.

## Mission 07 academic foundation

The Mission 07 implementation below supersedes the earlier statement that the
academic schema and access matrix were pending. It does not change Mission 06
authentication/profile behavior.

### Code-verified implementation

- Collections implemented by the synthetic dataset builder: `semesters`,
  `courses`, `courseOfferings`, and `enrollments`. `users/{uid}` remains the
  Mission 06 trusted profile collection. Attendance and bulletin collections
  are not implemented.
- The emulator fixture contains 3 representative semesters, 5 DIT course
  references, 12 group offerings, and 12 enrollment records (32 documents).
  `BBA1152` / Advanced English II / 2 credits and `KOM4263` /
  Pengaturcaraan Web / 3 credits are the only confirmed subject references.
  Computer Forensic, SULAM and Projek 1 retain null course code/credit values
  and `pending_confirmation`.
- Semester start/end dates are null and status is `pending_official_dates`.
  All offering/group/lecturer assignments and schedule templates are marked as
  synthetic representative data and are not official academic facts.
- A course offering embeds a `schedule` array. Each entry uses
  `scheduleType: recurring_weekly`, a `scheduleDay`, null `classDate`, 24-hour
  start/end times, course/group/venue/lecturer identifiers, null attendance
  status, and an explicit synthetic note. A future actual dated occurrence
  must be represented distinctly; this mission does not create occurrences.
- Flutter mapping rejects timetable entries whose group or lecturer UID
  differs from the parent offering. Student repository reads also reject
  mismatched offering/course/semester/group references from an enrollment.
- Enrollment IDs are deterministic: `{offeringId}_{studentUid}`. The trusted
  seeder uses create-only writes, accepts an exact existing document on retry,
  and fails on conflicts rather than overwriting them.
- Read rules allow active trusted users to read semester/course catalogs;
  students can query only their own enrollments and get only offerings backed
  by their deterministic active enrollment; lecturers can query/get only
  offerings assigned to their UID. All academic client writes are denied.
  The existing own-profile rule is preserved. Other and future collections
  remain denied by the catch-all.

### Query patterns and indexes

- Student enrollments: query `enrollments` with `studentUid == auth.uid`.
  Filter a selected semester client-side to avoid a composite index; rules
  require the ownership equality in the query.
- Student offerings: get each `courseOfferings/{courseOfferingId}` referenced
  by an owned `enrollments` document. Students cannot list offerings.
- Lecturer offerings: query `courseOfferings` with `lecturerUid == auth.uid`;
  apply an optional semester filter client-side. Rules require the lecturer
  ownership equality.
- Semester/course detail: direct document gets by referenced IDs.
- These patterns require only Firestore's automatic single-field indexes.
  No `firestore.indexes.json` was added.

### Provisioning and access limitations

- `npm --prefix functions run seed:academic-demo` is guarded by the exact
  `demo-smartumc` project ID and loopback Auth and Firestore emulator hosts.
  It provisions synthetic lecturer/student Auth identities through the
  existing trusted Mission 06 helper and creates matching profiles plus the
  academic fixture. Set `SMARTUMC_SEED_PASSWORD` only in the local process
  environment; it is removed before account operations and never logged.
- Reset means stopping the emulators and clearing their local emulator data;
  then start Auth and Firestore emulators again and rerun the seeder. Do not
  point this script at a live Firebase project.
- Student semester-specific enrollment filtering occurs client-side after
  the own-enrollment query. Lecturer roster access is intentionally not added.
- `attendanceSessions`, `attendanceRecords`, and `bulletins` are still
  inaccessible and reserved for later missions.

### Verification status

- **Passed:** Functions TypeScript build; 10 Functions unit tests, including
  dataset shape, deterministic IDs, exact retry behavior and conflict refusal.
- **Passed:** Auth/Firestore Emulator integration on `demo-smartumc` verified
  exact seed counts (32 created, then 32 already present), deterministic
  duplicate prevention, student-owned enrollment/offering access,
  assigned/unassigned lecturer access, denied client academic writes,
  unauthenticated denial, and existing profile access. The actual seeder CLI
  created 32 records using only emulator services and a generated synthetic
  password; emulators shut down cleanly.
- **Passed:** Flutter analyzer (no issues) and 12 Flutter tests. Functions
  TypeScript build and 10 Functions tests passed. The current shell used
  Node.js 24.21.0 for the Functions build/tests; the package remains
  configured for Node.js 22. Android Studio JBR OpenJDK 21.0.10 ran emulators.
  No Functions Emulator or production service was used for this mission.

### Mission 07.3 runtime limitation

- **Project director approved continuing:** Node.js 22.23.4 was unavailable
  for verification. The recorded Functions validation/tests ran on Node.js
  24.21.0; Node.js 22 compatibility remains unverified.

## Mission 07.2 production and attendance principles

- **Confirmed requirement:** The production database starts with empty
  application data. Synthetic users and academic records are for local
  development and emulator testing only. The seeder guards against production
  use; no production seed operation exists.
- **Confirmed requirement:** Super Admin will create student accounts and
  profile information through a future trusted workflow. Account creation
  does not create enrollment or timetable assignments. Academic records are
  managed separately; student clients cannot write them. Empty states are
  valid and expected.
- **Confirmed requirement for Mission 08:** Attendance should minimize fraud
  and provide evidence for lecturer review, not promise prevention of every
  proxy. A QR scan and location reading do not prove physical presence.
- **Confirmed requirement for Mission 08:** No fixed geofence radius is
  enforced initially. Physical-class location evidence includes latitude,
  longitude, reported accuracy, and timestamp when available. Permission
  denial, unavailable location, and unreliable readings are distinguishable;
  these conditions alone do not automatically reject submission. Online
  attendance can omit precise location and the lecturer chooses the session
  mode.
- **Confirmed requirement:** Preserve green/yellow/red meanings already
  documented; store location evidence separately from submission status and
  lecturer judgement.
- **Not implemented:** Attendance sessions/records, QR generation/rotation,
  GPS collection/validation, attendance submission, bulletins, Super Admin
  UI, and production provisioning remain outside Mission 07.2.
