import 'package:firebase_auth/firebase_auth.dart';

class UserProfile {
  final String uid;
  final String email;
  final String? displayName;
  final String? profilePictureId; // Now references local assets
  final String? phoneNumber;
  final String? location;
  final String? bio;

  UserProfile({
    required this.uid,
    required this.email,
    this.displayName,
    this.profilePictureId,
    this.phoneNumber,
    this.location,
    this.bio,
  });

  factory UserProfile.fromFirebaseUser(User user) {
    return UserProfile(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      profilePictureId: user.photoURL,
    );
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] as String,
      email: map['email'] as String,
      displayName: map['displayName'] as String?,
      profilePictureId: map['photoUrl'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      location: map['location'] as String?,
      bio: map['bio'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': profilePictureId,
      'phoneNumber': phoneNumber,
      'location': location,
      'bio': bio,
    };
  }

  UserProfile copyWith({
    String? displayName,
    String? profilePictureId,
    String? phoneNumber,
    String? location,
    String? bio,
  }) {
    return UserProfile(
    uid: uid,
    email: email,
    displayName: displayName ?? this.displayName,
    profilePictureId: profilePictureId ?? this.profilePictureId,  // Updated this line
    phoneNumber: phoneNumber ?? this.phoneNumber,
    location: location ?? this.location,
    bio: bio ?? this.bio,
  );
  }
  String get profilePictureAsset {
    return profilePictureId != null
        ? 'assets/profile_pictures/$profilePictureId.png'
        : 'assets/profile_pictures/default.png'; // Fallback image
  }
}