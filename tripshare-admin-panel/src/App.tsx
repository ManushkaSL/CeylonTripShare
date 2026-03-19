/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState, useEffect, useRef } from 'react';
import { Plus, Trash2, MapPin, Clock, DollarSign, Image as ImageIcon, Loader2, LayoutDashboard, LogOut, Lock, Mail, Route, User, Tag, Upload, X, ChevronLeft, ChevronRight, Pencil } from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { Tour } from './types';
import { db } from './firebase';
import { addDoc, collection, deleteDoc, doc, getDocs, orderBy, query, serverTimestamp, updateDoc } from 'firebase/firestore';
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
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loginError, setLoginError] = useState('');

  const handleLogin = (e: React.FormEvent) => {
    e.preventDefault();
    if (email === 'admin@gmail.com' && password === 'admin123') {
      setIsAuthenticated(true);
      sessionStorage.setItem('admin_auth', 'true');
      setLoginError('');
    } else {
      setLoginError('Invalid email or password');
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
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleLogout = () => {
    setIsAuthenticated(false);
    sessionStorage.removeItem('admin_auth');
  };

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

  useEffect(() => {
    if (isAuthenticated) fetchTours();
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
            <p className="text-zinc-500 text-sm mt-1">Sign in to access the admin panel</p>
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
              className="w-full py-3 bg-emerald-600 hover:bg-emerald-700 text-white font-semibold rounded-xl shadow-lg shadow-emerald-600/20 transition-all active:scale-95"
            >
              Sign In
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
        ...newTour,
        price: Number(newTour.price || 0),
        seat_count: Number(newTour.seat_count || 0),
        available_seats: Number(newTour.available_seats ?? newTour.seat_count ?? 0),
        start_day: newTour.start_day || '',
        start_time: mergeTimeWithPeriod(newTour.start_time, newTour.start_time_period),
        end_day: newTour.end_day || '',
        end_time: mergeTimeWithPeriod(newTour.end_time, newTour.end_time_period),
        booking_close_date: newTour.booking_close_date || '',
        booking_close_time: mergeTimeWithPeriod(newTour.booking_close_time, newTour.booking_close_period),
        route,
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
      <aside className="w-64 bg-white border-r border-zinc-200 flex flex-col hidden md:flex">
        <div className="p-6 border-b border-zinc-100">
          <h1 className="text-xl font-bold tracking-tight text-emerald-600 flex items-center gap-2">
            <LayoutDashboard className="w-6 h-6" />
            TripShare Admin
          </h1>
        </div>
        <nav className="flex-1 p-4 space-y-1">
          <a href="#" className="flex items-center gap-3 px-4 py-2 text-sm font-medium text-emerald-600 bg-emerald-50 rounded-lg">
            <LayoutDashboard className="w-4 h-4" />
            Tours Management
          </a>
        </nav>
        <div className="p-4 border-t border-zinc-100">
          <button onClick={handleLogout} className="flex items-center gap-3 px-4 py-2 text-sm font-medium text-zinc-500 hover:text-zinc-900 transition-colors w-full">
            <LogOut className="w-4 h-4" />
            Sign Out
          </button>
        </div>
      </aside>

      {/* Main Content */}
      <main className="flex-1 flex flex-col min-w-0">
        <header className="h-16 bg-white border-b border-zinc-200 flex items-center justify-between px-8 sticky top-0 z-10">
          <h2 className="text-lg font-semibold text-zinc-900">Tours Management</h2>
          <button
            onClick={openCreateTourModal}
            className="bg-emerald-600 hover:bg-emerald-700 text-white px-4 py-2 rounded-lg text-sm font-medium flex items-center gap-2 transition-all shadow-sm active:scale-95"
          >
            <Plus className="w-4 h-4" />
            Add New Tour
          </button>
        </header>

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
                      <div className="flex flex-wrap items-center gap-2 mb-3">
                        <span className="text-xs font-medium bg-zinc-100 text-zinc-700 px-2 py-1 rounded-full">
                          Total Seats: {Number(tour.seat_count || 0)}
                        </span>
                        <span className="text-xs font-semibold bg-emerald-100 text-emerald-700 px-2 py-1 rounded-full">
                          Available Seats: {Number(tour.available_seats ?? tour.seat_count ?? 0)}
                        </span>
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
                    <div className="bg-red-50 text-red-700 text-sm font-medium px-4 py-3 rounded-xl border border-red-100 break-words">
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
                          onChange={e => {
                            const seatCount = Number(e.target.value);
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
                          onChange={e => setNewTour({ ...newTour, price: Number(e.target.value) })}
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
                      <div className="flex gap-2">
                        <div className="relative flex-1">
                          <Clock className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-400" />
                          <input
                            type="text"
                            value={newTour.start_time}
                            onChange={e => setNewTour({ ...newTour, start_time: e.target.value })}
                            className="w-full pl-9 pr-4 py-2.5 bg-zinc-50 border border-zinc-200 rounded-xl focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 outline-none transition-all"
                            placeholder="e.g. 5:00"
                          />
                        </div>
                        <select
                          value={newTour.start_time_period || 'AM'}
                          onChange={e => setNewTour({ ...newTour, start_time_period: e.target.value as 'AM' | 'PM' })}
                          className="px-3 py-2.5 bg-zinc-50 border border-zinc-200 rounded-xl text-sm font-medium text-zinc-700 focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 outline-none"
                        >
                          <option value="AM">AM</option>
                          <option value="PM">PM</option>
                        </select>
                      </div>
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
                      <div className="flex gap-2">
                        <div className="relative flex-1">
                          <Clock className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-400" />
                          <input
                            type="text"
                            value={newTour.end_time}
                            onChange={e => setNewTour({ ...newTour, end_time: e.target.value })}
                            className="w-full pl-9 pr-4 py-2.5 bg-zinc-50 border border-zinc-200 rounded-xl focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 outline-none transition-all"
                            placeholder="e.g. 7:00"
                          />
                        </div>
                        <select
                          value={newTour.end_time_period || 'PM'}
                          onChange={e => setNewTour({ ...newTour, end_time_period: e.target.value as 'AM' | 'PM' })}
                          className="px-3 py-2.5 bg-zinc-50 border border-zinc-200 rounded-xl text-sm font-medium text-zinc-700 focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 outline-none"
                        >
                          <option value="AM">AM</option>
                          <option value="PM">PM</option>
                        </select>
                      </div>
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
                      <div className="flex gap-2">
                        <div className="relative flex-1">
                          <Clock className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-400" />
                          <input
                            type="text"
                            value={newTour.booking_close_time}
                            onChange={e => setNewTour({ ...newTour, booking_close_time: e.target.value })}
                            className="w-full pl-9 pr-4 py-2.5 bg-zinc-50 border border-zinc-200 rounded-xl focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 outline-none transition-all"
                            placeholder="e.g. 10:00"
                          />
                        </div>
                        <select
                          value={newTour.booking_close_period || 'PM'}
                          onChange={e => setNewTour({ ...newTour, booking_close_period: e.target.value as 'AM' | 'PM' })}
                          className="px-3 py-2.5 bg-zinc-50 border border-zinc-200 rounded-xl text-sm font-medium text-zinc-700 focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 outline-none"
                        >
                          <option value="AM">AM</option>
                          <option value="PM">PM</option>
                        </select>
                      </div>
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
