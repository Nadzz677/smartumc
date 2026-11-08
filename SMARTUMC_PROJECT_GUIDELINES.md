# SMARTUMC — Project Guidelines

## Project Overview
SmartUMC is a university management application consisting of three role-based interfaces sharing one Flutter codebase and Firebase backend:
1. **Student** — Android mobile application.
2. **Lecturer** — Desktop-first web dashboard for attendance management.
3. **Super Admin** — Desktop-first web dashboard for managing university information and student records.

## Architecture Principles
- **One Flutter project**: Unified codebase supporting mobile and desktop-first web targets.
- **Three role-based interfaces**: Tailored user experiences and routing for Student, Lecturer, and Super Admin.
- **Shared Firebase backend**: Consolidated Cloud Firestore, Firebase Authentication, Storage, Functions, and Cloud Messaging.
- **Modular feature-based folder structure**: Clean boundaries organized by functional area and target role.
- **Reusable components where appropriate**: Common UI elements and helper utilities centralized under `core/` and `shared/`.
- **Separation of UI, business logic and data access**: Clear distinction between presentation layers, state/business logic, models, and repositories/services.
- **Secure role-based authorization**: Strict role validation preventing unauthorized navigation and actions.

## Development Rules
- Flutter and Dart exclusively for frontend development.
- Preserve existing approved Figma designs.
- Use synthetic demonstration data only.
- Never use real student personal information.
- Do not store passwords in Cloud Firestore.
- Privileged operations must be handled by trusted backend functions.
- Do not allow users to modify their own roles.
- Keep the code modular, readable and maintainable.

## Development Sequence
1. Project foundation.
2. Authentication and role-based routing.
3. Super Admin Dashboard.
4. Lecturer Dashboard.
5. Student Mobile Application.
6. Firebase integration.
7. Testing and refinement.
