# Firebase Dynamic Links Setup Guide

This guide explains how to complete the Firebase Dynamic Links setup so the tour sharing system works end-to-end.

---

## 🎯 How It Works

1. **User taps share button** → Generates a Firebase Dynamic Link
2. **Link is clicked** → Firebase detects device and app installation
3. **If app installed** → Opens app with tour details
4. **If not installed** → Redirects to App Store/Play Store
5. **After install** → User can click link again and open the app directly

---

## ✅ Step 1: Update Dynamic Link Domain

Your Firebase project has a unique dynamic link domain. Update it in:

**File:** `lib/services/dynamic_link_service.dart`

```dart
static const String _domain = 'https://YOUR_PROJECT_ID.page.link';
```

**How to find your domain:**
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your TripShare project
3. Go to **Dynamic Links** section
4. You'll see your dynamic link domain (e.g., `https://tripshare-abc123.page.link`)
5. Copy it and replace in the code above

---

## ✅ Step 2: Get Your App Store IDs

### iOS App Store ID
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Find your TripShare app
3. In the URL, find the ID number: `https://apps.apple.com/app/[name]/id**1234567890**`
4. Update in `lib/services/dynamic_link_service.dart`:
   ```dart
   appStoreId: '1234567890', // Your actual ID
   ```

### Android Package Name
1. Go to [Google Play Console](https://play.google.com/console)
2. Find your TripShare app
3. In the URL, find the package: `https://play.google.com/store/apps/details?id=**com.tripshare.app**`
4. This is already correct in the code: `com.tripshare.app`

---

## ✅ Step 3: Configure Android

### Android Intent Filter

Update `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest>
  <application>
    <activity
        android:name=".MainActivity"
        android:exported="true"
        android:launchMode="singleTop">
        
      <!-- Standard launcher intent -->
      <intent-filter>
        <action android:name="android.intent.action.MAIN" />
        <category android:name="android.intent.category.LAUNCHER" />
      </intent-filter>

      <!-- Handle Firebase Dynamic Links and custom scheme -->
      <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <!-- Firebase Dynamic Links domain -->
        <data
            android:scheme="https"
            android:host="tripshare-abc123.page.link" />
        <!-- Your custom deep link scheme -->
        <data android:scheme="tripshare" />
      </intent-filter>

    </activity>
  </application>
</manifest>
```

**Replace** `tripshare-abc123.page.link` with your actual Firebase dynamic link domain.

---

## ✅ Step 4: Configure iOS

### iOS Associated Domains

Update `ios/Runner/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- ... other config ... -->
    
    <!-- Firebase Dynamic Links -->
    <key>FirebaseDynamicLinksCustomDomains</key>
    <array>
        <string>https://ceylon-trip-share-ytdf.vercel.app</string>
        <string>https://tripshare-abc123.page.link</string>
    </array>
    
    <!-- Associated Domains for Universal Links -->
    <key>com.apple.developer.associated-domains</key>
    <array>
        <string>applinks:ceylon-trip-share-ytdf.vercel.app</string>
        <string>applinks:tripshare-abc123.page.link</string>
    </array>
    
    <!-- ... rest of config ... -->
</dict>
</plist>
```

---

## ✅ Step 5: Test the Setup

### Local Testing

1. Run: `flutter pub get`
2. Run app on physical device (not emulator for Firebase DL)
3. On your device, open a tour and tap Share
4. Copy the generated Firebase Dynamic Link
5. Open link in browser
   - **App installed:** Should open the tour in the app
   - **App not installed:** Should redirect to App Store/Play Store

### What You'll See

**In app (console logs):**
```
🔗 Generating Firebase Dynamic Link for tour: Dpe9GqIjWS8slOqZX2d7
✅ Firebase Dynamic Link generated: https://tripshare-abc123.page.link/abc123xyz
```

**Share message:**
```
Check out this amazing tour: Udawalawe Half Day Safari
💰 $50 per person
📍 Ella
📅 Available seats: 6/6

https://tripshare-abc123.page.link/abc123xyz
```

---

## 🔗 How Links Work

### Firebase Dynamic Link Path

When you generate a link, it creates a format like:
```
https://tripshare-abc123.page.link/a1b2c3d4e5f6g7h8
```

Firebase automatically:
1. Detects the device (iOS/Android)
2. Checks if app is installed
3. Opens the app if installed, showing the shared tour
4. Redirects to store if app not installed

Your Vercel landing page is a **fallback** - it only shows if something goes wrong with the Firebase link.

---

## 🚀 Complete Flow

```
User clicks Share
    ↓
generateTourShareLink() → Creates Firebase Dynamic Link
    ↓
Firebase Dynamic Link: https://tripshare-abc123.page.link/xyz123
    ↓
Link is shared via WhatsApp/SMS/etc
    ↓
Recipient clicks link
    ↓
Firebase detects device
    ├─ App installed? → Opens app with tour data ✅
    └─ App not installed? → Redirects to App Store/Play Store
        └─ After install, link opens app directly
```

---

## ❗ Troubleshooting

### Issue: Links not working on iOS
**Solution:** Ensure Bundle ID matches in:
- Xcode project settings
- Firebase Console
- `Info.plist` configuration

### Issue: Links not working on Android
**Solution:** 
- Verify package name: `com.tripshare.app`
- Check `AndroidManifest.xml` has correct domain
- Ensure Android app is signed with correct signing key

### Issue: Firebase Dynamic Links page shows 404
**Solution:** 
- Verify you used the correct dynamic link domain
- Domain must be in format: `https://PROJECT_ID.page.link`

### Issue: Redirects to store every time
**Solution:**
- App might not be properly associated with store
- Try installing app fresh and testing again
- Check app is signed with same certificate as store listing

---

## 📝 Configuration Checklist

- [ ] Updated `_domain` constant with your Firebase DL domain
- [ ] Updated iOS `appStoreId` with correct ID number
- [ ] Added Android Intent Filter to `AndroidManifest.xml`
- [ ] Added iOS Associated Domains to `Info.plist`
- [ ] Tested on physical iOS device
- [ ] Tested on physical Android device
- [ ] Share button generates Firebase Dynamic Links
- [ ] Links work when app is installed
- [ ] Links redirect to store when app not installed

---

## 🎉 You're Done!

Your tour sharing system is now complete. Users can:
- Share tours via any messaging app
- Links automatically detect if app is installed
- Seamless experience whether app is installed or not
- Users can download the app and view the shared tour immediately after installation

---

## Support

For more info:
- [Firebase Dynamic Links Docs](https://firebase.google.com/docs/dynamic-links)
- [Your Firebase Console](https://console.firebase.google.com)

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
