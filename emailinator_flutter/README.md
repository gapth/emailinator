# emailinator_flutter

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Running the App

### Prerequisites

1.  **Flutter SDK**: Make sure you have the Flutter SDK installed. You can follow the official guide: [https://flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install)
2.  **IDE with Flutter Plugin**: It's recommended to use VS Code with the Flutter extension, or Android Studio/IntelliJ with the Flutter plugin.
3.  **Dependencies**: Navigate to the `emailinator_flutter` directory and run `flutter pub get` to install the required dependencies.

### Running on Web

To run the app in a Chrome browser:

```bash
flutter run -d chrome --dart-define-from-file=.env.local.json 
```

### Running on iOS

1.  **Simulator**: To run on the iOS Simulator, make sure you have Xcode installed. Then, open the simulator by running `open -a Simulator`. Finally, run:
    ```bash
    flutter run --dart-define-from-file=.env.local.json 
    ```
2.  **Physical Device**: To run on a physical iOS device, connect it to your Mac, and follow the instructions in the Flutter documentation to set up your device for development. Then run `flutter run`.

### Running on Android

1.  **Emulator**: To run on an Android emulator, make sure you have Android Studio installed and an emulator configured. Launch the emulator, then run:
    ```bash
    flutter run --dart-define-from-file=.env.local.json 
    ```
2.  **Physical Device**: To run on a physical Android device, connect it to your computer, enable developer options and USB debugging, and then run `flutter run`.

## Deep Link / Change Password

The change password screen is available at the universal link:

https://emailinator.app/change-password

Platforms:

- Web: Navigating directly to that URL loads the app and routes to the change password screen.
- Android: Intent filter in `AndroidManifest.xml` handles the link and opens the app at that route. To enable full App Links verification (skip chooser), host `/.well-known/assetlinks.json` on `emailinator.app` with your app's SHA256 cert fingerprint.
- iOS: Add Associated Domains capability (`applinks:emailinator.app`) plus host the `apple-app-site-association` JSON (no extension) at the root (and/or `/.well-known/`). Until that’s done, users can still use the custom scheme fallback: `emailinator://change-password`.

The email inbound domain `in.emailinator.app` is only used for generated forwarding aliases; do not share it for user navigation.
