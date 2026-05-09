# Smart Deep Link Workflow - App Detection & Routing

## 🎯 How It Works

```
User clicks shared link
    ↓
Lands on smart redirect page
    ↓
  ┌─────────────────────────────────┐
  │  Detect if app is installed     │
  └─────────────────────────────────┘
       ↓ (App Open)      ↓ (App Not Found)
   ┌───────────┐       ┌──────────────┐
   │   NATIVE  │       │   WEB APP    │
   │   APP     │       │   VERSION    │
   │ Opens     │       │ Shows Tour   │
   │ Tour      │       │ Details      │
   │ Details   │       │              │
   └───────────┘       └──────────────┘
```

---

## ✅ Step 1: Add API Route to Your Vercel Project

### For Next.js Pages Router:

Create file: `pages/api/tour-link.ts`

```typescript
import type { NextApiRequest, NextApiResponse } from 'next';

export default function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const { tourId, name, price, location } = req.query;

  if (!tourId) {
    return res.status(400).json({ error: 'tourId is required' });
  }

  const deepLink = `tripshare://tour/${tourId}`;
  const webUrl = `https://ceylon-trip-share-ytdf.vercel.app/?tourId=${tourId}`;
  const userAgent = req.headers['user-agent'] || '';

  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <title>Opening Tour...</title>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style>
        body {
          margin: 0;
          padding: 20px;
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          background: #1a1a1a;
          display: flex;
          align-items: center;
          justify-content: center;
          min-height: 100vh;
          color: white;
        }
        .container { text-align: center; max-width: 400px; }
        .spinner {
          border: 4px solid rgba(255, 255, 255, 0.3);
          border-top: 4px solid white;
          border-radius: 50%;
          width: 40px;
          height: 40px;
          animation: spin 1s linear infinite;
          margin: 0 auto 20px;
        }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
        h1 { font-size: 20px; margin: 0 0 10px 0; }
        p { font-size: 14px; color: #ccc; margin: 0 0 30px 0; }
        .button {
          display: inline-block;
          padding: 12px 30px;
          background: #FF6B4A;
          color: white;
          text-decoration: none;
          border-radius: 8px;
          font-weight: 600;
          margin-top: 20px;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="spinner"></div>
        <h1>Opening Tour...</h1>
        <p>Redirecting to the app</p>
        <a href="${webUrl}" class="button">Open in Web</a>
      </div>

      <script>
        const deepLink = '${deepLink}';
        const webUrl = '${webUrl}';
        const startTime = Date.now();

        // Try to open app via deep link
        function openApp() {
          const iframe = document.createElement('iframe');
          iframe.style.display = 'none';
          iframe.src = deepLink;
          document.body.appendChild(iframe);

          // Set timeout to fall back to web
          setTimeout(() => {
            if (!document.hidden) {
              window.location.href = webUrl;
            }
          }, 3000);
        }

        // Start when page loads
        window.addEventListener('load', openApp);
        openApp();
      </script>
    </body>
    </html>
  `;

  res.status(200).setHeader('Content-Type', 'text/html').send(html);
}
```

### For Next.js App Router:

Create file: `app/api/tour-link/route.ts`

```typescript
import { NextRequest } from 'next/server';

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const tourId = searchParams.get('tourId');
  const name = searchParams.get('name');
  const price = searchParams.get('price');
  const location = searchParams.get('location');

  if (!tourId) {
    return new Response('tourId is required', { status: 400 });
  }

  const deepLink = `tripshare://tour/${tourId}`;
  const webUrl = `https://ceylon-trip-share-ytdf.vercel.app/?tourId=${tourId}`;

  // ... rest of HTML same as above ...

  return new Response(html, {
    headers: { 'Content-Type': 'text/html' },
  });
}
```

---

## ✅ Step 2: Update Share Link Generation in Flutter

Modify `lib/services/dynamic_link_service.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:trip_share_app/models/tour.dart';

class DynamicLinkService {
  // Your smart redirect endpoint
  static const String _baseUrl = 'https://ceylon-trip-share-ytdf.vercel.app';
  static const String _apiEndpoint = '$_baseUrl/api/tour-link';

  /// Generate a shareable link that detects app installation
  Future<String> generateTourShareLink(Tour tour) async {
    try {
      debugPrint('🔗 Generating smart share link for tour: ${tour.id}');

      // Create link to smart redirect API
      final shareUrl = '$_apiEndpoint'
          '?tourId=${tour.id}'
          '&name=${Uri.encodeComponent(tour.name)}'
          '&price=${tour.price.toInt()}'
          '&location=${Uri.encodeComponent(tour.startLocation)}';

      debugPrint('✅ Smart share link generated: $shareUrl');
      return shareUrl;
    } catch (e) {
      debugPrint('⚠️ Error generating share link: $e');
      return _baseUrl;
    }
  }

  /// Generate share message
  Future<String> getTourShareMessage(Tour tour) async {
    try {
      final shareLink = await generateTourShareLink(tour);
      return 'Check out this amazing tour: ${tour.name}\n'
          '💰 PKR ${tour.price.toInt()} per person\n'
          '📍 ${tour.startLocation}\n'
          '📅 Available seats: ${tour.remainingSeats}/${tour.totalSeats}\n\n'
          '$shareLink';
    } catch (e) {
      debugPrint('⚠️ Error creating share message: $e');
      return 'Check out this tour: ${tour.name}\n$_baseUrl';
    }
  }
}
```

---

## ✅ Step 3: Update Web Page to Show Tour Details

Your Vercel landing page needs to accept `tourId` and display tour:

```html
<!-- In your Vercel project or index page -->
<script>
  const params = new URLSearchParams(window.location.search);
  const tourId = params.get('tourId');

  if (tourId) {
    // Fetch tour from Firestore
    fetch('/api/get-tour?id=' + tourId)
      .then(res => res.json())
      .then(tour => {
        // Display tour details on web
        document.getElementById('tour-name').textContent = tour.name;
        document.getElementById('tour-price').textContent = '₨' + tour.price;
        document.getElementById('tour-location').textContent = tour.startLocation;
        document.getElementById('tour-image').src = tour.imageUrl;
        
        // Show booking button
        document.getElementById('book-btn').href = '/booking?tourId=' + tourId;
      })
      .catch(err => {
        // Show fallback if tour not found
        document.getElementById('error').style.display = 'block';
      });
  }
</script>
```

---

## ✅ Step 4: Create Web API Route to Fetch Tour

Create file: `pages/api/get-tour.ts` (or `app/api/get-tour/route.ts`)

```typescript
import type { NextApiRequest, NextApiResponse } from 'next';
import * as admin from 'firebase-admin';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  try {
    const { id } = req.query;

    if (!id) {
      return res.status(400).json({ error: 'Tour ID required' });
    }

    // Initialize Firebase Admin SDK (set up environment variables)
    const db = admin.firestore();
    
    const tourDoc = await db.collection('tours').doc(id as string).get();

    if (!tourDoc.exists) {
      return res.status(404).json({ error: 'Tour not found' });
    }

    return res.status(200).json({
      id: tourDoc.id,
      ...tourDoc.data(),
    });
  } catch (error) {
    console.error('Error fetching tour:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}
```

---

## 🧪 Testing the Workflow

### Test 1: Share from App
```bash
1. Open app
2. Select a tour
3. Tap Share button
4. Copy the API link (should be: https://ceylon-trip-share-ytdf.vercel.app/api/tour-link?tourId=...)
5. Open in browser on same phone
```

Expected behavior:
- ✅ Page shows "Opening Tour..." spinner
- ✅ After 3 seconds, app opens to tour details
- ✅ If app not installed, redirects to web version

### Test 2: Simulate No App
```bash
1. Get the smart link
2. Open on a device where app isn't installed
3. Click the link
```

Expected behavior:
- ✅ Redirect page shows
- ✅ After 3 seconds, shows web version of tour
- ✅ User can still see tour details and possibly book

---

## 📋 Deployment Checklist

- [ ] API route created in Vercel project (`pages/api/tour-link.ts`)
- [ ] API route deployed to Vercel
- [ ] `dynamic_link_service.dart` updated with API endpoint
- [ ] Web page updated to accept `tourId` parameter
- [ ] Web API route created (`pages/api/get-tour.ts`)
- [ ] Tour details page created on web version
- [ ] Tested on iOS device with app installed
- [ ] Tested on iOS device without app installed
- [ ] Tested on Android device with app installed
- [ ] Tested on Android device without app installed
- [ ] Flutter app rebuilt: `flutter clean && flutter pub get && flutter run`

---

## 🔍 How to Deploy the API Routes

### If you're using Next.js:

```bash
cd your-vercel-project
npm install  # or yarn install
npm run deploy  # or use `vercel deploy`
```

### If you don't have Next.js:

You can add a simple Node/Express endpoint:

```bash
# Add to package.json scripts
"api": "node api/tour-link.js"
```

Create `api/tour-link.js`:

```javascript
module.exports = (req, res) => {
  const { tourId } = req.query;
  const deepLink = `tripshare://tour/${tourId}`;
  const webUrl = `https://ceylon-trip-share-ytdf.vercel.app/?tourId=${tourId}`;
  
  // Send the HTML redirect page...
};
```

---

## ⚠️ Troubleshooting

| Issue | Solution |
|-------|----------|
| "App not opening" | Check that deep link handler is working with: `adb shell am start -a android.intent.action.VIEW -d "tripshare://tour/TEST123"` |
| "Always goes to web" | Deep link might have wrong format. Check logs in: `flutter logs` |
| "API route 404" | Make sure route is deployed. Check Vercel dashboard for deployment |
| "Web page blank" | Make sure `/api/get-tour` endpoint exists and Firebase config is correct |

