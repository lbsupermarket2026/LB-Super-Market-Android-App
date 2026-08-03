# Razorpay — required once you enable code shrinking (isMinifyEnabled)
# for a real release build. Not needed for debug/test builds, but safe
# to have in place now so it's ready when you get to that step.
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** {*;}
-optimizations !method/inlining/
-keepclasseswithmembers class * {
  public void onPayment*(...);
}


# --- Flutter ---
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# --- Firebase / Google Play Services ---
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# --- Hive (uses reflection for type adapters) ---
-keep class hive.** { *; }
-keep class * extends com.google.gson.TypeAdapter

# --- General attribute preservation (needed by many reflection-based libs) ---
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# --- Keep your app's model/entity classes from being stripped ---
# (Riverpod/Freezed generated code, JSON serialization, and Hive
# adapters all rely on your data classes keeping their structure)
-keep class com.lbsupermarket.** { *; } 

# --- Play Core (deferred components) — not used by this app, R8 just
# needs to stop treating these as hard errors during minification ---
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**