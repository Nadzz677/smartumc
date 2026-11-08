# SmartUMC Requirements

Labels distinguish approved scope from inspected implementation and future design. A documented requirement is not proof of implementation.

## Confirmed requirements

- Flutter and Dart frontend; Firebase backend; Cloud Firestore is the primary database.
- One shared Flutter repository. Student experience is an Android application; lecturer experience is a separate web interface. Super Admin is a limited role for synthetic demonstration data.
- Academic scope is Diploma in Information Technology (DIT), with three representative semesters in academic session 2026/2027.
- Use synthetic demonstration data only. Do not use real university or student records.
- Student login uses matric number and password. Staff identity and role assignment require trusted identity verification. Clients must not assign privileged roles.
- Geolocation verification is mandatory for attendance. Dynamic QR generation is optional and controlled by lecturers; when enabled it refreshes every one minute.
- Preserve display indicators: **Green** = student location successfully traced; **Yellow** = student scanned but did not open location; **Red** = student did not scan.
- Keep detailed location verification results separate from the three display indicators.
- Use a minimal Firestore architecture; add collections only when justified. The historical 22-collection proposal is not automatically approved.

## Code-verified implementation (inspection baseline)

- Firebase Core initialization and generated Android/web Firebase options are present.
- `AuthUser`, `AuthState`, `AuthService`, and an abstract `AuthRepository` exist. The service validates empty credentials but delegates authentication to the abstract repository.
- Student, lecturer, and admin role values and route constants/helpers exist. `AppRouter` currently renders placeholders.
- `main.dart` currently launches a Firebase test/counter screen.
- No concrete Firebase Auth repository, Firestore operations/rules, attendance/location/QR implementation, role dashboard, or DIT demonstration dataset was found in the inspected source.

## Proposed design

- Build only the workflows needed to demonstrate the confirmed DIT scope; use trusted backend validation wherever identity, roles, attendance, or QR integrity is at stake.
- Keep attendance display indicators as defined above and persist richer location verification details separately.

## Pending approval

- Lecturer web interface deployment boundary (separate deployment in this repository versus a separate project/codebase).
- Exact semester dates and synthetic DIT courses, students, lecturers, and enrollments for the three-semester dataset.
- Geofence parameters and detailed result taxonomy for location verification, provided they do not alter the approved display indicators.
- Identity mapping mechanism for matric-number sign-in and the staff sign-in identifier.
- Backend services/billing constraints and whether password recovery is in demonstration scope.
