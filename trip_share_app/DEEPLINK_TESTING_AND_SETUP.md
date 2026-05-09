# Deep Link Testing & Setup Guide

## ✅ What I Fixed

1. **iOS Info.plist**: Added Universal Links support configuration
2. **Android Manifest**: Added App Links intent filter for landing page domain
3. **main.dart**: Improved deep link initialization order and robustness
4. **Deep Link Parsing**: Enhanced to handle both custom scheme and vercel domain

## 🔧 What You MUST Do After This Fix

### Option A: Use Firebase Dynamic Links (RECOMMENDED)

This is the easiest and most reliable method:

1. **Go to Firebase Console**
   - Open [Firebase Console](https://console.firebase.google.com)
   - Select your TripShare project
   - Go to **Dynamic Links** section

2. **Create a Dynamic Link Domain** (if you haven't already)
   - Click "Begin" in Dynamic Links
   - Create a new dynamic link domain (e.g., `tripshareapp.page.link`)

3. **Update your code**
   - Update `lib/services/dynamic_link_service.dart`:
   ```dart
   static const String _domain = 'https://YOUR_DOMAIN.page.link';
   ```
   - Replace `YOUR_DOMAIN` with your actual Firebase domain

4. **Test Sharing**
   - Open the app
   - Find a tour
   - Tap Share button
   - Copy the link and open it in a browser

---

### Option B: Set Up Landing Page Redirects (For Your Vercel Domain)

If you want to use the existing Vercel landing page (`ceylon-trip-share-ytdf.vercel.app`), you need to add redirect logic.

**On your Vercel landing page, add this JavaScript:**

```html
<script>
  // Extract tourId from URL
  const params = new URLSearchParams(window.location.search);
  const tourId = params.get('tourId');

  if (tourId) {
    // Store tourId in sessionStorage for later retrieval
    sessionStorage.setItem('pendingTourId', tourId);
    
    // Try to open the app
    const appLink = `tripshare://tour/${tourId}`;
    
    // Attempt to redirect to app
    window.location.href = appLink;
    
    // Fallback: If app doesn't open, redirect to App Store after delay
    setTimeout(() => {
      const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent);
      const isAndroid = /Android/.test(navigator.userAgent);
      
      if (isIOS) {
        // Replace with your actual App Store link
        window.location.href = 'https://apps.apple.com/app/your-app-id';
      } else if (isAndroid) {
        // Replace with your actual Play Store link
        window.location.href = 'https://play.google.com/store/apps/details?id=com.tripshare.app';
      }
    }, 1000);
  }
</script>
```

3. **Add assetlinks.json for Android** (in your Vercel project)
   - Create `.well-known/assetlinks.json` at the root of your Vercel deployment:
   ```json
   [
     {
       "relation": ["delegate_permission/common.handle_all_urls"],
       "target": {
         "namespace": "android_app",
         "package_name": "com.tripshare.app",
         "sha256_cert_fingerprints": [
           "YOUR_SIGNING_CERTIFICATE_SHA256_FINGERPRINT"
         ]
       }
     }
   ]
   ```
   
   To get your SHA256 fingerprint:
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA256
   ```

---

## 🧪 Testing Your Deep Links

### Test on iOS

1. **Via Custom Scheme:**
   - Open Notes app
   - Add text: `tripshare://tour/TOUR_ID`
   - Press and hold, then tap "Open"

2. **Via Safari:**
   - Open Safari
   - Type: `tripshare://tour/TOUR_ID` in address bar
   - Press Go

### Test on Android

1. **Via ADB:**
   ```bash
   adb shell am start -a android.intent.action.VIEW -d "tripshare://tour/TOUR_ID"
   ```

2. **Via Custom Scheme in Chrome:**
   - Open Chrome
   - Type: `tripshare://tour/TOUR_ID`
   - Press Enter

### Test Share Button in App

1. Open the app
2. Find a tour
3. Tap Share button
4. Copy link
5. Open in new browser tab or send via WhatsApp
6. Tap link → App should open to tour details

---

## 🔍 Debugging

If the app doesn't open:

1. **Check Flutter logs:**
   ```bash
   flutter logs
   ```
   Look for lines starting with `🔗 Deep link` or `📱 Handling deep link`

2. **Check console for errors:**
   - iOS: Use Xcode console
   - Android: Use Android Studio logcat

3. **Verify Intent Filter** (Android):
   ```bash
   adb shell cmd package resolve-activity -a android.intent.action.VIEW -d tripshare://tour/test
   ```
   Should show: `com.tripshare.app/.MainActivity`

4. **Check URL Schemes** (iOS):
   - Open Settings → Trip Share App
   - Verify it appears in "Open supported links"

---

## 📋 Quick Checklist

- [ ] Firebase Dynamic Links domain configured (Option A) OR Vercel redirect script added (Option B)
- [ ] assetlinks.json added to Vercel `.well-known/` folder (Android)
- [ ] `dynamic_link_service.dart` updated with correct domain
- [ ] App has been rebuilt after manifest/plist changes
- [ ] Tested with at least one real link
- [ ] Verified through Flutter logs that deep link is received

---

## ⚠️ Common Issues

| Issue | Solution |
|-------|----------|
| "App not opening" | Make sure you're using `tripshare://` scheme or full domain link, not http/https |
| "Tour not found" | Check that tourId is valid in Firestore and being parsed correctly (check logs) |
| "Only works on first install" | Rebuild app after changing manifests. Clean build: `flutter clean && flutter pub get` |
| "Link opens but wrong page shows" | Check that AuthService initialization completes before navigation |

