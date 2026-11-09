# SmartUMC Agent Instructions

## Project identity and scope

SmartUMC is a Flutter/Dart FYP demonstration using Firebase Authentication and Cloud Firestore. The confirmed demonstration scope is Diploma in Information Technology (DIT), three representative semesters in academic session 2026/2027, and synthetic demonstration data only. Never use real university or student records.

## Confirmed architecture

- One shared Flutter repository and Firebase backend; Cloud Firestore is the primary database.
- Student experience: Android application.
- Lecturer experience: separate web interface (deployment boundary is pending approval).
- Super Admin is a limited administrative role for managing synthetic demonstration data, not a mandate for a broad third application.
- Student sign-in uses matric number and password. Staff identity and role assignment require trusted verification; clients cannot assign or elevate roles.
- Attendance evidence is used to minimize fraud and support lecturer review, not to guarantee zero proxy attendance. Physical-class workflows collect location evidence when available; unavailable or unreliable GPS alone must not automatically reject a submission. Online sessions may omit precise location, and the lecturer configures the attendance mode. Dynamic QR remains optional and lecturer-controlled, refreshing every minute when enabled.
- Preserve the approved display indicators: green means student location was successfully traced; yellow means the student scanned but did not open location; red means the student did not scan. Keep detailed location verification results separate from these indicators.
- Use the minimum Firestore model justified by approved requirements. Do not adopt the historical 22-collection proposal by default.

## Implementation status discipline

Inspect relevant source and configuration before making changes. Never infer implementation from plans, comments, UI, generated artifacts, or dependencies alone. Label findings in documentation as **Confirmed requirement**, **Code-verified implementation**, **Proposed design**, or **Pending approval**. Report conflicts and unresolved decisions instead of silently resolving them.

## Coding conventions

- Use readable, idiomatic Dart and existing analyzer/lint conventions.
- Inspect existing architecture and state-management patterns before adding or changing code.
- Prefer reusable widgets and clear separation between presentation, application/domain logic, and data access.
- Keep changes scoped; do not replace working code without understanding its purpose.
- Do not add dependencies without explaining their purpose and obtaining project director approval.
- Preserve Android and web compatibility where code is shared; verify both targets when relevant.

## Folder organization principles

- Keep Flutter application code under `lib/`, organized by feature and shared core responsibilities.
- Keep tests under `test/` and mirror feature boundaries where practical.
- Keep reusable agent skills under `.agents/skills/<skill-name>/SKILL.md`.
- Keep project documentation under `docs/`; preserve historical plans at the repository root unless specifically approved otherwise.
- Add folders/files only for a justified, approved feature; avoid speculative scaffolding.

## Security requirements

- Never expose credentials, service-account keys, private signing material, or QR secrets.
- Never store passwords in Firestore.
- Never trust client-provided roles or allow clients to assign privileged roles.
- Enforce authorization in Firestore Security Rules and trusted backend validation; UI visibility and client routing are not security boundaries.
- Protect attendance records and QR secrets from unauthorized reads/writes, replay, and forged submissions.
- Treat location results as verification data and retain the approved distinction between display indicators and detailed location results.
- Never use real student information.
- Do not modify Firebase production configuration or deploy Firebase services without explicit project director approval.

## Database design principles

- Firestore is the primary database. The minimal academic schema and backend attendance collections (`attendanceSessions`, `attendanceRecords`) are implemented; bulletin workflows remain unimplemented. Attendance reads/writes go through trusted Cloud Functions; direct client access is denied.
- Production application data must start empty. Synthetic users and academic records are local emulator/development fixtures only; never automatically seed production.
- Account creation and academic enrollment are separate trusted operations. A new account receives no enrollment or timetable assignment automatically, and students cannot modify trusted academic records.
- Start with the smallest schema that supports the approved DIT demonstration workflows.
- Add collections and fields only when tied to an approved requirement; document purpose, ownership, access, and lifecycle.
- Keep trusted writes in backend operations where authorization or integrity depends on them.
- Do not treat any schema in historical plans as approved or implemented without verification.

## Testing expectations

- Add appropriate unit, widget, and integration tests for changed behavior.
- Cover authentication, trusted role resolution, role routing, Firestore authorization, attendance, QR expiry/rotation, location outcomes, negative cases, and regressions as relevant.
- Report tests that could not be run and the reason. Do not claim tests passed unless they were executed and observed.
- Use synthetic data in all tests.

## Documentation requirements

- Keep requirements, architecture, database schema, and roadmap documentation current with approved decisions and verified code.
- Distinguish requirements from code-verified implementation, proposed design, and pending approval.
- Record assumptions, unresolved decisions, and security implications; do not invent missing product requirements.
- Preserve historical authentication plans; do not silently present their proposals as current truth.

## Git and version-control expectations

- Inspect repository status and diffs before and after changes when Git metadata is available.
- Do not discard, overwrite, or reformat unrelated user changes.
- Keep changes focused and reviewable; describe intended commit boundaries, but do not commit or push unless explicitly asked.
- If Git metadata is unavailable, report that limitation rather than assuming a clean tree.

## AI agent restrictions

1. Inspect existing files before changing them.
2. Never replace working code without understanding its purpose.
3. Never introduce dependencies without explaining and obtaining approval.
4. Never change approved architectural decisions independently.
5. Never assume a documented feature is implemented.
6. Never invent database collections or application requirements.
7. Never expose credentials or secrets.
8. Never use real student information.
9. Never modify Firebase production configuration or deploy services without explicit approval.
10. Report unresolved decisions instead of making unsupported assumptions.
