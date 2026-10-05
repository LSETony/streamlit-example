// Регионы работы core.: Россия и ОАЭ. Регион выбирается при создании зала и задаёт валюту,
// телефонный код, часовые пояса, язык кабинета по умолчанию и доступные способы оплаты.

export type Region = "RU" | "AE";
export type Currency = "RUB" | "AED";

export interface RegionInfo {
  currency: Currency;
  /** знак валюты в подписях полей: «Цена, ₽» / «Price, AED» */
  symbol: string;
  timezone: string;
  locale: "ru" | "en";
  phoneCode: string;
  phonePlaceholder: string;
  /** онлайн-оплата по ссылке (ЮKassa работает только в России) */
  onlinePayments: boolean;
}

export const REGIONS: Record<Region, RegionInfo> = {
  RU: { currency: "RUB", symbol: "₽", timezone: "Europe/Moscow", locale: "ru", phoneCode: "+7", phonePlaceholder: "+7 916 123-45-67", onlinePayments: true },
  AE: { currency: "AED", symbol: "AED", timezone: "Asia/Dubai", locale: "en", phoneCode: "+971", phonePlaceholder: "+971 50 123 4567", onlinePayments: false },
};

export function isRegion(v: unknown): v is Region {
  return v === "RU" || v === "AE";
}

export function regionInfo(region: string | null | undefined): RegionInfo {
  return REGIONS[isRegion(region) ? region : "RU"];
}

/** Шаблоны тарифов для мастера настройки — цены в копейках/филсах своей валюты */
export const PLAN_TEMPLATE_PRICES: Record<Region, { single: number; month: number; pack8: number; quarter: number; year: number }> = {
  RU: { single: 60000, month: 350000, pack8: 280000, quarter: 900000, year: 2900000 },
  AE: { single: 7500, month: 45000, pack8: 40000, quarter: 120000, year: 400000 },
};
