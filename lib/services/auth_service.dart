import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;
  AuthService._() {
    _auth.authStateChanges().listen((user) {
      _updateFromUser(user);
      notifyListeners();
    });
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool _isLoggedIn = false;
  String _userName = '';
  String _userEmail = '';
  String _photoUrl = '';

  bool get isLoggedIn => _isLoggedIn;
  String get userName => _userName;
  String get userEmail => _userEmail;
  String get photoUrl => _photoUrl;
  User? get currentUser => _auth.currentUser;

  void _updateFromUser(User? user) {
    if (user != null) {
      _isLoggedIn = true;
      _userName = user.displayName ?? user.email?.split('@').first ?? '';
      _userEmail = user.email ?? '';
      _photoUrl = user.photoURL ?? '';
    } else {
      _isLoggedIn = false;
      _userName = '';
      _userEmail = '';
      _photoUrl = '';
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false; // user cancelled

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      return true;
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
