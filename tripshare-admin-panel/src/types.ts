export interface Tour {
  id: string;
  title: string;
  category: string;
  description: string;
  price: number;
  pricingMode?: 'per_person' | 'fixed_tour' | 'per_seat';
  fixedTourPrice?: number;
  images: string[];
  seat_count: number;
  available_seats: number;
  start_location: string;
  start_day: string;
  start_time: string;
  start_time_period: 'AM' | 'PM';
  end_location: string;
  end_day: string;
  end_time: string;
  end_time_period: 'AM' | 'PM';
  booking_close_time: string;
  booking_close_period: 'AM' | 'PM';
  booking_close_date: string;
  route: string[];
  operator_name: string;
  whats_included: string;
  tour_features: string;
  location?: string;
  duration?: string;
  start_time_location?: string;
  last_joining_time?: string;
  end_time_location?: string;
  created_at?: unknown;
}

export interface PassengerInfo {
  userId: string;
  name: string;
  email: string;
  phone: string;
}

export interface Driver {
  id: string;
  userId?: string;
  uid?: string;
  email: string;
  name?: string;
  status?: 'pending' | 'active' | 'inactive';
  phone?: string;
  phoneNumber?: string;
  license_number?: string;
  vehicle?: string;
  rating?: number;
  total_trips?: number;
  completion_rate?: string;
  created_at?: unknown;
  updated_at?: unknown;
}

export interface Booking {
  id: string;
  userId: string;
  tourId: string;
  instanceId?: string;
  visibility: 'public' | 'private';
  isPrivate: boolean;
  status: 'pending' | 'confirmed' | 'cancelled' | 'completed';
  numberOfPeople: number;
  totalPrice: number;
  userEmail?: string;
  userName?: string;
  userPhone?: string;
  tourTitle?: string;
  driverId?: string;
  driverName?: string;
  driverEmail?: string;
  passengers?: PassengerInfo[];
  createdAt?: unknown;
  updatedAt?: unknown;
  tourDate?: unknown;
  completedAt?: unknown;
  completedBy?: string;
}

export interface CommunityRideSubmission {
  id: string;
  hostUserId: string;
  hostName: string;
  hostEmail: string;
  hostPhone: string;
  whatsappNumber?: string;
  isHostDriver: boolean;
  driverName: string;
  driverPhone: string;
  driverLicenseNumber: string;
  origin: string;
  pickupLocation: string;
  destination: string;
  dropoffLocation: string;
  routeStops: string[];
  departureAt: unknown;
  estimatedArrivalAt: unknown;
  offeredSeats: number;
  pricePerPassenger: number;
  currency: string;
  vehicleType?: string;
  hasAirConditioning: boolean;
  luggageAvailable: boolean;
  notes?: string;
  approvalStatus: 'pending_review' | 'approved' | 'rejected';
  status: string;
  reviewNote?: string;
  createdAt?: unknown;
  reviewedAt?: unknown;
}
