import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _isLoading = false;

  User? get currentUser => _firebaseAuth.currentUser;
  bool get isLoading => _isLoading;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await _saveFCMToken(userCredential.user!.uid);
      }

      return userCredential;
    } catch (e) {
      debugPrint('Sign in error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<UserCredential?> createAccount({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await _saveFCMToken(userCredential.user!.uid);
        await _createUserProfile(userCredential.user!);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Account creation error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _createUserProfile(User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('User profile creation error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      _setLoading(true);
      if (currentUser != null) {
        await _removeFCMToken(currentUser!.uid);
      }
      await _firebaseAuth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resetPassword({required String email}) async {
    try {
      _setLoading(true);
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Password reset error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateUsername({required String username}) async {
    try {
      _setLoading(true);
      await currentUser!.updateDisplayName(username);
      await _firestore.collection('users').doc(currentUser!.uid).update({
        'displayName': username,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      notifyListeners();
    } catch (e) {
      debugPrint('Username update error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteAccount({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await currentUser!.reauthenticateWithCredential(credential);
      await _removeFCMToken(currentUser!.uid);
      await _firestore.collection('users').doc(currentUser!.uid).delete();
      await currentUser!.delete();
      await _firebaseAuth.signOut();
    } catch (e) {
      debugPrint('Account deletion error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resetPasswordFromCurrentPassword({
    required String currentPassword,
    required String newPassword,
    required String email,
  }) async {
    try {
      _setLoading(true);
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await currentUser!.reauthenticateWithCredential(credential);
      await currentUser!.updatePassword(newPassword);
    } catch (e) {
      debugPrint('Password reset error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _saveFCMToken(String userId) async {
    try {
      final String? token = await _fcm.getToken();
      if (token != null) {
        await _firestore.collection('fcm_tokens').doc(userId).set({
          'userId': userId,
          'token': token,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Handle token refresh
        _fcm.onTokenRefresh.listen((newToken) async {
          await _firestore.collection('fcm_tokens').doc(userId).set({
            'userId': userId,
            'token': newToken,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        });
      }
    } catch (e) {
      debugPrint('FCM token save error: $e');
    }
  }

  Future<void> _removeFCMToken(String userId) async {
    try {
      await _firestore.collection('fcm_tokens').doc(userId).delete();
    } catch (e) {
      debugPrint('FCM token removal error: $e');
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}