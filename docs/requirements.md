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
- Geolocation verification is mandatory for attendance. Dynamic QR generation is optional and controlled by lecturers; when enabled it refreshes every one minute.
- Preserve display indicators: **Green** = student location successfully traced; **Yellow** = student scanned but did not open location; **Red** = student did not scan.
- Keep detailed location verification results separate from the three display indicators.
- Use a minimal Firestore architecture; add collections only when justified. The historical 22-collection proposal is not automatically approved.

## Code-verified implementation

- Firebase Core initialization and generated Android/web Firebase options are present.
- Flutter initializes Firebase using the generated client options. Debug builds opt in to local Auth/Firestore emulators with `SMARTUMC_USE_FIREBASE_EMULATORS=true`; emulator hosts are configured for Android Emulator and web/desktop. The default is emulator-off.
- A concrete Firebase Auth repository authenticates students with the deterministic matric alias and staff with email, observes ID-token changes, force-refreshes the initial/restored token, validates canonical Custom Claims against the server-read profile, rejects inactive/missing/malformed/mismatched authorization, restores sessions, and signs out cleanly.
- The authentication gate keeps protected experiences hidden while authorization resolves and routes authorized users by role. Client-side routing is not a security boundary.
- A local provisioning process creates synthetic Firebase Auth accounts, assigns trusted claims, and writes matching `users/{uid}` profiles. It refuses to run unless the Auth and Firestore emulators are local and the project is exactly `demo-smartumc`.
- Firestore Rules allow only an authenticated user's single-document `get` of `users/{uid}` where the path UID equals their Firebase UID. Listing, all profile writes, and all other collections remain denied.
- Focused Dart and Functions tests cover matric aliasing, role/claim validation, routing/session transitions, provisioning validation/retry/rollback, and emulator profile access. See `docs/architecture.md` for executed verification results.
- Attendance, location verification, dynamic QR, password recovery, and academic data workflows remain unimplemented. Password recovery is outside Mission 06 and requires a separate project decision; the `.invalid` alias cannot receive email.

## Proposed design

- Build only the workflows needed to demonstrate the confirmed DIT scope; use trusted backend validation wherever identity, roles, attendance, or QR integrity is at stake.
- Keep attendance display indicators as defined above and persist richer location verification details separately.

## Pending approval

- Lecturer web interface deployment boundary (separate deployment in this repository versus a separate project/codebase).
- Exact semester dates and synthetic DIT courses, students, lecturers, and enrollments for the three-semester dataset.
- Geofence parameters and detailed result taxonomy for location verification, provided they do not alter the approved display indicators.
- Official institutional matric-number format; the current validator accepts 4–20 ASCII letters, digits, and hyphens, based on the approved example and should be tightened if the director supplies a formal format.
- Production staff identity verification/provisioning process and backend services/billing constraints. Mission 06 establishes only the trusted local synthetic-account process.
- Student password-recovery channel and policy. Email reset is not implemented and the `.invalid` alias is not a recovery channel.
