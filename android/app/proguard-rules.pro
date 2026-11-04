# R8 keep rules for Catharsis Cards (release builds).
# Most libraries (Firebase, Play Billing, Google Mobile Ads, Google Sign-In)
# ship their own consumer rules; only the gaps are covered here.
# If a release build crashes with ClassNotFoundException / NoSuchMethodException,
# add a -keep rule for that class here.

# Flutter: deferred-components classes are referenced but not bundled.
-dontwarn com.google.android.play.core.**

# awesome_notifications: uses reflection and Gson to (de)serialise
# notification models, including scheduled notifications after a reboot.
-keep class me.carda.awesome_notifications.** { *; }
-keep class me.carda.awesome_notifications_core.** { *; }

# Gson (used by awesome_notifications): keep generic type info.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# Keep line numbers so Play Console crash reports stay readable
# (R8 uploads a mapping file with the bundle for deobfuscation).
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
