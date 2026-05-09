# Step 3 & 4 Complete - Setup Firebase Credentials on Vercel

## ✅ What I've Created

### Step 3: Firestore API (`api/get-tour.ts`)
- Fetches tour details from Firestore
- Accepts tour ID as parameter
- Returns complete tour data as JSON

### Step 4: Web Tour Display (`TourRedirect.tsx`)
- Beautiful tour details page
- Shows all tour information
- Download app buttons
- Open in app option

---

## 🔧 Setup Firebase Credentials on Vercel

Your new API needs Firebase credentials to access Firestore. Here's how to set it up:

### **Step 1: Get Firebase Credentials**

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your **TripShare** project
3. Go to **Settings** → **Service Accounts**
4. Click **Generate New Private Key**
5. A JSON file will download - **keep it safe!**

Your JSON file will look like:
```json
{
  "type": "service_account",
  "project_id": "your-project-id",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk@your-project-id.iam.gserviceaccount.com",
  "client_id": "...",
  "auth_uri": "...",
  "token_uri": "...",
  "auth_provider_x509_cert_url": "...",
  "client_x509_cert_url": "..."
}
```

### **Step 2: Add Credentials to Vercel**

1. Go to [Vercel Dashboard](https://vercel.com)
2. Click your **trip_share_app_downloadsite** project
3. Click **Settings**
4. Go to **Environment Variables**
5. Add these three variables:

#### Variable 1: Project ID
- **Name:** `FIREBASE_PROJECT_ID`
- **Value:** Copy from JSON → `project_id`
- Click **Add**

#### Variable 2: Client Email
- **Name:** `FIREBASE_CLIENT_EMAIL`
- **Value:** Copy from JSON → `client_email`
- Click **Add**

#### Variable 3: Private Key
- **Name:** `FIREBASE_PRIVATE_KEY`
- **Value:** Copy from JSON → `private_key` (the full key including `-----BEGIN...`)
- Click **Add**

**Important:** Make sure you're setting these for **Production** environment.

---

## 📋 Deploy and Test

### Deploy Your Changes

```bash
cd trip_share_app_downloadsite

# Update dependencies
npm install

# Add and commit files
git add api/get-tour.ts src/pages/TourRedirect.tsx package.json
git commit -m "Add Firestore API and tour display page"

# Push to Vercel
git push origin main
```

Vercel will automatically redeploy. Wait 1-2 minutes for deployment to complete.

---

## 🧪 Test It Works

### Test the API Route

Open this in your browser (replace TOUR_ID with a real tour ID from your Firestore):

```
https://ceylon-trip-share-ytdf.vercel.app/api/get-tour?tourId=YOUR_REAL_TOUR_ID
```

**Expected response (JSON):**
```json
{
  "id": "tour123",
  "name": "Tour Name",
  "price": 5000,
  "startLocation": "Colombo",
  "endLocation": "Kandy",
  "imageUrl": "...",
  "totalSeats": 10,
  "remainingSeats": 3,
  ...
}
```

### Test the Web Page

Open this in your browser:

```
https://ceylon-trip-share-ytdf.vercel.app/tour/YOUR_REAL_TOUR_ID
```

You should see:
- ✅ Loading spinner while app checks
- ✅ After 2 seconds, shows beautiful tour details page
- ✅ Tour information with image, price, location, etc.
- ✅ Download app and Open in app buttons

---

## 🧐 Troubleshooting

| Problem | Solution |
|---------|----------|
| "Firebase credentials not configured" | Check all 3 environment variables are set in Vercel Settings |
| API returns 404 | Tour ID doesn't exist in Firestore. Use a valid tour ID |
| Page shows error | Check browser console (F12) for details. Might be credentials issue |
| Tour image not showing | Make sure `imageUrl` field exists in Firestore tour document |

---

## 🔄 Complete Flow Now Works

```
User shares tour from Flutter app
    ↓
Gets smart link: /api/tour-link?tourId=ABC123...
    ↓
User clicks link
    ↓
  ✓ App installed → Opens app to tour
  ✓ App NOT installed → Shows web page with tour details
```

---

## ✅ Next Steps

Once everything works:

1. **Test sharing from app:**
   ```bash
   # In Flutter app
   flutter run
   ```
   - Find a tour
   - Tap Share
   - Copy the link

2. **Test on device WITHOUT app:**
   - Click link on browser/different device
   - Should see tour details page

3. **Test on device WITH app:**
   - Click link on same device as app
   - Should open app directly

---

## 🎉 Congratulations!

You now have a complete smart deep link system:
- ✅ Flutter app generates smart share links
- ✅ Vercel detects if app is installed
- ✅ Opens app if available
- ✅ Shows beautiful web page if app not installed
- ✅ Firestore integration for tour details

All ready to go live! 🚀
