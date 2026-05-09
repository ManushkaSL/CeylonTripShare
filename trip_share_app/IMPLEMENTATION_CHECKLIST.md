# Implementation Checklist - Smart Deep Link Workflow

## 🎯 Goal
User clicks shared link → App detects if installed → Opens app OR web version

---

## 📋 Implementation Steps

### Phase 1: Flutter App Setup ✅ (DONE)

- [x] Updated `dynamic_link_service.dart` to use smart API endpoint
- [x] Fixed `main.dart` deep link handling (initialization order, timing)
- [x] Added Android App Links intent filter for Vercel domain
- [x] Added iOS configuration for custom scheme
- [x] Enhanced deep link parsing for all formats

**Status:** Flutter app is ready ✅

---

### Phase 2: Vercel Backend Setup (TODO)

Your smart redirect endpoint needs to be created on your Vercel project.

#### 2.1: Add API Route to Vercel
Choose ONE based on your Vercel project setup:

**Option A: Next.js (Recommended)**
```bash
# Create this file in your Vercel project:
pages/api/tour-link.ts
```
Copy the code from: `SMART_DEEPLINK_WORKFLOW.md` → Step 1

**Option B: Express/Node.js**
```bash
# Create this file:
api/tour-link.js
```

**Option C: Already have a redirect endpoint?**
- Just update it to accept `tourId`, `name`, `price`, `location` parameters
- Make it try to open `tripshare://tour/{tourId}` deeplink
- Fallback to `https://ceylon-trip-share-ytdf.vercel.app/?tourId={tourId}` if app not installed

#### 2.2: Deploy Vercel Changes
```bash
# In your Vercel project directory
git add .
git commit -m "Add smart tour link redirect API"
git push origin main
# OR
vercel deploy
```

---

### Phase 3: Web App Tour Display (TODO)

Your web app needs to accept `tourId` parameter and show tour details.

#### 3.1: Update Landing Page
Add code to your main landing page/index to:
- Accept `tourId` from URL query params
- Fetch tour from Firestore using API route
- Display tour details (name, price, location, image)
- Show booking button

#### 3.2: Create Tour API Route
**Create:** `pages/api/get-tour.ts` (or `api/get-tour/route.ts`)

This endpoint should:
- Accept tour ID as parameter
- Fetch from Firestore database
- Return tour data as JSON
- Handle errors gracefully

See: `SMART_DEEPLINK_WORKFLOW.md` → Step 4 for code

#### 3.3: Firebase Admin Setup (If not done)
```bash
# Install Firebase Admin SDK
npm install firebase-admin

# Create service account in Firebase Console
# Settings → Service Accounts → Generate new private key
# Save as `.env.local` and add to Vercel secrets
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY=your-private-key
FIREBASE_CLIENT_EMAIL=your-email
```

---

### Phase 4: Testing (TODO)

#### Test 1: App Installed Scenario
```bash
# Device with app installed
1. Open Flutter app
2. Find a tour you created/have data for
3. Tap Share button
4. Copy the link (should contain ?tourId=...)
5. Open link in browser on SAME device
6. Verify: App opens to tour details (not web)
```

#### Test 2: App NOT Installed Scenario
```bash
# Device without app installed (or use browser on desktop)
1. Get smart link from above
2. Open link in browser
3. Wait 3 seconds
4. Verify: Redirects to web version with tour details
```

#### Test 3: Cross-Share Scenario
```bash
1. Open app, find tour
2. Tap Share → Copy link
3. Send via WhatsApp to someone
4. They click link:
   - If they have app → opens in app
   - If not → shows web version
```

---

## 📝 Your Next Action Items

### **IMMEDIATE (Do First):**

1. **Build Flutter app** to apply the fixes:
   ```bash
   cd your-flutter-project
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Test the custom scheme is working:**
   
   **iOS:**
   ```bash
   # In iOS Simulator or device
   Open Notes → type: tripshare://tour/test123
   Press and hold → tap "Open"
   # Should either open app or show "Cannot Open"
   ```
   
   **Android:**
   ```bash
   adb shell am start -a android.intent.action.VIEW -d "tripshare://tour/test123"
   # Should open app or give error about app not found
   ```

### **SHORT TERM (Next 1-2 days):**

3. **Go to your Vercel project** and add the API route:
   - If using Next.js: Copy code from `SMART_DEEPLINK_WORKFLOW.md` Step 1 → create `pages/api/tour-link.ts`
   - Deploy to Vercel

4. **Update your landing page** to accept `tourId` and display tour details
   - Create `/api/get-tour` endpoint
   - Set up Firestore admin access
   - Fetch and display tour info

### **VERIFICATION (After setup):**

5. **Test the complete flow:**
   ```bash
   1. Share tour from app
   2. Click link on device WITH app installed
   3. Should open app to tour
   
   4. Click link on device WITHOUT app
   5. Should redirect to web version
   ```

---

## 📊 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    SHARED LINK FLOW                          │
└─────────────────────────────────────────────────────────────┘

1. SHARING (Flutter App)
   ├─ User taps Share
   ├─ generateTourShareLink() called
   ├─ Returns: https://ceylon-trip-share-ytdf.vercel.app/api/tour-link?tourId=ABC
   └─ Shared via WhatsApp/SMS/Email

2. RECEIVING (Browser/Device)
   ├─ User clicks link
   ├─ Lands on Vercel API route (tour-link)
   ├─ Page tries to open: tripshare://tour/ABC
   └─ OS handles redirection

3. APP INSTALLED CASE
   ├─ tripshare:// scheme recognized
   ├─ Android/iOS opens app
   ├─ App receives deep link in main.dart
   ├─ _handleDeepLink() extracts tourId
   ├─ _navigateToTourFromDeepLink() calls Firebase
   ├─ Fetches tour data from Firestore
   └─ Displays TourDetailScreen

4. APP NOT INSTALLED CASE
   ├─ tripshare:// fails after 3 seconds
   ├─ Browser redirects to web version
   ├─ URL: https://ceylon-trip-share-ytdf.vercel.app/?tourId=ABC
   ├─ Web page loads
   ├─ JavaScript fetches /api/get-tour?id=ABC
   ├─ Shows tour details on web
   └─ User can book from web

```

---

## 🔧 Troubleshooting Commands

```bash
# Check if deep link handler is registered (Android)
adb shell cmd package resolve-activity \
  -a android.intent.action.VIEW \
  -d tripshare://tour/test

# Should output something with: com.tripshare.app


# Check Flutter logs for deep link events
flutter logs | grep -i "deep\|link\|🔗\|📱"


# Test if Vercel API route is working
curl "https://ceylon-trip-share-ytdf.vercel.app/api/tour-link?tourId=test123"
# Should return HTML page with redirect logic


# Test if Firestore API is accessible
curl "https://ceylon-trip-share-ytdf.vercel.app/api/get-tour?id=ABC123"
# Should return JSON with tour data
```

---

## ✅ Final Verification Checklist

When complete, verify:

- [ ] Flutter app builds and runs: `flutter run`
- [ ] Vercel API route responds: accessible at `/api/tour-link`
- [ ] Deep link opens app: `adb shell am start -d "tripshare://tour/TEST"`
- [ ] Share generates smart link: Link contains `/api/tour-link?tourId=`
- [ ] Link opens app: Click link on device with app → opens in app
- [ ] Link opens web: Click link on device without app → shows web tour
- [ ] Firestore integration works: Web page displays tour details
- [ ] CrossShare works: Can share via WhatsApp and friend can open tour

---

## 💡 Pro Tips

1. **Test with real tourIds**: Use actual tour IDs from your Firestore for testing
2. **Check Vercel logs**: Look at Vercel dashboard for API request logs
3. **Monitor Flutter logs**: Run `flutter logs` while testing to see deep link events
4. **Use Chrome DevTools**: Inspect redirect flow on web version
5. **Test on real devices**: Emulator behavior may differ from real devices

