/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { BrowserRouter, Routes, Route } from 'react-router-dom';
import HomePage from './pages/HomePage';
import TourRedirect from './pages/TourRedirect';

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<HomePage />} />
        <Route path="/tour/:tourId" element={<TourRedirect />} />
      </Routes>
    </BrowserRouter>
  );
}
          className="relative flex justify-center lg:justify-end"
        >
          <div className="relative w-full max-w-md aspect-square bg-emerald-100/50 rounded-full flex items-center justify-center overflow-hidden">
             {/* Abstract background blobs */}
             <div className="absolute top-10 right-10 w-32 h-32 bg-emerald-300/30 rounded-full blur-3xl animate-pulse" />
             <div className="absolute bottom-10 left-10 w-48 h-48 bg-emerald-400/20 rounded-full blur-3xl animate-pulse delay-700" />
             
             {/* Using a high quality placeholder illustration since tool failed */}
             <div className="relative z-10 w-[120%] lg:w-[140%] drop-shadow-2xl">
               <img 
                  src="https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&q=80&w=1000" 
                  alt="TripShare App Mockup" 
                  className="rounded-3xl shadow-2xl border-4 border-white/50 object-cover aspect-[9/19] h-[500px] mx-auto transform rotate-[-4deg] hover:rotate-[0deg] transition-transform duration-500"
                  referrerPolicy="no-referrer"
               />
               
               {/* Floating elements */}
               <motion.div 
                animate={{ y: [0, -10, 0] }}
                transition={{ duration: 3, repeat: Infinity }}
                className="absolute -top-6 -right-6 bg-white p-4 rounded-2xl shadow-xl border border-emerald-50"
               >
                 <div className="flex items-center gap-3">
                   <div className="w-10 h-10 bg-emerald-500 rounded-full flex items-center justify-center">
                     <Download className="w-5 h-5 text-white" />
                   </div>
                   <div>
                     <p className="text-xs font-bold text-emerald-950 leading-tight">Shared a Trip!</p>
                     <p className="text-[10px] text-emerald-600">Just now</p>
                   </div>
                 </div>
               </motion.div>

               <motion.div 
                animate={{ y: [0, 10, 0] }}
                transition={{ duration: 4, repeat: Infinity }}
                className="absolute bottom-10 -left-10 bg-white p-4 rounded-2xl shadow-xl border border-emerald-50 hidden md:block"
               >
                 <div className="flex items-center gap-3">
                    <div className="w-8 h-8 bg-emerald-100 rounded-full flex items-center justify-center">
                      <span className="text-emerald-600 text-lg">🌍</span>
                    </div>
                    <p className="text-xs font-bold text-emerald-950 leading-tight">Explore the World</p>
                 </div>
               </motion.div>
             </div>
          </div>
        </motion.div>
      </main>

      <footer className="mt-20 text-emerald-900/40 text-sm font-medium">
        © {new Date().getFullYear()} TripShare Inc. All rights reserved.
      </footer>
    </div>
  );
}
