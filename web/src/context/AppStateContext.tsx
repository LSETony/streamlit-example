import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import * as api from "../lib/api";
import { deviceUserId } from "../lib/deviceUser";
import { gymLocations, type GymLocation } from "../lib/gymLocations";
import type {
  Trainer,
  Product,
  WorkoutCard,
  ImportantCard,
  FoodRecipe,
  GymZone,
  SubscriptionPlan,
  BookedSession,
  CartLine,
  Achievement,
  LeaderboardEntry,
  WorkoutHistoryEntry,
  TrainerSpecial,
} from "../lib/models";
import { useToast } from "./ToastContext";

const AVATAR_PRESET_KEY = "core.avatarPresetID";
const AVATAR_URL_KEY = "core.avatarImageURLString";

function nextOccurrence(time: string): Date | null {
  const parts = time.split(":").map(Number);
  if (parts.length !== 2 || parts.some(Number.isNaN)) return null;
  const now = new Date();
  const date = new Date(now);
  date.setHours(parts[0], parts[1], 0, 0);
  if (date.getTime() < now.getTime()) date.setDate(date.getDate() + 1);
  return date;
}

const OCCUPANCY_CURVE = [
  { hour: 6, shape: 0.1 },
  { hour: 8, shape: 0.22 },
  { hour: 10, shape: 0.355 },
  { hour: 12, shape: 0.5 },
  { hour: 14, shape: 0.79 },
  { hour: 16, shape: 0.9 },
  { hour: 18, shape: 1.0 },
  { hour: 20, shape: 0.6 },
  { hour: 22, shape: 0.355 },
];

function sampleOccupancyCurve(): number {
  const now = new Date();
  const fractionalHour = now.getHours() + now.getMinutes() / 60;
  const sorted = OCCUPANCY_CURVE;
  const first = sorted[0];
  const last = sorted[sorted.length - 1];
  if (fractionalHour <= first.hour) return first.shape;
  if (fractionalHour >= last.hour) return last.shape;
  const upperIndex = sorted.findIndex((p) => p.hour >= fractionalHour);
  const upper = sorted[upperIndex];
  const lower = sorted[Math.max(0, upperIndex - 1)];
  const span = upper.hour - lower.hour;
  const t = span > 0 ? (fractionalHour - lower.hour) / span : 0;
  return lower.shape + (upper.shape - lower.shape) * t;
}

const SEED_WORKOUT_HISTORY: WorkoutHistoryEntry[] = [
  { date: "Yesterday", title: "Beginner Body Weight Plan", sets: 10, minutes: 27, calories: 205, completedAt: daysAgo(1) },
  { date: "Mon", title: "Sam's Prental Flow", sets: 12, minutes: 22, calories: 168, completedAt: daysAgo(3) },
  { date: "Sat", title: "Beginner Female Aesthetics", sets: 16, minutes: 41, calories: 289, completedAt: daysAgo(5) },
];

function daysAgo(n: number): string {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return d.toISOString();
}

function isToday(iso: string): boolean {
  const d = new Date(iso);
  const now = new Date();
  return d.toDateString() === now.toDateString();
}

interface AppStateValue {
  isLoading: boolean;

  // Profile
  fullName: string;
  initials: string;
  memberSince: string;
  totalVisits: number;
  septemberVisits: number;
  scansThisMonth: number;
  ptSessionsLeft: number;
  membershipPlanName: string;
  membershipRenewDate: string;
  avatarPresetID: string | null;
  avatarImageURL: string | null;
  setAvatarPresetID: (id: string | null) => void;
  setAvatarImageURL: (url: string | null) => void;

  // Club / occupancy
  clubName: string;
  setClubName: (name: string) => void;
  gymLocations: GymLocation[];
  currentLocation: GymLocation;
  gymPhotoURLs: string[];
  occupancyPercent: number;
  occupancyInClub: number;
  occupancyCapacity: number;

  // Workout history / progress
  workoutHistory: WorkoutHistoryEntry[];
  trainingSetsToday: number;
  trainingMinutesToday: number;
  trainingCaloriesToday: number;
  totalSetsThisWeek: number;
  totalMinutesThisWeek: number;
  totalCaloriesThisWeek: number;
  recordWorkoutCompletion: (title: string, sets: number, minutes: number, calories: number) => Promise<Achievement | null>;

  // Catalog
  beginnerPlanCards: WorkoutCard[];
  topWorkoutCards: WorkoutCard[];
  importantCards: ImportantCard[];
  foodRecipes: FoodRecipe[];
  trainers: Trainer[];
  trainerSlots: string[];
  gymZones: GymZone[];
  subscriptionPlans: SubscriptionPlan[];
  products: Product[];

  // Bookings
  bookedSessions: BookedSession[];
  bookZone: (zone: GymZone, time: string) => Promise<void>;
  bookTrainerSpecial: (special: TrainerSpecial) => Promise<void>;
  rescheduleSession: (session: BookedSession, newDateIso: string) => Promise<void>;
  cancelSession: (session: BookedSession) => Promise<void>;
  todaysSpecials: TrainerSpecial[];

  // Cart
  cart: CartLine[];
  cartCount: number;
  cartTotal: number;
  addToCart: (product: Product) => Promise<void>;
  removeFromCart: (line: CartLine) => Promise<void>;
  clearCart: () => Promise<void>;

  // Growth
  streakDays: number;
  referralCode: string;
  leaderboard: LeaderboardEntry[];
  achievements: Achievement[];
  recordActivity: () => Promise<boolean>;
  refreshLeaderboard: () => Promise<void>;
  redeemReferralCode: (code: string) => Promise<void>;

  // Membership toggles
  membershipPlanNameSet: (name: string) => void;
}

const AppStateContext = createContext<AppStateValue | null>(null);

export function AppStateProvider({ children }: { children: ReactNode }) {
  const { trigger } = useToast();
  const [isLoading, setIsLoading] = useState(true);

  const [fullName] = useState("Jarvis Kitsune Jr");
  const [clubName, setClubName] = useState(gymLocations[0].name);
  const [gymPhotoURLs, setGymPhotoURLs] = useState<string[]>([]);

  const [occupancyPercent, setOccupancyPercent] = useState(0);
  const [occupancyInClub, setOccupancyInClub] = useState(0);
  const occupancyCapacity = 90;

  const [workoutHistory, setWorkoutHistory] = useState<WorkoutHistoryEntry[]>(SEED_WORKOUT_HISTORY);

  const [beginnerPlanCards, setBeginnerPlanCards] = useState<WorkoutCard[]>([]);
  const [topWorkoutCards, setTopWorkoutCards] = useState<WorkoutCard[]>([]);
  const [importantCards, setImportantCards] = useState<ImportantCard[]>([]);
  const [foodRecipes, setFoodRecipes] = useState<FoodRecipe[]>([]);
  const [trainers, setTrainers] = useState<Trainer[]>([]);
  const [trainerSlots] = useState<string[]>(["07:30", "11:00", "17:00", "19:30"]);
  const [gymZones, setGymZones] = useState<GymZone[]>([]);
  const [subscriptionPlans, setSubscriptionPlans] = useState<SubscriptionPlan[]>([]);
  const [products, setProducts] = useState<Product[]>([]);

  const [bookedSessions, setBookedSessions] = useState<BookedSession[]>([]);
  const [cart, setCart] = useState<CartLine[]>([]);

  const [membershipPlanName, setMembershipPlanName] = useState("Unlimited 24/7");
  const [membershipRenewDate] = useState("12 Mar 2027");
  const [memberSince] = useState("March 2023");
  const [totalVisits, setTotalVisits] = useState(128);
  const [septemberVisits] = useState(18);
  const [scansThisMonth] = useState(6);
  const [ptSessionsLeft] = useState(3);

  const [avatarPresetID, setAvatarPresetIDState] = useState<string | null>(() => {
    try {
      return localStorage.getItem(AVATAR_PRESET_KEY);
    } catch {
      return null;
    }
  });
  const [avatarImageURL, setAvatarImageURLState] = useState<string | null>(() => {
    try {
      return localStorage.getItem(AVATAR_URL_KEY);
    } catch {
      return null;
    }
  });

  const [streakDays, setStreakDays] = useState(0);
  const [referralCode, setReferralCode] = useState("");
  const [lastActivityDate, setLastActivityDate] = useState<string | null>(null);
  const [leaderboard, setLeaderboard] = useState<LeaderboardEntry[]>([]);

  const currentLocation = useMemo(
    () => gymLocations.find((l) => l.name === clubName) ?? gymLocations[0],
    [clubName]
  );

  const todaysEntries = useMemo(() => workoutHistory.filter((e) => isToday(e.completedAt)), [workoutHistory]);
  const trainingSetsToday = useMemo(() => todaysEntries.reduce((sum, e) => sum + e.sets, 0), [todaysEntries]);
  const trainingMinutesToday = useMemo(() => todaysEntries.reduce((sum, e) => sum + e.minutes, 0), [todaysEntries]);
  const trainingCaloriesToday = useMemo(() => todaysEntries.reduce((sum, e) => sum + e.calories, 0), [todaysEntries]);
  const totalSetsThisWeek = useMemo(() => workoutHistory.reduce((sum, e) => sum + e.sets, 0), [workoutHistory]);
  const totalMinutesThisWeek = useMemo(() => workoutHistory.reduce((sum, e) => sum + e.minutes, 0), [workoutHistory]);
  const totalCaloriesThisWeek = useMemo(() => workoutHistory.reduce((sum, e) => sum + e.calories, 0), [workoutHistory]);

  const achievements: Achievement[] = useMemo(
    () => [
      { icon: "🏃", title: "First Workout", detail: "Log your first session", isUnlocked: workoutHistory.length > 0 },
      { icon: "🔥", title: "7 Day Streak", detail: "Stay active 7 days running", isUnlocked: streakDays >= 7 },
      { icon: "🔥", title: "30 Day Streak", detail: "Stay active 30 days running", isUnlocked: streakDays >= 30 },
      { icon: "✅", title: "10 Workouts", detail: "Complete 10 sessions", isUnlocked: workoutHistory.length >= 10 },
      { icon: "✅", title: "50 Workouts", detail: "Complete 50 sessions", isUnlocked: workoutHistory.length >= 50 },
      { icon: "⭐", title: "100 Visits", detail: "Check in 100 times", isUnlocked: totalVisits >= 100 },
    ],
    [workoutHistory, streakDays, totalVisits]
  );

  const todaysSpecials: TrainerSpecial[] = useMemo(() => {
    const today = new Date();
    const bookedToday = new Set(
      bookedSessions
        .filter((s) => new Date(s.date).toDateString() === today.toDateString())
        .map((s) => {
          const d = new Date(s.date);
          const hh = String(d.getHours()).padStart(2, "0");
          const mm = String(d.getMinutes()).padStart(2, "0");
          return `${s.title}|${hh}:${mm}`;
        })
    );
    const specials: TrainerSpecial[] = [];
    for (const trainer of trainers) {
      for (const slot of trainerSlots) {
        const slotDate = nextOccurrence(slot);
        if (!slotDate || slotDate.toDateString() !== today.toDateString()) continue;
        const key = `${trainer.name}|${slot}`;
        if (bookedToday.has(key)) continue;
        const originalPrice = parseInt(trainer.priceCompact, 10) || 0;
        const discountPercent = 30;
        specials.push({
          id: `${trainer.id}-${slot}`,
          trainer,
          time: slot,
          originalPrice,
          discountPercent,
          discountedPrice: Math.max(0, originalPrice - Math.round((originalPrice * discountPercent) / 100)),
        });
      }
    }
    return specials;
  }, [trainers, trainerSlots, bookedSessions]);

  const cartCount = cart.length;
  const cartTotal = useMemo(() => cart.reduce((sum, l) => sum + l.price, 0), [cart]);

  // ---- Initial load ----

  useEffect(() => {
    let cancelled = false;
    async function load() {
      setOccupancyPercent(Math.round(sampleOccupancyCurve() * 100));
      setOccupancyInClub(Math.round(sampleOccupancyCurve() * occupancyCapacity));

      const [
        trainerRows,
        productRows,
        workoutRows,
        importantRows,
        foodRows,
        zoneRows,
        planRows,
        sessionRows,
        cartRows,
        settingRows,
      ] = await Promise.all([
        api.fetchTrainers(),
        api.fetchProducts(),
        api.fetchWorkoutCards(),
        api.fetchImportantCards(),
        api.fetchFoodRecipes(),
        api.fetchGymZones(),
        api.fetchSubscriptionPlans(),
        api.fetchOwnBookedSessions(),
        api.fetchOwnCart(),
        api.fetchAppSettings(),
      ]);
      if (cancelled) return;

      setTrainers(trainerRows);
      setProducts(productRows);
      setBeginnerPlanCards(workoutRows.filter((c) => c.section === "beginner_plan"));
      setTopWorkoutCards(workoutRows.filter((c) => c.section === "top_workouts"));
      setImportantCards(importantRows);
      setFoodRecipes(foodRows);
      setGymZones(zoneRows);
      setSubscriptionPlans(planRows);
      setBookedSessions(sessionRows);
      setCart(cartRows);
      const photoUrls = settingRows["gym_photo_urls"]
        ?.split(",")
        .map((s) => s.trim())
        .filter(Boolean);
      setGymPhotoURLs(photoUrls ?? []);

      // Member stats (streak / visits / referral code)
      const stats = await api.fetchOwnMemberStats();
      if (cancelled) return;
      if (stats) {
        setTotalVisits(stats.total_visits);
        setStreakDays(stats.current_streak);
        setLastActivityDate(stats.last_activity_date);
        if (stats.referral_code) {
          setReferralCode(stats.referral_code);
        } else {
          const code = api.generateReferralCode();
          setReferralCode(code);
          await api.upsertMemberStats({
            displayName: fullName,
            totalVisits: stats.total_visits,
            currentStreak: stats.current_streak,
            lastActivityDate: stats.last_activity_date,
            referralCode: code,
          });
        }
      } else {
        const code = api.generateReferralCode();
        setReferralCode(code);
        await api.upsertMemberStats({
          displayName: fullName,
          totalVisits,
          currentStreak: streakDays,
          lastActivityDate: null,
          referralCode: code,
        });
      }

      // Live occupancy from recent check-ins
      const cutoff = new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString();
      const recent = await api.fetchRecentCheckins(cutoff);
      if (cancelled) return;
      const distinct = new Set(recent);
      const count = Math.min(distinct.size, occupancyCapacity);
      if (count > 0) {
        setOccupancyInClub(count);
        setOccupancyPercent(Math.round((count / occupancyCapacity) * 100));
      }

      setIsLoading(false);
    }
    load();
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const setAvatarPresetID = useCallback((id: string | null) => {
    setAvatarPresetIDState(id);
    setAvatarImageURLState(null);
    try {
      if (id) localStorage.setItem(AVATAR_PRESET_KEY, id);
      else localStorage.removeItem(AVATAR_PRESET_KEY);
      localStorage.removeItem(AVATAR_URL_KEY);
    } catch {
      /* ignore */
    }
  }, []);

  const setAvatarImageURL = useCallback((url: string | null) => {
    setAvatarImageURLState(url);
    setAvatarPresetIDState(null);
    try {
      if (url) localStorage.setItem(AVATAR_URL_KEY, url);
      else localStorage.removeItem(AVATAR_URL_KEY);
      localStorage.removeItem(AVATAR_PRESET_KEY);
    } catch {
      /* ignore */
    }
  }, []);

  const bookZone = useCallback(
    async (zone: GymZone, time: string) => {
      const date = nextOccurrence(time);
      if (!date) return;
      const session: BookedSession = { id: crypto.randomUUID(), date: date.toISOString(), title: zone.name, trainerName: zone.subtitle };
      setBookedSessions((prev) => [...prev, session]);
      await api.insertSession(session);
    },
    []
  );

  const bookTrainerSpecial = useCallback(
    async (special: TrainerSpecial) => {
      const date = nextOccurrence(special.time);
      if (!date) return;
      const session: BookedSession = {
        id: crypto.randomUUID(),
        date: date.toISOString(),
        title: special.trainer.name,
        trainerName: special.trainer.specialty,
      };
      setBookedSessions((prev) => [...prev, session]);
      trigger({
        icon: "🏷️",
        title: "Special booked!",
        subtitle: `${special.trainer.name} · ${special.time} · $${special.discountedPrice}`,
        accent: "var(--accent-purple)",
      });
      await api.insertSession(session);
    },
    [trigger]
  );

  const rescheduleSession = useCallback(async (session: BookedSession, newDateIso: string) => {
    setBookedSessions((prev) => prev.map((s) => (s.id === session.id ? { ...s, date: newDateIso } : s)));
    await api.updateSessionDate(session.id, newDateIso);
  }, []);

  const cancelSession = useCallback(async (session: BookedSession) => {
    setBookedSessions((prev) => prev.filter((s) => s.id !== session.id));
    await api.deleteSession(session.id);
  }, []);

  const addToCart = useCallback(async (product: Product) => {
    const line: CartLine = { id: crypto.randomUUID(), name: product.name, price: product.price };
    setCart((prev) => [...prev, line]);
    await api.insertCartLine(line);
  }, []);

  const removeFromCart = useCallback(async (line: CartLine) => {
    setCart((prev) => prev.filter((l) => l.id !== line.id));
    await api.deleteCartLine(line.id);
  }, []);

  const clearCart = useCallback(async () => {
    setCart([]);
    await api.deleteAllCartLines();
  }, []);

  const recordActivity = useCallback(async () => {
    await api.logCheckIn();
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const todayKey = today.toISOString().slice(0, 10);
    if (lastActivityDate === todayKey) return false;

    let nextStreak = 1;
    if (lastActivityDate) {
      const yesterday = new Date(today);
      yesterday.setDate(yesterday.getDate() - 1);
      if (lastActivityDate === yesterday.toISOString().slice(0, 10)) {
        nextStreak = streakDays + 1;
      }
    }
    setStreakDays(nextStreak);
    setLastActivityDate(todayKey);
    const nextVisits = totalVisits + 1;
    setTotalVisits(nextVisits);
    await api.upsertMemberStats({
      displayName: fullName,
      totalVisits: nextVisits,
      currentStreak: nextStreak,
      lastActivityDate: todayKey,
      referralCode: referralCode || null,
    });
    return true;
  }, [lastActivityDate, streakDays, totalVisits, fullName, referralCode]);

  const recordWorkoutCompletion = useCallback(
    async (title: string, sets: number, minutes: number, calories: number) => {
      const unlockedBefore = new Set(achievements.filter((a) => a.isUnlocked).map((a) => a.title));
      const entry: WorkoutHistoryEntry = { date: "Today", title, sets, minutes, calories, completedAt: new Date().toISOString() };
      setWorkoutHistory((prev) => [entry, ...prev]);
      await recordActivity();
      // achievements recomputes from the new state on next render; approximate the diff here
      const nextUnlocked = new Set(
        achievements
          .map((a) => ({ ...a, isUnlocked: a.isUnlocked || a.title === "First Workout" }))
          .filter((a) => a.isUnlocked)
          .map((a) => a.title)
      );
      const newlyUnlocked = [...nextUnlocked].find((t) => !unlockedBefore.has(t));
      const found = achievements.find((a) => a.title === newlyUnlocked) ?? null;
      trigger({
        icon: found ? "🏆" : "✅",
        title: found ? "Achievement unlocked!" : "Workout complete!",
        subtitle: found ? found.title : undefined,
        accent: "var(--accent)",
      });
      return found;
    },
    [achievements, recordActivity, trigger]
  );

  const refreshLeaderboard = useCallback(async () => {
    const rows = await api.fetchLeaderboard();
    const sorted = rows
      .sort((a, b) => b.total_visits - a.total_visits)
      .slice(0, 20)
      .map((row) => ({
        id: row.device_user_id,
        displayName: row.display_name,
        totalVisits: row.total_visits,
        streakDays: row.current_streak,
        isMe: row.device_user_id === deviceUserId,
      }));
    setLeaderboard(sorted);
  }, []);

  const redeemReferralCode = useCallback(
    async (code: string) => {
      const trimmed = code.trim().toUpperCase();
      if (!trimmed || trimmed === referralCode) return;
      await api.upsertMemberStats({
        displayName: fullName,
        totalVisits,
        currentStreak: streakDays,
        lastActivityDate,
        referralCode: referralCode || api.generateReferralCode(),
      });
    },
    [referralCode, fullName, totalVisits, streakDays, lastActivityDate]
  );

  const value: AppStateValue = {
    isLoading,
    fullName,
    initials: fullName
      .split(" ")
      .map((s) => s[0])
      .join("")
      .toUpperCase(),
    memberSince,
    totalVisits,
    septemberVisits,
    scansThisMonth,
    ptSessionsLeft,
    membershipPlanName,
    membershipRenewDate,
    avatarPresetID,
    avatarImageURL,
    setAvatarPresetID,
    setAvatarImageURL,
    clubName,
    setClubName,
    gymLocations,
    currentLocation,
    gymPhotoURLs,
    occupancyPercent,
    occupancyInClub,
    occupancyCapacity,
    workoutHistory,
    trainingSetsToday,
    trainingMinutesToday,
    trainingCaloriesToday,
    totalSetsThisWeek,
    totalMinutesThisWeek,
    totalCaloriesThisWeek,
    recordWorkoutCompletion,
    beginnerPlanCards,
    topWorkoutCards,
    importantCards,
    foodRecipes,
    trainers,
    trainerSlots,
    gymZones,
    subscriptionPlans,
    products,
    bookedSessions,
    bookZone,
    bookTrainerSpecial,
    rescheduleSession,
    cancelSession,
    todaysSpecials,
    cart,
    cartCount,
    cartTotal,
    addToCart,
    removeFromCart,
    clearCart,
    streakDays,
    referralCode,
    leaderboard,
    achievements,
    recordActivity,
    refreshLeaderboard,
    redeemReferralCode,
    membershipPlanNameSet: setMembershipPlanName,
  };

  return <AppStateContext.Provider value={value}>{children}</AppStateContext.Provider>;
}

export function useAppState(): AppStateValue {
  const ctx = useContext(AppStateContext);
  if (!ctx) throw new Error("useAppState must be used within an AppStateProvider");
  return ctx;
}
