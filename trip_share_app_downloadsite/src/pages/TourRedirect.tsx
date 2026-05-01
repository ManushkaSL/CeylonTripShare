/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { useEffect } from 'react';
import { useParams, useSearchParams } from 'react-router-dom';
import { Smartphone, Loader } from 'lucide-react';
import { APP_CONFIG } from '../config';

export default function TourRedirect() {
  const { tourId } = useParams();
  const [searchParams] = useSearchParams();

  useEffect(() => {
    if (!tourId) return;

    // Extract tour details from URL parameters
    const name = searchParams.get('name') || 'Amazing Tour';
    const price = searchParams.get('price') || '0';
    const location = searchParams.get('location') || 'Unknown';

    // Detect device type
    const userAgent = navigator.userAgent;
    const isIOS = /iPad|iPhone|iPod/.test(userAgent);
    const isAndroid = /Android/.test(userAgent);

    // Custom URL scheme for the app
    const customScheme = `${APP_CONFIG.DEEP_LINK_SCHEME}://tour/${tourId}?name=${encodeURIComponent(name)}&price=${price}&location=${encodeURIComponent(location)}`;

    console.log(`Device detected: ${isIOS ? 'iOS' : isAndroid ? 'Android' : 'Web'}`);
    console.log(`Attempting deep link: ${customScheme}`);

    // Attempt to open the app with the custom scheme
    const attemptAppDeepLink = () => {
      // Create an iframe to silently attempt the deep link
      const iframe = document.createElement('iframe');
      iframe.style.display = 'none';
      iframe.src = customScheme;
      document.body.appendChild(iframe);

      // If the app doesn't open after 2 seconds, redirect to the store
      const timeout = setTimeout(() => {
        if (isIOS) {
          window.location.href = APP_CONFIG.IOS_APP_URL;
        } else if (isAndroid) {
          window.location.href = APP_CONFIG.ANDROID_APP_URL;
        } else {
          // For web, show the download page
          window.location.href = '/';
        }
      }, 2000);

      // Cleanup
      return () => clearTimeout(timeout);
    };

    attemptAppDeepLink();
  }, [tourId, searchParams]);

  return (
    <div className="min-h-screen flex flex-col items-center justify-center p-6 bg-gradient-to-br from-emerald-50 to-teal-50">
      <div className="text-center space-y-6 max-w-md">
        <div className="flex justify-center">
          <div className="animate-spin">
            <Loader className="w-12 h-12 text-emerald-600" />
          </div>
        </div>

        <div className="space-y-3">
          <h1 className="text-3xl font-bold text-emerald-950">Opening Tour</h1>
          <p className="text-emerald-700/70 leading-relaxed">
            We're attempting to open the tour in your TripShare app...
          </p>
        </div>

        <div className="bg-white/60 backdrop-blur-sm rounded-2xl p-6 border border-emerald-100 space-y-4">
          <p className="text-sm text-emerald-900/70">
            If the app doesn't open automatically, you'll be redirected to the app store to download TripShare.
          </p>

          <div className="flex items-center justify-center gap-2 text-xs text-emerald-600">
            <Smartphone className="w-4 h-4" />
            <span>Opening app...</span>
          </div>
        </div>
      </div>
    </div>
  );
}
