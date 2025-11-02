# Keep Razorpay SDK classes
-keep class com.razorpay.** { *; }
-keepattributes *Annotation*

# Keep method names used in reflection
-keepclassmembers class * {
    @proguard.annotation.Keep <methods>;
}
-keepclassmembers class * {
    @proguard.annotation.KeepClassMembers <fields>;
}
