import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/user_role.dart';
import 'auth_repository.dart';
import 'auth_state.dart';
import 'auth_user.dart';
import 'matric_identity.dart';

/// Firebase-backed repository. Roles are read from verified ID-token claims;
/// the profile is used only as a consistency and active-account check.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : _auth = auth,
       _firestore = firestore;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  Stream<AuthState> get authStateChanges {
    String? initiallyRefreshedUid;
    return _auth.idTokenChanges().asyncMap((user) async {
      if (user == null) {
        initiallyRefreshedUid = null;
        return const Unauthenticated();
      }
      final refreshToken = initiallyRefreshedUid != user.uid;
      initiallyRefreshedUid = user.uid;
      try {
        return Authenticated(
          await _resolveAuthorizedUser(user, forceRefresh: refreshToken),
        );
      } on AuthAuthorizationException {
        await _auth.signOut();
        return const Unauthenticated(message: 'This account is not authorized for SmartUMC.');
      } on FirebaseAuthException catch (error) {
        if (error.code == 'user-disabled' || error.code == 'user-token-expired') {
          await _auth.signOut();
          return const Unauthenticated(message: 'This account is not authorized for SmartUMC.');
        }
        return const AuthFailure('Unable to verify your account. Please try again.');
      } catch (_) {
        return const AuthFailure('Unable to verify your account. Please try again.');
      }
    });
  }

  @override
  Future<AuthUser?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      return await _resolveAuthorizedUser(user, forceRefresh: true);
    } on AuthAuthorizationException {
      await _auth.signOut();
      return null;
    }
  }

  @override
  Future<AuthUser> signInWithMatricNumber({
    required String matricNumber,
    required String password,
  }) async {
    final email = MatricIdentity.emailAlias(matricNumber);
    return _signIn(
      email: email,
      password: password,
      allowedRoles: const {UserRole.student},
    );
  }

  @override
  Future<AuthUser> signInWithStaffCredentials({
    required String email,
    required String password,
  }) => _signIn(
    email: email.trim().toLowerCase(),
    password: password,
    allowedRoles: const {UserRole.lecturer, UserRole.superAdmin},
  );

  Future<AuthUser> _signIn({
    required String email,
    required String password,
    required Set<UserRole> allowedRoles,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) throw const AuthAuthorizationException();
      final authorizedUser = await _resolveAuthorizedUser(user, forceRefresh: true);
      if (!allowedRoles.contains(authorizedUser.role)) {
        throw const AuthAuthorizationException();
      }
      return authorizedUser;
    } on AuthAuthorizationException {
      await _auth.signOut();
      throw const AuthAuthorizationException();
    } on FirebaseAuthException {
      // Keep invalid email/password and missing accounts indistinguishable.
      throw const AuthSignInException();
    }
  }

  Future<AuthUser> _resolveAuthorizedUser(
    User user, {
    bool forceRefresh = false,
  }) async {
    final token = await user.getIdTokenResult(forceRefresh);
    final profileSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .get(const GetOptions(source: Source.server));
    if (!profileSnapshot.exists) throw const AuthAuthorizationException();

    final profile = profileSnapshot.data();
    if (profile == null) throw const AuthAuthorizationException();

    final authorizedUser = AuthUser.fromTrustedSources(
      uid: user.uid,
      claims: token.claims ?? const <String, dynamic>{},
      profile: profile,
      email: user.email,
    );
    final profileEmail = profile['email'];
    if (profileEmail is! String ||
        !MatricIdentity.matchesAuthProfile(
          authEmail: user.email,
          profileEmail: profileEmail,
          role: authorizedUser.role,
          matricNumber: authorizedUser.matricNumber,
        )) {
      throw const AuthAuthorizationException();
    }
    return authorizedUser;
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

class AuthSignInException implements Exception {
  const AuthSignInException();
}
