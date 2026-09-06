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

# Keep custom application class (namespace: com.swu.dormi2)
-keep class com.swu.dormi2.** { *; }

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
# ──────────── 플러그인별 keep 규칙 ────────────
# R8 활성화 후 리플렉션/네이티브 호출로 참조되는 클래스가 제거되지 않도록 한다.

# Firebase Messaging (백그라운드 푸시 알림)
-keep class com.google.firebase.messaging.** { *; }
-keep class io.flutter.plugins.firebase.messaging.** { *; }

# flutter_local_notifications: 예약 알림 복원 시 GSON 리플렉션 사용
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Syncfusion PDF Viewer
-keep class com.syncfusion.** { *; }
-dontwarn com.syncfusion.**

# mobile_scanner (ML Kit 바코드)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# video_compress / video_player
-keep class com.otaliastudios.** { *; }
-dontwarn com.otaliastudios.**

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }

# Play Core (Flutter 지연 컴포넌트 - 미사용 시 경고만 억제)
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
