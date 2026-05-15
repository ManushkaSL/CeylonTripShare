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
  
  // If app not found, redirect to download page
  const downloadUrl = `https://ceylon-trip-share-ytdf.vercel.app/`;

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
        <p>Redirecting to the app</p>
        <p id="status">Please wait...</p>
        <a id="fallback-link" href="https://ceylon-trip-share-ytdf.vercel.app/" class="button">
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
        // If app not found, redirect to download page
        const downloadUrl = 'https://ceylon-trip-share-ytdf.vercel.app/';
        const packageName = 'com.example.trip_share_app';

        // Attempt to open the app
        function attemptOpenApp() {
          try {
            if (isAndroid) {
              // Android: Use intent URI for more reliable app detection
              const intentUri = 'intent://tour/${tourId}#Intent;scheme=tripshare;package=' + packageName + ';end';
              window.location.href = intentUri;
            } else {
              // iOS and others: Use custom scheme directly
              window.location.href = deepLink;
            }
          } catch (e) {
            console.error('Error opening app:', e);
            // Fall back immediately
            redirectToHome();
          }
        }

        function redirectToHome() {
          document.getElementById('status').textContent = 'Opening app...';
          window.location.href = downloadUrl;
        }

        // Start the process when page loads
        window.addEventListener('load', () => {
          console.log('Page loaded, attempting to open app...');
          attemptOpenApp();

          // Fallback timeout: if still on this page after 4 seconds, app didn't open
          // or user dismissed the app dialog
          setTimeout(() => {
            if (document.hidden === false) {
              console.log('No response from app, redirecting to home...');
              redirectToHome();
            }
          }, 4000);
        });

        // Also start immediately if script loads after body
        attemptOpenApp();
      </script>
    </body>
    </html>
  `;

  res.status(200).setHeader('Content-Type', 'text/html').send(html);
}
