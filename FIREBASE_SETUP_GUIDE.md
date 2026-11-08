# SMARTUMC — Firebase Project Configuration & Integration Guide

This guide details the end-to-end setup and architecture plan for connecting **SmartUMC** to a single, unified Firebase project supporting three role-based interfaces across Android mobile and Flutter Web.

---

## 1. Project Overview & Multi-Platform Architecture

SmartUMC shares **one Flutter codebase** and connects to **one unified Firebase backend**:

```
                              ┌────────────────────────────────────────┐
                              │            SmartUMC Flutter            │
                              │                Codebase                │
                              └───────────────────┬────────────────────┘
                                                  │
                  ┌───────────────────────────────┼───────────────────────────────┐
                  ▼                               ▼                               ▼
       ┌─────────────────────┐         ┌─────────────────────┐         ┌─────────────────────┐
       │   Student Mobile    │         │  Lecturer Dashboard │         │ Super Admin Dashb.  │
       │    (Android App)    │         │     (Flutter Web)   │         │     (Flutter Web)   │
       └──────────┬──────────┘         └──────────┬──────────┘         └──────────┬──────────┘
                  │                               │                               │
                  └───────────────────────────────┼───────────────────────────────┘
                                                  │
                                                  ▼
                               ┌─────────────────────────────────────┐
                               │       Shared Firebase Project       │
                               │             (SmartUMC)              │
                               ├─────────────────────────────────────┤
                               │ • Firebase Authentication           │
                               │ • Cloud Firestore                   │
                               │ • Firebase Storage                  │
                               │ • Firebase Cloud Functions          │
                               │ • Firebase Cloud Messaging (FCM)    │
                               └─────────────────────────────────────┘
```

- **Student Interface**: Android mobile application designed for student attendance, timetable tracking, academic records, and university bulletins.
- **Lecturer Interface**: Desktop-first Flutter Web dashboard designed for attendance session management, dynamic QR code generation, and student verification.
- **Super Admin Interface**: Desktop-first Flutter Web dashboard for complete university administration, faculty management, student enrollments, and system configurations.

---

## 2. Planned Firebase Services

| Service | Primary Purpose in SmartUMC | Target Interfaces |
| :--- | :--- | :--- |
| **Firebase Authentication** | Canonical user identity management (UID), session tokens, and secure sign-in handling. | Student, Lecturer, Super Admin |
| **Cloud Firestore** | Primary NoSQL document database storing application state, role mappings, attendance logs, timetables, and academic records. | Student, Lecturer, Super Admin |
| **Firebase Storage** | Object storage for student profile photos, bulletin banners, official university documents, and academic attachments. | Student, Lecturer, Super Admin |
| **Cloud Functions** | Trusted serverless backend execution for privileged operations: matric number lookup, role verification/custom claims, attendance validation, and account provisioning. | Backend / All Interfaces |
| **Firebase Cloud Messaging (FCM)** | Targeted push notifications for timetable schedule changes, attendance alerts, and university bulletins. | Student Mobile (Android) |

---

## 3. Discovered Project Configuration

From inspection of the existing project files:

- **Android Namespace / Application ID**: `com.example.smartumc`  
  *(Located in [android/app/build.gradle.kts](file:///d:/smartumc/android/app/build.gradle.kts#L9-L24))*
- **Web App Title**: `smartumc`  
  *(Located in [web/index.html](file:///d:/smartumc/web/index.html#L32))*
- **Target Android Compile / Java Compatibility**: Java 17, Android Gradle Plugin 8.11.1, Kotlin 2.2.20.

> [!IMPORTANT]
> The current Android application ID is the default `com.example.smartumc`. Before production release or publishing to Google Play, the application ID should optionally be updated to a registered institutional domain (e.g. `edu.umc.smartumc`). The initial Firebase registration can proceed with `com.example.smartumc` for development.

---

## 4. Manual Firebase Console Setup Steps

To initialize the backend, execute the following steps in the [Firebase Console](https://console.firebase.google.com/):

### Step A: Create the Firebase Project
1. Open the Firebase Console and click **Add project**.
2. Enter the project name: `SmartUMC`.
3. Firebase will generate a unique project ID (e.g. `smartumc-xxxxx`). Note this project ID.
4. Google Analytics can be toggled per organizational preferences (recommended for crash and usage telemetry).
5. Click **Create project** and await completion.

### Step B: Register the Android Application
1. In Project Overview, select the **Android** icon (`+ Add app`).
2. Provide the Android package name exactly matching the Gradle configuration:
   - **Android package name**: `com.example.smartumc`
   - **App nickname**: `SmartUMC Android (Student)`
3. **Debug signing certificate SHA-1**:
   - Required for Firebase Auth phone/Google providers and dynamic links.
   - Obtain from your local debug keystore via standard keytool when configuring auth.
4. Click **Register app**.
5. *Note: Do not download or commit `google-services.json` manually if using FlutterFire CLI, as FlutterFire will manage this automatically.*

### Step C: Register the Web Application
1. In Project Overview, select the **Web** icon (`</> Add app`).
2. Enter the app nickname: `SmartUMC Web (Lecturer & Admin)`.
3. Check or leave unchecked Firebase Hosting (can be activated later).
4. Click **Register app**.

### Step D: Configure Firebase Authentication
1. Navigate to **Build > Authentication** and click **Get started**.
2. Under the **Sign-in method** tab, enable:
   - **Email/Password**: Enable email sign-in (used directly by lecturers and administrators; student matric number workflow will map to Firebase Auth via Cloud Functions or programmatic email aliases).
3. Ensure **Email link (passwordless sign-in)** remains disabled unless specified.
4. Ensure public sign-ups are restricted (users are provisioned by admin/system, not self-registered).

### Step E: Enable Cloud Firestore
1. Navigate to **Build > Firestore Database** and click **Create database**.
2. Choose database location: Select the region nearest to users (e.g. `asia-southeast1` for Southeast Asia).
3. Security rules mode: Select **Start in production mode** (all reads/writes locked down by default).
4. Initial planned collections schema:
   - `users/`: `{ uid, role, email, displayName, createdAt, isActive }`
   - `students/`: `{ matricNumber, uid, programme, intake, faculty, status }`
   - `lecturers/`: `{ staffId, uid, department, faculty, coursesAssigned }`
   - `super_admins/`: `{ staffId, uid, permissions }`
   - `attendance_sessions/`: `{ sessionId, courseCode, lecturerId, qrToken, validUntil, status }`
   - `attendance_records/`: `{ recordId, sessionId, studentId, matricNumber, timestamp, status }`
   - `bulletins/`: `{ bulletinId, title, content, targetAudience, authorId, createdAt }`

### Step F: Enable Firebase Storage
1. Navigate to **Build > Storage** and click **Get started**.
2. Select **Start in production mode**.
3. Choose the storage location matching your Cloud Firestore region.
4. Storage folder layout:
   - `/profiles/{uid}/avatar.jpg`
   - `/bulletins/{bulletinId}/banner.png`
   - `/attachments/{courseCode}/{fileId}.pdf`

### Step G: Plan Cloud Functions & Cloud Messaging
1. **Cloud Functions**: Reserved for privileged actions (role assignment, custom token generation for matric-number sign-in, attendance token rotation). Requires the Blaze (pay-as-you-go) plan on Firebase.
2. **Firebase Cloud Messaging**: APNs and Web Push credentials can be configured when push notification requirements are implemented.

---

## 5. FlutterFire Integration Procedure

The official **FlutterFire CLI** automates platform registrations and generates configuration files without manual errors or placeholder guessing.

### Prerequisites (When Authorized to Run)
1. Ensure Node.js (v18+) and npm are installed on the development workstation.
2. Install the Firebase CLI:
   ```powershell
   npm install -g firebase-tools
   ```
3. Authenticate with your Google account:
   ```powershell
   firebase login
   ```
4. Install the FlutterFire CLI globally:
   ```powershell
   dart pub global activate flutterfire_cli
   ```

### Execution Steps (Future Integration Phase)
1. From the project root (`d:\smartumc`), run:
   ```powershell
   flutterfire configure --project=<YOUR_FIREBASE_PROJECT_ID>
   ```
2. Select the platforms: **Android** and **Web**.
3. The FlutterFire CLI will automatically:
   - Verify the registered Android app `com.example.smartumc`.
   - Register the Web app if not already linked.
   - Generate [`lib/firebase_options.dart`](file:///d:/smartumc/lib/firebase_options.dart) containing official credentials for each platform.
   - Download [`android/app/google-services.json`](file:///d:/smartumc/android/app/google-services.json).
   - Configure Android Gradle scripts.

### Required Flutter Dependencies (To Add in Future Mission)
Once authorized to modify `pubspec.yaml`, the required packages are:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Firebase Core (Required for all Firebase services)
  firebase_core: ^3.12.1

  # Authentication
  firebase_auth: ^5.5.1

  # Cloud Firestore Database
  cloud_firestore: ^5.6.5

  # Firebase Cloud Storage
  firebase_storage: ^12.4.4

  # Cloud Functions
  cloud_functions: ^5.3.4

  # Push Notifications
  firebase_messaging: ^15.2.4
```

*(Exact package versions will be resolved against the active Flutter SDK upon installation).*

---

## 6. Security Considerations & Best Practices

1. **Synthetic Data Policy**:
   - Only use synthetic demonstration accounts, mock student matric numbers, and simulated attendance records.
   - Never import or test with real personal student data (complying with personal data protection regulations).
2. **Zero Client Secret Exposure**:
   - Never store Firebase service account keys, admin private keys, or elevated database credentials inside the Flutter codebase or repository.
   - The generated `firebase_options.dart` and `google-services.json` contain public identifiers (API keys, project IDs) designed to identify client apps, not secret authorization keys.
3. **Strict Firestore Security Rules**:
   - Authorization must be enforced server-side.
   - Users can only read and write documents permitted by their backend-verified role:
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       // Helper functions
       function isAuthenticated() {
         return request.auth != null;
       }
       function getUserRole() {
         return request.auth.token.role; // Custom claim or Firestore lookup
       }
       function isStudent() {
         return isAuthenticated() && getUserRole() == 'student';
       }
       function isLecturer() {
         return isAuthenticated() && getUserRole() == 'lecturer';
       }
       function isAdmin() {
         return isAuthenticated() && getUserRole() == 'admin';
       }

       // Strict role-based collection rules
       match /users/{userId} {
         allow read: if isAuthenticated() && (request.auth.uid == userId || isAdmin());
         allow write: if isAdmin(); // Clients cannot alter their own user document or role
       }
       
       match /attendance_sessions/{sessionId} {
         allow read: if isAuthenticated();
         allow write: if isLecturer() || isAdmin();
       }
       
       match /bulletins/{bulletinId} {
         allow read: if isAuthenticated();
         allow write: if isAdmin();
       }
     }
   }
   ```
4. **Privileged Operations via Cloud Functions**:
   - Role elevation, account provisioning, and matric-to-identity binding must execute strictly within authenticated Cloud Functions.
   - Client applications must never write directly to role fields.

---

## 7. Future Integration Sequence

1. **Mission 03 (Current)**: Firebase Project Configuration & Integration Guide established.
2. **Mission 04 (Next)**: Manual Firebase project creation in Firebase Console and dependency integration approval.
3. **Mission 05**: FlutterFire configuration execution to generate official `firebase_options.dart` and `google-services.json`.
4. **Mission 06**: Concrete implementation of `AuthRepository` (`FirebaseAuthRepository`) wiring `AuthUser`, `AuthState`, and `AuthService`.
5. **Mission 07**: Role-based routing activation in `AppRouter` directing authenticated roles to respective modules.
6. **Mission 08+**: Successive implementation of Super Admin dashboard, Lecturer dashboard, and Student mobile app interfaces.
