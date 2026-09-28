// Сквозной сценарий MVP на живом стенде (deploy/docker-compose.yml + supabase/seed.sql + next start):
// ресепшен → QR из «приложения» → красный экран → продажа → зелёный экран; новый клиент; импорт Excel;
// запись на занятие; права ролей; онлайн-оплата (ЮKassa или её имитация) → webhook → абонемент активен.
//
// Запуск: APP_URL=http://localhost:3000 SUPABASE_URL=http://localhost:54321 ANON_KEY=... node e2e/smoke.mjs
// Для шага онлайн-оплаты нужен YK_MOCK_URL (имитация ЮKassa, см. docs/testing.md) — иначе шаг пропускается.
import { chromium } from "playwright";
import { createHmac } from "node:crypto";
import { writeFileSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const APP = process.env.APP_URL ?? "http://localhost:3000";
const API = process.env.SUPABASE_URL ?? "http://localhost:54321";
const ANON = process.env.ANON_KEY;
const YK_MOCK = process.env.YK_MOCK_URL;
const SHOTS = process.env.SHOTS_DIR;
const SERVICE = process.env.SERVICE_ROLE_KEY; // для сброса состояния демо-клиента между прогонами
const RUN = String(Date.now()).slice(-5);
if (!ANON) throw new Error("ANON_KEY не задан");

let failures = 0;
const step = async (name, fn) => {
  const t = Date.now();
  try {
    await fn();
    console.log(`✓ ${name} (${Date.now() - t} мс)`);
  } catch (e) {
    failures++;
    if (SHOTS) for (const pg of openPages) await pg.screenshot({ path: join(SHOTS, `fail-${failures}-${openPages.indexOf(pg)}.png`) }).catch(() => {});
    console.log(`✗ ${name}: ${e.message.split("\n")[0]}`);
  }
};
const assert = (cond, msg) => { if (!cond) throw new Error(msg); };

async function api(path, { method = "GET", token, body } = {}) {
  const res = await fetch(API + path, {
    method,
    headers: { apikey: ANON, "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  return { status: res.status, data: text ? JSON.parse(text) : null };
}

function qrPayload(deviceId, secretHex, now = Date.now()) {
  const t = Math.floor(now / 1000 / 30);
  const msg = `CORE1:${deviceId}:${t}`;
  return `${msg}:${createHmac("sha256", Buffer.from(secretHex, "hex")).update(msg).digest("hex").slice(0, 32)}`;
}

const browser = await chromium.launch();
const openPages = [];
async function login(email) {
  const ctx = await browser.newContext({ viewport: { width: 1366, height: 900 }, locale: "ru-RU", permissions: ["clipboard-read", "clipboard-write"] });
  const page = await ctx.newPage();
  openPages.push(page);
  page.on("pageerror", (e) => { failures++; console.log(`  ! ошибка на странице: ${e.message}`); });
  await page.goto(`${APP}/login`);
  await page.fill("input[name=email]", email);
  await page.fill("input[name=password]", "demo12345");
  await page.click("button[type=submit]");
  await page.waitForURL((u) => !u.pathname.startsWith("/login"), { timeout: 20000 });
  return page;
}
const shot = async (page, name) => SHOTS && page.screenshot({ path: join(SHOTS, `${name}.png`) });

// --- «Приложение»: вход по телефону, привязка к залу, регистрация устройства -----------------
let client = {};
await step("приложение: вход по SMS-коду, привязка к залу по телефону, выдача секрета QR", async () => {
  const otp = await api("/auth/v1/otp", { method: "POST", body: { phone: "+79160000001" } });
  assert(otp.status === 200, `otp ${otp.status}`);
  const v = await api("/auth/v1/verify", { method: "POST", body: { phone: "+79160000001", token: "123456", type: "sms" } });
  assert(v.data?.access_token, "нет токена");
  client.token = v.data.access_token;
  const link = await api("/functions/v1/link", { method: "POST", token: client.token });
  assert(link.data?.clients?.length === 1, JSON.stringify(link.data));
  client.id = link.data.clients[0].client_id;
  const dev = await api("/functions/v1/devices", { method: "POST", token: client.token, body: { platform: "ios", push_token: "e2e" } });
  assert(dev.data?.qr_secret, JSON.stringify(dev.data));
  client.device = dev.data;
  if (SERVICE) {
    // сценарий начинается с клиента без действующего абонемента и без визитов сегодня
    const h = { apikey: SERVICE, Authorization: `Bearer ${SERVICE}`, "Content-Type": "application/json" };
    await fetch(`${API}/rest/v1/memberships?client_id=eq.${client.id}&status=in.(active,frozen,pending)`, { method: "PATCH", headers: h, body: JSON.stringify({ status: "cancelled" }) });
    await fetch(`${API}/rest/v1/visits?client_id=eq.${client.id}&checked_in_at=gt.${new Date(Date.now() - 86400000).toISOString()}`, { method: "DELETE", headers: h });
  }
});

// --- Права ролей -----------------------------------------------------------------------------
const reception = await login("reception@demo.core");
await step("ресепшен: нет доступа к дашборду и оплатам", async () => {
  for (const path of ["/dashboard", "/payments", "/settings"]) {
    await reception.goto(`${APP}${path}`);
    await reception.waitForURL("**/reception", { timeout: 8000 });
  }
});

// --- Ресепшен: QR → красный → продажа → зелёный ---------------------------------------------
await step("ресепшен: QR клиента без абонемента → красный экран с кнопкой «Продать»", async () => {
  await reception.goto(`${APP}/reception`);
  await reception.waitForLoadState("networkidle");
  const t0 = Date.now();
  await reception.keyboard.type(qrPayload(client.device.device_id, client.device.qr_secret), { delay: 2 });
  await reception.keyboard.press("Enter");
  await reception.getByRole("alertdialog").waitFor({ timeout: 5000 });
  const ms = Date.now() - t0;
  await shot(reception, "e2e-red");
  const text = await reception.getByRole("alertdialog").innerText();
  assert(text.includes("Нет действующего абонемента"), text);
  assert(text.includes("Петров Иван"), "нет имени клиента");
  console.log(`  скан → результат: ${ms} мс (с набором ~110 символов)`);
  await reception.getByRole("button", { name: "Продать абонемент" }).click();
  await reception.getByRole("radio", { name: /Месяц/ }).click();
  await reception.getByRole("button", { name: "Карта" }).click();
  await reception.getByRole("button", { name: /Принять/ }).click();
  await reception.getByText(/Продано: «Месяц»/).waitFor({ timeout: 8000 });
});

await step("ресепшен: повторный скан QR → зелёный экран, визит отмечен", async () => {
  await reception.waitForTimeout(4200); // тот же код в течение 4 с сканер игнорирует как дубль
  await reception.keyboard.type(qrPayload(client.device.device_id, client.device.qr_secret), { delay: 2 });
  await reception.keyboard.press("Enter");
  const dlg = reception.getByRole("alertdialog", { name: "Проход разрешён" });
  await dlg.waitFor({ timeout: 5000 });
  await shot(reception, "e2e-green");
  assert((await dlg.innerText()).includes("Проходите"), await dlg.innerText());
  await reception.keyboard.press("Escape");
});

await step("ресепшен: скриншот QR старше минуты не проходит", async () => {
  await reception.waitForTimeout(4200);
  await reception.keyboard.type(qrPayload(client.device.device_id, client.device.qr_secret, Date.now() - 95_000), { delay: 2 });
  await reception.keyboard.press("Enter");
  const dlg = reception.getByRole("alertdialog", { name: "Проход запрещён" });
  await dlg.waitFor({ timeout: 5000 });
  assert((await dlg.innerText()).includes("QR устарел"), await dlg.innerText());
  await reception.keyboard.press("Escape");
});

await step("ресепшен: ручная отметка через поиск", async () => {
  await reception.getByPlaceholder("Начните вводить фамилию или телефон").fill("Петров Ив");
  await reception.getByRole("option", { name: /Петров Иван/ }).first().click();
  const dlg = reception.getByRole("alertdialog");
  await dlg.waitFor({ timeout: 5000 });
  assert((await dlg.innerText()).includes("Визит уже отмечен"), "повтор за 10 минут должен не списывать визит");
  await reception.keyboard.press("Escape");
});

// --- Новый клиент за 30 секунд ---------------------------------------------------------------
await step("ресепшен: новый клиент → карточка → продажа наличными", async () => {
  const t0 = Date.now();
  await reception.goto(`${APP}/clients`);
  await reception.getByRole("button", { name: "Новый клиент" }).click();
  await reception.fill("input[name=full_name]", `Тестова Анна ${RUN}`);
  const phone = "+7 999 " + String(Date.now()).slice(-7);
  await reception.fill("input[name=phone]", phone);
  await reception.check("input[name=consent_pd]");
  await reception.getByRole("button", { name: "Добавить и продать абонемент" }).click();
  await reception.waitForURL(/\/clients\/[0-9a-f-]+/, { timeout: 10000 });
  await reception.getByRole("radio", { name: /8 занятий/ }).click();
  await reception.getByRole("button", { name: "Наличные" }).click();
  await reception.getByRole("button", { name: /Принять/ }).click();
  await reception.getByText(/Продано: «8 занятий»/).waitFor({ timeout: 8000 });
  console.log(`  создание клиента с продажей: ${((Date.now() - t0) / 1000).toFixed(1)} с`);
});

// --- Владелец: ЮKassa, импорт, дашборд -------------------------------------------------------
const owner = await login("owner@demo.core");
await step("владелец: подключение ЮKassa (ключ шифруется на сервере)", async () => {
  await owner.goto(`${APP}/settings`);
  await owner.fill("input[name=shop_id]", "123456");
  await owner.fill("input[name=secret_key]", "test_secret_key");
  await owner.locator("form", { has: owner.locator("input[name=shop_id]") }).getByRole("button", { name: "Сохранить" }).click();
  await owner.getByText("Подключено · магазин 123456").waitFor({ timeout: 8000 });
});

await step("владелец: импорт Excel — ошибки по строкам, остальные загружены", async () => {
  const dir = mkdtempSync(join(tmpdir(), "core-e2e-"));
  const csv = join(dir, "clients.csv");
  const seed = String(Date.now()).slice(-4);
  writeFileSync(csv, [
    "ФИО;Телефон;Абонемент;Действует до;Осталось визитов",
    `Импортов Первый;8 926 5${seed}01;Месяц;30.12.2026;`,
    `Импортов Второй;12345;;;`,
    `Импортова Третья;+7 926 5${seed}03;8 занятий;31.02.2026;4`,
    `Импортов Четвёртый;926 5${seed}04;;;`,
  ].join("\n"));
  await owner.goto(`${APP}/clients/import`);
  await owner.setInputFiles("input[type=file]", csv);
  await owner.getByText("Готово к загрузке: 2").waitFor({ timeout: 8000 });
  await owner.check("text=Клиенты из файла дали залу согласие");
  await owner.getByRole("button", { name: /Загрузить 2 клиентов/ }).click();
  await owner.getByText(/Импорт завершён/).waitFor({ timeout: 20000 });
  await shot(owner, "e2e-import");
  const text = await owner.locator("body").innerText();
  assert(text.includes("Новых клиентов: 2"), text.slice(0, 400));
  assert(text.includes("с ошибками: 2"), "ожидали 2 строки с ошибками");
});

// --- Расписание: владелец создаёт занятие, ресепшен записывает клиента ------------------------
await step("владелец: создание занятия; ресепшен: запись клиента, лишний сверх вместимости не проходит", async () => {
  const tomorrow = new Date(Date.now() + 86400000).toISOString().slice(0, 10);
  await owner.goto(`${APP}/schedule?view=day&date=${tomorrow}`);
  await owner.getByRole("button", { name: "Занятие" }).click();
  await owner.fill("input[name=title]", `E2E ${RUN}`);
  await owner.fill("input[name=time]", "13:00");
  await owner.fill("input[name=capacity]", "1");
  await owner.getByRole("button", { name: "Создать" }).click();
  await owner.getByText("Занятие создано").waitFor({ timeout: 8000 });

  await reception.goto(`${APP}/schedule?view=day&date=${tomorrow}`);
  await reception.locator(`button[title*='E2E ${RUN}']`).click();
  const search = reception.getByPlaceholder("Записать клиента: ФИО или телефон");
  await search.fill(`Тестова Анна ${RUN}`);
  await reception.getByRole("option", { name: new RegExp(`Тестова Анна ${RUN}`) }).first().click();
  await reception.getByText(/записан\(а\)/).first().waitFor({ timeout: 8000 });
  await search.fill("Петров Ив");
  await reception.getByRole("option", { name: /Петров Иван/ }).first().click();
  await reception.getByText("Свободных мест нет").waitFor({ timeout: 8000 });
});

await step("владелец: дашборд открывается за 2 секунды", async () => {
  const t0 = Date.now();
  await owner.goto(`${APP}/dashboard`);
  await owner.getByText("Выручка", { exact: true }).waitFor();
  const ms = Date.now() - t0;
  console.log(`  дашборд: ${ms} мс`);
  assert(ms < 2000, `${ms} мс`);
});

// --- Онлайн-оплата: платёж → оплата → webhook → абонемент активен ------------------------------
if (YK_MOCK) {
  await step("приложение: онлайн-оплата → webhook ЮKassa → абонемент активирован, повтор webhook без эффекта", async () => {
    const pay = await api("/functions/v1/payments", { method: "POST", token: client.token, body: { plan_id: "d3000000-0000-0000-0000-000000000004" } });
    assert(pay.status === 201 && pay.data.confirmation_token, JSON.stringify(pay.data));
    await fetch(`${YK_MOCK}/_pay/${pay.data.provider_payment_id}`, { method: "POST" });
    const hook = { type: "notification", event: "payment.succeeded", object: { id: pay.data.provider_payment_id, status: "succeeded" } };
    const w1 = await api("/functions/v1/payments/webhook", { method: "POST", body: hook });
    assert(w1.data?.result === "activated", JSON.stringify(w1.data));
    const w2 = await api("/functions/v1/payments/webhook", { method: "POST", body: hook });
    assert(w2.data?.result === "already_processed", JSON.stringify(w2.data));
    const st = await api(`/functions/v1/payments/${pay.data.payment_id}`, { token: client.token });
    assert(st.data?.status === "succeeded", JSON.stringify(st.data));
    const ms = await api(`/rest/v1/memberships?id=eq.${pay.data.membership_id}&select=status,plan_name`, { token: client.token });
    assert(ms.data?.[0]?.status === "active", JSON.stringify(ms.data));
    client.onlinePayment = pay.data.payment_id;
  });

  await step("администратор: возврат онлайн-оплаты из кабинета через ЮKassa", async () => {
    const admin = await login("admin@demo.core");
    await admin.goto(`${APP}/clients/${client.id}`);
    await admin.getByRole("tab", { name: "Оплаты" }).click();
    await admin.getByRole("row", { name: /Онлайн/ }).first().getByRole("button", { name: "Возврат" }).click();
    await admin.getByRole("button", { name: /Вернуть/ }).click();
    await admin.locator("[data-sonner-toast]").getByText(/Возвращено|отправлен в ЮKassa/).waitFor({ timeout: 10000 });
  });
} else {
  console.log("– онлайн-оплата пропущена (YK_MOCK_URL не задан)");
}

// --- Изоляция: клиент видит только своё --------------------------------------------------------
await step("приложение: клиент видит только свои данные", async () => {
  const all = await api("/rest/v1/clients?select=id", { token: client.token });
  assert(all.data.length === 1, `видит ${all.data.length} клиентов`);
  const pays = await api("/rest/v1/payments?select=client_id", { token: client.token });
  assert(pays.data.every((p) => p.client_id === client.id), "видит чужие оплаты");
});

await browser.close();
console.log(failures ? `\nПровалено шагов: ${failures}` : "\nВсе шаги пройдены");
process.exit(failures ? 1 : 0);
