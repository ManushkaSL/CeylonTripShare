/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { useEffect, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { motion } from "motion/react";
import { Download, Smartphone, Apple, Play, Loader } from "lucide-react";
import { APP_CONFIG } from "../config";

export default function HomePage() {
  const [isChecking, setIsChecking] = useState(true);
  const [searchParams] = useSearchParams();

  useEffect(() => {
    const checkIfAppInstalled = () => {
      const userAgent = navigator.userAgent;
      const isIOS = /iPad|iPhone|iPod/.test(userAgent);
      const isAndroid = /Android/.test(userAgent);

      if (!isIOS && !isAndroid) {
        // Not a mobile device
        setIsChecking(false);
        return;
      }

      console.log(`Mobile device detected: ${isIOS ? 'iOS' : 'Android'}`);

      // Get tour details from URL parameters (passed by Firebase Dynamic Links)
      const tourId = searchParams.get('tourId');
      const tourName = searchParams.get('name');
      const tourPrice = searchParams.get('price');
      const tourLocation = searchParams.get('location');

      // Build deep link URL with tour data
      let deepLinkUrl = `${APP_CONFIG.DEEP_LINK_SCHEME}://tour`;
      
      if (tourId) {
        deepLinkUrl += `/${tourId}`;
        if (tourName || tourPrice || tourLocation) {
          const params = [];
          if (tourName) params.push(`name=${encodeURIComponent(tourName)}`);
          if (tourPrice) params.push(`price=${tourPrice}`);
          if (tourLocation) params.push(`location=${encodeURIComponent(tourLocation)}`);
          if (params.length > 0) {
            deepLinkUrl += `?${params.join('&')}`;
          }
        }
      }

      console.log(`Attempting to open: ${deepLinkUrl}`);

      // Try to open the app
      window.location.href = deepLinkUrl;

      // Wait to see if app opens
      setTimeout(() => {
        const beforeTime = Date.now();
        
        // Check if we're still in the browser
        if (document.hidden === false) {
          console.log('App not detected - showing download page');
          setIsChecking(false);
        }
      }, 2500);

      // Use visibility API as backup
      const handleVisibilityChange = () => {
        if (document.hidden) {
          console.log('App opened successfully');
          setIsChecking(false);
        }
      };

      document.addEventListener('visibilitychange', handleVisibilityChange);

      return () => {
        document.removeEventListener('visibilitychange', handleVisibilityChange);
      };
    };

    const timer = setTimeout(checkIfAppInstalled, 500);
    return () => clearTimeout(timer);
  }, [searchParams]);

  // Show loading state while checking
  if (isChecking) {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center p-6 bg-gradient-to-br from-emerald-50 to-teal-50">
        <div className="text-center space-y-6">
          <div className="flex justify-center">
            <div className="animate-spin">
              <Loader className="w-12 h-12 text-emerald-600" />
            </div>
          </div>
          <div className="space-y-2">
            <h1 className="text-2xl font-bold text-emerald-950">Checking for TripShare...</h1>
            <p className="text-emerald-700/70">Opening app if installed...</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex flex-col items-center justify-center p-6 md:p-12 selection:bg-emerald-200">
      <main className="w-full max-w-6xl grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
        {/* Left Content */}
        <motion.div 
          initial={{ opacity: 0, x: -20 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ duration: 0.6, ease: "easeOut" }}
          className="flex flex-col space-y-8"
        >
          <div className="space-y-4">
            <motion.h1 
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.2 }}
              className="font-display text-5xl md:text-7xl font-bold tracking-tight text-emerald-950"
            >
              Download <br />
              <span className="text-emerald-600">TripShare</span>
            </motion.h1>
            <motion.p 
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.3 }}
              className="text-lg md:text-xl text-emerald-900/70 max-w-md leading-relaxed"
            >
              Start sharing and discovering amazing travel experiences with your community across your devices.
            </motion.p>
            <motion.p
              initial={{ opacity: 0 }}
              animate={{ opacity: 0.6 }}
              transition={{ delay: 0.4 }}
              className="text-xs font-medium uppercase tracking-widest text-emerald-950"
            >
              By installing TripShare, you agree to our Terms & Privacy Policy.
            </motion.p>
          </div>

          <div className="space-y-4">
            <div className="bg-white/80 backdrop-blur-md rounded-3xl p-8 border border-emerald-100 shadow-xl shadow-emerald-900/5 max-w-md transform hover:scale-[1.02] transition-transform duration-300">
              <div className="flex items-center gap-3 mb-4">
                <Smartphone className="w-6 h-6 text-emerald-600" />
                <h2 className="font-display text-2xl font-semibold text-emerald-950">Mobile</h2>
              </div>
              <p className="text-emerald-900/70 mb-8 leading-relaxed">
                Connect with travelers, share itineraries, and explore hidden gems worldwide. Requires iOS 14.0 or Android 8.0 and newer.
              </p>
              
              <div className="flex flex-col sm:flex-row gap-4">
                <a 
                  href={APP_CONFIG.IOS_APP_URL} 
                  target="_blank" 
                  rel="noopener noreferrer"
                  className="flex items-center justify-center gap-3 bg-black text-white hover:bg-zinc-800 px-6 py-3.5 rounded-xl transition-all duration-200 group shadow-lg"
                >
                  <Apple className="w-6 h-6 fill-white" />
                  <div className="flex flex-col items-start leading-none">
                    <span className="text-[10px] uppercase font-medium opacity-70">Download from the</span>
                    <span className="text-lg font-semibold">App Store</span>
                  </div>
                </a>

                <a 
                  href={APP_CONFIG.ANDROID_APP_URL} 
                  target="_blank" 
                  rel="noopener noreferrer"
                  className="flex items-center justify-center gap-3 bg-black text-white hover:bg-zinc-800 px-6 py-3.5 rounded-xl transition-all duration-200 group shadow-lg"
                >
                  <Play className="w-6 h-6 fill-white" />
                  <div className="flex flex-col items-start leading-none">
                    <span className="text-[10px] uppercase font-medium opacity-70">Get it on</span>
                    <span className="text-lg font-semibold">Google Play</span>
                  </div>
                </a>
              </div>
            </div>

            <button className="flex items-center gap-2 text-emerald-700 hover:text-emerald-900 font-medium transition-colors pl-2 group">
              Explore in browser
              <motion.span animate={{ x: [0, 4, 0] }} transition={{ repeat: Infinity, duration: 1.5 }}>
                →
              </motion.span>
            </button>
          </div>
        </motion.div>

        {/* Right Illustration */}
        <motion.div 
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.8, ease: "easeOut" }}
          className="relative flex justify-center lg:justify-end"
        >
          <div className="relative w-full max-w-md aspect-square bg-emerald-100/50 rounded-full flex items-center justify-center overflow-hidden">
             <div className="absolute top-10 right-10 w-32 h-32 bg-emerald-300/30 rounded-full blur-3xl" />
             <div className="absolute bottom-10 left-10 w-48 h-48 bg-emerald-400/20 rounded-full blur-3xl" />
             
             <div className="relative z-10 w-full max-w-xs drop-shadow-2xl">
               <img 
                  src="https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&q=80&w=1000" 
                  alt="TripShare App Mockup" 
                  className="rounded-3xl shadow-2xl border-4 border-white/50 object-cover h-96 w-full mx-auto"
               />
               
               {/* Floating elements */}
               <div className="absolute -top-6 -right-6 bg-white p-4 rounded-2xl shadow-xl border border-emerald-50">
                 <div className="flex items-center gap-3">
                   <div className="w-10 h-10 bg-emerald-500 rounded-full flex items-center justify-center">
                     <Download className="w-5 h-5 text-white" />
                   </div>
                   <div>
                     <p className="text-xs font-bold text-emerald-950 leading-tight">Shared a Trip!</p>
                     <p className="text-xs text-emerald-600">Just now</p>
                   </div>
                 </div>
               </div>

               <div className="absolute bottom-10 -left-10 bg-white p-4 rounded-2xl shadow-xl border border-emerald-50 hidden md:block">
                 <div className="flex items-center gap-3">
                    <div className="w-8 h-8 bg-emerald-100 rounded-full flex items-center justify-center">
                      <span className="text-emerald-600 text-lg">🌍</span>
                    </div>
                    <p className="text-xs font-bold text-emerald-950 leading-tight">Explore the World</p>
                 </div>
               </div>
             </div>
          </div>
        </motion.div>
      </main>
    </div>
  );
}
