---
description: Build an Android APK for release
---

To build an APK file that can be installed on Android devices:

1.  Run the build command:
    ```bash
    flutter build apk --release
    ```

2.  Locate the file:
    The APK will be generated at:
    `build/app/outputs/flutter-apk/app-release.apk`

3.  (Optional) To install it on a connected device:
    ```bash
    flutter install
    ```
