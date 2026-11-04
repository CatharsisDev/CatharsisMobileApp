import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Remote "minimum version" check, used to force users off builds with a
/// known problem (e.g. a security fix).
///
/// Controlled from the Firestore console — no app release needed. Create the
/// document `config/app` with these fields:
///
///   minBuildNumber          int     Required build number on both platforms.
///   minBuildNumberIos       int     Optional — overrides minBuildNumber on iOS.
///   minBuildNumberAndroid   int     Optional — overrides it on Android.
///   updateMessage           string  Optional — replaces the default message.
///
/// The build number is the part after the "+" in pubspec.yaml's `version`
/// (3.0.3+59 → 59). Any device running a lower build sees a blocking
/// "update required" screen until it updates.
///
/// Fails open: if the document is missing, the device is offline, or anything
/// goes wrong, the user is let through. A broken check must never lock
/// everyone out of the app.
class ForceUpdateService {
  ForceUpdateService._();

  static const String iosStoreUrl =
      'https://apps.apple.com/app/id6754243648';
  static const String androidStoreUrl =
      'https://play.google.com/store/apps/details?id=com.catharsis.cards';

  static const String defaultMessage =
      'A new version of Catharsis is available with important fixes. '
      'Please update to continue.';

  /// Returns an [UpdateRequirement] if this build is below the minimum,
  /// otherwise null.
  static Future<UpdateRequirement?> check() async {
    if (!Platform.isIOS && !Platform.isAndroid) return null;
    try {
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber);
      if (currentBuild == null) return null;

      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('app')
          .get()
          .timeout(const Duration(seconds: 5));
      final data = doc.data();
      if (data == null) return null;

      final platformKey =
          Platform.isIOS ? 'minBuildNumberIos' : 'minBuildNumberAndroid';
      final minBuild = _asInt(data[platformKey]) ?? _asInt(data['minBuildNumber']);
      if (minBuild == null || currentBuild >= minBuild) return null;

      final message = data['updateMessage'];
      return UpdateRequirement(
        message: message is String && message.trim().isNotEmpty
            ? message.trim()
            : defaultMessage,
        storeUrl: Platform.isIOS ? iosStoreUrl : androidStoreUrl,
      );
    } catch (e) {
      print('[ForceUpdate] Check skipped: $e');
      return null;
    }
  }

  /// Firestore console numbers can arrive as int, double, or a typed string.
  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }
}

class UpdateRequirement {
  final String message;
  final String storeUrl;
  const UpdateRequirement({required this.message, required this.storeUrl});
}
