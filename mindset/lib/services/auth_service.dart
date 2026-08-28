import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<void> createAccount({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'missing-user',
        message: 'Firebase did not return a user for this account.',
      );
    }

    await user.updateDisplayName(fullName);
    await user.reload();
    await ensureUserProfile(fullName: fullName);
  }

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    await ensureUserProfile();
  }

  Future<void> ensureUserProfile({String? fullName}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'missing-user',
        message: 'Sign in before saving the account profile.',
      );
    }

    final profile = _firestore.collection('users').doc(user.uid);
    final snapshot = await profile.get();
    final existingData = snapshot.data();
    final resolvedName = (fullName ?? user.displayName ?? '').trim();
    final data = <String, dynamic>{
      'uid': user.uid,
      'fullName': resolvedName.isEmpty ? 'MindSet User' : resolvedName,
      'email': user.email ?? '',
      'lastSignedInAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!snapshot.exists ||
        !(existingData?.containsKey('createdAt') ?? false)) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await profile.set(data, SetOptions(merge: true));
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() {
    return _auth.signOut();
  }

  String errorMessage(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'email-already-in-use' =>
          'An account already exists for this email. Log in instead, or reset the password if it is yours.',
        'invalid-email' => 'Enter a valid email address.',
        'invalid-credential' ||
        'user-not-found' ||
        'wrong-password' => 'The email or password is incorrect.',
        'user-disabled' => 'This account has been disabled.',
        'weak-password' =>
          'Use a stronger password with at least 6 characters.',
        'network-request-failed' =>
          'Check your internet connection and try again.',
        _ => error.message ?? 'Authentication failed. Please try again.',
      };
    }

    if (error is FirebaseException) {
      return error.message ?? 'Could not save the account profile.';
    }

    return 'Something went wrong. Please try again.';
  }
}
