# SmartUMC Requirements

Labels distinguish approved scope from inspected implementation and future design. A documented requirement is not proof of implementation.

## Confirmed requirements

- Flutter and Dart frontend; Firebase backend; Cloud Firestore is the primary database.
- One shared Flutter repository. Student experience is an Android application; lecturer experience is a separate web interface. Super Admin is a limited role for synthetic demonstration data.
- Academic scope is Diploma in Information Technology (DIT), with three representative semesters in academic session 2026/2027.
- Use synthetic demonstration data only. Do not use real university or student records.
- Student login uses matric number and password; the client normalizes the matric number and maps it to a deterministic internal Firebase Auth email alias. Students never enter that alias, and it is not a password-recovery address.
- Lecturers authenticate with their provisioned Firebase Auth email and password. Super Admin identities are provisioned only through a trusted administrative process. Supported trusted roles are `student`, `lecturer`, and `super_admin`; clients may not assign roles.
- Firebase Auth UID is the canonical SmartUMC identity. Firebase Custom Claims provide the trusted role and active flag; Firestore `users/{uid}` provides the matching profile. Active users with a canonical trusted role may read only their own profile. Clients cannot write user profiles.
- Attendance evidence aims to minimize fraud and support lecturer review; neither a QR scan nor location evidence guarantees physical presence. Dynamic QR generation is optional and lecturer-controlled; when enabled, it refreshes every one minute.
- Preserve display indicators: **Green** = student location successfully traced; **Yellow** = student scanned but did not open location; **Red** = student did not scan.
- Keep detailed location verification results separate from the three display indicators.
- Use a minimal Firestore architecture; add collections only when justified. The historical 22-collection proposal is not automatically approved.

## Code-verified implementation

- Firebase Core initialization and generated Android/web Firebase options are present.
- Flutter initializes Firebase using the generated client options. Debug builds opt in to local Auth/Firestore emulators with `SMARTUMC_USE_FIREBASE_EMULATORS=true`; emulator hosts are configured for Android Emulator and web/desktop. The default is emulator-off.
- A concrete Firebase Auth repository authenticates students with the deterministic matric alias and staff with email, observes ID-token changes, force-refreshes the initial/restored token, validates canonical Custom Claims against the server-read profile, rejects inactive/missing/malformed/mismatched authorization, restores sessions, and signs out cleanly.
- The authentication gate keeps protected experiences hidden while authorization resolves and routes authorized users by role. Client-side routing is not a security boundary.
- A local provisioning process creates synthetic Firebase Auth accounts, assigns trusted claims, and writes matching `users/{uid}` profiles. It refuses to run unless the Auth and Firestore emulators are local and the project is exactly `demo-smartumc`.
- Firestore Rules preserve authenticated own-profile `get` on `users/{uid}` and allow scoped academic reads for active trusted users; profile and academic client writes remain denied. Other collections remain denied.
- Focused Dart and Functions tests cover matric aliasing, role/claim validation, routing/session transitions, provisioning, academic models/seeding, and emulator access rules. See `docs/architecture.md` and `docs/database-schema.md` for executed verification results.
- Attendance, location verification, dynamic QR, and password recovery remain unimplemented. Password recovery is outside Mission 06 and requires a separate project decision; the `.invalid` alias cannot receive email. Academic data foundation is implemented under Mission 07; full academic UI is not.

## Proposed design

- Build only the workflows needed to demonstrate the confirmed DIT scope; use trusted backend validation wherever identity, roles, attendance, or QR integrity is at stake.
- Keep attendance display indicators as defined above and persist richer location verification details separately.

## Pending approval

- Lecturer web interface deployment boundary (separate deployment in this repository versus a separate project/codebase).
- Official semester dates, course code/credit details for Computer Forensic, SULAM and Projek 1, and official offering/lecturer/group/timetable assignments. Existing local data is synthetic only.
- Detailed implementation of location evidence presentation and lecturer review, while preserving the confirmed evidence fields, outcomes, and indicators below.
- Official institutional matric-number format; the current validator accepts 4–20 ASCII letters, digits, and hyphens, based on the approved example and should be tightened if the director supplies a formal format.
- Production staff identity verification/provisioning process and backend services/billing constraints. Mission 06 establishes only the trusted local synthetic-account process.
- Student password-recovery channel and policy. Email reset is not implemented and the `.invalid` alias is not a recovery channel.

## Mission 07.2 confirmed operational requirements

### Production data lifecycle

- **Confirmed requirement:** Production must start with empty application data. Synthetic seed data is restricted to local development and Firebase Emulators; production must never receive demonstration records automatically.
- **Confirmed requirement:** Super Admin is responsible for creating student accounts and entering profile information through a future trusted administrative workflow. Account creation and academic enrollment are separate operations. Creating an account must not assign an enrollment or timetable automatically.
- **Confirmed requirement:** Super Admin manages academic records, including semesters, course offerings, timetable assignments, and university/club bulletins. No dashboard or production provisioning workflow is implemented in this mission.
- **Confirmed requirement:** Empty states are expected application states. Students cannot directly modify trusted academic records. Existing synthetic users, profiles, offerings, enrollments, and schedules are development/test fixtures only.
- **Code-verified implementation:** The academic seed CLI is restricted to project `demo-smartumc` with loopback Auth and Firestore emulator endpoints. No automatic production seeding path was added. The live production data state was not inspected by this implementation task.

### Attendance principles approved for Mission 08

- **Confirmed requirement:** The objective is to minimize attendance fraud and support lecturer review, not guarantee zero proxy attendance. A successful QR scan is not proof of physical presence.
- **Confirmed requirement:** No fixed geofence radius will be enforced initially. For physical classes, capture latitude, longitude, reported accuracy, and timestamp when available. Distinguish location permission denied, location unavailable, and unreliable readings. GPS absence or low reliability alone must not automatically reject attendance submission.
- **Confirmed requirement:** Location evidence is presented separately from submission status and lecturer judgement. Coordinates and reported accuracy are evidence, not guaranteed proof of presence.
- **Confirmed requirement:** Lecturers configure attendance mode. Online attendance can be submitted without precise physical location; location evidence is not mandatory for online sessions.
- **Confirmed requirement:** Preserve indicators exactly: green = location successfully traced when scanned; yellow = scanned but did not open location; red = did not scan. Detailed evidence and GPS reliability remain separate.
- **Not implemented:** QR generation/rotation, attendance sessions/records, GPS collection/validation, and attendance submission remain Mission 08 work.

## Mission 07 academic data status

### Confirmed requirement

- Academic scope is DIT only, session 2026/2027, with three representative
  semesters and synthetic demonstration data only.
- Only Advanced English II (BBA1152, 2 credits) and Pengaturcaraan Web
  (KOM4263, 3 credits) have supplied course references. Computer Forensic,
  SULAM and Projek 1 remain pending confirmation. No official semester dates,
  group schedules or lecturer assignments may be invented.
- Students may read only their own enrolled offerings. Lecturers may read
  offerings assigned to them. Clients may not write academic catalogs,
  offerings, enrollments or trusted user profiles.

### Code-verified implementation

- Mission 07 adds models and a read-only Firestore repository for student
  semesters, enrolled offerings, timetable entries, and lecturer offerings.
  The result type distinguishes loading, empty, data and error states. No
  academic screens or UI redesign are included.
- Local fixtures mark all data synthetic; dates and unconfirmed subject
  details remain null/pending. Two synthetic groups and representative venues
  are used only for local testing.
- The seed command requires the Auth and Firestore emulators, loopback
  endpoints, and exact `demo-smartumc` project ID. Rules preserve own-profile
  access and deny client writes and unimplemented collections.

### Proposed design

- Embedded weekly schedule templates are distinct from dated class
  occurrences. A future occurrence feature should model actual dates
  explicitly rather than treating a recurrence template as an occurrence.
- Current query patterns use owner equality filters and document lookups;
  no composite index is required.

### Pending approval

- Official semester dates/status lifecycle, course codes and credits for the
  three pending subjects, and the official timetable/lecturer/group mapping.
- Whether student timetable views should show lecturer names or only assigned
  lecturer identity. This implementation returns lecturer UID and does not
  broaden user-profile reads.
