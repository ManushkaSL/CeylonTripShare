/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { useEffect, useState } from 'react';
import { useParams, useSearchParams } from 'react-router-dom';
import { Loader, MapPin, Users, Clock, ArrowRight } from 'lucide-react';
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

  // If someone reaches this page, it means App Links didn't intercept the URL
  // (i.e., the app is not installed). Just show tour details + download prompt.
  useEffect(() => {
    if (!tourId) return;

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
        // Fallback to URL params if API fails
        const name = searchParams.get('name');
        const price = searchParams.get('price');
        const location = searchParams.get('location');

        if (name) {
          setTour({
            id: tourId,
            name: name,
            imageUrl: '',
            price: Number(price) || 0,
            startLocation: location || 'Unknown',
            endLocation: '',
            description: '',
            totalSeats: 0,
            remainingSeats: 0,
            startDate: '',
            operatorName: '',
            whatsIncluded: [],
          });
          setError(null);
        } else {
          setError(err instanceof Error ? err.message : 'Failed to load tour details');
        }
      } finally {
        setLoading(false);
      }
    };

    fetchTour();
  }, [tourId, searchParams]);

  // Loading state
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

  // Error state
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

  // Show tour details (user doesn't have the app, so show download prompt)
  if (tour) {
    const startDate = tour.startDate ? new Date(tour.startDate) : null;
    const formattedDate = startDate
      ? startDate.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
      : '';

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
              {/* Title */}
              <div>
                <h1 className="text-3xl md:text-4xl font-bold text-emerald-950 mb-2">
                  {tour.name}
                </h1>
              </div>

              {/* Price and Availability */}
              <div className="flex flex-col md:flex-row gap-4 md:items-center">
                <div className="flex items-baseline gap-2">
                  <span className="text-4xl font-bold text-emerald-600">
                    LKR {tour.price.toLocaleString()}
                  </span>
                  <span className="text-emerald-600/70">per person</span>
                </div>

                {tour.totalSeats > 0 && (
                  <div className="flex items-center gap-2 px-4 py-2 bg-emerald-100 rounded-lg w-fit">
                    <Users className="w-5 h-5 text-emerald-600" />
                    <span className="font-semibold text-emerald-900">
                      {tour.remainingSeats}/{tour.totalSeats} seats left
                    </span>
                  </div>
                )}
              </div>

              {/* Details Grid */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 py-6 border-y border-emerald-100">
                {tour.startLocation && (
                  <div className="flex items-start gap-3">
                    <MapPin className="w-5 h-5 text-emerald-600 flex-shrink-0 mt-1" />
                    <div>
                      <p className="text-sm text-emerald-600/70">Route</p>
                      <p className="font-semibold text-emerald-950">
                        {tour.startLocation}
                        {tour.endLocation && (
                          <> <ArrowRight className="w-4 h-4 inline mx-1" /> {tour.endLocation}</>
                        )}
                      </p>
                    </div>
                  </div>
                )}

                {formattedDate && (
                  <div className="flex items-start gap-3">
                    <Clock className="w-5 h-5 text-emerald-600 flex-shrink-0 mt-1" />
                    <div>
                      <p className="text-sm text-emerald-600/70">Start Date</p>
                      <p className="font-semibold text-emerald-950">{formattedDate}</p>
                    </div>
                  </div>
                )}

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

              {/* Download App CTA */}
              <div className="bg-emerald-50 rounded-xl p-6 border border-emerald-200">
                <p className="text-sm text-emerald-700/70 mb-4">
                  Download the TripShare app to book this tour and get the best experience.
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
