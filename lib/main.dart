import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/authentication/auth_service.dart';
import 'core/authentication/firebase_auth_repository.dart';
import 'core/academics/firebase_academic_repository.dart';
import 'core/academics/academic_repository.dart';
import 'core/design_system/app_theme.dart';
import 'features/authentication/authentication_gate.dart';
import 'firebase_options.dart';

const _useFirebaseEmulators = bool.fromEnvironment(
  'SMARTUMC_USE_FIREBASE_EMULATORS',
  defaultValue: false,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (_useFirebaseEmulators) {
    if (!kDebugMode) {
      throw StateError(
        'Firebase Emulators may only be enabled in a debug build.',
      );
    }
    final host = kIsWeb || defaultTargetPlatform != TargetPlatform.android
        ? '127.0.0.1'
        : '10.0.2.2';
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  }

  final authService = AuthService(
    repository: FirebaseAuthRepository(
      auth: FirebaseAuth.instance,
      firestore: FirebaseFirestore.instance,
    ),
  );
  final academicRepository = FirebaseAcademicRepository(
    auth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
  );
  runApp(
    SmartUMCApp(
      authService: authService,
      academicRepository: academicRepository,
    ),
  );
}

class SmartUMCApp extends StatelessWidget {
  const SmartUMCApp({
    required this.authService,
    required this.academicRepository,
    super.key,
  });

  final AuthService authService;
  final AcademicRepository academicRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartUMC',
      theme: AppTheme.light,
      home: AuthenticationGate(
        authService: authService,
        academicRepository: academicRepository,
      ),
    );
  }
}
