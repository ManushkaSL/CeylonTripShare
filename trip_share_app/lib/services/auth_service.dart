import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;
  AuthService._() {
    _updateFromUser(_auth.currentUser);
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

  Future<String?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e.code);
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  Future<String?> registerWithEmailAndPassword({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final trimmedEmail = email.trim();
      final credential = await _auth.createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      final trimmedName = username.trim();
      _updateFromUser(credential.user ?? _auth.currentUser);
      notifyListeners();

      if (trimmedName.isNotEmpty) {
        try {
          await credential.user?.updateDisplayName(trimmedName);
          await credential.user?.reload();
          _updateFromUser(_auth.currentUser);
          notifyListeners();
        } catch (e) {
          debugPrint('Profile update after sign up failed: $e');
        }
      }

      return null;
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e.code);
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  String _authErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found for this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
