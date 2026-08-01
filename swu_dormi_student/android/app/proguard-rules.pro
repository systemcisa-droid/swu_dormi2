# Flutter Wrapper - essential only
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase Core - essential classes only
-keepattributes Signature
-keepattributes *Annotation*

# Firebase Auth
-keepclassmembers class com.google.firebase.auth.FirebaseAuth { *; }
-keepclassmembers class com.google.firebase.auth.FirebaseUser { *; }

# Firebase Firestore
-keepclassmembers class com.google.firebase.firestore.** {
    public <methods>;
}
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
}

# Firebase Storage
-keepclassmembers class com.google.firebase.storage.FirebaseStorage { *; }
-keepclassmembers class com.google.firebase.storage.StorageReference { *; }

# Google Play Services - essential only
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.tasks.** { *; }

# Warnings to ignore
-dontwarn com.google.android.play.core.**

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep custom application class
-keep class com.swu.dormi.swu_dormi.** { *; }

# Android components
-keepclassmembers class * extends android.app.Activity {
   public void *(android.view.View);
}

# Enum
-keepclassmembers enum * { *; }

# Parcelable
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# R class
-keepclassmembers class **.R$* {
    public static <fields>;
}