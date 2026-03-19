export interface Tour {
  id: string;
  title: string;
  category: string;
  description: string;
  price: number;
  images: string[];
  location: string;
  duration: string;
  start_time_location: string;
  last_joining_time: string;
  end_time_location: string;
  route: string;
  operator_name: string;
  whats_included: string;
  tour_features: string;
  created_at?: unknown;
}
