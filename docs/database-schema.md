# Database Schema Planning

## Confirmed requirements

- Cloud Firestore is the primary database.
- Data is limited to a synthetic DIT demonstration with three representative semesters in 2026/2027.
- Keep the schema minimal and add collections only when justified. Do not automatically use the historical 22-collection proposal.
- Client-provided roles are untrusted; privileged writes require trusted validation. Passwords must never be stored in Firestore.
- Attendance requires geolocation verification. Preserve display indicators separately from detailed verification results.

## Code-verified implementation

No Firestore collection reads/writes, schema models/repositories, rules, indexes, or seed data were found in the inspected source. Firebase Firestore dependency/configuration exists, but this does not establish a deployed or implemented schema.

### Mission 05 security foundation status

- `firestore.rules` now provides a deny-all client-access baseline. This is intentionally conservative and means authenticated app clients cannot yet read or write Firestore documents.
- No collection schema, index, seed data, or client access policy has been implemented. The design below remains proposed pending approval.
- Trusted backend code will bypass Firestore Rules when using the Admin SDK, so each future privileged operation must validate caller identity, role, ownership, and request data itself.
- Mission 05.3 verified the current deny-all baseline with the local Firestore Emulator under `demo-smartumc`: an unauthenticated document read was denied as expected. The emulator was shut down after the probe. This does not validate any future collection-specific rules or schema because neither is implemented.

## Proposed design (not an approved schema)

The demonstration will likely need data representing:

- User identity/profile and trusted role mapping.
- DIT academic semesters, course definitions/offerings, and synthetic enrollments.
- Attendance sessions and attendance records, including the approved indicator and separately stored location verification details.

These are logical data needs, not approved Firestore collection names or a finalized structure. Prefer stable IDs, explicit ownership, minimal personal fields, and backend-controlled integrity fields. Keep QR secrets inaccessible to clients. Define access rules alongside each schema decision.

## Pending approval

- Exact collection/document structure, field names, retention, and access matrix.
- Semester identifiers/date boundaries and synthetic course/enrollment dataset.
- Detailed location-result fields and geofence parameters.
- Which attendance/session operations are client-readable versus backend-only.
