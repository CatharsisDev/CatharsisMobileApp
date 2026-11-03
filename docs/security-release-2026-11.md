# eMudhra security release

Prepared version: **3.0.3 (58)**. Confirm that build 58 is higher than every build
already uploaded to App Store Connect and Google Play before uploading.

## Why both mobile apps need a release

The previous lockfiles use `cloud_firestore 5.6.12` and Apple Firebase `11.15.0`.
The local Flutter SDK was `3.44.1` with Dart `3.12.1`.

- iOS: update Firestore and its native Firebase dependencies.
- Android: rebuild with the patched Flutter/Dart runtime. The Android Firestore
  SDK itself is unaffected, but Dart HTTPS networking is affected.
- Existing installations remain affected until users install the new binary.

Sources:
- [Firebase remediation guidance](https://firebase.google.com/support/guides/compromised-emudhra-intermediate-ca)
- [Dart/Flutter advisory](https://github.com/dart-lang/sdk/security/advisories/GHSA-frr6-h895-5pxp)

## Required versions

- Flutter stable **3.47.8 or later**, including Dart **3.13.7 or later**.
- `cloud_firestore` **6.10.2** or a later patched release. This project uses the
  supported 6.x backport to limit the emergency migration.
- `firebase_core` **4.15.2** or a compatible later 4.x release.
- Apple Firebase via CocoaPods **12.19.3** or later patched 12.x release.
- Android build tools: Gradle **8.14.4**, Android Gradle Plugin **8.11.1**,
  and Kotlin **2.2.20**, meeting the patched Flutter SDK's minimum versions.

The `pubspec.yaml` SDK and package constraints prevent falling below these
Flutter, Dart, and FlutterFire security floors. The Android workflow pins Flutter
3.47.8. Both local Flutter installations must also be upgraded before they are
used for future releases; the temporary SDK used for this task does not update
them.

## Build and verify

Use the patched Flutter executable for every command. During this task it is
`/private/tmp/catharsis-flutter-3.47.8/bin/flutter`.

For the signed release, after configuring the existing store signing credentials:

```sh
/private/tmp/catharsis-flutter-3.47.8/bin/flutter pub get
/private/tmp/catharsis-flutter-3.47.8/bin/flutter build ipa --release
/private/tmp/catharsis-flutter-3.47.8/bin/flutter build appbundle --release
```

The SDK is in a temporary directory. For subsequent releases, install a patched
stable SDK in a permanent location and point the IDE and build commands to it.
Do not bypass the minimum SDK constraints with an older Flutter installation.

1. Resolve packages with `flutter pub get` and retain `pubspec.lock`.
2. Update the Firebase pods in `ios`, retaining `ios/Podfile.lock`. Check the
   resolved `FirebaseFirestore` and `FirebaseFirestoreInternal` versions before
   archiving. A pubspec change alone does not prove the native fix is included.
3. Run analysis and applicable tests, then build release binaries:
   `flutter build ipa --release` and `flutter build appbundle --release`.
   Store signing credentials are required for distribution.
4. On physical iOS and Android devices, verify cold start, existing-session
   login, Google/Apple/email sign-in, Firestore reads/writes/listeners, offline
   reconnect, Cloud Functions, and purchase/restore behavior in the store sandbox.
5. Review the final lockfiles and build SDK version before upload.

## Local verification

- Package resolution succeeded using Flutter **3.47.8** / Dart **3.13.7**.
- `pubspec.lock` resolves `cloud_firestore 6.10.2` and `firebase_core 4.15.2`.
- `pod update` succeeded; `ios/Podfile.lock` resolves both `FirebaseFirestore`
  and `FirebaseFirestoreInternal` to **12.19.3**.
- Static analysis reports **0 errors**, with 106 warnings and 918 informational
  findings. A pre-existing missing `subscriptionDuration` local declaration in
  the purchase handler was repaired to restore compilation.
- The existing `test/widget_test.dart` fails: it is the starter counter test,
  starts `MyApp` without Firebase initialization, and expects a counter screen.
  It does not provide a valid application smoke test.
- iOS release compilation passed with codesigning disabled. The app is at
  `build/ios/iphoneos/Runner.app`; a signed archive and device testing are still
  required before submission. Its embedded version is **3.0.3 (58)**.
- Build 58 aligns the Firebase app ID, bundle ID, and Google Sign-In client ID
  in `firebase_options.dart` and `Info.plist` with the production
  `GoogleService-Info.plist`. Build 57 contained conflicting iOS configuration
  values and can fail before the Flutter UI starts.
- Android release compilation passed. The unsigned bundle is at
  `build/app/outputs/bundle/release/app-release.aab`. Rebuild with the release
  signing configuration, or use the existing GitHub workflow, before upload.
- Both native builds emitted dependency/deprecation warnings. Android also
  reported a Kotlin metadata compatibility message for Firebase Auth; compilation
  completed successfully. Include authentication in device smoke testing.
- Generated machine-specific package/cache files were restored after validation.
  Run `pub get` with the patched SDK before the next build.
- No store submission has been made.
- Local Android signing files (`android/key.properties` and
  `android/app/release.jks`) are absent. The existing GitHub workflow supplies
  signing material from repository secrets.

## Distribution

1. Upload the signed iOS build to App Store Connect, test through TestFlight, and
   submit the security fix for review. Request expedited review if available.
2. Upload the signed Android bundle to Play Console, smoke test internally, and
   release the security update promptly.
3. After each store version is available, notify users through existing channels
   and ask them to update. Suggested copy: "An important security update for
   Catharsis Cards is available. Please update to the latest version."
4. Monitor crashes, authentication failures, Firestore connection errors, and
   adoption of the patched version.

No existing mandatory-update mechanism was found in `lib`. Adding one to this
release would only affect users after they install it; it cannot retroactively
force old installations to update.
