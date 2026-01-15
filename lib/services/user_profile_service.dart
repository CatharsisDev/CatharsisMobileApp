// services/user_profile_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class UserProfile {
  final String? avatar;
  final String? username;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfile({
    this.avatar,
    this.username,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'avatar': avatar,
      'username': username,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      avatar: map['avatar'],
      username: map['username'],
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
    );
  }

  UserProfile copyWith({
    String? avatar,
    String? username,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      avatar: avatar ?? this.avatar,
      username: username ?? this.username,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class UserProfileService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload profile picture to Firebase Storage
  static Future<String?> uploadProfilePicture(File imageFile) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    try {
      final fileName = 'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('profile_pictures').child(fileName);
      
      await ref.putFile(imageFile);
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading profile picture: $e');
      throw Exception('Failed to upload profile picture');
    }
  }

  // Get current user's profile
  static Future<UserProfile?> getUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (doc.exists) {
        return UserProfile.fromMap(doc.data()!);
      }

      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Update user profile
  static Future<void> updateProfile({
    File? avatarFile,
    String? username,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    String? avatarUrl;
    
    // Upload avatar file if provided
    if (avatarFile != null) {
      avatarUrl = await uploadProfilePicture(avatarFile);
    }

    final now = DateTime.now();

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (doc.exists) {
        await _firestore.collection('users').doc(user.uid).update({
          if (avatarUrl != null) 'avatar': avatarUrl,
          if (username != null) 'username': username,
          'updatedAt': now.toIso8601String(),
        });
      } else {
        await _firestore.collection('users').doc(user.uid).set({
          if (avatarUrl != null) 'avatar': avatarUrl,
          if (username != null) 'username': username,
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        });
      }
    } catch (e) {
      print('Error updating profile: $e');
      throw Exception('Failed to save profile');
    }
  }

  // Clear profile data (kept for compatibility)
  static Future<void> clearProfile() async {
    // No local data to clear since everything is in Firestore
    return;
  }

  // Stream user profile changes
  static Stream<UserProfile?> profileStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return UserProfile.fromMap(snapshot.data()!);
      }
      return null;
    });
  }
}