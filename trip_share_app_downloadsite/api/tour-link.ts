export default function handler(req: any, res: any) {
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
  const webUrl = `https://ceylon-trip-share-ytdf.vercel.app/tour/${tourId}?name=${name || 'Tour'}&price=${price || '0'}&location=${location || 'Sri Lanka'}`;

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
        const startTime = Date.now();
        let appOpened = false;

        // Try to open the app
        function openApp() {
          document.getElementById('status-text').textContent = 'Opening app...';
          
          // Create hidden iframe to trigger the deep link
          const iframe = document.createElement('iframe');
          iframe.style.display = 'none';
          iframe.src = deepLink;
          document.body.appendChild(iframe);

          // Set timeout to fall back to web
          setTimeout(() => {
            if (!document.hidden) {
              // App didn't open, redirect to web
              document.getElementById('status-text').textContent = 'App not found, opening web version...';
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

        // Fallback after 4 seconds just in case
        setTimeout(() => {
          if (!appOpened && !document.hidden) {
            document.getElementById('status-text').textContent = 'Redirecting...';
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
