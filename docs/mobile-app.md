# Подключение iOS-приложения core. к API

Приложение (SwiftUI + `supabase-swift`) ходит в тот же бэкенд, что и кабинет. Полная спецификация — `docs/openapi.yaml`.

## 1. Клиент Supabase

```swift
let supabase = SupabaseClient(
  supabaseURL: URL(string: "https://api.core.example.ru")!,
  supabaseKey: "<ANON_KEY>"            // публичный ключ; service key в приложение не попадает никогда
)
```

## 2. Вход по телефону и привязка к залу

```swift
try await supabase.auth.signInWithOTP(phone: "+79160000001")
try await supabase.auth.verifyOTP(phone: "+79160000001", token: code, type: .sms)

struct Linked: Decodable { let phone: String; let clients: [LinkedClient] }
struct LinkedClient: Decodable { let client_id: UUID; let gym_id: UUID; let gym_name: String }
let linked: Linked = try await supabase.functions.invoke("link")
```

Если `clients` пуст — показать каталог `public_gyms`, затем `rpc("join_gym", ["p_gym": id, "p_full_name": name])`.

## 3. Устройство и динамический QR

```swift
struct Device: Decodable { let device_id: UUID; let qr_secret: String }
let device: Device = try await supabase.functions.invoke(
  "devices", options: .init(body: ["platform": "ios", "push_token": apnsTokenHex]))
Keychain.save(device.qr_secret, for: "qr_secret")     // секрет не покидает Keychain
Keychain.save(device.device_id.uuidString, for: "device_id")
```

QR строится на телефоне, без интернета, и меняется каждые 30 секунд:

```swift
import CryptoKit

func passPayload(deviceId: String, secretHex: String, now: Date = .now) -> String {
  let t = Int(now.timeIntervalSince1970) / 30
  let msg = "CORE1:\(deviceId.lowercased()):\(t)"
  let key = SymmetricKey(data: Data(hexString: secretHex)!)
  let mac = HMAC<SHA256>.authenticationCode(for: Data(msg.utf8), using: key)
  let sig = Data(mac).prefix(16).map { String(format: "%02x", $0) }.joined()
  return "\(msg):\(sig)"
}
```

Эталонная реализация и тест совместимости с сервером — `web/lib/qr.ts`, `web/lib/qr.test.ts`, SQL-проверка — функция
`private.verify_qr` (`supabase/migrations/20260928000003_business.sql`). Скриншот старше 60 секунд не проходит; при
регистрации нового телефона старый секрет отзывается. Этот же формат подойдёт для Apple Wallet и турникетов (релиз 4).

## 4. Абонементы, расписание, запись

```swift
let memberships: [Membership] = try await supabase.from("memberships")
  .select("id,plan_name,kind,status,starts_on,ends_on,visits_left,freeze_days_max,freeze_days_used")
  .order("ends_on", ascending: false).execute().value

let result: BookingResult = try await supabase.functions.invoke(
  "bookings", options: .init(body: ["schedule_item_id": item.id.uuidString]))
```

Ошибки приходят как `{code, message}`: показывайте `message`, ветвитесь по `code`
(`CLASS_FULL`, `NO_ACTIVE_MEMBERSHIP`, `CANCEL_TOO_LATE`, `MEMBERSHIP_FROZEN`, …).

## 5. Оплата

1. `POST /functions/v1/payments {plan_id}` → `confirmation_token` (или передайте `payment_token` из мобильного SDK ЮKassa).
2. Открыть виджет/SDK ЮKassa с токеном.
3. После оплаты опросить `GET /functions/v1/payments/{payment_id}` или слушать Realtime — абонемент станет `active`
   по уведомлению ЮKassa.

## 6. Реальное время

```swift
let channel = supabase.channel("me")
let visits = channel.postgresChange(InsertAction.self, schema: "public", table: "visits")
await channel.subscribe()
for await _ in visits { showToast("Вы в зале 💪") }
```

RLS действует и для Realtime: клиент получает только свои визиты и записи.

## 7. Push

APNs-токен передаётся в `/functions/v1/devices`. Сервер отправляет: подтверждение и отмену записи, напоминание
за 2 часа до занятия, напоминания об окончании абонемента за 7 и 1 день (только с согласием на рассылки),
сообщения зала из списка «в зоне риска». Ночью (22:00–9:00 по времени зала) уведомления не уходят.
Поле `kind` в payload: `booking_confirmed`, `booking_cancelled`, `class_cancelled`, `class_reminder`,
`membership_expiring`, `risk_push`.

## 8. Удаление аккаунта

`DELETE /functions/v1/me` — обязательная кнопка в настройках приложения (152-ФЗ и требования App Store).
