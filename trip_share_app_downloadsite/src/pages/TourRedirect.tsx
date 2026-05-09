/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { useEffect, useState } from 'react';
import { useParams, useSearchParams } from 'react-router-dom';
import { Smartphone, Loader, MapPin, Users, Clock, DollarSign, ArrowRight } from 'lucide-react';
import { APP_CONFIG } from '../config';

interface Tour {
  id: string;
  name: string;
  imageUrl: string;
  price: number;
  startLocation: string;
  endLocation: string;
  description: string;
  totalSeats: number;
  remainingSeats: number;
  startDate: string;
  operatorName: string;
  whatsIncluded: string[];
}

export default function TourRedirect() {
  const { tourId } = useParams();
  const [searchParams] = useSearchParams();
  const [tour, setTour] = useState<Tour | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [appCheckTimeout, setAppCheckTimeout] = useState(false);

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

      // Check if app opens (for mobile devices)
      if (isIOS || isAndroid) {
        const timeout = setTimeout(() => {
          if (!document.hidden) {
            // App didn't open
            console.log('App not detected, showing web version');
            setAppCheckTimeout(true);
          }
        }, 2000);

        return () => clearTimeout(timeout);
      } else {
        // For web devices, immediately show web version
        setAppCheckTimeout(true);
      }
    };

    attemptAppDeepLink();
  }, [tourId, searchParams]);

  // Fetch tour details after app check
  useEffect(() => {
    if (!appCheckTimeout || !tourId) return;

    const fetchTour = async () => {
      try {
        setLoading(true);
        const response = await fetch(`/api/get-tour?tourId=${tourId}`);

        if (!response.ok) {
          throw new Error(`Failed to fetch tour: ${response.statusText}`);
        }

        const data = await response.json();
        setTour(data);
        setError(null);
      } catch (err) {
        console.error('Error fetching tour:', err);
        setError(err instanceof Error ? err.message : 'Failed to load tour details');
        setTour(null);
      } finally {
        setLoading(false);
      }
    };

    fetchTour();
  }, [appCheckTimeout, tourId]);

  // Show loading spinner while checking for app
  if (!appCheckTimeout) {
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
              If the app doesn't open automatically, we'll show you the tour details on the web.
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

  // Show error state
  if (error) {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center p-6 bg-gradient-to-br from-emerald-50 to-teal-50">
        <div className="text-center space-y-6 max-w-md">
          <div className="text-6xl">⚠️</div>

          <div className="space-y-3">
            <h1 className="text-3xl font-bold text-emerald-950">Tour Not Found</h1>
            <p className="text-emerald-700/70 leading-relaxed">
              We couldn't find this tour. It may have been deleted or the link might be invalid.
            </p>
          </div>

          <div className="bg-white/60 backdrop-blur-sm rounded-2xl p-6 border border-emerald-100 space-y-4">
            <p className="text-sm text-red-600 font-medium bg-red-50 p-3 rounded-lg">
              {error}
            </p>

            <a
              href="/"
              className="inline-block px-6 py-3 bg-emerald-600 text-white font-semibold rounded-lg hover:bg-emerald-700 transition-colors"
            >
              Back to Home
            </a>
          </div>
        </div>
      </div>
    );
  }

  // Show loading while fetching tour data
  if (loading) {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center p-6 bg-gradient-to-br from-emerald-50 to-teal-50">
        <div className="text-center space-y-6 max-w-md">
          <div className="flex justify-center">
            <div className="animate-spin">
              <Loader className="w-12 h-12 text-emerald-600" />
            </div>
          </div>
          <p className="text-emerald-700/70">Loading tour details...</p>
        </div>
      </div>
    );
  }

  // Show tour details
  if (tour) {
    const startDate = new Date(tour.startDate);
    const formattedDate = startDate.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });

    return (
      <div className="min-h-screen bg-gradient-to-br from-emerald-50 to-teal-50 p-4 md:p-8">
        <div className="max-w-2xl mx-auto">
          {/* Back Button */}
          <a href="/" className="inline-flex items-center gap-2 text-emerald-600 hover:text-emerald-700 font-medium mb-6">
            ← Back
          </a>

          {/* Tour Card */}
          <div className="bg-white rounded-2xl shadow-xl overflow-hidden">
            {/* Hero Image */}
            {tour.imageUrl && (
              <img 
                src={tour.imageUrl} 
                alt={tour.name}
                className="w-full h-64 md:h-80 object-cover"
              />
            )}

            {/* Content */}
            <div className="p-6 md:p-8 space-y-6">
              {/* Title and Price */}
              <div>
                <h1 className="text-3xl md:text-4xl font-bold text-emerald-950 mb-2">
                  {tour.name}
                </h1>
                <p className="text-emerald-600/80 text-sm">{tour.category}</p>
              </div>

              {/* Price and Availability */}
              <div className="flex flex-col md:flex-row gap-4 md:items-center">
                <div className="flex items-baseline gap-2">
                  <span className="text-4xl font-bold text-emerald-600">
                    PKR {tour.price.toLocaleString()}
                  </span>
                  <span className="text-emerald-600/70">per person</span>
                </div>

                <div className="flex items-center gap-2 px-4 py-2 bg-emerald-100 rounded-lg w-fit">
                  <Users className="w-5 h-5 text-emerald-600" />
                  <span className="font-semibold text-emerald-900">
                    {tour.remainingSeats}/{tour.totalSeats} seats left
                  </span>
                </div>
              </div>

              {/* Details Grid */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 py-6 border-y border-emerald-100">
                <div className="flex items-start gap-3">
                  <MapPin className="w-5 h-5 text-emerald-600 flex-shrink-0 mt-1" />
                  <div>
                    <p className="text-sm text-emerald-600/70">Route</p>
                    <p className="font-semibold text-emerald-950">
                      {tour.startLocation} <ArrowRight className="w-4 h-4 inline mx-1" /> {tour.endLocation}
                    </p>
                  </div>
                </div>

                <div className="flex items-start gap-3">
                  <Clock className="w-5 h-5 text-emerald-600 flex-shrink-0 mt-1" />
                  <div>
                    <p className="text-sm text-emerald-600/70">Start Date</p>
                    <p className="font-semibold text-emerald-950">{formattedDate}</p>
                  </div>
                </div>

                {tour.operatorName && (
                  <div className="flex items-start gap-3">
                    <span className="text-sm text-emerald-600/70">Operator</span>
                    <p className="font-semibold text-emerald-950">{tour.operatorName}</p>
                  </div>
                )}
              </div>

              {/* Description */}
              {tour.description && (
                <div>
                  <h2 className="text-lg font-semibold text-emerald-950 mb-3">About This Tour</h2>
                  <p className="text-emerald-700/80 leading-relaxed">{tour.description}</p>
                </div>
              )}

              {/* What's Included */}
              {tour.whatsIncluded && tour.whatsIncluded.length > 0 && (
                <div>
                  <h2 className="text-lg font-semibold text-emerald-950 mb-3">What's Included</h2>
                  <ul className="space-y-2">
                    {tour.whatsIncluded.map((item, index) => (
                      <li key={index} className="flex items-start gap-3 text-emerald-700/80">
                        <span className="text-emerald-600 font-bold">✓</span>
                        <span>{item}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              )}

              {/* Download App Button */}
              <div className="bg-emerald-50 rounded-xl p-6 border border-emerald-200">
                <p className="text-sm text-emerald-700/70 mb-4">
                  Want to book this tour? Download the TripShare app for a better experience.
                </p>
                <div className="flex flex-col sm:flex-row gap-3">
                  <a 
                    href={APP_CONFIG.IOS_APP_URL}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex-1 inline-flex items-center justify-center gap-2 px-4 py-3 bg-emerald-600 text-white font-semibold rounded-lg hover:bg-emerald-700 transition-colors"
                  >
                    📱 Download App
                  </a>
                  <button 
                    onClick={() => window.location.href = APP_CONFIG.DEEP_LINK_SCHEME + `://tour/${tourId}`}
                    className="flex-1 inline-flex items-center justify-center gap-2 px-4 py-3 bg-white text-emerald-600 font-semibold rounded-lg border-2 border-emerald-600 hover:bg-emerald-50 transition-colors"
                  >
                    Open in App
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return null;
}

