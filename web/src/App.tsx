import { BrowserRouter, Route, Routes } from "react-router-dom";
import { I18nProvider } from "./i18n/I18nProvider";
import { ToastProvider } from "./context/ToastContext";
import { AuthProvider, useAuth } from "./context/AuthContext";
import { AppStateProvider } from "./context/AppStateContext";
import { MainLayout } from "./components/MainLayout";
import { AuthWelcomeScreen } from "./screens/AuthWelcomeScreen";
import { OTPVerificationScreen } from "./screens/OTPVerificationScreen";
import { HomeScreen } from "./screens/HomeScreen";
import { WorkoutsScreen } from "./screens/WorkoutsScreen";
import { WorkoutDetailScreen } from "./screens/WorkoutDetailScreen";
import { CustomWorkoutBuilderScreen } from "./screens/CustomWorkoutBuilderScreen";
import { GymSafetyScreen } from "./screens/GymSafetyScreen";
import { EventsScreen } from "./screens/EventsScreen";
import { ProfileScreen } from "./screens/ProfileScreen";
import { ProgressScreen } from "./screens/ProgressScreen";
import { LeaderboardScreen } from "./screens/LeaderboardScreen";
import { ReferralScreen } from "./screens/ReferralScreen";
import { SubscriptionsScreen } from "./screens/SubscriptionsScreen";
import { TrainersScreen } from "./screens/TrainersScreen";
import { TrainerDetailScreen } from "./screens/TrainerDetailScreen";
import { StoreScreen } from "./screens/StoreScreen";
import { ProductDetailScreen } from "./screens/ProductDetailScreen";
import { CartScreen } from "./screens/CartScreen";
import { FoodScreen } from "./screens/FoodScreen";
import { CalendarScreen } from "./screens/CalendarScreen";
import { BookZoneScreen } from "./screens/BookZoneScreen";
import { ZoneBookingScreen } from "./screens/ZoneBookingScreen";
import { CheckInScreen } from "./screens/CheckInScreen";
import { ScanScreen } from "./screens/ScanScreen";
import { CoreAIScreen } from "./screens/CoreAIScreen";
import { HealthMetricsScreen } from "./screens/HealthMetricsScreen";
import { OnboardingScreen } from "./screens/OnboardingScreen";
import { OccupancyDetailScreen } from "./screens/OccupancyDetailScreen";
import { TodaysSpecialsScreen } from "./screens/TodaysSpecialsScreen";
import { QRPassScreen } from "./screens/QRPassScreen";
import { LanguagePickerScreen } from "./screens/LanguagePickerScreen";
import { InstallPrompt } from "./components/InstallPrompt";

function RootGate() {
  const { isAuthenticated } = useAuth();
  if (!isAuthenticated) {
    return (
      <Routes>
        <Route path="/otp" element={<OTPVerificationScreen />} />
        <Route path="*" element={<AuthWelcomeScreen />} />
      </Routes>
    );
  }
  return (
    <AppStateProvider>
      <Routes>
        <Route element={<MainLayout />}>
          <Route path="/" element={<HomeScreen />} />
          <Route path="/calendar" element={<CalendarScreen />} />
          <Route path="/workouts" element={<WorkoutsScreen />} />
          <Route path="/progress" element={<ProgressScreen />} />
          <Route path="/profile" element={<ProfileScreen />} />
        </Route>
        <Route path="/workouts/builder" element={<CustomWorkoutBuilderScreen />} />
        <Route path="/workouts/:id" element={<WorkoutDetailScreen />} />
        <Route path="/occupancy" element={<OccupancyDetailScreen />} />
        <Route path="/specials" element={<TodaysSpecialsScreen />} />
        <Route path="/gym-safety" element={<GymSafetyScreen />} />
        <Route path="/events" element={<EventsScreen />} />
        <Route path="/leaderboard" element={<LeaderboardScreen />} />
        <Route path="/referral" element={<ReferralScreen />} />
        <Route path="/subscriptions" element={<SubscriptionsScreen />} />
        <Route path="/trainers" element={<TrainersScreen />} />
        <Route path="/trainers/:id" element={<TrainerDetailScreen />} />
        <Route path="/store" element={<StoreScreen />} />
        <Route path="/store/:id" element={<ProductDetailScreen />} />
        <Route path="/cart" element={<CartScreen />} />
        <Route path="/food" element={<FoodScreen />} />
        <Route path="/book" element={<BookZoneScreen />} />
        <Route path="/book/:zoneId" element={<ZoneBookingScreen />} />
        <Route path="/checkin" element={<CheckInScreen />} />
        <Route path="/scan" element={<ScanScreen />} />
        <Route path="/core-ai" element={<CoreAIScreen />} />
        <Route path="/health" element={<HealthMetricsScreen />} />
        <Route path="/onboarding" element={<OnboardingScreen />} />
        <Route path="/qr-pass" element={<QRPassScreen />} />
        <Route path="/language" element={<LanguagePickerScreen />} />
      </Routes>
    </AppStateProvider>
  );
}

export default function App() {
  return (
    <I18nProvider>
      <ToastProvider>
        <AuthProvider>
          <BrowserRouter>
            <RootGate />
          </BrowserRouter>
          <InstallPrompt />
        </AuthProvider>
      </ToastProvider>
    </I18nProvider>
  );
}
