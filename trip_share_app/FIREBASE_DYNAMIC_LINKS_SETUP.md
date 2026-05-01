# Firebase Dynamic Links Setup Guide

This guide walks you through setting up Firebase Dynamic Links for the TripShare app to enable tour sharing with deep links.

## Prerequisites

- Firebase project already set up
- Firebase Console access
- Android and iOS apps registered in Firebase

## Step 1: Enable Firebase Dynamic Links

1. Go to **Firebase Console** → Your Project
2. Navigate to **Engage** section → **Dynamic Links**
3. Click **Get Started** or **Create New Domain**
4. Follow the prompts to create a Dynamic Link domain (e.g., `https://tripshareapp.page.link`)

## Step 2: Configure Android Deep Links

### In Android Manifest (`android/app/src/main/AndroidManifest.xml`)

Add an intent filter to handle deep links:

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:theme="@style/LaunchTheme"
    android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
    android:hardwareAccelerated="true"
    android:windowSoftInputMode="adjustResize">
    
    <intent-filter>
        <action android:name="android.intent.action.MAIN" />
        <category android:name="android.intent.category.LAUNCHER" />
    </intent-filter>

    <!-- Deep link intent filter for Dynamic Links -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <!-- Your Dynamic Links domain -->
        <data android:host="tripshareapp.page.link" android:scheme="https" />
        <!-- App deep links -->
        <data android:host="tripshareapp.com" android:scheme="https" android:pathPrefix="/tour" />
    </intent-filter>
</activity>
```

## Step 3: Configure iOS Deep Links

### In Info.plist (`ios/Runner/Info.plist`)

Add the following:

```xml
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>

<!-- URL scheme for your app -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.tripshare.app</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>tripshare</string>
        </array>
    </dict>
</array>

<!-- Associated domains for Universal Links -->
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:tripshareapp.page.link</string>
    <string>applinks:tripshareapp.com</string>
</array>
```

### In Info.plist (Alternative - declarative approach)

You can also configure this through Xcode:
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select **Runner** → **Signing & Capabilities**
3. Add **Associated Domains** capability
4. Add domains:
   - `applinks:tripshareapp.page.link`
   - `applinks:tripshareapp.com`

## Step 4: Update DynamicLinkService Configuration

Edit `lib/services/dynamic_link_service.dart`:

```dart
// Replace these with your actual values:
static const String _domainUriPrefix = 'https://tripshareapp.page.link';
static const String _androidPackageName = 'com.example.tripshareapp'; // Your app's package name
static const String _iosBundleId = 'com.example.tripshareapp'; // Your app's bundle ID
```

And in the iOS parameters:
```dart
iosParameters: IosParameters(
  bundleId: _iosBundleId,
  minimumVersion: '1.0',
  appStoreId: 'YOUR_APP_STORE_ID', // Get this from App Store Connect
),
```

## Step 5: Configure Firebase Project Links

In **Firebase Console** → **Dynamic Links** → Your Domain:

1. **Android**:
   - Package name: `com.example.tripshareapp`
   - SHA-256 Certificate Fingerprint: (Get from Android keystore)
   - App preview page: Leave as default

2. **iOS**:
   - Bundle ID: `com.example.tripshareapp`
   - App Store ID: (From App Store Connect)
   - Team ID: (From Apple Developer account)

## Step 6: Get Android SHA-256 Certificate Fingerprint

Run this command:
```bash
cd android
./gradlew signingReport
```

Find the SHA-256 fingerprint for your release or debug keystore.

## Step 7: Test Dynamic Links

### Android Testing:
```bash
flutter run
```

Then manually test by:
1. Tapping share button on a tour card
2. Share the generated link via any messaging app
3. Click the link - app should open and show tour details

### iOS Testing:
1. Build and run on iOS device
2. Tap share button
3. Share link via messaging
4. Click link on another device
5. App should open and show tour details

## Step 8: Troubleshooting

### Link Not Opening App
- Ensure Deep Link handlers are installed
- Check AndroidManifest.xml and Info.plist configurations
- Verify package names and bundle IDs match Firebase console

### Link Opens Browser Instead
- Dynamic Links domain is not properly configured
- Certificate fingerprints don't match

### Tour Not Loading After Deep Link
- Check Firestore database - ensure tour exists with correct ID
- Check console logs for errors in DeepLinkNavigationService

## Step 9: Production Deployment

Before deploying to production:
1. Update all hardcoded URLs/domains to production values
2. Get a production signing certificate for Android
3. Update SHA-256 fingerprint in Firebase console
4. Test thoroughly on both Android and iOS
5. Set App Store ID in DynamicLinkService

## Important Notes

- Dynamic Links require a valid HTTPS domain
- Firebase will redirect to App Store / Play Store if app is not installed
- Test with real devices for best results
- SHA-256 certificate fingerprints must match for Android deep links to work

## Reference Links

- [Firebase Dynamic Links Documentation](https://firebase.google.com/docs/dynamic-links)
- [Android Deep Links Guide](https://developer.android.com/training/app-links)
- [iOS Universal Links Guide](https://developer.apple.com/ios/universal-links/)
