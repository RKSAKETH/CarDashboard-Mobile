
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'firestore_service.dart';

/// Service to handle Authentication logic
class AuthService {
  // Singleton instance
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Google Sign In instance
  // Note: For Web, ensure you have added the meta tag with 'google-signin-client_id' in index.html
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Stream to listen to auth state changes (User Login/Logout)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Sign in with Google
  /// Returns the UserCredential if successful
  /// Throws descriptive error messages on failure
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // 1. Trigger the authentication flow
      // On Web: This will trigger a popup. Browser must not block popups.
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // The user canceled the sign-in flow
        return null;
      }

      // 2. Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Sign in to Firebase with the Google User credential
      final userCredential = await _auth.signInWithCredential(credential);

      // 5. Save user profile to Firestore
      if (userCredential.user != null) {
        await FirestoreService().createOrUpdateUserProfile(
          uid: userCredential.user!.uid,
          email: userCredential.user!.email ?? '',
          displayName: userCredential.user!.displayName,
          photoUrl: userCredential.user!.photoURL,
        );
      }

      return userCredential;

    } on FirebaseAuthException catch (e) {
      // Handle Firebase specific Auth errors
      String message = 'Authentication failed.';
      switch (e.code) {
        case 'account-exists-with-different-credential':
          message = 'Account exists with a different sign-in method.';
          break;
        case 'invalid-credential':
          message = 'Invalid credentials provided.';
          break;
        case 'operation-not-allowed':
          message = 'Google sign-in is not enabled in Firebase Console.';
          break;
        case 'user-disabled':
          message = 'This user has been disabled.';
          break;
        case 'user-not-found':
          message = 'No user found with this email.';
          break;
        case 'wrong-password':
          message = 'Wrong password provided.';
          break;
        case 'invalid-verification-code':
          message = 'Invalid verification code.';
          break;
        case 'invalid-verification-id':
          message = 'Invalid verification ID.';
          break;
        default:
          message = 'Error: ${e.message}';
      }
      print('FirebaseAuthException: $message');
      throw message;
      
    } catch (e) {
      // Handle generic errors (Network, Platform, etc.)
      print('Google Sign-In Error: $e');
      if (kIsWeb) {
         print('Web-specific hint: check Authorized Domains in Firebase Console and Client ID in index.html');
      }
      throw 'An unexpected error occurred. Please try again.';
    }
  }


  /// Sign in with Email and Password

  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update last login
      if (userCredential.user != null) {
        await FirestoreService().createOrUpdateUserProfile(
          uid: userCredential.user!.uid,
          email: userCredential.user!.email ?? '',
          displayName: userCredential.user!.displayName,
          photoUrl: userCredential.user!.photoURL,
        );
      }
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthError(e);
    } catch (e) {
      throw 'An unexpected error occurred.';
    }
  }

  /// Register with Email and Password
  Future<UserCredential?> registerWithEmailAndPassword(String email, String password, String username) async {
    try {
      // 1. Create user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Update display name
      if (userCredential.user != null) {
        await userCredential.user!.updateDisplayName(username);
        
        // 3. Create user profile in Firestore
        await FirestoreService().createOrUpdateUserProfile(
          uid: userCredential.user!.uid,
          email: email,
          displayName: username,
        );
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthError(e);
    } catch (e) {
      throw 'An unexpected error occurred.';
    }
  }

  String _handleFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'The email address is already in use.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'user-disabled':
        return 'The user account has been disabled.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      default:
        return 'Error: ${e.message}';
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      // Sign out from Google to allow account selection next time
      await _googleSignIn.signOut(); 
      // Sign out from Firebase
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      throw 'Failed to sign out.';
    }
  }
}
