/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState, useEffect, useRef } from 'react';
import { Plus, Trash2, MapPin, Clock, DollarSign, Image as ImageIcon, Loader2, LayoutDashboard, LogOut, Lock, Mail, Route, User, Tag, Upload, X, ChevronLeft, ChevronRight, Pencil, Users, Calendar, CheckCircle, AlertCircle } from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { Tour, Booking } from './types';
import { db, auth } from './firebase';
import { addDoc, collection, deleteDoc, doc, getDocs, orderBy, query, serverTimestamp, updateDoc, setDoc } from 'firebase/firestore';
import { signInWithEmailAndPassword, signOut, onAuthStateChanged } from 'firebase/auth';
import { supabase } from './supabase';

const SUPABASE_BUCKET = 'images';

function extractSupabasePathFromUrl(imageUrl: string, bucket: string) {
  try {
    const parsed = new URL(imageUrl);
    const markers = [
      `/storage/v1/object/public/${bucket}/`,
      `/storage/v1/object/authenticated/${bucket}/`,
      `/storage/v1/object/sign/${bucket}/`,
    ];

    for (const marker of markers) {
      const index = parsed.pathname.indexOf(marker);
      if (index >= 0) {
        return decodeURIComponent(parsed.pathname.slice(index + marker.length));
      }
    }
  } catch {
    return null;
  }

  return null;
}

function normalizeRouteValue(route: Tour['route'] | string | undefined) {
  if (Array.isArray(route)) {
    return route.filter(stop => stop?.trim().length > 0);
  }

  if (typeof route === 'string') {
    const trimmed = route.trim();
    if (!trimmed) return [];

    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      try {
        const parsed = JSON.parse(trimmed);
        if (Array.isArray(parsed)) {
          return parsed.filter(stop => typeof stop === 'string' && stop.trim().length > 0);
        }
      } catch {
        return [];
      }
    }

    return trimmed
      .split('\n')
      .map(stop => stop.trim())
      .filter(Boolean);
  }

  return [];
}

function parseTimeValueAndPeriod(value?: string, defaultPeriod: 'AM' | 'PM' = 'AM') {
  if (!value) {
    return { time: '', period: defaultPeriod };
  }

  const normalized = value.trim();
  const periodMatch = normalized.match(/\b(a\.?m\.?|p\.?m\.?)\b/i);
  const period = periodMatch
    ? periodMatch[0].toLowerCase().includes('p')
      ? 'PM'
      : 'AM'
    : defaultPeriod;

  const time = normalized
    .replace(/\b(a\.?m\.?|p\.?m\.?)\b/gi, '')
    .replace(/\s+/g, ' ')
    .trim();

  return { time, period };
}

function mergeTimeWithPeriod(time?: string, period?: string) {
  const cleanTime = (time || '').trim();
  if (!cleanTime) return '';
  return `${cleanTime} ${period === 'PM' ? 'PM' : 'AM'}`;
}

function convertTo24HourFormat(time: string, period: 'AM' | 'PM'): string {
  const cleanTime = time.trim().replace('.', ':');
  const timeParts = cleanTime.split(':');
  let hours = parseInt(timeParts[0], 10);
  const minutes = (timeParts[1] || '00').trim();

  if (period === 'PM' && hours !== 12) {
    hours += 12;
  } else if (period === 'AM' && hours === 12) {
    hours = 0;
  }

  return `${String(hours).padStart(2, '0')}:${minutes}`;
}

function hasBookingClosePassed(
  bookingCloseDate?: string,
  bookingCloseTime?: string,
  bookingClosePeriod: 'AM' | 'PM' = 'PM'
): boolean {
  if (!bookingCloseDate || !bookingCloseTime) return false;

  try {
    const time24 = convertTo24HourFormat(bookingCloseTime, bookingClosePeriod);
    const closeDatetime = new Date(`${bookingCloseDate}T${time24}:00`);
    const now = new Date();

    return now > closeDatetime;
  } catch (error) {
    console.error('Error checking booking close time:', error);
    return false;
  }
}

function TourImageCarousel({ images, title }: { images: string[]; title: string }) {
  const [idx, setIdx] = useState(0);

  const getImageSrc = (image: string) => {
    if (image.startsWith('http://') || image.startsWith('https://') || image.startsWith('/uploads/')) {
      return image;
    }
    return `/uploads/${image}`;
  };

  return (
    <>
      <img
        key={`${title}-${idx}`}
        src={getImageSrc(images[idx])}
        alt={title}
        className="w-full h-full object-cover transition-transform duration-500"
      />
      {images.length > 1 && (
        <>
          <button
            type="button"
            onClick={(e) => { e.stopPropagation(); setIdx((prev) => (prev - 1 + images.length) % images.length); }}
            className="absolute z-20 left-2 top-1/2 -translate-y-1/2 p-1 bg-white/80 backdrop-blur-sm rounded-full shadow hover:bg-white transition-colors pointer-events-auto"
          >
            <ChevronLeft className="w-4 h-4 text-zinc-700" />
          </button>
          <button
            type="button"
            onClick={(e) => { e.stopPropagation(); setIdx((prev) => (prev + 1) % images.length); }}
            className="absolute z-20 right-2 top-1/2 -translate-y-1/2 p-1 bg-white/80 backdrop-blur-sm rounded-full shadow hover:bg-white transition-colors pointer-events-auto"
          >
            <ChevronRight className="w-4 h-4 text-zinc-700" />
          </button>
          <div className="absolute z-20 bottom-2 left-1/2 -translate-x-1/2 flex gap-1">
            {images.map((_, i) => (
              <span key={i} className={`w-1.5 h-1.5 rounded-full ${i === idx ? 'bg-white' : 'bg-white/50'}`} />
            ))}
          </div>
        </>
      )}
    </>
  );
}

export default function App() {
  const initialTourForm: Partial<Tour> = {
    title: '',
    category: '',
    seat_count: 0,
    available_seats: 0,
    description: '',
    price: 0,
    start_location: '',
    start_day: '',
    start_time: '',
    start_time_period: 'AM',
    end_location: '',
    end_day: '',
    end_time: '',
    end_time_period: 'PM',
    booking_close_date: '',
    booking_close_time: '',
    booking_close_period: 'PM',
    route: [],
    operator_name: '',
    whats_included: '',
    tour_features: ''
  };

  const [isAuthenticated, setIsAuthenticated] = useState(() => sessionStorage.getItem('admin_auth') === 'true');
  const [userRole, setUserRole] = useState(() => sessionStorage.getItem('admin_role') || '');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loginError, setLoginError] = useState('');
  const [isLoggingIn, setIsLoggingIn] = useState(false);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoggingIn(true);
    setLoginError('');

    try {
      const userCredential = await signInWithEmailAndPassword(auth, email, password);
      const uid = userCredential.user.uid;
      
      // Create/update user record in Firestore with admin role
      await setDoc(doc(db, 'users', uid), {
        email: email,
        role: 'admin',
        lastLogin: serverTimestamp()
      }, { merge: true });

      setIsAuthenticated(true);
      setUserRole('admin');
      sessionStorage.setItem('admin_user_id', uid);
      sessionStorage.setItem('admin_email', email);
      setEmail('');
      setPassword('');
    } catch (error: any) {
      const errorMessage = error?.code === 'auth/user-not-found' || error?.code === 'auth/wrong-password'
        ? 'Invalid email or password'
        : error?.message || 'An error occurred during login. Please try again.';
      setLoginError(errorMessage);
    } finally {
      setIsLoggingIn(false);
    }
  };

  const [tours, setTours] = useState<Tour[]>([]);
  const [loading, setLoading] = useState(true);
  const [isAdding, setIsAdding] = useState(false);
  const [editingTourId, setEditingTourId] = useState<string | null>(null);
  const [editingOriginalImages, setEditingOriginalImages] = useState<string[]>([]);
  const [editingImages, setEditingImages] = useState<string[]>([]);
  const [isCreating, setIsCreating] = useState(false);
  const [createStep, setCreateStep] = useState('');
  const [createError, setCreateError] = useState('');
  const [newTour, setNewTour] = useState<Partial<Tour>>(initialTourForm);
  const [routeInput, setRouteInput] = useState('');
  const [imageFiles, setImageFiles] = useState<File[]>([]);
  const [imagePreviews, setImagePreviews] = useState<string[]>([]);
  const [activeSection, setActiveSection] = useState<'tours' | 'drivers' | 'bookings'>('tours');
  const [drivers, setDrivers] = useState<any[]>([]);
  const [driverEmail, setDriverEmail] = useState('');
  const [addingDriver, setAddingDriver] = useState(false);
  const [driverError, setDriverError] = useState('');
  const [expandedDriverId, setExpandedDriverId] = useState<string | null>(null);
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [bookingsLoading, setBookingsLoading] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleLogout = async () => {
    try {
      await signOut(auth);
      setIsAuthenticated(false);
      setUserRole('');
      sessionStorage.removeItem('admin_user_id');
      sessionStorage.removeItem('admin_email');
      setEmail('');
      setPassword('');
    } catch (error) {
      console.error('Logout error:', error);
    }
  };

  // Check authentication state on mount
  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (user) => {
      if (user) {
        setIsAuthenticated(true);
        setUserRole('admin');
        sessionStorage.setItem('admin_user_id', user.uid);
        sessionStorage.setItem('admin_email', user.email || '');
      } else {
        setIsAuthenticated(false);
        setUserRole('');
        sessionStorage.removeItem('admin_user_id');
        sessionStorage.removeItem('admin_email');
      }
    });
    return () => unsubscribe();
  }, []);

  const closeTourModal = () => {
    setIsAdding(false);
    setEditingTourId(null);
    setEditingOriginalImages([]);
    setEditingImages([]);
    setCreateError('');
    setCreateStep('');
    imagePreviews.forEach(url => URL.revokeObjectURL(url));
    setImageFiles([]);
    setImagePreviews([]);
    setRouteInput('');
    setNewTour(initialTourForm);
  };

  const openCreateTourModal = () => {
    setEditingTourId(null);
    setCreateError('');
    setCreateStep('');
    setRouteInput('');
    setIsAdding(true);
  };

  const handleEditTour = (tour: Tour) => {
    const existingImages = Array.isArray(tour.images) ? tour.images : [];
    const existingRoute = normalizeRouteValue(tour.route);
    const parsedStartTime = parseTimeValueAndPeriod(tour.start_time || tour.start_time_location, 'AM');
    const parsedEndTime = parseTimeValueAndPeriod(tour.end_time || tour.end_time_location, 'PM');
    const parsedBookingCloseTime = parseTimeValueAndPeriod(tour.last_joining_time || tour.booking_close_time, 'PM');
    imagePreviews.forEach(url => URL.revokeObjectURL(url));
    setImageFiles([]);
    setImagePreviews([]);
    setRouteInput('');
    setCreateError('');
    setCreateStep('');
    setEditingTourId(tour.id);
    setEditingOriginalImages(existingImages);
    setEditingImages(existingImages);
    setNewTour({
      title: tour.title,
      category: tour.category,
      description: tour.description,
      price: tour.price,
      seat_count: Number(tour.seat_count || 0),
      available_seats: Number(tour.available_seats ?? tour.seat_count ?? 0),
      start_location: tour.start_location || tour.location || '',
      start_day: tour.start_day || '',
      start_time: parsedStartTime.time,
      start_time_period: tour.start_time_period || parsedStartTime.period,
      end_location: tour.end_location || '',
      end_day: tour.end_day || '',
      end_time: parsedEndTime.time,
      end_time_period: tour.end_time_period || parsedEndTime.period,
      booking_close_date: tour.booking_close_date || '',
      booking_close_time: parsedBookingCloseTime.time,
      booking_close_period: tour.booking_close_period || parsedBookingCloseTime.period,
      route: existingRoute,
      operator_name: tour.operator_name,
      whats_included: tour.whats_included,
      tour_features: tour.tour_features,
    });
    setIsAdding(true);
  };

  const addRouteStop = () => {
    const stop = routeInput.trim();
    if (!stop) return;

    setNewTour(prev => ({
      ...prev,
      route: [...normalizeRouteValue(prev.route), stop],
    }));
    setRouteInput('');
  };

  const removeRouteStop = (index: number) => {
    setNewTour(prev => {
      const currentRoute = normalizeRouteValue(prev.route);
      return {
        ...prev,
        route: currentRoute.filter((_, i) => i !== index),
      };
    });
  };

  const removeExistingImage = (index: number) => {
    setEditingImages(prev => prev.filter((_, i) => i !== index));
  };

  const moveExistingImage = (index: number, direction: 'left' | 'right') => {
    setEditingImages(prev => {
      const targetIndex = direction === 'left' ? index - 1 : index + 1;
      if (targetIndex < 0 || targetIndex >= prev.length) return prev;

      const next = [...prev];
      [next[index], next[targetIndex]] = [next[targetIndex], next[index]];
      return next;
    });
  };

  const fetchDrivers = async () => {
    try {
      const q = query(collection(db, 'drivers'), orderBy('created_at', 'desc'));
      const querySnapshot = await getDocs(q);
      const driversData = querySnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
      setDrivers(driversData);
    } catch (error) {
      console.error('Failed to fetch drivers:', error);
    }
  };

  const handleAddDriver = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!driverEmail.trim()) {
      setDriverError('Please enter a valid email');
      return;
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(driverEmail)) {
      setDriverError('Please enter a valid email address');
      return;
    }

    setAddingDriver(true);
    setDriverError('');

    try {
      const existingDriver = drivers.find(d => d.email === driverEmail.trim().toLowerCase());
      if (existingDriver) {
        setDriverError('This email is already registered as a driver');
        setAddingDriver(false);
        return;
      }

      await addDoc(collection(db, 'drivers'), {
        email: driverEmail.trim().toLowerCase(),
        status: 'pending',
        created_at: serverTimestamp(),
        updated_at: serverTimestamp(),
      });

      setDriverEmail('');
      await fetchDrivers();
      alert('Driver email added successfully! They can now sign up with this email to access the driver dashboard.');
    } catch (error: any) {
      console.error('Failed to add driver:', error);
      console.error('Error code:', error.code);
      console.error('Error message:', error.message);
      const errorMsg = error.message || 'Failed to add driver. Please try again.';
      setDriverError(errorMsg);
    } finally {
      setAddingDriver(false);
    }
  };

  const handleDeleteDriver = async (driverId: string) => {
    if (!confirm('Are you sure you want to remove this driver?')) return;
    try {
      await deleteDoc(doc(db, 'drivers', driverId));
      setDrivers(drivers.filter(d => d.id !== driverId));
    } catch (error) {
      console.error('Failed to delete driver:', error);
    }
  };

  const fetchBookings = async () => {
    setBookingsLoading(true);
    try {
      console.log('Fetching bookings from collection: bookings');
      
      // Simple query without any ordering to avoid index issues
      const bookingsRef = collection(db, 'bookings');
      const querySnapshot = await getDocs(bookingsRef);
      
      console.log('Raw query snapshot:', querySnapshot);
      console.log('Number of documents:', querySnapshot.size);
      console.log('Empty:', querySnapshot.empty);
      
      const bookingsData = querySnapshot.docs.map((doc) => {
        const data = doc.data();
        console.log('Raw booking document:', { id: doc.id, data });
        
        // Map the fields to match the Booking interface
        return {
          id: doc.id,
          userId: data.userId || '',
          tourId: data.tourId || '',
          status: data.status || 'pending',
          numberOfPeople: data.totalPersons || data.numberOfPeople || 0,
          totalPrice: data.totalPrice || 0,
          userEmail: data.userEmail || '',
          userName: data.userName || '',
          tourTitle: data.tourName || data.tourTitle || '',
          driverId: data.driverId,
          driverName: data.driverName,
          driverEmail: data.driverEmail,
          createdAt: data.createdAt || data.bookedAt,
          updatedAt: data.updatedAt
        } as Booking;
      });

      console.log('Processed bookings:', bookingsData);
      console.log('Total bookings:', bookingsData.length);
      setBookings(bookingsData);
    } catch (error: any) {
      console.error('Failed to fetch bookings:', error);
      console.error('Error code:', error.code);
      console.error('Error message:', error.message);
      console.error('Stack trace:', error.stack);
      alert(`Error fetching bookings: ${error.message}`);
    } finally {
      setBookingsLoading(false);
    }
  };

  const updateBookingStatus = async (bookingId: string, newStatus: string) => {
    try {
      await updateDoc(doc(db, 'bookings', bookingId), {
        status: newStatus,
        updatedAt: serverTimestamp()
      });
      await fetchBookings();
    } catch (error) {
      console.error('Failed to update booking status:', error);
      alert('Failed to update booking status');
    }
  };

  const deleteBooking = async (bookingId: string) => {
    if (!confirm('Are you sure you want to delete this booking?')) return;
    try {
      const userId = sessionStorage.getItem('admin_user_id');
      console.log('Attempting to delete booking:', bookingId);
      console.log('Admin user ID:', userId);
      await deleteDoc(doc(db, 'bookings', bookingId));
      console.log('Booking deleted successfully');
      await fetchBookings();
    } catch (error: any) {
      console.error('Full delete error:', error);
      console.error('Error code:', error.code);
      console.error('Error message:', error.message);
      alert(`Failed to delete booking: ${error.message}`);
    }
  };

  const assignDriverToBooking = async (bookingId: string, driverId: string) => {
    try {
      const selectedDriver = drivers.find(d => d.id === driverId);
      if (!selectedDriver) return;

      console.log('Attempting to assign driver...');
      console.log('Booking ID:', bookingId);
      console.log('Driver ID:', driverId);
      console.log('Current user ID:', sessionStorage.getItem('admin_user_id'));
      console.log('Current user email:', sessionStorage.getItem('admin_email'));

      await updateDoc(doc(db, 'bookings', bookingId), {
        driverId: driverId,
        driverName: selectedDriver.name || selectedDriver.email,
        driverEmail: selectedDriver.email,
        updatedAt: serverTimestamp()
      });
      
      console.log('Driver assigned successfully');
      await fetchBookings();
    } catch (error: any) {
      console.error('Full error object:', error);
      console.error('Error code:', error.code);
      console.error('Error message:', error.message);
      console.error('Failed to assign driver:', error);
      alert(`Failed to assign driver: ${error.message}`);
    }
  };

  const getAssignedToursForDriver = (driverId: string) => {
    return bookings.filter(b => b.driverId === driverId && b.status !== 'cancelled');
  };

  useEffect(() => {
    if (isAuthenticated) {
      fetchTours();
      fetchDrivers();
      fetchBookings();
    }
  }, [isAuthenticated]);

  if (!isAuthenticated) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-zinc-50 p-4">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="w-full max-w-md"
        >
          <div className="text-center mb-8">
            <div className="w-16 h-16 bg-emerald-100 rounded-2xl flex items-center justify-center mx-auto mb-4">
              <LayoutDashboard className="w-8 h-8 text-emerald-600" />
            </div>
            <h1 className="text-2xl font-bold text-zinc-900">TripShare Admin</h1>
            <p className="text-zinc-500 text-sm mt-1">Admin role required to access this panel</p>
            <div className="flex items-center gap-2 px-3 py-2 mt-3 bg-blue-50 border border-blue-200 rounded-lg">
              <Lock className="w-4 h-4 text-blue-600" />
              <span className="text-xs text-blue-700">Only users with <strong>admin</strong> role can access</span>
            </div>
          </div>

          <form onSubmit={handleLogin} className="bg-white rounded-2xl border border-zinc-200 shadow-sm p-8 space-y-5">
            {loginError && (
              <div className="bg-red-50 text-red-600 text-sm font-medium px-4 py-3 rounded-xl border border-red-100">
                {loginError}
              </div>
            )}
            <div>
              <label className="block text-sm font-semibold text-zinc-700 mb-1.5">Email</label>
              <div className="relative">
                <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-400" />
                <input
                  required
                  type="email"
                  value={email}
                  onChange={e => setEmail(e.target.value)}
                  className="w-full pl-10 pr-4 py-2.5 bg-zinc-50 border border-zinc-200 rounded-xl focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 outline-none transition-all"
                  placeholder="admin@gmail.com"
                />
              </div>
            </div>
            <div>
              <label className="block text-sm font-semibold text-zinc-700 mb-1.5">Password</label>
              <div className="relative">
                <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-400" />
                <input
                  required
                  type="password"
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  className="w-full pl-10 pr-4 py-2.5 bg-zinc-50 border border-zinc-200 rounded-xl focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 outline-none transition-all"
                  placeholder="••••••••"
                />
              </div>
            </div>
            <button
              type="submit"
              disabled={isLoggingIn}
              className="w-full py-3 bg-emerald-600 hover:bg-emerald-700 disabled:bg-emerald-400 text-white font-semibold rounded-xl shadow-lg shadow-emerald-600/20 transition-all active:scale-95 flex items-center justify-center gap-2"
            >
              {isLoggingIn ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  Signing In...
                </>
              ) : (
                'Sign In'
              )}
            </button>
          </form>
        </motion.div>
      </div>
    );
  }

  const fetchTours = async () => {
    try {
      const q = query(collection(db, 'tours'), orderBy('created_at', 'desc'));
      const snapshot = await getDocs(q);
      const data = snapshot.docs.map((docSnapshot) => {
        const tour = docSnapshot.data() as Omit<Tour, 'id'> & { images?: string[] | string; route?: string[] | string; available_seats?: number };
        const images = Array.isArray(tour.images)
          ? tour.images
          : typeof tour.images === 'string'
            ? JSON.parse(tour.images)
            : [];
        const route = normalizeRouteValue(tour.route);
        const parsedStartTime = parseTimeValueAndPeriod(tour.start_time || tour.start_time_location, 'AM');
        const parsedEndTime = parseTimeValueAndPeriod(tour.end_time || tour.end_time_location, 'PM');
        const parsedBookingCloseTime = parseTimeValueAndPeriod(tour.last_joining_time || tour.booking_close_time, 'PM');
        return {
          id: docSnapshot.id,
          ...tour,
          seat_count: Number(tour.seat_count || 0),
          available_seats: Number(tour.available_seats ?? tour.seat_count ?? 0),
          start_location: tour.start_location || tour.location || '',
          start_day: tour.start_day || '',
          start_time: parsedStartTime.time,
          start_time_period: tour.start_time_period || parsedStartTime.period,
          end_location: tour.end_location || '',
          end_day: tour.end_day || '',
          end_time: parsedEndTime.time,
          end_time_period: tour.end_time_period || parsedEndTime.period,
          booking_close_date: tour.booking_close_date || '',
          booking_close_time: parsedBookingCloseTime.time,
          booking_close_period: tour.booking_close_period || parsedBookingCloseTime.period,
          route,
          images,
        } as Tour;
      });
      setTours(data);
    } catch (error) {
      console.error('Failed to fetch tours:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleImageSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files: File[] = Array.from(e.target.files ?? []);
    const maxSizeBytes = 8 * 1024 * 1024;
    const validFiles = files.filter(file => file.size <= maxSizeBytes);
    const rejectedCount = files.length - validFiles.length;

    if (rejectedCount > 0) {
      setCreateError(`Skipped ${rejectedCount} image(s). Max allowed size is 8MB per image.`);
    }

    setImageFiles(prev => [...prev, ...validFiles]);
    const newPreviews = validFiles.map(f => URL.createObjectURL(f as Blob));
    setImagePreviews(prev => [...prev, ...newPreviews]);
  };

  const removeImage = (index: number) => {
    URL.revokeObjectURL(imagePreviews[index]);
    setImageFiles(prev => prev.filter((_, i) => i !== index));
    setImagePreviews(prev => prev.filter((_, i) => i !== index));
  };

  const handleAddTour = async (e: React.FormEvent) => {
    e.preventDefault();
    const isEditMode = Boolean(editingTourId);
    setCreateError('');
    setIsCreating(true);
    setCreateStep('Preparing upload...');
    try {
      setCreateStep(imageFiles.length > 0 ? `Uploading ${imageFiles.length} image(s)...` : 'Saving tour...');
      const imageUrls = await Promise.all(
        imageFiles.map(async (file) => {
          const safeName = file.name.replace(/\s+/g, '-');
          const imagePath = `tours/${Date.now()}-${Math.random().toString(36).slice(2)}-${safeName}`;

          const { error: uploadError } = await supabase.storage
            .from(SUPABASE_BUCKET)
            .upload(imagePath, file, {
              cacheControl: '3600',
              upsert: false,
              contentType: file.type || undefined,
            });

          if (uploadError) throw uploadError;

          const { data } = supabase.storage.from(SUPABASE_BUCKET).getPublicUrl(imagePath);
          if (!data?.publicUrl) {
            throw new Error('Failed to generate image URL from Supabase');
          }

          return data.publicUrl;
        })
      );

      setCreateStep('Finalizing...');

      const route = normalizeRouteValue(newTour.route);
      const payload = {
        // Basic Details
        title: newTour.title || '',
        category: newTour.category || '',
        description: newTour.description || '',
        price: Number(newTour.price || 0),
        seat_count: Number(newTour.seat_count || 0),
        available_seats: Number(newTour.available_seats ?? newTour.seat_count ?? 0),
        
        // Schedule
        start_location: newTour.start_location || '',
        start_day: newTour.start_day || '',
        start_time: mergeTimeWithPeriod(newTour.start_time, newTour.start_time_period),
        start_time_period: newTour.start_time_period || 'AM',
        
        end_location: newTour.end_location || '',
        end_day: newTour.end_day || '',
        end_time: mergeTimeWithPeriod(newTour.end_time, newTour.end_time_period),
        end_time_period: newTour.end_time_period || 'PM',
        
        booking_close_date: newTour.booking_close_date || '',
        booking_close_time: mergeTimeWithPeriod(newTour.booking_close_time, newTour.booking_close_period),
        booking_close_period: newTour.booking_close_period || 'PM',
        
        // Route & Extra Details
        route,
        operator_name: newTour.operator_name || '',
        whats_included: newTour.whats_included || '',
        tour_features: newTour.tour_features || '',
        guideId: sessionStorage.getItem('admin_user_id') || '',
      };

      if (isEditMode && editingTourId) {
        const finalImages = [...editingImages, ...imageUrls];

        await updateDoc(doc(db, 'tours', editingTourId), {
          ...payload,
          images: finalImages,
          updated_at: serverTimestamp(),
        });

        const removedImages = editingOriginalImages.filter(image => !editingImages.includes(image));
        for (const imageUrl of removedImages) {
          const imagePath = extractSupabasePathFromUrl(imageUrl, SUPABASE_BUCKET);
          if (imagePath) {
            const { error: removeError } = await supabase.storage.from(SUPABASE_BUCKET).remove([imagePath]);
            if (removeError) {
              console.warn('Failed to delete removed image from Supabase Storage:', removeError);
            }
          }
        }
      } else {
        await addDoc(collection(db, 'tours'), {
          ...payload,
          available_seats: Number(newTour.seat_count || 0),
          images: imageUrls,
          created_at: serverTimestamp(),
        });
      }

      closeTourModal();
      await fetchTours();
    } catch (error) {
      console.error(`Failed to ${isEditMode ? 'update' : 'add'} tour:`, error);
      const appError = error as { code?: string; message?: string; error?: string; statusCode?: string };
      const message = appError?.code
        ? `${appError.code}: ${appError.message || 'Unknown error'}`
        : (appError?.message || appError?.error || 'Failed to create tour. Check Supabase Storage/Firestore rules and console.');

      const lower = `${appError?.message || ''} ${appError?.error || ''}`.toLowerCase();

      let hint = '';
      if (lower.includes('bucket') && lower.includes('not found')) {
        hint = `Supabase bucket not found. Create bucket \"${SUPABASE_BUCKET}\" or set VITE_SUPABASE_BUCKET to your bucket name.`;
      } else if (lower.includes('row-level security') || lower.includes('unauthorized') || lower.includes('permission')) {
        hint = 'Access denied by rules/policies. Check Supabase Storage policies and Firestore rules for writes.';
      } else if (lower.includes('network')) {
        hint = 'Network issue while uploading. Check internet and retry with smaller files.';
      }

      const finalMessage = hint ? `${message}\n\n${hint}` : message;
      setCreateError(finalMessage);
      alert(finalMessage);
    } finally {
      setIsCreating(false);
      setCreateStep('');
    }
  };

  const handleDeleteTour = async (id: string, images: string[]) => {
    if (!confirm('Are you sure you want to delete this tour?')) return;
    try {
      for (const imageUrl of images) {
        const imagePath = extractSupabasePathFromUrl(imageUrl, SUPABASE_BUCKET);
        if (imagePath) {
          const { error: removeError } = await supabase.storage.from(SUPABASE_BUCKET).remove([imagePath]);
          if (removeError) {
            console.warn('Failed to delete image from Supabase Storage:', removeError);
          }
        }
      }

      await deleteDoc(doc(db, 'tours', id));
      setTours(tours.filter(t => t.id !== id));
    } catch (error) {
      console.error('Failed to delete tour:', error);
    }
  };

  return (
    <div className="min-h-screen flex bg-zinc-50">
      {/* Sidebar */}
      <aside className="w-64 bg-white border-r border-zinc-200 flex flex-col hidden md:flex sticky top-0 h-screen overflow-y-auto">
        <div className="p-6 border-b border-zinc-100">
          <h1 className="text-xl font-bold tracking-tight text-emerald-600 flex items-center gap-2">
            <LayoutDashboard className="w-6 h-6" />
            TripShare Admin
          </h1>
        </div>
        <nav className="flex-1 p-4 space-y-1">
          <button
            onClick={() => setActiveSection('tours')}
            className={`flex items-center gap-3 px-4 py-2 text-sm font-medium rounded-lg w-full transition-colors ${
              activeSection === 'tours'
                ? 'text-emerald-600 bg-emerald-50'
                : 'text-zinc-500 hover:text-zinc-900 hover:bg-zinc-50'
            }`}
          >
            <LayoutDashboard className="w-4 h-4" />
            Tours Management
          </button>
          <button
            onClick={() => setActiveSection('bookings')}
            className={`flex items-center gap-3 px-4 py-2 text-sm font-medium rounded-lg w-full transition-colors ${
              activeSection === 'bookings'
                ? 'text-emerald-600 bg-emerald-50'
                : 'text-zinc-500 hover:text-zinc-900 hover:bg-zinc-50'
            }`}
          >
            <Calendar className="w-4 h-4" />
            Booking Management
          </button>
          <button
            onClick={() => setActiveSection('drivers')}
            className={`flex items-center gap-3 px-4 py-2 text-sm font-medium rounded-lg w-full transition-colors ${
              activeSection === 'drivers'
                ? 'text-emerald-600 bg-emerald-50'
                : 'text-zinc-500 hover:text-zinc-900 hover:bg-zinc-50'
            }`}
          >
            <Users className="w-4 h-4" />
            Driver Management
          </button>
        </nav>
        <div className="p-4 border-t border-zinc-100">
          <div className="px-4 py-3 mb-3 bg-emerald-50 rounded-lg border border-emerald-200">
            <p className="text-xs font-medium text-zinc-600 mb-1">Logged in as</p>
            <p className="text-sm font-semibold text-zinc-900 truncate">{sessionStorage.getItem('admin_email') || email}</p>
            <div className="flex items-center gap-2 mt-2">
              <span className="inline-block px-2 py-1 text-xs font-bold text-white bg-emerald-600 rounded-full">
                {userRole || 'ADMIN'}
              </span>
            </div>
          </div>
          <button onClick={handleLogout} className="flex items-center gap-3 px-4 py-2 text-sm font-medium text-zinc-500 hover:text-zinc-900 transition-colors w-full rounded-lg hover:bg-zinc-50">
            <LogOut className="w-4 h-4" />
            Sign Out
          </button>
        </div>
      </aside>

      {/* Main Content */}
      <main className="flex-1 flex flex-col min-w-0">
        <header className="h-16 bg-white border-b border-zinc-200 flex items-center justify-between px-8 sticky top-0 z-10">
          <div className="flex items-center gap-3">
            <h2 className="text-lg font-semibold text-zinc-900">
              {activeSection === 'tours' ? 'Tours Management' : activeSection === 'bookings' ? 'Booking Management' : 'Driver Management'}
            </h2>
            <span className="inline-flex items-center gap-1 px-2.5 py-1 bg-emerald-100 text-emerald-700 text-xs font-semibold rounded-full">
              <Lock className="w-3 h-3" />
              Admin Access
            </span>
          </div>
          {activeSection === 'tours' && (
            <button
              onClick={openCreateTourModal}
              className="bg-emerald-600 hover:bg-emerald-700 text-white px-4 py-2 rounded-lg text-sm font-medium flex items-center gap-2 transition-all shadow-sm active:scale-95"
            >
              <Plus className="w-4 h-4" />
              Add New Tour
            </button>
          )}
        </header>

        {activeSection === 'tours' && (
        <div className="p-8 max-w-7xl mx-auto w-full">
          {loading ? (
            <div className="flex flex-col items-center justify-center py-20 gap-4">
              <Loader2 className="w-8 h-8 text-emerald-600 animate-spin" />
              <p className="text-zinc-500 font-medium">Loading tours...</p>
            </div>
          ) : (
            <div className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-6">
              <AnimatePresence mode="popLayout">
                {tours.map((tour) => (
                  <motion.div
                    key={tour.id}
                    layout
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, scale: 0.95 }}
                    className="bg-white rounded-2xl border border-zinc-200 overflow-hidden shadow-sm hover:shadow-md transition-shadow group"
                  >
                    <div className="aspect-video relative overflow-hidden bg-zinc-100">
                      {(() => {
                        const imgs: string[] = Array.isArray(tour.images)
                          ? tour.images
                          : typeof tour.images === 'string'
                            ? JSON.parse(tour.images)
                            : [];
                        if (imgs.length > 0) {
                          return <TourImageCarousel images={imgs} title={tour.title} />;
                        }
                        return (
                          <div className="w-full h-full flex items-center justify-center text-zinc-400">
                            <ImageIcon className="w-12 h-12" />
                          </div>
                        );
                      })()}
                      <div className="absolute top-4 right-4">
                        <div className="flex items-center gap-2">
                          <button
                            onClick={() => handleEditTour(tour)}
                            className="p-2 bg-white/90 backdrop-blur-sm text-zinc-700 rounded-full hover:bg-zinc-100 transition-colors shadow-sm"
                          >
                            <Pencil className="w-4 h-4" />
                          </button>
                          <button
                            onClick={() => handleDeleteTour(tour.id, Array.isArray(tour.images) ? tour.images : [])}
                            className="p-2 bg-white/90 backdrop-blur-sm text-red-600 rounded-full hover:bg-red-50 transition-colors shadow-sm"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                      </div>
                    </div>
                    <div className="p-6">
                      <div className="flex items-center justify-between mb-2">
                        <div className="flex items-center gap-2 text-xs font-semibold text-emerald-600 uppercase tracking-wider">
                          <MapPin className="w-3 h-3" />
                          {tour.start_location || tour.location || 'Unknown Location'}
                        </div>
                        {tour.category && (
                          <span className="text-xs font-medium bg-emerald-50 text-emerald-700 px-2 py-0.5 rounded-full">{tour.category}</span>
                        )}
                      </div>
                      <h3 className="text-lg font-bold text-zinc-900 mb-2 line-clamp-1">{tour.title}</h3>
                      <p className="text-zinc-500 text-sm line-clamp-2 mb-3">{tour.description}</p>
                      {tour.operator_name && (
                        <p className="text-xs text-zinc-400 mb-3">by <span className="font-medium text-zinc-600">{tour.operator_name}</span></p>
                      )}
                      <div className="mb-3 rounded-xl border border-emerald-200 bg-emerald-50 px-3 py-2">
                        <p className="text-xs font-medium text-zinc-600">Total Seats: <span className="font-semibold text-zinc-800">{Number(tour.seat_count || 0)}</span></p>
                        <p className="text-sm font-bold text-emerald-700">Available Seats: {Number(tour.available_seats ?? tour.seat_count ?? 0)}</p>
                      </div>
                      <div className="flex items-center justify-between pt-4 border-t border-zinc-100">
                        <div className="flex items-center gap-4">
                          <div className="flex items-center gap-1.5 text-zinc-600 text-sm">
                            <Clock className="w-4 h-4" />
                            {tour.start_time ? `${tour.start_time} ${tour.start_time_period || 'AM'}` : 'N/A'}
                          </div>
                          <div className="flex items-center gap-1.5 text-zinc-900 font-bold">
                            <DollarSign className="w-4 h-4 text-emerald-600" />
                            {tour.price}
                          </div>
                        </div>
                      </div>
                    </div>
                  </motion.div>
                ))}
              </AnimatePresence>
            </div>
          )}

          {!loading && tours.length === 0 && !isAdding && (
            <div className="text-center py-20 bg-white rounded-3xl border-2 border-dashed border-zinc-200">
              <div className="w-16 h-16 bg-zinc-50 rounded-full flex items-center justify-center mx-auto mb-4">
                <LayoutDashboard className="w-8 h-8 text-zinc-300" />
              </div>
              <h3 className="text-lg font-semibold text-zinc-900 mb-1">No tours found</h3>
              <p className="text-zinc-500 mb-6">Get started by creating your first tour package.</p>
              <button
                onClick={openCreateTourModal}
                className="bg-emerald-600 hover:bg-emerald-700 text-white px-6 py-2.5 rounded-xl font-medium transition-all inline-flex items-center gap-2"
              >
                <Plus className="w-4 h-4" />
                Add Tour
              </button>
            </div>
          )}
        </div>
        )}

        {activeSection === 'drivers' && (
        <div className="p-8 max-w-7xl mx-auto w-full">
          <div className="space-y-6">
            {/* Add Driver Form */}
            <div className="bg-white rounded-2xl border border-zinc-200 p-6">
              <h3 className="text-lg font-semibold text-zinc-900 mb-4">Add Driver by Email</h3>
              <form onSubmit={handleAddDriver} className="flex flex-col sm:flex-row gap-3">
                <div className="flex-1">
                  <input
                    type="email"
                    value={driverEmail}
                    onChange={e => {
                      setDriverEmail(e.target.value);
                      setDriverError('');
                    }}
                    placeholder="Enter driver email address"
                    className="w-full px-4 py-3 bg-zinc-50 border border-zinc-200 rounded-xl focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 outline-none transition-all"
                  />
                </div>
                <button
                  type="submit"
                  disabled={addingDriver}
                  className="px-6 py-3 bg-emerald-600 hover:bg-emerald-700 disabled:bg-emerald-400 text-white font-medium rounded-xl transition-all flex items-center gap-2 whitespace-nowrap"
                >
                  {addingDriver ? (
                    <>
                      <Loader2 className="w-4 h-4 animate-spin" />
                      Adding...
                    </>
                  ) : (
                    <>
                      <Plus className="w-4 h-4" />
                      Add as Driver
                    </>
                  )}
                </button>
              </form>
              {driverError && (
                <div className="mt-3 bg-red-50 text-red-700 text-sm font-medium px-4 py-3 rounded-xl border border-red-100">
                  {driverError}
                </div>
              )}
            </div>

            {/* Drivers List */}
            <div className="bg-white rounded-2xl border border-zinc-200 overflow-hidden">
              <div className="p-6 border-b border-zinc-100">
                <h3 className="text-lg font-semibold text-zinc-900">Registered Drivers ({drivers.length})</h3>
              </div>
              {drivers.length === 0 ? (
                <div className="p-8 text-center">
                  <div className="w-16 h-16 bg-zinc-50 rounded-full flex items-center justify-center mx-auto mb-4">
                    <Users className="w-8 h-8 text-zinc-300" />
                  </div>
                  <p className="text-zinc-500">No drivers added yet. Add driver emails to get started.</p>
                </div>
              ) : (
                <div className="divide-y divide-zinc-100">
                  <AnimatePresence mode="popLayout">
                    {drivers.map((driver) => (
                      <div key={driver.id}>
                        <motion.div
                          layout
                          initial={{ opacity: 0, x: -20 }}
                          animate={{ opacity: 1, x: 0 }}
                          exit={{ opacity: 0, x: 20 }}
                          onClick={() => setExpandedDriverId(expandedDriverId === driver.id ? null : driver.id)}
                          className="p-6 flex items-center justify-between hover:bg-zinc-50 transition-colors cursor-pointer"
                        >
                          <div className="flex-1">
                            <p className="font-medium text-zinc-900">{driver.email}</p>
                          <div className="flex items-center gap-3 mt-2">
                              <span className={`text-xs font-semibold px-2.5 py-1 rounded-full ${
                                driver.status === 'active'
                                  ? 'bg-emerald-100 text-emerald-700'
                                  : driver.status === 'pending'
                                    ? 'bg-yellow-100 text-yellow-700'
                                    : 'bg-zinc-100 text-zinc-700'
                              }`}>
                                {driver.status === 'active' ? 'Active' : driver.status === 'pending' ? 'Pending' : 'Inactive'}
                              </span>
                              {getAssignedToursForDriver(driver.id).length > 0 && (
                                <span className="text-xs font-semibold px-2.5 py-1 rounded-full bg-blue-100 text-blue-700 flex items-center gap-1">
                                  <Calendar className="w-3 h-3" />
                                  Assigned to {getAssignedToursForDriver(driver.id).length} tour(s)
                                </span>
                              )}
                              {driver.created_at && (
                                <span className="text-xs text-zinc-500">
                                  Added {new Date(driver.created_at.toDate?.() || driver.created_at).toLocaleDateString()}
                                </span>
                              )}
                            </div>
                          </div>
                          <div className="flex items-center gap-2 ml-4">
                            <motion.div
                              initial={false}
                              animate={{ rotate: expandedDriverId === driver.id ? 180 : 0 }}
                              transition={{ duration: 0.2 }}
                            >
                              <ChevronRight className="w-5 h-5 text-zinc-400" />
                            </motion.div>
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                handleDeleteDriver(driver.id);
                              }}
                              className="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                              title="Remove driver"
                            >
                              <Trash2 className="w-4 h-4" />
                            </button>
                          </div>
                        </motion.div>

                        {/* Expanded Details */}
                        <AnimatePresence>
                          {expandedDriverId === driver.id && (
                            <motion.div
                              initial={{ opacity: 0, height: 0 }}
                              animate={{ opacity: 1, height: 'auto' }}
                              exit={{ opacity: 0, height: 0 }}
                              className="overflow-hidden border-t border-zinc-100"
                            >
                              <div className="p-6 bg-zinc-50 space-y-5">
                                <div>
                                  <h4 className="text-sm font-semibold text-zinc-900 mb-4">Driver Information</h4>
                                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                                    <div>
                                      <p className="text-xs font-medium text-zinc-500 uppercase tracking-wide mb-1">Email</p>
                                      <p className="text-sm font-medium text-zinc-900">{driver.email}</p>
                                    </div>
                                    <div>
                                      <p className="text-xs font-medium text-zinc-500 uppercase tracking-wide mb-1">Status</p>
                                      <p className="text-sm font-medium text-zinc-900">{driver.status || 'N/A'}</p>
                                    </div>
                                    <div>
                                      <p className="text-xs font-medium text-zinc-500 uppercase tracking-wide mb-1">Phone</p>
                                      <p className="text-sm font-medium text-zinc-900">{driver.phone || 'Not provided'}</p>
                                    </div>
                                    <div>
                                      <p className="text-xs font-medium text-zinc-500 uppercase tracking-wide mb-1">License</p>
                                      <p className="text-sm font-medium text-zinc-900">{driver.license_number || 'Not provided'}</p>
                                    </div>
                                    <div>
                                      <p className="text-xs font-medium text-zinc-500 uppercase tracking-wide mb-1">Vehicle</p>
                                      <p className="text-sm font-medium text-zinc-900">{driver.vehicle || 'Not assigned'}</p>
                                    </div>
                                    <div>
                                      <p className="text-xs font-medium text-zinc-500 uppercase tracking-wide mb-1">Assigned Tours</p>
                                      <p className="text-sm font-medium text-zinc-900">{getAssignedToursForDriver(driver.id).length}</p>
                                    </div>
                                  </div>
                                </div>

                                <div className="border-t border-zinc-200 pt-4">
                                  <h4 className="text-sm font-semibold text-zinc-900 mb-3">Active Ratings</h4>
                                  <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                                    <div className="bg-white rounded-lg p-3 border border-zinc-200">
                                      <p className="text-xs font-medium text-zinc-500 mb-1">Average Rating</p>
                                      <p className="text-lg font-bold text-emerald-600">{driver.rating || '4.8'}/5</p>
                                    </div>
                                    <div className="bg-white rounded-lg p-3 border border-zinc-200">
                                      <p className="text-xs font-medium text-zinc-500 mb-1">Total Trips</p>
                                      <p className="text-lg font-bold text-blue-600">{driver.total_trips || 0}</p>
                                    </div>
                                    <div className="bg-white rounded-lg p-3 border border-zinc-200">
                                      <p className="text-xs font-medium text-zinc-500 mb-1">Completion Rate</p>
                                      <p className="text-lg font-bold text-purple-600">{driver.completion_rate || '98%'}</p>
                                    </div>
                                  </div>
                                </div>

                                {getAssignedToursForDriver(driver.id).length > 0 && (
                                  <div className="border-t border-zinc-200 pt-4">
                                    <h4 className="text-sm font-semibold text-zinc-900 mb-3">Assigned Tours</h4>
                                    <div className="space-y-2">
                                      {getAssignedToursForDriver(driver.id).map(booking => (
                                        <div key={booking.id} className="bg-blue-50 border border-blue-200 rounded-lg p-3">
                                          <div className="flex items-start justify-between">
                                            <div className="flex-1">
                                              <p className="text-sm font-semibold text-zinc-900">{booking.tourTitle || 'Tour Name'}</p>
                                              <p className="text-xs text-zinc-600 mt-1">User: {booking.userName}</p>
                                              <p className="text-xs text-zinc-600">Passengers: {booking.numberOfPeople}</p>
                                            </div>
                                            <span className={`text-xs font-semibold px-2 py-0.5 rounded whitespace-nowrap ml-2 ${
                                              booking.status === 'confirmed' ? 'bg-emerald-100 text-emerald-700' :
                                              booking.status === 'pending' ? 'bg-amber-100 text-amber-700' :
                                              'bg-red-100 text-red-700'
                                            }`}>
                                              {booking.status}
                                            </span>
                                          </div>
                                        </div>
                                      ))}
                                    </div>
                                  </div>
                                )}

                                <div className="border-t border-zinc-200 pt-4">
                                  <div className="flex gap-2">
                                    <button className="flex-1 px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white text-sm font-medium rounded-lg transition-colors">
                                      Edit Driver
                                    </button>
                                    <button className="flex-1 px-4 py-2 bg-zinc-200 hover:bg-zinc-300 text-zinc-900 text-sm font-medium rounded-lg transition-colors">
                                      View History
                                    </button>
                                  </div>
                                </div>
                              </div>
                            </motion.div>
                          )}
                        </AnimatePresence>
                      </div>
                    ))}
                  </AnimatePresence>
                </div>
              )}
            </div>
          </div>
        </div>
        )}

        {activeSection === 'bookings' && (
        <div className="p-8 max-w-7xl mx-auto w-full">
          <div className="space-y-6">
            {/* Bookings Stats */}
            <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
              <div className="bg-white rounded-2xl border border-zinc-200 p-6">
                <p className="text-sm font-medium text-zinc-500 mb-2">Total Bookings</p>
                <p className="text-3xl font-bold text-zinc-900">{bookings.length}</p>
              </div>
              <div className="bg-white rounded-2xl border border-zinc-200 p-6">
                <p className="text-sm font-medium text-zinc-500 mb-2">Confirmed</p>
                <p className="text-3xl font-bold text-emerald-600">{bookings.filter(b => b.status === 'confirmed').length}</p>
              </div>
              <div className="bg-white rounded-2xl border border-zinc-200 p-6">
                <p className="text-sm font-medium text-zinc-500 mb-2">Pending</p>
                <p className="text-3xl font-bold text-amber-600">{bookings.filter(b => b.status === 'pending').length}</p>
              </div>
              <div className="bg-white rounded-2xl border border-zinc-200 p-6">
                <p className="text-sm font-medium text-zinc-500 mb-2">Cancelled</p>
                <p className="text-3xl font-bold text-red-600">{bookings.filter(b => b.status === 'cancelled').length}</p>
              </div>
            </div>

            {/* Bookings Table */}
            <div className="bg-white rounded-2xl border border-zinc-200 overflow-hidden">
              <div className="p-6 border-b border-zinc-100 flex items-center justify-between">
                <div>
                  <h3 className="text-lg font-semibold text-zinc-900">All Bookings</h3>
                  <p className="text-sm text-zinc-500 mt-1">Manage and track all tour bookings</p>
                </div>
                <button
                  onClick={fetchBookings}
                  className="px-4 py-2 text-sm font-medium text-emerald-600 hover:bg-emerald-50 rounded-lg transition-colors"
                  disabled={bookingsLoading}
                >
                  {bookingsLoading ? 'Refreshing...' : 'Refresh'}
                </button>
              </div>

              {bookingsLoading ? (
                <div className="p-12 text-center">
                  <Loader2 className="w-8 h-8 animate-spin text-emerald-600 mx-auto mb-3" />
                  <p className="text-zinc-500">Loading bookings...</p>
                </div>
              ) : bookings.length === 0 ? (
                <div className="p-12 text-center">
                  <Calendar className="w-8 h-8 text-zinc-300 mx-auto mb-3" />
                  <p className="text-zinc-500">No bookings found</p>
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full">
                    <thead className="bg-zinc-50 border-b border-zinc-100">
                      <tr>
                        <th className="px-6 py-3 text-left text-xs font-semibold text-zinc-700 uppercase tracking-wide">Booking ID</th>
                        <th className="px-6 py-3 text-left text-xs font-semibold text-zinc-700 uppercase tracking-wide">User</th>
                        <th className="px-6 py-3 text-left text-xs font-semibold text-zinc-700 uppercase tracking-wide">Tour</th>
                        <th className="px-6 py-3 text-left text-xs font-semibold text-zinc-700 uppercase tracking-wide">People</th>
                        <th className="px-6 py-3 text-left text-xs font-semibold text-zinc-700 uppercase tracking-wide">Price</th>
                        <th className="px-6 py-3 text-left text-xs font-semibold text-zinc-700 uppercase tracking-wide">Status</th>
                        <th className="px-6 py-3 text-left text-xs font-semibold text-zinc-700 uppercase tracking-wide">Driver</th>
                        <th className="px-6 py-3 text-left text-xs font-semibold text-zinc-700 uppercase tracking-wide">Actions</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-zinc-100">
                      {bookings.map(booking => (
                        <tr key={booking.id} className="hover:bg-zinc-50 transition-colors">
                          <td className="px-6 py-3 text-sm font-mono text-zinc-600">{booking.id.substring(0, 12)}...</td>
                          <td className="px-6 py-3 text-sm">
                            <div>
                              <p className="font-medium text-zinc-900">{booking.userName || 'N/A'}</p>
                              <p className="text-xs text-zinc-500">{booking.userEmail || 'N/A'}</p>
                            </div>
                          </td>
                          <td className="px-6 py-3 text-sm text-zinc-600">{booking.tourTitle || 'N/A'}</td>
                          <td className="px-6 py-3 text-sm font-medium text-zinc-900">{booking.numberOfPeople || 0}</td>
                          <td className="px-6 py-3 text-sm font-medium text-emerald-600">Rs. {booking.totalPrice?.toFixed(2) || '0.00'}</td>
                          <td className="px-6 py-3 text-sm">
                            <select
                              value={booking.status}
                              onChange={e => updateBookingStatus(booking.id, e.target.value)}
                              className={`px-3 py-1.5 rounded-lg text-sm font-medium border-0 outline-none transition-colors ${
                                booking.status === 'confirmed' ? 'bg-emerald-100 text-emerald-700' :
                                booking.status === 'pending' ? 'bg-amber-100 text-amber-700' :
                                'bg-red-100 text-red-700'
                              }`}
                            >
                              <option value="pending">Pending</option>
                              <option value="confirmed">Confirmed</option>
                              <option value="cancelled">Cancelled</option>
                            </select>
                          </td>
                          <td className="px-6 py-3 text-sm">
                            <select
                              value={booking.driverId || ''}
                              onChange={e => assignDriverToBooking(booking.id, e.target.value)}
                              className="px-3 py-1.5 rounded-lg text-sm font-medium border border-zinc-200 outline-none focus:border-emerald-500 transition-colors"
                            >
                              <option value="">Not Assigned</option>
                              {drivers.map(driver => (
                                <option key={driver.id} value={driver.id}>
                                  {driver.name || driver.email}
                                </option>
                              ))}
                            </select>
                          </td>
                          <td className="px-6 py-3 text-sm">
                            <button
                              onClick={() => deleteBooking(booking.id)}
                              className="text-red-600 hover:text-red-700 hover:bg-red-50 px-3 py-1.5 rounded-lg transition-colors flex items-center gap-1"
                            >
                              <Trash2 className="w-4 h-4" />
                              Delete
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          </div>
        </div>
        )}
      </main>

      {/* Add Tour Modal */}
      <AnimatePresence>
        {isAdding && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={closeTourModal}
              className="absolute inset-0 bg-zinc-900/40 backdrop-blur-sm"
            />
            <motion.div
              initial={{ opacity: 0, scale: 0.95, y: 20 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.95, y: 20 }}
              className="relative w-full max-w-4xl bg-white rounded-3xl border border-zinc-200 shadow-2xl overflow-hidden max-h-[92vh] flex flex-col"
            >
              <div className="p-7 border-b border-zinc-100 bg-white sticky top-0 z-10">
                <div className="flex items-center justify-between">
                  <div>
                    <h3 className="text-2xl font-bold text-zinc-900">{editingTourId ? 'Edit Tour' : 'Create New Tour'}</h3>
                    <p className="text-sm text-zinc-500 mt-1">Fill in the details below to publish this tour.</p>
                  </div>
                  <button
                    onClick={closeTourModal}
                    className="p-2 hover:bg-zinc-100 rounded-full transition-colors"
                  >
                    <Plus className="w-6 h-6 rotate-45 text-zinc-400" />
                  </button>
                </div>
              </div>

              <div className="p-7 overflow-y-auto bg-zinc-50/50">
                <form onSubmit={handleAddTour} className="space-y-6">
                  {createError && (
                    <div className="bg-red-50 text-red-700 text-sm font-medium px-4 py-3 rounded-xl border border-red-100 break-all">
                      {createError}
                    </div>
                  )}
                  {isCreating && createStep && (
                    <div className="bg-emerald-50 text-emerald-700 text-sm font-medium px-4 py-3 rounded-xl border border-emerald-100">
                      {createStep}
                    </div>
                  )}
                  <div className="bg-white border border-zinc-200 rounded-2xl p-5 space-y-4">
                    <p className="text-xs font-semibold tracking-wide uppercase text-zinc-500">Basic Details</p>
                    <div>
                      <label className="block text-sm font-semibold text-zinc-700 mb-1.5">Tour Name</label>
                      <input
                        required
                        type="text"
                        value={newTour.title}
                        onChange={e => setNewTour({ ...newTour, title: e.target.value })}
                        className="w-full px-4 py-2.5 bg-zinc-50 border border-zinc-200 rounded-xl focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 outline-none transition-all"
                        placeholder="e.g. Wilpattu Full Day Safari from Anuradhapura"
                      />
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                    <div>
                      <label className="block text-sm font-semibold text-zinc-700 mb-1.5">Category</label>
                      <div className="relative">
                        <Tag className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-400" />
                        <input
                          type="text"
                          value={newTour.category}
                          onChange={e => setNewTour({ ...newTour, category: e.target.value })}
                          className="w-full pl-9 pr-4 py-2.5 bg-zinc-50 border border-zinc-200 rounded-xl focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 outline-none transition-all"
                          placeholder="e.g. Wildlife Jeep Safari"
                        />
                      </div>
                    </div>
                    <div>
                      <label className="block text-sm font-semibold text-zinc-700 mb-1.5">Seat Count</label>
                      <div className="relative">
                        <User className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-400" />
                        <input
                          required
                          type="number"
                          min={0}
                          value={newTour.seat_count}
                          onFocus={e => {
                            if (e.target.value === '0') {
                              e.target.value = '';
                            }
                          }}
                          onChange={e => {
                            const seatCount = Number(e.target.value || 0);
                            setNewTour({
                              ...newTour,
                              seat_count: seatCount,
                              available_seats: editingTourId ? newTour.available_seats : seatCount,
                            });
                          }}
                          className="w-full pl-9 pr-4 py-2.5 bg-zinc-50 border border-zinc-200 rounded-xl focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 outline-none transition-all"
                          placeholder="e.g. 6"
                        />
                      </div>
                    </div>
                    <div>
                      <label className="block text-sm font-semibold text-zinc-700 mb-1.5">Price</label>
                      <div className="relative">
                        <DollarSign className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-400" />
                        <input
                          required
                          type="number"
                          min={0}
                          value={newTour.price}
                          onFocus={e => {
                            if (e.target.value === '0') {
                              e.target.value = '';
                            }
                          }}
                          onChange={e => setNewTour({ ...newTour, price: Number(e.target.value || 0) })}
                          className="w-full pl-9 pr-4 py-2.5 bg-zinc-50 border border-zinc-200 rounded-xl focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 outline-none transition-all"
                          placeholder="e.g. 250"
                        />
                      </div>
                    </div>
                  </div>

                    <div>
                      <label className="block text-sm font-semibold text-zinc-700 mb-1.5">Description</label>
                      <textarea
                        value={newTour.description}
                        onChange={e => setNewTour({ ...newTour, description: e.target.value })}
                        className="w-full px-4 py-2.5 bg-zinc-50 border border-zinc-200 rounded-xl focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 outline-none transition-all h-24 resize-none"
                        placeholder="Describe the tour highlights..."
                      />
                    </div>
                  </div>

                  <div className="bg-white border border-zinc-200 rounded-2xl p-5 space-y-4">
                    <p className="text-xs font-semibold tracking-wide uppercase text-zinc-500">Schedule</p>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                      <label className="block text-sm font-semibold text-zinc-700 mb-1.5">Start Location</label>
                      <div className="relative">
                        <MapPin className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-400" />
                        <input
                          type="text"
                          value={newTour.start_location}
                          onChange={e => setNewTour({ ...newTour, start_location: e.target.value })}
                          className="w-full pl-9 pr-4 py-2.5 bg-zinc-50 border border-zinc-200 rounded-xl focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 outline-none transition-all"
                          placeholder="e.g. Anuradhapura Town"
                        />
                      </div>
                    </div>
                    <div>
                      <label className="block text-sm font-semibold text-zinc-700 mb-1.5">Tour Start Day</label>
                      <input
                        type="date"
                        value={newTour.start_day}
                        onChange={e => setNewTour({ ...newTour, start_day: e.target.value })}
                        className="w-full px-4 py-2.5 bg-zinc-50 border border-zinc-200 rounded-xl focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 outline-none transition-all"
                      />
                    </div>
                  </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                      <label className="block text-sm font-semibold text-zinc-700 mb-1.5">Start Time</label>
                      <input
                        type="time"
                        value={
                          newTour.start_time
                            ? convertTo24HourFormat(newTour.start_time, newTour.start_time_period || 'AM')
                            : ''
                        }
                        onChange={e => {
                          if (e.target.value) {
                            const [hours, minutes] = e.target.value.split(':');
                            const hour = parseInt(hours, 10);
                            const isPM = hour >= 12;
                            const hour12 = hour > 12 ? hour - 12 : hour === 0 ? 12 : hour;
                            setNewTour({
                              ...newTour,
                              start_time: `${hour12}:${minutes}`,
                              start_time_period: isPM ? 'PM' : 'AM',
                            });
                          }
                        }}
                        className="w-full px-4 py-2.5 bg-zinc-50 border border-zinc-200 rounded-xl focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 outline-none transition-all"
                      />
                    </div>
                    <div>
                      <label className="block text-sm font-semibold text-zinc-700 mb-1.5">End Location</label>
                      <div className="relative">
                        <MapPin className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-400" />
                        <input
                          type="text"
                          value={newTour.end_location}
                          onChange={e => setNewTour({ ...newTour, end_location: e.target.value })}
                          className="w-full pl-9 pr-4 py-2.5 bg-zinc-50 border border-zinc-200 rounded-xl focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 outline-none transition-all"
                          placeholder="e.g. Anuradhapura Town"
                        />
                      </div>
                    </div>
                  </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                      <label className="block text-sm font-semibold text-zinc-700 mb-1.5">Tour End Day</label>
                      <input
                        type="date"
                        value={newTour.end_day}
                        onChange={e => setNewTour({ ...newTour, end_day: e.target.value })}
                        className="w-full px-4 py-2.5 bg-zinc-50 border border-zinc-200 rounded-xl focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 outline-none transition-all"
                      />
                    </div>
                    <div>
                      <label className="block text-sm font-semibold text-zinc-700 mb-1.5">End Time</label>
                      <input
                        type="time"
                        value={
                          newTour.end_time
                            ? convertTo24HourFormat(newTour.end_time, newTour.end_time_period || 'PM')
                            : ''
                        }
                        onChange={e => {
                          if (e.target.value) {
                            const [hours, minutes] = e.target.value.split(':');
                            const hour = parseInt(hours, 10);
                            const isPM = hour >= 12;
                            const hour12 = hour > 12 ? hour - 12 : hour === 0 ? 12 : hour;
                            setNewTour({
                              ...newTour,
                              end_time: `${hour12}:${minutes}`,
                              end_time_period: isPM ? 'PM' : 'AM',
                            });
                          }
                        }}
                        className="w-full px-4 py-2.5 bg-zinc-50 border border-zinc-200 rounded-xl focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 outline-none transition-all"
                      />
                    </div>
                  </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                      <label className="block text-sm font-semibold text-zinc-700 mb-1.5">Booking Close Date</label>
                      <input
                        type="date"
                        value={newTour.booking_close_date}
                        onChange={e => setNewTour({ ...newTour, booking_close_date: e.target.value })}
                        className="w-full px-4 py-2.5 bg-zinc-50 border border-zinc-200 rounded-xl focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 outline-none transition-all"
                      />
                    </div>
                    <div>
                      <label className="block text-sm font-semibold text-zinc-700 mb-1.5">Booking Close Time</label>
                      <input
                        type="time"
                        value={
                          newTour.booking_close_time
                            ? convertTo24HourFormat(newTour.booking_close_time, newTour.booking_close_period || 'PM')
                            : ''
                        }
                        onChange={e => {
                          if (e.target.value) {
                            const [hours, minutes] = e.target.value.split(':');
                            const hour = parseInt(hours, 10);
                            const isPM = hour >= 12;
                            const hour12 = hour > 12 ? hour - 12 : hour === 0 ? 12 : hour;
                            setNewTour({
                              ...newTour,
                              booking_close_time: `${hour12}:${minutes}`,
                              booking_close_period: isPM ? 'PM' : 'AM',
                            });
                          }
                        }}
                        className="w-full px-4 py-2.5 bg-zinc-50 border border-zinc-200 rounded-xl focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 outline-none transition-all"
                      />
                    </div>
                  </div>
                  </div>

                  <div className="bg-white border border-zinc-200 rounded-2xl p-5 space-y-3">
                    <p className="text-xs font-semibold tracking-wide uppercase text-zinc-500">Route</p>
                    <label className="block text-sm font-semibold text-zinc-700">Locations</label>
                    <div className="flex gap-2">
                      <div className="relative flex-1">
                        <Route className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-400" />
                        <input
                          type="text"
                          value={routeInput}
                          onChange={e => setRouteInput(e.target.value)}
                          onKeyDown={e => {
                            if (e.key === 'Enter') {
                              e.preventDefault();
                              addRouteStop();
                            }
                          }}
                          className="w-full pl-9 pr-4 py-2.5 bg-zinc-50 border border-zinc-200 rounded-xl focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 outline-none transition-all"
                          placeholder="e.g. Kurunegala"
                        />
                      </div>
                      <button
                        type="button"
                        onClick={addRouteStop}
                        className="px-4 py-2.5 bg-emerald-50 text-emerald-700 border border-emerald-200 rounded-xl font-medium hover:bg-emerald-100 transition-all"
                      >
                        Add Location
                      </button>
                    </div>
                    <div className="mt-2 space-y-2">
                      {normalizeRouteValue(newTour.route).length === 0 ? (
                        <div className="text-xs text-zinc-500 bg-zinc-50 border border-zinc-200 rounded-lg px-3 py-2">
                          No route locations added yet.
                        </div>
                      ) : (
                        normalizeRouteValue(newTour.route).map((stop, index) => (
                          <div key={`${stop}-${index}`} className="flex items-center justify-between gap-3 bg-zinc-50 border border-zinc-200 rounded-lg px-3 py-2">
                            <span className="text-sm text-zinc-700">{index + 1}. {stop}</span>
                            <button
                              type="button"
                              onClick={() => removeRouteStop(index)}
                              className="text-red-600 hover:text-red-700 text-xs font-medium"
                            >
                              Remove
                            </button>
                          </div>
                        ))
                      )}
                    </div>
                  </div>

                  <div className="bg-white border border-zinc-200 rounded-2xl p-5 space-y-4">
                    <p className="text-xs font-semibold tracking-wide uppercase text-zinc-500">Extra Details</p>
                    <div>
                      <label className="block text-sm font-semibold text-zinc-700 mb-1.5">Operator Name</label>
                      <div className="relative">
                        <User className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-400" />
                        <input
                          type="text"
                          value={newTour.operator_name}
                          onChange={e => setNewTour({ ...newTour, operator_name: e.target.value })}
                          className="w-full pl-9 pr-4 py-2.5 bg-zinc-50 border border-zinc-200 rounded-xl focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 outline-none transition-all"
                          placeholder="e.g. Ceylon Transit Safaris"
                        />
                      </div>
                    </div>

                    <div>
                      <label className="block text-sm font-semibold text-zinc-700 mb-1.5">What's Included</label>
                      <input
                        type="text"
                        value={newTour.whats_included}
                        onChange={e => setNewTour({ ...newTour, whats_included: e.target.value })}
                        className="w-full px-4 py-2.5 bg-zinc-50 border border-zinc-200 rounded-xl focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 outline-none transition-all"
                        placeholder="e.g. Entry Tickets, Jeep and Guide, Lunch, Water"
                      />
                    </div>

                    <div>
                      <label className="block text-sm font-semibold text-zinc-700 mb-1.5">Tour Features</label>
                      <input
                        type="text"
                        value={newTour.tour_features}
                        onChange={e => setNewTour({ ...newTour, tour_features: e.target.value })}
                        className="w-full px-4 py-2.5 bg-zinc-50 border border-zinc-200 rounded-xl focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 outline-none transition-all"
                        placeholder="e.g. Expert Tracking, Quality Jeeps, Ethical Practices"
                      />
                    </div>
                  </div>

                  <div className="bg-white border border-zinc-200 rounded-2xl p-5 space-y-3">
                    <p className="text-xs font-semibold tracking-wide uppercase text-zinc-500">Images</p>
                    <label className="block text-sm font-semibold text-zinc-700">Tour Images</label>
                    {editingTourId && (
                      <div className="mb-3">
                        <p className="text-xs font-medium text-zinc-500 mb-2">Current Images</p>
                        {editingImages.length > 0 ? (
                          <div className="grid grid-cols-4 gap-2">
                            {editingImages.map((src, i) => (
                              <div key={`${src}-${i}`} className="relative aspect-square rounded-lg overflow-hidden group/img border border-zinc-200">
                                <img src={src} className="w-full h-full object-cover" />
                                <div className="absolute inset-x-1 bottom-1 flex items-center justify-between gap-1 opacity-0 group-hover/img:opacity-100 transition-opacity">
                                  <button
                                    type="button"
                                    onClick={() => moveExistingImage(i, 'left')}
                                    disabled={i === 0}
                                    className="p-1 bg-white/95 text-zinc-700 rounded disabled:opacity-40 disabled:cursor-not-allowed"
                                  >
                                    <ChevronLeft className="w-3 h-3" />
                                  </button>
                                  <button
                                    type="button"
                                    onClick={() => moveExistingImage(i, 'right')}
                                    disabled={i === editingImages.length - 1}
                                    className="p-1 bg-white/95 text-zinc-700 rounded disabled:opacity-40 disabled:cursor-not-allowed"
                                  >
                                    <ChevronRight className="w-3 h-3" />
                                  </button>
                                </div>
                                <button
                                  type="button"
                                  onClick={() => removeExistingImage(i)}
                                  className="absolute top-1 right-1 p-0.5 bg-red-500 text-white rounded-full opacity-0 group-hover/img:opacity-100 transition-opacity"
                                >
                                  <X className="w-3 h-3" />
                                </button>
                              </div>
                            ))}
                          </div>
                        ) : (
                          <div className="text-xs text-zinc-500 bg-zinc-50 border border-zinc-200 rounded-lg px-3 py-2">
                            No current images. Add new ones below.
                          </div>
                        )}
                      </div>
                    )}
                    <input
                      ref={fileInputRef}
                      type="file"
                      accept="image/*"
                      multiple
                      onChange={handleImageSelect}
                      className="hidden"
                    />
                    <button
                      type="button"
                      onClick={() => fileInputRef.current?.click()}
                      className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-zinc-50 border-2 border-dashed border-zinc-300 rounded-xl text-zinc-500 hover:border-emerald-400 hover:text-emerald-600 transition-all"
                    >
                      <Upload className="w-4 h-4" />
                      {editingTourId ? 'Add More Images' : 'Browse Images'}
                    </button>
                    {imagePreviews.length > 0 && (
                      <div className="mt-3 grid grid-cols-4 gap-2">
                        {imagePreviews.map((src, i) => (
                          <div key={i} className="relative aspect-square rounded-lg overflow-hidden group/img">
                            <img src={src} className="w-full h-full object-cover" />
                            <button
                              type="button"
                              onClick={() => removeImage(i)}
                              className="absolute top-1 right-1 p-0.5 bg-red-500 text-white rounded-full opacity-0 group-hover/img:opacity-100 transition-opacity"
                            >
                              <X className="w-3 h-3" />
                            </button>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>

                  <div className="pt-5 -mx-7 px-7 pb-1 flex gap-3 sticky bottom-0 bg-white/95 backdrop-blur-sm border-t border-zinc-200">
                    <button
                      type="button"
                      onClick={closeTourModal}
                      className="flex-1 px-6 py-3 bg-zinc-100 hover:bg-zinc-200 text-zinc-700 font-semibold rounded-xl transition-all"
                    >
                      Cancel
                    </button>
                    <button
                      type="submit"
                      disabled={isCreating}
                      className="flex-1 px-6 py-3 bg-emerald-600 hover:bg-emerald-700 disabled:bg-emerald-400 text-white font-semibold rounded-xl shadow-lg shadow-emerald-600/20 transition-all active:scale-95 disabled:cursor-not-allowed"
                    >
                      {isCreating ? (createStep || (editingTourId ? 'Saving...' : 'Creating...')) : (editingTourId ? 'Save Changes' : 'Create Tour')}
                    </button>
                  </div>
                </form>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
}
