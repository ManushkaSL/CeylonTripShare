# TripShare Download Site - Deep Link Setup Guide

## Overview
Your download site now has complete deep link functionality. When users click a shared tour link, the site will:

1. Detect if they have the TripShare app installed
2. If installed: Deep link directly into the app with the tour details
3. If not installed: Redirect them to the App Store or Play Store to download

---

## Step 1: Update App Store IDs

Edit `src/config.ts` and update these values with your actual app IDs:

```typescript
// iOS - Get your app ID from App Store URL
// Example URL: https://apps.apple.com/app/tripshare/id1234567890
// The ID is: 1234567890
IOS_APP_ID: '1234567890',
IOS_APP_URL: 'https://apps.apple.com/app/tripshare/id1234567890',

// Android - Get your package name from Play Store URL
// Example URL: https://play.google.com/store/apps/details?id=com.tripshare.app
// The package name is: com.tripshare.app
ANDROID_PACKAGE_NAME: 'com.tripshare.app',
ANDROID_APP_URL: 'https://play.google.com/store/apps/details?id=com.tripshare.app',
```

---

## Step 2: Deep Link Flow

### What happens when someone shares a tour:

**Share Link Format:**
```
https://ceylon-trip-share-ytdf.vercel.app/tour/TOUR_ID?name=Tour%20Name&price=50&location=City
```

### When the link is clicked:

1. **User opens link** → Visits your Vercel site
2. **TourRedirect page loads** → Extracts tour ID and details from URL
3. **Attempts deep link** → Tries to open: `tripshare://tour/TOUR_ID?...`
4. **If app installed** → App receives the deep link and navigates to tour details
5. **If app not installed** → After 2 seconds, redirects to App Store or Play Store
6. **User downloads app** → After installing, clicking the link again will open the tour

---

## Step 3: Verify Deep Link Configuration in Your Flutter App

Your Flutter app needs to be configured to handle the custom URL scheme:

### Android Configuration
In `android/app/src/main/AndroidManifest.xml`, ensure you have:

```xml
<activity
    android:name=".MainActivity"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="tripshare" android:host="tour" />
    </intent-filter>
</activity>
```

### iOS Configuration
In `ios/Runner/Info.plist`, ensure you have:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.example.tripshare</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>tripshare</string>
        </array>
    </dict>
</array>
```

---

## Step 4: Test the Deep Link

### Local Testing:
1. Update `src/config.ts` with your actual app IDs
2. Run `npm run dev` to start the dev server
3. Navigate to: `http://localhost:3000/tour/test-tour-id?name=Test&price=100&location=NYC`
4. You should see the loading screen and either the app opens or redirects to the store

### Browser Console Testing:
Open your browser's developer console on the redirect page to see logs:
- Device type detected (iOS/Android/Web)
- Deep link URL being attempted
- Redirect destination

### Production Testing:
After deploying to Vercel:
1. Share a real tour from your app
2. Click the link on a device without the app installed → Should go to store
3. Install the app
4. Click the link again → Should open the tour in the app

---

## Route Structure

```
/ → Home page with download buttons
/tour/:tourId → Deep link redirect page
  Query params:
  - name: Tour name
  - price: Tour price
  - location: Starting location
```

---

## File Structure

```
src/
├── App.tsx                 # Router setup
├── config.ts              # ⭐ UPDATE THIS with your app IDs
├── pages/
│   ├── HomePage.tsx       # Landing page
│   └── TourRedirect.tsx    # Deep link handler
├── main.tsx
└── index.css
```

---

## Common Issues

### Link shows 404
- Check that your Vercel deployment has the `vercel.json` config file
- SPA routing must be enabled so `/tour/:tourId` routes to index

### App doesn't open from deep link
- Verify the `tripshare://` scheme is configured in AndroidManifest.xml and Info.plist
- Check your Flutter app handles the deep link in `main.dart`
- Test the deep link directly on device: `adb shell am start -W -a android.intent.action.VIEW -d "tripshare://tour/test-id" com.tripshare.app`

### Redirects to store instead of opening app
- This is normal behavior when the app isn't installed (2-second timeout)
- After installing the app, try clicking the link again

---

## Next Steps

1. ✅ Update `src/config.ts` with your app store IDs
2. ✅ Verify Android/iOS deep link configuration
3. ✅ Deploy to Vercel
4. ✅ Test the complete flow end-to-end
5. ✅ Users can now share tours with your custom deep links!

---

## Support

If you have questions about:
- **App Store IDs**: Check your app's official store listings
- **Deep links**: See the Flutter app's `main.dart` and `deep_link_navigation_service.dart`
- **Vercel deployment**: Check `vercel.json` and ensure build succeeds
