# Database Schema Planning

## Confirmed requirements

- Cloud Firestore is the primary database.
- Data is limited to a synthetic DIT demonstration with three representative semesters in 2026/2027.
- Keep the schema minimal and add collections only when justified. Do not automatically use the historical 22-collection proposal.
- Client-provided roles are untrusted; privileged writes require trusted validation. Passwords must never be stored in Firestore.
- Attendance requires geolocation verification. Preserve display indicators separately from detailed verification results.

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
- Detailed location-result fields and geofence parameters.
- Which attendance/session operations are client-readable versus backend-only.
