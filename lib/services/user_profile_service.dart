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
    if (user == null) {
      print('[PROFILE_SERVICE] Error: No authenticated user');
      throw Exception('No authenticated user');
    }

    try {
      // Verify file exists before upload
      if (!await imageFile.exists()) {
        print('[PROFILE_SERVICE] Error: Image file does not exist at ${imageFile.path}');
        throw Exception('Image file does not exist');
      }

      final fileSize = await imageFile.length();
      print('[PROFILE_SERVICE] Uploading avatar - Size: ${fileSize} bytes, Path: ${imageFile.path}');

      final fileName = 'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('profile_pictures').child(fileName);
      
      print('[PROFILE_SERVICE] Storage path: profile_pictures/$fileName');
      
      final uploadTask = ref.putFile(imageFile);
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('[PROFILE_SERVICE] Upload progress: ${progress.toStringAsFixed(1)}%');
      });
      
      await uploadTask;
      final downloadUrl = await ref.getDownloadURL();
      
      print('[PROFILE_SERVICE] Upload successful! URL: $downloadUrl');
      return downloadUrl;
    } on FirebaseException catch (e) {
      print('[PROFILE_SERVICE] Firebase error uploading profile picture:');
      print('  Code: ${e.code}');
      print('  Message: ${e.message}');
      print('  Details: ${e.plugin}');
      throw Exception('Firebase Storage error: ${e.message}');
    } catch (e) {
      print('[PROFILE_SERVICE] Error uploading profile picture: $e');
      throw Exception('Failed to upload profile picture: $e');
    }
  }

  // Get current user's profile
  static Future<UserProfile?> getUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('[PROFILE_SERVICE] No authenticated user');
      return null;
    }

    try {
      print('[PROFILE_SERVICE] Fetching profile for user: ${user.uid}');
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (doc.exists) {
        final profile = UserProfile.fromMap(doc.data()!);
        print('[PROFILE_SERVICE] Profile loaded - Username: ${profile.username}, Avatar: ${profile.avatar != null ? "set" : "not set"}');
        return profile;
      }

      print('[PROFILE_SERVICE] No profile document exists yet');
      return null;
    } catch (e) {
      print('[PROFILE_SERVICE] Error getting user profile: $e');
      return null;
    }
  }

  // Update user profile
  static Future<void> updateProfile({
    File? avatarFile,
    String? username,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      print('[PROFILE_SERVICE] Error: No authenticated user for update');
      throw Exception('No authenticated user');
    }

    print('[PROFILE_SERVICE] Updating profile for ${user.uid}');
    print('[PROFILE_SERVICE] - Avatar file: ${avatarFile != null ? avatarFile.path : "none"}');
    print('[PROFILE_SERVICE] - Username: ${username ?? "none"}');

    String? avatarUrl;
    
    // Upload avatar file if provided
    if (avatarFile != null) {
      print('[PROFILE_SERVICE] Starting avatar upload...');
      avatarUrl = await uploadProfilePicture(avatarFile);
      print('[PROFILE_SERVICE] Avatar uploaded successfully: $avatarUrl');
    }

    final now = DateTime.now();

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();

      final Map<String, dynamic> updateData = {
        'updatedAt': now.toIso8601String(),
      };

      if (avatarUrl != null) {
        updateData['avatar'] = avatarUrl;
      }
      if (username != null) {
        updateData['username'] = username;
      }

      if (doc.exists) {
        print('[PROFILE_SERVICE] Updating existing document');
        await _firestore.collection('users').doc(user.uid).update(updateData);
      } else {
        print('[PROFILE_SERVICE] Creating new document');
        updateData['createdAt'] = now.toIso8601String();
        await _firestore.collection('users').doc(user.uid).set(updateData);
      }

      print('[PROFILE_SERVICE] Profile updated successfully');
    } catch (e) {
      print('[PROFILE_SERVICE] Error updating Firestore: $e');
      throw Exception('Failed to save profile: $e');
    }
  }

  // Clear profile data (kept for compatibility)
  static Future<void> clearProfile() async {
    // No local data to clear since everything is in Firestore
    print('[PROFILE_SERVICE] Clear profile called (no-op)');
    return;
  }

  // Stream user profile changes
  static Stream<UserProfile?> profileStream() {
    final user = _auth.currentUser;
    if (user == null) {
      print('[PROFILE_SERVICE] No user for profile stream');
      return Stream.value(null);
    }

    print('[PROFILE_SERVICE] Starting profile stream for ${user.uid}');
    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        final profile = UserProfile.fromMap(snapshot.data()!);
        print('[PROFILE_SERVICE] Profile stream update - Username: ${profile.username}');
        return profile;
      }
      print('[PROFILE_SERVICE] Profile stream - no document');
      return null;
    });
  }
}