export interface Trainer {
  id: string;
  imageName: string;
  name: string;
  specialty: string;
  rating: string;
  reviews: number;
  priceLabel: string;
  priceCompact: string;
  nextAvailable: string;
  availabilityColor: string;
  yearsExperience: string;
  clients: number;
  sessions: number;
  tags: string[];
  bio: string;
}

export interface Ingredient {
  name: string;
  amount: string;
}

export interface Product {
  id: string;
  abbr: string;
  name: string;
  form: string;
  dose: string;
  count: string;
  price: number;
  subscriptionPrice: number;
  tag: string;
  tagColor: string;
  desc: string;
  ingredients: Ingredient[];
  benefits: string;
  risks: string;
  interactions: string;
}

export interface Exercise {
  name: string;
  icon: string;
  sets: number;
  reps: string;
}

export interface WorkoutCard {
  id: string;
  section: "beginner_plan" | "top_workouts";
  imageName: string;
  title: string;
  level: string;
  duration: string;
  category: string;
  exercises: Exercise[];
  imageURL: string | null;
  videoURL: string | null;
}

export interface ImportantCard {
  icon: string;
  title: string;
  subtitle: string;
}

export interface FoodRecipe {
  id: string;
  name: string;
  price: number;
  ingredients: string[];
  imageURL: string | null;
}

export interface GymZone {
  id: string;
  icon: string;
  name: string;
  subtitle: string;
  capacity: number;
}

export interface SubscriptionPlan {
  id: string;
  name: string;
  price: number;
  period: string;
  perks: string[];
  recommended: boolean;
}

export interface BookedSession {
  id: string;
  date: string; // ISO
  title: string;
  trainerName: string;
}

export interface CartLine {
  id: string;
  name: string;
  price: number;
}

export interface Achievement {
  icon: string;
  title: string;
  detail: string;
  isUnlocked: boolean;
}

export interface LeaderboardEntry {
  id: string;
  displayName: string;
  totalVisits: number;
  streakDays: number;
  isMe: boolean;
}

export interface WorkoutHistoryEntry {
  date: string;
  title: string;
  sets: number;
  minutes: number;
  calories: number;
  completedAt: string; // ISO
}

export interface TrainerSpecial {
  id: string;
  trainer: Trainer;
  time: string;
  originalPrice: number;
  discountPercent: number;
  discountedPrice: number;
}
