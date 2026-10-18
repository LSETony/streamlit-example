import { supabase } from "./supabase";
import { deviceUserId } from "./deviceUser";
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
} from "./models";

/// Web port of AppState+Supabase.swift / AppState+Growth.swift — same
/// tables, same device-scoped trust model (anon key, scoped client-side by
/// a random id kept in localStorage instead of a Supabase Auth session).

export async function fetchTrainers(): Promise<Trainer[]> {
  const { data, error } = await supabase.from("trainers").select("*");
  if (error) {
    console.error("fetchTrainers", error);
    return [];
  }
  return (data ?? []).map((row) => ({
    id: row.id,
    imageName: row.image_name,
    name: row.name,
    specialty: row.specialty,
    rating: row.rating,
    reviews: row.reviews,
    priceLabel: row.price_label,
    priceCompact: row.price_compact,
    nextAvailable: row.next_available,
    availabilityColor: row.availability_color,
    yearsExperience: row.years_experience,
    clients: row.clients,
    sessions: row.sessions,
    tags: row.tags ?? [],
    bio: row.bio,
  }));
}

export async function fetchProducts(): Promise<Product[]> {
  const { data, error } = await supabase.from("products").select("*, product_ingredients(*)");
  if (error) {
    console.error("fetchProducts", error);
    return [];
  }
  return (data ?? []).map((row) => ({
    id: row.id,
    abbr: row.abbr,
    name: row.name,
    form: row.form,
    dose: row.dose,
    count: row.count,
    price: row.price,
    subscriptionPrice: row.subscription_price,
    tag: row.tag,
    tagColor: row.tag_color,
    desc: row.description,
    ingredients: (row.product_ingredients ?? []).map((i: { name: string; amount: string }) => ({
      name: i.name,
      amount: i.amount,
    })),
    benefits: row.benefits,
    risks: row.risks,
    interactions: row.interactions,
  }));
}

export async function fetchWorkoutCards(): Promise<WorkoutCard[]> {
  const { data, error } = await supabase.from("workout_cards").select("*, exercises(*)");
  if (error) {
    console.error("fetchWorkoutCards", error);
    return [];
  }
  return (data ?? []).map((row) => ({
    id: row.id,
    section: row.section,
    imageName: row.image_name,
    title: row.title,
    level: row.level,
    duration: row.duration,
    category: row.category,
    exercises: (row.exercises ?? [])
      .sort((a: { sort_order: number }, b: { sort_order: number }) => a.sort_order - b.sort_order)
      .map((e: { name: string; icon: string; sets: number; reps: string }) => ({
        name: e.name,
        icon: e.icon,
        sets: e.sets,
        reps: e.reps,
      })),
    imageURL: row.image_url,
    videoURL: row.video_url,
  }));
}

export async function fetchImportantCards(): Promise<ImportantCard[]> {
  const { data, error } = await supabase.from("important_cards").select("*");
  if (error) {
    console.error("fetchImportantCards", error);
    return [];
  }
  return (data ?? []).map((row) => ({ icon: row.icon, title: row.title, subtitle: row.subtitle }));
}

export async function fetchFoodRecipes(): Promise<FoodRecipe[]> {
  const { data, error } = await supabase.from("food_recipes").select("*");
  if (error) {
    console.error("fetchFoodRecipes", error);
    return [];
  }
  return (data ?? []).map((row) => ({
    id: row.id,
    name: row.name,
    price: row.price,
    ingredients: row.ingredients ?? [],
    imageURL: row.image_url,
  }));
}

export async function fetchGymZones(): Promise<GymZone[]> {
  const { data, error } = await supabase.from("gym_zones").select("*");
  if (error) {
    console.error("fetchGymZones", error);
    return [];
  }
  return (data ?? []).map((row) => ({
    id: row.id,
    icon: row.icon,
    name: row.name,
    subtitle: row.subtitle,
    capacity: row.capacity,
  }));
}

export async function fetchSubscriptionPlans(): Promise<SubscriptionPlan[]> {
  const { data, error } = await supabase.from("subscription_plans").select("*");
  if (error) {
    console.error("fetchSubscriptionPlans", error);
    return [];
  }
  return (data ?? []).map((row) => ({
    id: row.id,
    name: row.name,
    price: row.price,
    period: row.period,
    perks: row.perks ?? [],
    recommended: row.recommended,
  }));
}

export async function fetchAppSettings(): Promise<Record<string, string>> {
  const { data, error } = await supabase.from("app_settings").select("*");
  if (error) {
    console.error("fetchAppSettings", error);
    return {};
  }
  return Object.fromEntries((data ?? []).map((row) => [row.key, row.value]));
}

export async function fetchOwnBookedSessions(): Promise<BookedSession[]> {
  const { data, error } = await supabase.from("booked_sessions").select("*").eq("device_user_id", deviceUserId);
  if (error) {
    console.error("fetchOwnBookedSessions", error);
    return [];
  }
  return (data ?? []).map((row) => ({ id: row.id, date: row.date, title: row.title, trainerName: row.trainer_name }));
}

export async function insertSession(session: BookedSession): Promise<void> {
  const { error } = await supabase.from("booked_sessions").insert({
    id: session.id,
    device_user_id: deviceUserId,
    date: session.date,
    title: session.title,
    trainer_name: session.trainerName,
  });
  if (error) console.error("insertSession", error);
}

export async function updateSessionDate(id: string, newDateIso: string): Promise<void> {
  const { error } = await supabase.from("booked_sessions").update({ date: newDateIso }).eq("id", id);
  if (error) console.error("updateSessionDate", error);
}

export async function deleteSession(id: string): Promise<void> {
  const { error } = await supabase.from("booked_sessions").delete().eq("id", id);
  if (error) console.error("deleteSession", error);
}

export async function fetchOwnCart(): Promise<CartLine[]> {
  const { data, error } = await supabase.from("cart_items").select("*").eq("device_user_id", deviceUserId);
  if (error) {
    console.error("fetchOwnCart", error);
    return [];
  }
  return (data ?? []).map((row) => ({ id: row.id, name: row.name, price: row.price }));
}

export async function insertCartLine(line: CartLine): Promise<void> {
  const { error } = await supabase
    .from("cart_items")
    .insert({ id: line.id, device_user_id: deviceUserId, name: line.name, price: line.price });
  if (error) console.error("insertCartLine", error);
}

export async function deleteCartLine(id: string): Promise<void> {
  const { error } = await supabase.from("cart_items").delete().eq("id", id);
  if (error) console.error("deleteCartLine", error);
}

export async function deleteAllCartLines(): Promise<void> {
  const { error } = await supabase.from("cart_items").delete().eq("device_user_id", deviceUserId);
  if (error) console.error("deleteAllCartLines", error);
}

// MARK: Member stats (streak / visits / referral)

interface MemberStatsRow {
  device_user_id: string;
  display_name: string;
  total_visits: number;
  current_streak: number;
  last_activity_date: string | null;
  referral_code: string | null;
}

export async function fetchOwnMemberStats(): Promise<MemberStatsRow | null> {
  const { data, error } = await supabase.from("member_stats").select("*").eq("device_user_id", deviceUserId).maybeSingle();
  if (error) {
    console.error("fetchOwnMemberStats", error);
    return null;
  }
  return data as MemberStatsRow | null;
}

export async function upsertMemberStats(row: {
  displayName: string;
  totalVisits: number;
  currentStreak: number;
  lastActivityDate: string | null;
  referralCode: string | null;
}): Promise<void> {
  const { error } = await supabase.from("member_stats").upsert(
    {
      device_user_id: deviceUserId,
      display_name: row.displayName,
      total_visits: row.totalVisits,
      current_streak: row.currentStreak,
      last_activity_date: row.lastActivityDate,
      referral_code: row.referralCode,
    },
    { onConflict: "device_user_id" }
  );
  if (error) console.error("upsertMemberStats", error);
}

export async function fetchLeaderboard(): Promise<MemberStatsRow[]> {
  const { data, error } = await supabase.from("member_stats").select("*");
  if (error) {
    console.error("fetchLeaderboard", error);
    return [];
  }
  return (data ?? []) as MemberStatsRow[];
}

export async function logCheckIn(): Promise<void> {
  const { error } = await supabase.from("checkins").insert({ device_user_id: deviceUserId });
  if (error) console.error("logCheckIn", error);
}

export async function fetchRecentCheckins(sinceIso: string): Promise<string[]> {
  const { data, error } = await supabase.from("checkins").select("device_user_id, checked_in_at").gte("checked_in_at", sinceIso);
  if (error) {
    console.error("fetchRecentCheckins", error);
    return [];
  }
  return (data ?? []).map((row) => row.device_user_id as string);
}

// MARK: Progress photos

interface ProgressPhotoRow {
  id: string;
  image_url: string;
  taken_at: string;
}

export async function fetchOwnProgressPhotos(): Promise<ProgressPhotoRow[]> {
  const { data, error } = await supabase.from("progress_photos").select("*").eq("device_user_id", deviceUserId);
  if (error) {
    console.error("fetchOwnProgressPhotos", error);
    return [];
  }
  return (data ?? []) as ProgressPhotoRow[];
}

export async function uploadProgressPhoto(file: File): Promise<{ id: string; imageURL: string } | null> {
  const id = crypto.randomUUID();
  const path = `progress/${deviceUserId}/${id}.jpg`;
  const { error: uploadError } = await supabase.storage.from("media").upload(path, file, { contentType: file.type || "image/jpeg" });
  if (uploadError) {
    console.error("uploadProgressPhoto storage", uploadError);
    return null;
  }
  const { data: publicData } = supabase.storage.from("media").getPublicUrl(path);
  const imageURL = publicData.publicUrl;
  const { error: insertError } = await supabase
    .from("progress_photos")
    .insert({ id, device_user_id: deviceUserId, image_url: imageURL });
  if (insertError) {
    console.error("uploadProgressPhoto insert", insertError);
    return null;
  }
  return { id, imageURL };
}

export async function deleteProgressPhoto(id: string): Promise<void> {
  const { error } = await supabase.from("progress_photos").delete().eq("id", id);
  if (error) console.error("deleteProgressPhoto", error);
}

export function generateReferralCode(): string {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let code = "";
  for (let i = 0; i < 6; i++) code += alphabet[Math.floor(Math.random() * alphabet.length)];
  return `CORE-${code}`;
}
