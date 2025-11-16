import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:campus_gaurd_final/auth_screen.dart';
import 'package:campus_gaurd_final/home_screen.dart';
import 'package:campus_gaurd_final/active_sos_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const CampusGuardApp());
}

class CampusGuardApp extends StatelessWidget {
  const CampusGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus Guard',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return const _HomeScreenWithActiveSOSCheck();
          }
          return const AuthScreen();
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class _HomeScreenWithActiveSOSCheck extends StatefulWidget {
  const _HomeScreenWithActiveSOSCheck();

  @override
  State<_HomeScreenWithActiveSOSCheck> createState() => _HomeScreenWithActiveSOSCheckState();
}

class _HomeScreenWithActiveSOSCheckState extends State<_HomeScreenWithActiveSOSCheck> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkActiveSOS();
  }

  Future<void> _checkActiveSOS() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _isChecking = false);
      return;
    }

    try {
      final activeSOS = await _firestore
          .collection('sos_events')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (mounted) {
        if (activeSOS.docs.isNotEmpty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ActiveSosScreen(sosId: activeSOS.docs.first.id),
            ),
          );
        } else {
          setState(() => _isChecking = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return const HomeScreen();
  }
}
