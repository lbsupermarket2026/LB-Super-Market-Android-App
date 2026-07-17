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
