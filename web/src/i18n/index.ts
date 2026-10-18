import { createContext, useContext } from "react";
import { generatedDict } from "./generatedDict";

export type Language = "en" | "ru";

export const LANGUAGE_STORAGE_KEY = "core.web.language";

export const languageNativeName: Record<Language, string> = {
  en: "English",
  ru: "Русский",
};

// Hand-written entries for strings that only exist in the web app (cart,
// checkout, nav labels, empty states, etc.) — the generated dict above
// covers everything that already existed in the iOS String Catalog so the
// two apps read identically wherever their copy overlaps.
const handWritten: Record<string, { en: string; ru: string }> = {
  "nav.home": { en: "Home", ru: "Главная" },
  "nav.workouts": { en: "Workouts", ru: "Тренировки" },
  "nav.profile": { en: "Profile", ru: "Профиль" },
  "nav.progress": { en: "Your Progress", ru: "Прогресс" },

  "home.specialsForToday": { en: "Specials for today", ru: "Акции сегодня" },
  "home.unbookedSlots": { en: "unbooked slots, discounted", ru: "свободных слотов со скидкой" },

  "cart.title": { en: "Cart", ru: "Корзина" },
  "cart.empty": { en: "Your cart is empty.", ru: "Ваша корзина пуста." },
  "cart.subtotal": { en: "Subtotal", ru: "Сумма" },
  "cart.checkout": { en: "Checkout", ru: "Оформить заказ" },
  "cart.remove": { en: "Remove", ru: "Удалить" },

  "common.loading": { en: "Loading…", ru: "Загрузка…" },
  "common.retry": { en: "Retry", ru: "Повторить" },
  "common.close": { en: "Close", ru: "Закрыть" },
  "common.back": { en: "Back", ru: "Назад" },
  "common.save": { en: "Save", ru: "Сохранить" },
  "common.error": { en: "Something went wrong.", ru: "Что-то пошло не так." },
  "common.comingSoon": { en: "Coming soon", ru: "Скоро" },

  "scan.title": { en: "Scan", ru: "Сканер" },
  "scan.noCamera": {
    en: "Camera barcode scanning isn't available in a web browser the way it is on iOS. Search for a product instead.",
    ru: "Сканирование камерой недоступно в браузере так, как на iOS. Найдите товар через поиск.",
  },
  "scan.searchPlaceholder": { en: "Search a product…", ru: "Найти товар…" },

  "coreAI.title": { en: "Core AI", ru: "Core AI" },
  "coreAI.unavailable": {
    en: "Core AI runs on Apple Intelligence on iOS, which has no web equivalent — there's no on-device model to run in a browser tab. A real chat here would need its own server-side AI backend, which isn't wired up yet.",
    ru: "Core AI работает на Apple Intelligence в iOS — в браузере аналога этой технологии нет, на устройстве нет модели, которую можно запустить во вкладке. Настоящий чат здесь потребовал бы отдельного серверного AI-бэкенда, который пока не подключён.",
  },

  "health.title": { en: "Health Metrics", ru: "Показатели здоровья" },
  "health.unavailable": {
    en: "This screen reads from Apple Health on iOS. Browsers have no equivalent health data store to read from, so there's nothing to sync here — this is a platform limit, not a missing feature.",
    ru: "Этот экран на iOS читает данные из Apple Здоровье. У браузеров нет аналогичного хранилища данных о здоровье, поэтому синхронизировать здесь нечего — это ограничение платформы, а не недостающая функция.",
  },

  "auth.continueWithEmail": { en: "Continue with email", ru: "Продолжить с email" },
  "auth.appleUnavailable": {
    en: "Sign in with Apple needs a native iOS app — it isn't available on the web.",
    ru: "Вход через Apple доступен только в нативном iOS-приложении — в браузере недоступен.",
  },
  "auth.googleUnavailable": {
    en: "Google Sign-In isn't configured for this project yet.",
    ru: "Вход через Google пока не настроен для этого проекта.",
  },
  "auth.fullName": { en: "Full name", ru: "Полное имя" },
  "auth.email": { en: "Email", ru: "Email" },

  "install.title": { en: "Install core.", ru: "Установите core." },
  "install.body": {
    en: "Add this to your home screen for the full-screen app experience — no App Store needed.",
    ru: "Добавьте приложение на главный экран для полноэкранного режима — без App Store.",
  },
  "install.cta": { en: "Add to Home Screen", ru: "На экран «Домой»" },
  "install.dismiss": { en: "Not now", ru: "Не сейчас" },

  "profile.memberSince": { en: "Member since", ru: "Участник с" },
  "profile.progressAndAchievements": { en: "Progress & Achievements", ru: "Прогресс и достижения" },

  "Rules & equipment guide": { en: "Rules & equipment guide", ru: "Правила и инструкция по оборудованию" },
  "What's on this month": { en: "What's on this month", ru: "Что происходит в этом месяце" },
  "No members yet — be the first to check in.": { en: "No members yet — be the first to check in.", ru: "Пока нет участников — отметьтесь первым." },
  "Product not found.": { en: "Product not found.", ru: "Товар не найден." },
  "Streak": { en: "Streak", ru: "Серия" },
  "Show this at reception to check in.": { en: "Show this at reception to check in.", ru: "Покажите это на ресепшене для отметки." },
  "I was invited": { en: "I was invited", ru: "Меня пригласили" },
  "No discounted slots left today.": { en: "No discounted slots left today.", ru: "Сегодня больше нет слотов со скидкой." },
  "Trainer not found.": { en: "Trainer not found.", ru: "Тренер не найден." },
  "Workout not found.": { en: "Workout not found.", ru: "Тренировка не найдена." },
  "Zone not found.": { en: "Zone not found.", ru: "Зона не найдена." },
  "days in a row": { en: "days in a row", ru: "дней подряд" },

  "referral.copyCode": { en: "Copy code", ru: "Скопировать код" },
  "referral.copied": { en: "Copied!", ru: "Скопировано!" },
  "referral.enterCode": { en: "Enter a friend's code", ru: "Введите код друга" },
  "referral.redeem": { en: "Redeem", ru: "Применить" },

  "subscriptions.switchTo": { en: "Switch to", ru: "Перейти на" },
  "Basic": { en: "Basic", ru: "Базовый" },
  "Unlimited 24/7": { en: "Unlimited 24/7", ru: "Безлимит 24/7" },
  "Premium + PT": { en: "Premium + PT", ru: "Премиум + тренер" },

  "specials.bookOff": { en: "Book —", ru: "Забронировать —" },
  "specials.percentOff": { en: "% off", ru: "% скидка" },

  "trainer.sessionBooked": { en: "Session booked!", ru: "Сессия забронирована!" },
  "trainer.reviews": { en: "reviews", ru: "отзывов" },
  "trainer.booked": { en: "Booked", ru: "Забронировано" },
  "trainer.bookFor": { en: "Book ·", ru: "Забронировать ·" },
  "zone.confirmBooking": { en: "Confirm booking", ru: "Подтвердить бронь" },
  "Check In": { en: "Check In", ru: "Отметиться" },

  "checkin.instructions": {
    en: "Show this code to reception. No scanner at the front desk yet? Use the button below instead.",
    ru: "Покажите этот код на ресепшене. Если сканера пока нет, используйте кнопку ниже.",
  },
  "checkin.cta": { en: "I'm here — check in", ru: "Я здесь — отметиться" },
  "checkin.dayStreak": { en: "-day streak", ru: "-дневная серия" },

  "workout.reps": { en: "reps", ru: "повторений" },
  "workout.finishWorkout": { en: "Finish Workout", ru: "Завершить тренировку" },

  "otp.resendIn": { en: "Resend in", ru: "Повтор через" },
  "otp.enterCodeSentTo": { en: "Enter the code we sent to", ru: "Введите код, который мы отправили на" },

  "workouts.noneYet.all": { en: "No workouts yet.", ru: "Пока нет тренировок." },
  "workouts.noneYet.strength": { en: "No strength workouts yet.", ru: "Пока нет силовых тренировок." },
  "workouts.noneYet.cardio": { en: "No cardio workouts yet.", ru: "Пока нет кардио-тренировок." },
  "workouts.noneYet.flexibility": { en: "No flexibility workouts yet.", ru: "Пока нет тренировок на растяжку." },
};

export const dict: Record<string, { en: string; ru: string }> = {
  ...generatedDict,
  ...handWritten,
};

export function translate(language: Language, key: string): string {
  const entry = dict[key];
  if (!entry) return key;
  return entry[language] || entry.en || key;
}

interface I18nContextValue {
  language: Language;
  setLanguage: (language: Language) => void;
  t: (key: string) => string;
}

export const I18nContext = createContext<I18nContextValue | null>(null);

export function useI18n(): I18nContextValue {
  const ctx = useContext(I18nContext);
  if (!ctx) throw new Error("useI18n must be used within an I18nProvider");
  return ctx;
}
