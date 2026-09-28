// Уведомление команды в Telegram при сбоях (раздел 7, «Наблюдаемость»)
export async function alertTeam(text: string): Promise<void> {
  const token = Deno.env.get("TELEGRAM_ALERT_BOT_TOKEN");
  const chat = Deno.env.get("TELEGRAM_ALERT_CHAT_ID");
  console.error("ALERT:", text);
  if (!token || !chat) return;
  try {
    await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ chat_id: chat, text: `core. ⚠️ ${text}`.slice(0, 4000) }),
    });
  } catch (e) {
    console.error("telegram alert failed", e);
  }
}
