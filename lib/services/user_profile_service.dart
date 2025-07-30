// services/user_profile_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Get current user's profile
  static Future<UserProfile?> getUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      // Try to get from Firestore first
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        return UserProfile.fromMap(doc.data()!);
      }

      // Fallback to local storage
      final prefs = await SharedPreferences.getInstance();
      final avatar = prefs.getString('user_avatar');
      final username = prefs.getString('user_username');

      if (avatar != null || username != null) {
        return UserProfile(avatar: avatar, username: username);
      }

      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      
      // Fallback to local storage on error
      try {
        final prefs = await SharedPreferences.getInstance();
        final avatar = prefs.getString('user_avatar');
        final username = prefs.getString('user_username');
        
        if (avatar != null || username != null) {
          return UserProfile(avatar: avatar, username: username);
        }
      } catch (localError) {
        print('Error getting local profile: $localError');
      }
      
      return null;
    }
  }

  // Update user profile
  static Future<void> updateProfile({
    String? avatar,
    String? username,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final now = DateTime.now();
    final profile = UserProfile(
      avatar: avatar,
      username: username,
      updatedAt: now,
    );

    try {
      // Check if profile exists
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        // Update existing profile
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({
          if (avatar != null) 'avatar': avatar,
          if (username != null) 'username': username,
          'updatedAt': now.toIso8601String(),
        });
      } else {
        // Create new profile
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set({
          if (avatar != null) 'avatar': avatar,
          if (username != null) 'username': username,
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        });
      }

      // Also save locally for offline access
      final prefs = await SharedPreferences.getInstance();
      if (avatar != null) {
        await prefs.setString('user_avatar', avatar);
      }
      if (username != null) {
        await prefs.setString('user_username', username);
      }

    } catch (e) {
      print('Error updating profile in Firestore: $e');
      
      // Fallback to local storage only
      try {
        final prefs = await SharedPreferences.getInstance();
        if (avatar != null) {
          await prefs.setString('user_avatar', avatar);
        }
        if (username != null) {
          await prefs.setString('user_username', username);
        }
      } catch (localError) {
        print('Error saving profile locally: $localError');
        throw Exception('Failed to save profile');
      }
    }
  }

  // Clear profile data (for sign out)
  static Future<void> clearProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_avatar');
      await prefs.remove('user_username');
    } catch (e) {
      print('Error clearing local profile: $e');
    }
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