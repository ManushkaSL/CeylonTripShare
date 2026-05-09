# Step 2: Add Vercel API Route - Complete Guide

## 🎯 What This Step Does

Creates a smart redirect page on your Vercel that:
1. Tries to open the app (using `tripshare://` scheme)
2. If app installed → opens in app
3. If app NOT installed → redirects to web version after 3 seconds

---

## 📋 Prerequisites

Before starting, you need:
1. Access to your Vercel project (ceylon-trip-share-ytdf.vercel.app)
2. Know if you're using **Next.js** or plain HTML/Node.js
3. Git installed and connected to your Vercel repo

### How to Check Your Project Type:

**In your Vercel project folder:**
```bash
# If you see these files → it's Next.js
ls package.json
ls pages/  (or app/)

# If you don't see pages/ or app/ → it's plain HTML/Node.js
ls public/
ls index.html
```

---

## 🛠️ Step 2.1: Check Your Project Type

### Option A: Check on Vercel Dashboard
1. Go to [vercel.com](https://vercel.com)
2. Click your **TripShare** project
3. Go to **Settings** → **Environment Variables**
4. Look for `NEXT_PUBLIC_*` variables (means it's Next.js)
5. OR check **Deployments** and see if it mentions "Next.js"

### Option B: Check Git Repo
```bash
cd your-vercel-project-folder  # if you have it locally
cat package.json | grep "next\|express\|nuxt"
```

---

## ✅ Step 2.2: Add the API Route

### If You Have NEXT.JS:

**Create this file:**
```
your-vercel-project/
├── pages/
│   ├── api/
│   │   └── tour-link.ts  ← CREATE THIS FILE
│   └── ...
└── package.json
```

**File path:** `pages/api/tour-link.ts`

**Copy & Paste this code:**

```typescript
import type { NextApiRequest, NextApiResponse } from 'next';

export default function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const { tourId, name, price, location } = req.query;

  if (!tourId) {
    return res.status(400).json({ 
      error: 'tourId parameter is required',
      example: '/api/tour-link?tourId=ABC123&name=Tour%20Name&price=5000&location=City'
    });
  }

  // Build the deep link that opens the app
  const deepLink = `tripshare://tour/${tourId}`;
  
  // Fallback web URL if app is not installed
  const webUrl = `https://ceylon-trip-share-ytdf.vercel.app/?tourId=${tourId}&name=${name || 'Tour'}&price=${price || '0'}&location=${location || 'Sri Lanka'}`;

  // HTML page that tries to open app and falls back to web
  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <title>Opening Tour...</title>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          background: linear-gradient(135deg, #FF6B4A 0%, #FF8566 100%);
          display: flex;
          align-items: center;
          justify-content: center;
          min-height: 100vh;
          padding: 20px;
        }
        .container {
          text-align: center;
          background: rgba(255, 255, 255, 0.95);
          padding: 40px;
          border-radius: 16px;
          max-width: 400px;
          box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
        }
        .spinner {
          border: 4px solid rgba(255, 107, 74, 0.2);
          border-top: 4px solid #FF6B4A;
          border-radius: 50%;
          width: 50px;
          height: 50px;
          animation: spin 1s linear infinite;
          margin: 0 auto 25px;
        }
        @keyframes spin {
          0% { transform: rotate(0deg); }
          100% { transform: rotate(360deg); }
        }
        h1 {
          font-size: 22px;
          color: #333;
          margin: 0 0 12px 0;
          font-weight: 600;
        }
        .status {
          font-size: 14px;
          color: #666;
          margin-bottom: 30px;
          min-height: 40px;
          display: flex;
          align-items: center;
          justify-content: center;
        }
        .buttons {
          display: flex;
          flex-direction: column;
          gap: 12px;
        }
        .button {
          padding: 14px 28px;
          font-size: 16px;
          font-weight: 600;
          border: none;
          border-radius: 10px;
          cursor: pointer;
          text-decoration: none;
          transition: all 0.3s ease;
          display: inline-block;
        }
        .button-primary {
          background: #FF6B4A;
          color: white;
        }
        .button-primary:hover {
          background: #E55A39;
          transform: translateY(-2px);
          box-shadow: 0 5px 15px rgba(255, 107, 74, 0.4);
        }
        .button-secondary {
          background: #f0f0f0;
          color: #333;
        }
        .button-secondary:hover {
          background: #e0e0e0;
        }
        .info {
          font-size: 12px;
          color: #999;
          margin-top: 20px;
          padding-top: 20px;
          border-top: 1px solid #eee;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="spinner"></div>
        <h1>Opening Tour</h1>
        <div class="status">
          <span id="status-text">Checking for app...</span>
        </div>
        
        <div class="buttons">
          <a href="${deepLink}" class="button button-primary" id="app-link">
            Open in App
          </a>
          <a href="${webUrl}" class="button button-secondary">
            Open in Web
          </a>
        </div>
        
        <div class="info">
          <p>If the app doesn't open automatically, click "Open in App" or use the web version.</p>
        </div>
      </div>

      <script>
        const deepLink = '${deepLink}';
        const webUrl = '${webUrl}';
        const statusText = document.getElementById('status-text');
        const appLink = document.getElementById('app-link');
        const startTime = Date.now();
        let appOpened = false;

        // Try to open the app
        function openApp() {
          statusText.textContent = 'Opening app...';
          
          // Create hidden iframe to trigger the deep link
          const iframe = document.createElement('iframe');
          iframe.style.display = 'none';
          iframe.src = deepLink;
          document.body.appendChild(iframe);

          // Set a timeout to redirect if app doesn't open
          setTimeout(() => {
            if (!document.hidden) {
              // App didn't open, redirect to web
              statusText.textContent = 'App not found, opening web version...';
              setTimeout(() => {
                window.location.href = webUrl;
              }, 800);
            }
          }, 2500);
        }

        // Listen for visibility changes (app opening)
        document.addEventListener('visibilitychange', () => {
          if (document.hidden) {
            appOpened = true;
          }
        });

        // Start the process when page loads
        window.addEventListener('load', () => {
          openApp();
        });

        // Also try immediately
        openApp();

        // Fallback after 4 seconds
        setTimeout(() => {
          if (!appOpened && !document.hidden) {
            statusText.textContent = 'Redirecting...';
            window.location.href = webUrl;
          }
        }, 4000);
      </script>
    </body>
    </html>
  `;

  // Send the HTML response
  res.status(200)
    .setHeader('Content-Type', 'text/html; charset=utf-8')
    .send(html);
}
```

**That's it!** Now go to Step 2.3 to deploy.

---

### If You DON'T Have Next.js (Plain HTML/Node):

**Create this file in your Vercel project root:**
```
your-vercel-project/
├── api/
│   └── tour-link.js  ← CREATE THIS FILE
└── package.json
```

**File path:** `api/tour-link.js`

**Copy & Paste this code:**

```javascript
module.exports = (req, res) => {
  const { tourId, name, price, location } = req.query;

  if (!tourId) {
    return res.status(400).json({ 
      error: 'tourId parameter is required',
      example: '/api/tour-link?tourId=ABC123&name=Tour%20Name&price=5000&location=City'
    });
  }

  const deepLink = `tripshare://tour/${tourId}`;
  const webUrl = `https://ceylon-trip-share-ytdf.vercel.app/?tourId=${tourId}&name=${name || 'Tour'}&price=${price || '0'}&location=${location || 'Sri Lanka'}`;

  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <title>Opening Tour...</title>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          background: linear-gradient(135deg, #FF6B4A 0%, #FF8566 100%);
          display: flex;
          align-items: center;
          justify-content: center;
          min-height: 100vh;
          padding: 20px;
        }
        .container {
          text-align: center;
          background: rgba(255, 255, 255, 0.95);
          padding: 40px;
          border-radius: 16px;
          max-width: 400px;
          box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
        }
        .spinner {
          border: 4px solid rgba(255, 107, 74, 0.2);
          border-top: 4px solid #FF6B4A;
          border-radius: 50%;
          width: 50px;
          height: 50px;
          animation: spin 1s linear infinite;
          margin: 0 auto 25px;
        }
        @keyframes spin {
          0% { transform: rotate(0deg); }
          100% { transform: rotate(360deg); }
        }
        h1 {
          font-size: 22px;
          color: #333;
          margin: 0 0 12px 0;
          font-weight: 600;
        }
        .status {
          font-size: 14px;
          color: #666;
          margin-bottom: 30px;
          min-height: 40px;
          display: flex;
          align-items: center;
          justify-content: center;
        }
        .buttons {
          display: flex;
          flex-direction: column;
          gap: 12px;
        }
        .button {
          padding: 14px 28px;
          font-size: 16px;
          font-weight: 600;
          border: none;
          border-radius: 10px;
          cursor: pointer;
          text-decoration: none;
          transition: all 0.3s ease;
          display: inline-block;
        }
        .button-primary {
          background: #FF6B4A;
          color: white;
        }
        .button-primary:hover {
          background: #E55A39;
          transform: translateY(-2px);
          box-shadow: 0 5px 15px rgba(255, 107, 74, 0.4);
        }
        .button-secondary {
          background: #f0f0f0;
          color: #333;
        }
        .button-secondary:hover {
          background: #e0e0e0;
        }
        .info {
          font-size: 12px;
          color: #999;
          margin-top: 20px;
          padding-top: 20px;
          border-top: 1px solid #eee;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="spinner"></div>
        <h1>Opening Tour</h1>
        <div class="status">
          <span id="status-text">Checking for app...</span>
        </div>
        
        <div class="buttons">
          <a href="${deepLink}" class="button button-primary" id="app-link">
            Open in App
          </a>
          <a href="${webUrl}" class="button button-secondary">
            Open in Web
          </a>
        </div>
        
        <div class="info">
          <p>If the app doesn't open automatically, click "Open in App".</p>
        </div>
      </div>

      <script>
        const deepLink = '${deepLink}';
        const webUrl = '${webUrl}';
        const startTime = Date.now();

        function openApp() {
          document.getElementById('status-text').textContent = 'Opening app...';
          
          const iframe = document.createElement('iframe');
          iframe.style.display = 'none';
          iframe.src = deepLink;
          document.body.appendChild(iframe);

          setTimeout(() => {
            if (!document.hidden) {
              document.getElementById('status-text').textContent = 'Opening web version...';
              setTimeout(() => {
                window.location.href = webUrl;
              }, 500);
            }
          }, 2500);
        }

        window.addEventListener('load', openApp);
        openApp();

        setTimeout(() => {
          if (!document.hidden) {
            window.location.href = webUrl;
          }
        }, 4000);
      </script>
    </body>
    </html>
  `;

  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.end(html);
};
```

---

## ✅ Step 2.3: Deploy to Vercel

### Option A: Deploy via Git (Recommended)

```bash
# 1. Navigate to your Vercel project folder
cd your-vercel-project-location

# 2. Add the new file to git
git add pages/api/tour-link.ts
# OR
git add api/tour-link.js

# 3. Commit the changes
git commit -m "Add smart tour link redirect API"

# 4. Push to main branch
git push origin main
```

**Vercel will automatically deploy!** Check [vercel.com](https://vercel.com) dashboard → your project → you should see "Deployed" status in a few seconds.

---

### Option B: Deploy via Vercel CLI

```bash
# If you don't have Vercel CLI installed
npm install -g vercel

# Deploy directly
vercel deploy

# Or deploy production
vercel deploy --prod
```

---

## ✅ Step 2.4: Verify It's Working

### Test the API Route

**Open in your browser:**
```
https://ceylon-trip-share-ytdf.vercel.app/api/tour-link?tourId=ABC123&name=Test%20Tour&price=5000&location=Colombo
```

**Expected result:**
- ✅ Page shows spinner with "Checking for app..."
- ✅ Page tries to open app (you'll see an attempt if app installed)
- ✅ After 3 seconds, either:
  - Opens the app (if you have it), OR
  - Shows the manual buttons

**If you see a 404 or error:**
- Wait 30 seconds for Vercel to fully deploy
- Check your file is in correct location:
  - `pages/api/tour-link.ts` (Next.js), OR
  - `api/tour-link.js` (Node.js)
- Check Vercel dashboard for deployment errors
- Check file name spelling exactly

---

## 📝 How the Share Link Flow Works Now

```
1. User taps Share in Flutter app
   ↓
2. Flutter generates URL:
   https://ceylon-trip-share-ytdf.vercel.app/api/tour-link?
   tourId=ABC123&name=Tour1&price=5000&location=Colombo
   ↓
3. You send this link via WhatsApp/Email/SMS
   ↓
4. Friend clicks the link
   ↓
5. Vercel API route opens:
   - Try to open: tripshare://tour/ABC123
   - If app installed → opens app to tour
   - If not → redirect to web after 3 seconds

```

---

## ✅ Checklist for Step 2

- [ ] Checked if project is Next.js or Node.js
- [ ] Created correct file:
  - [ ] `pages/api/tour-link.ts` (Next.js), OR
  - [ ] `api/tour-link.js` (Node.js)
- [ ] Copied complete code into file
- [ ] Committed and pushed to GitHub
- [ ] Waited for Vercel deployment (check dashboard)
- [ ] Tested URL in browser
- [ ] Got "Opening Tour..." page with spinner
- [ ] Verified no 404 errors

---

## 🆘 Troubleshooting

| Problem | Solution |
|---------|----------|
| 404 Not Found | File in wrong location. Check exact path: `pages/api/tour-link.ts` |
| Deployment not working | Check git push succeeded. See Vercel dashboard for errors |
| Page loads but doesn't redirect | Clear browser cache. Try incognito/private window |
| "App not found" after 3 sec | Normal! It means app isn't installed on that device. Should show web fallback |

---

## 📋 Next Steps

Once Step 2 is complete:
1. Move to **Step 3**: Create Firestore API (`/api/get-tour`)
2. Then **Step 4**: Update web app to show tours
3. Then test complete flow

Need help with anything in Step 2? Let me know! 👍

