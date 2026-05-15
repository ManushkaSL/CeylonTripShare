/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { useEffect } from 'react';
import { useParams, useSearchParams } from 'react-router-dom';

export default function TourRedirect() {
  const { tourId } = useParams();
  const [searchParams] = useSearchParams();

  useEffect(() => {
    if (!tourId) {
      window.location.href = '/';
      return;
    }

    const name = searchParams.get('name') || '';
    const price = searchParams.get('price') || '0';
    const location = searchParams.get('location') || '';

    const isAndroid = /Android/i.test(navigator.userAgent);

    if (isAndroid) {
      // Android Intent URL: 
      // - If app installed → opens the app directly with tripshare://tour/{id}
      // - If app NOT installed → opens the fallback URL (homepage)
      const intentUrl =
        `intent://tour/${tourId}?name=${encodeURIComponent(name)}&price=${price}&location=${encodeURIComponent(location)}` +
        `#Intent;scheme=tripshare;package=com.example.trip_share_app;` +
        `S.browser_fallback_url=${encodeURIComponent('https://ceylon-trip-share-ytdf.vercel.app/')};end`;

      window.location.href = intentUrl;
    } else {
      // iOS / Desktop: try custom scheme, then fallback to homepage
      const customScheme = `tripshare://tour/${tourId}?name=${encodeURIComponent(name)}&price=${price}&location=${encodeURIComponent(location)}`;

      // Try opening the app
      window.location.href = customScheme;

      // If app doesn't open within 1.5s, redirect to homepage
      setTimeout(() => {
        if (!document.hidden) {
          window.location.href = 'https://ceylon-trip-share-ytdf.vercel.app/';
        }
      }, 1500);
    }
  }, [tourId, searchParams]);

  // Brief loading state while redirect happens
  return (
    <div style={{
      minHeight: '100vh',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      background: 'linear-gradient(135deg, #ecfdf5, #f0fdfa)',
      fontFamily: 'system-ui, -apple-system, sans-serif',
    }}>
      <p style={{ color: '#047857', fontSize: '16px' }}>Redirecting...</p>
    </div>
  );
}
