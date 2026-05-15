// Save this as next.js API route or add to your Vercel project
// File: pages/api/tour-link.ts (or /api/tour-link/route.ts for App Router)

import type { NextApiRequest, NextApiResponse } from 'next';

export default function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const { tourId, name, price, location } = req.query;

  // Get user agent to detect platform
  const userAgent = req.headers['user-agent'] || '';
  const isIOS = /iPad|iPhone|iPod/.test(userAgent);
  const isAndroid = /Android/.test(userAgent);

  // Build custom deep link
  const deepLink = `tripshare://tour/${tourId}`;
  
  // If app not found, redirect to download page with tourId so "Open in App" button works
  const downloadUrl = `https://ceylon-trip-share-ytdf.vercel.app/?tourId=${tourId}`;

  // HTML page that tries to open app and falls back to web
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
        }
        .container {
          text-align: center;
          color: white;
          max-width: 400px;
        }
        .spinner {
          border: 4px solid rgba(255, 255, 255, 0.3);
          border-top: 4px solid white;
          border-radius: 50%;
          width: 40px;
          height: 40px;
          animation: spin 1s linear infinite;
          margin: 0 auto 20px;
        }
        @keyframes spin {
          0% { transform: rotate(0deg); }
          100% { transform: rotate(360deg); }
        }
        h1 {
          font-size: 20px;
          margin: 0 0 10px 0;
        }
        p {
          font-size: 14px;
          color: #ccc;
          margin: 0 0 30px 0;
        }
        .button {
          display: inline-block;
          padding: 12px 30px;
          background: #007AFF;
          color: white;
          text-decoration: none;
          border-radius: 8px;
          font-weight: 600;
          margin-top: 20px;
        }
        .button:hover {
          background: #0051D5;
        }
        .error-icon {
          font-size: 50px;
          margin-bottom: 15px;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="spinner"></div>
        <h1>Opening Tour...</h1>
        <p>Attempting to open in your app</p>
        <p id="status">If your app doesn't open, you'll be redirected...</p>
        <a id="fallback-link" href="${downloadUrl}" class="button">
          Download App
        </a>
      </div>

      <script>
        // Store tour info for when app opens
        sessionStorage.setItem('pendingTourId', '${tourId}');
        sessionStorage.setItem('pendingTourData', JSON.stringify({
          tourId: '${tourId}',
          name: '${name}',
          price: '${price}',
          location: '${location}'
        }));

        const deepLink = '${deepLink}';
        const isIOS = ${isIOS ? 'true' : 'false'};
        const isAndroid = ${isAndroid ? 'true' : 'false'};
        const downloadUrl = '${downloadUrl}';
        const packageName = 'com.example.trip_share_app';

        let appOpened = false;
        const startTime = Date.now();
        let pageVisited = false;

        // Track if the page goes out of focus (app opened)
        document.addEventListener('visibilitychange', () => {
          if (document.hidden) {
            appOpened = true;
            pageVisited = false;
            console.log('✅ App detected as opened (visibility changed)');
          } else {
            pageVisited = true;
            console.log('⚠️ Page came to foreground');
          }
        });

        // Track if window loses focus (app opened)
        window.addEventListener('blur', () => {
          appOpened = true;
          pageVisited = false;
          console.log('✅ App detected as opened (blur event)');
        });

        window.addEventListener('focus', () => {
          pageVisited = true;
          console.log('⚠️ Window focused - app might not have opened');
        });

        // Attempt to open the app
        function attemptOpenApp() {
          try {
            console.log('Attempting to open app via deepLink:', deepLink);
            console.log('Platform - Android: ' + isAndroid + ', iOS: ' + isIOS);
            
            // Direct approach: Use window.location.href to open the deep link
            // This is the most reliable method on mobile browsers
            window.location.href = deepLink;
            
            appOpened = true; // Assume it worked
            
          } catch (e) {
            console.error('Error opening app:', e);
          }
        }

        // Start the process when page loads
        window.addEventListener('load', () => {
          console.log('📱 Page loaded, attempting to open app with deepLink:', deepLink);
          attemptOpenApp();

          // Wait for app to open - if it does, page will lose focus
          // If not, after timeout we redirect to download page
          setTimeout(() => {
            const elapsed = Date.now() - startTime;
            console.log('⏱️ Timeout check - Elapsed: ' + elapsed + 'ms, appOpened: ' + appOpened + ', pageVisi: ' + pageVisited);
            
            // If app opened (either via blur or visibility), don't redirect
            if (appOpened) {
              console.log('✅ App opened successfully, not redirecting');
              return;
            }
            
            // If page is not visible, app might be opening
            if (document.hidden) {
              console.log('📱 Page hidden, app likely opening...');
              return;
            }
            
            // If we reach here, app didn't open - redirect to download page
            console.log('❌ App did not open, redirecting to download page:', downloadUrl);
            document.getElementById('status').textContent = 'App not found. Downloading...';
            window.location.href = downloadUrl;
            
          }, 5000); // 5 second timeout
        });

        // Also try immediately if script loads after body
        attemptOpenApp();
      </script>
    </body>
    </html>
  `;

  res.status(200).setHeader('Content-Type', 'text/html').send(html);
}
