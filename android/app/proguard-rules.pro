# ============ Room / androidx.work ============
# AGP 9 默认开启 android.r8.strictFullModeForKeepRules，
# -keep 不再隐式保留默认构造器。Room 通过
# Class.forName("...WorkDatabase_Impl").newInstance() 反射实例化，
# 构造器被删掉会在启动时抛
#   "Failed to create an instance of class androidx.work.impl.WorkDatabase.canonicalName"
# 这里显式保留 RoomDatabase 子类的无参构造器。
-keepclassmembers class * extends androidx.room.RoomDatabase {
    public <init>();
}
-keep class * extends androidx.room.RoomDatabase { *; }
-dontwarn androidx.room.paging.**

# ============ Flutter / 插件 ============
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.hunghd.flutterdownloader.** { *; }
-keep class vn.hunghd.flutterdownloader.** { *; }

# ============ media_kit / libmpv ============
-keep class com.alexmercerind.media_kit.** { *; }
-keep class com.alexmercerind.mpv.** { *; }

# ============ R8 missing classes ============
# Flutter embedding 引用 Play Store 动态特性 API，但 app 不依赖
# play-core；AGP 9 的 R8 把缺类当错误，这里按官方 missing_rules 抑制。
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
