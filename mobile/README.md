# SHIFT mobile
Native Flutter source in this existing directory; no duplicate apps/mobile copy is introduced.

Start with the repository README and docs/FRONTEND_HANDOFF.md. Open the app and choose **Open local workspace** while cloud authentication is unconnected. Registration and sign-in forms accurately report that authentication is unavailable.

Android and iOS runners are checked in. Flutter tooling generates machine-specific files at build time. No SDK was downloaded, no app binary was produced, and no runtime result is claimed for this implementation.

## Android build JVM 25

SHIFT's Android toolchain is configured for **JDK/JVM 25** as the Gradle daemon runtime, with **Gradle 9.1.0**, **Android Gradle Plugin 9.0.1**, and **Kotlin Gradle Plugin 2.3.20** (Flutter 3.44+ compatibility mode). `android/gradle/gradle-daemon-jvm.properties` declares `toolchainVersion=25`. Install a full JDK 25 on your build machine; this repository does not bundle or download one. Gradle must discover a compatible local JDK 25 installation.

Android Java/Kotlin compilation still targets JVM **17**, which is separate from the JVM that executes Gradle. Do not change the Android bytecode target to 25: Android device compatibility requires an appropriately supported target.

Confirm the active JDK and build after installing the SDK/Flutter dependencies:

```powershell
java -version
cd mobile
flutter doctor -v
flutter pub get
flutter build apk
```

If a JDK 25 installation is not discovered, configure it in your IDE's Gradle JDK settings or JDK discovery. Avoid changing Flutter's global `--jdk-dir` setting solely for SHIFT if you build other projects using incompatible Gradle versions. This update is configuration-only until an Android build is run and verified.
