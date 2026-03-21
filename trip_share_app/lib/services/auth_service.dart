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
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId:
        '230136178640-hock9if7mjn0cb0oe4mqlkkpv93p8r7b.apps.googleusercontent.com',
  );

  bool _isLoggedIn = false;
  String _userName = '';
  String _userEmail = '';
  String _photoUrl = '';

  bool get isLoggedIn => _isLoggedIn;
  String get userName => _userName;
  String get userEmail => _userEmail;
  String get photoUrl => _photoUrl;
  String get userId => _auth.currentUser?.uid ?? '';
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

  Future<String?> signInWithGoogle() async {
    try {
      debugPrint('Starting Google sign-in...');
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('Google sign-in cancelled by user');
        return ''; // user cancelled - empty string indicates no error message to show
      }

      debugPrint('Google user signed in: ${googleUser.email}');
      debugPrint('Requesting authentication...');
      final googleAuth = await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        debugPrint('FAILED: Missing accessToken or idToken');
        debugPrint('AccessToken: ${googleAuth.accessToken}');
        debugPrint('IdToken: ${googleAuth.idToken}');
        return 'Failed to get authentication tokens. Please try again.';
      }

      debugPrint('Creating Firebase credential...');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken!,
        idToken: googleAuth.idToken!,
      );

      debugPrint('Signing in to Firebase with Google credential...');
      await _auth.signInWithCredential(credential);
      debugPrint('Firebase sign-in successful');
      return null; // success
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase auth error: ${e.code} - ${e.message}');
      return _authErrorMessage(e.code);
    } catch (e, stackTrace) {
      debugPrint('Google sign-in error: $e');
      debugPrint('Stack: $stackTrace');
      return 'Google sign-in failed. Please try again.';
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
      debugPrint('Registering user: $email');
      final trimmedEmail = email.trim();
      final credential = await _auth.createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      debugPrint('Account created successfully');
      final trimmedName = username.trim();
      _updateFromUser(credential.user ?? _auth.currentUser);
      notifyListeners();

      if (trimmedName.isNotEmpty && credential.user != null) {
        try {
          debugPrint('Updating display name: $trimmedName');
          await credential.user!.updateDisplayName(trimmedName);
          await credential.user!.reload();
          _updateFromUser(_auth.currentUser);
          notifyListeners();
          debugPrint('Display name updated');
        } catch (e) {
          debugPrint('Profile update after sign up failed: $e');
        }
      }

      debugPrint('Registration completed for: $email');
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase registration error: ${e.code} - ${e.message}');
      return _authErrorMessage(e.code);
    } catch (e) {
      debugPrint('Registration error: $e');
      return 'Something went wrong. Please try again.';
    }
  }

  String _authErrorMessage(String code) {
    debugPrint('Auth error code: $code');
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
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return 'Authentication failed ($code). Please try again.';
    }
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
