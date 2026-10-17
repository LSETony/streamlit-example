import "server-only";

// Отправка шаблонного сообщения через WhatsApp Business Cloud API (Meta).
// Сообщения первыми можно отправлять только по шаблону, заранее одобренному в WhatsApp Manager.
// Параметры шаблона: {{1}} — имя клиента, {{2}} — название зала.
const API_BASE = process.env.WHATSAPP_API_BASE ?? "https://graph.facebook.com/v21.0";

export interface WhatsappConfig {
  phoneId: string;
  token: string;
  template: string;
  lang: string;
}

export async function sendWhatsappTemplate(cfg: WhatsappConfig, to: string, params: string[]): Promise<{ ok: true } | { ok: false; error: string }> {
  const digits = to.replace(/\D/g, "");
  if (!digits) return { ok: false, error: "no phone" };
  try {
    const res = await fetch(`${API_BASE}/${encodeURIComponent(cfg.phoneId)}/messages`, {
      method: "POST",
      headers: { Authorization: `Bearer ${cfg.token}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        messaging_product: "whatsapp",
        to: digits,
        type: "template",
        template: {
          name: cfg.template,
          language: { code: cfg.lang },
          components: [{ type: "body", parameters: params.map((text) => ({ type: "text", text })) }],
        },
      }),
      signal: AbortSignal.timeout(15000),
    });
    if (res.ok) return { ok: true };
    const body = (await res.json().catch(() => null)) as { error?: { message?: string } } | null;
    return { ok: false, error: body?.error?.message ?? `HTTP ${res.status}` };
  } catch (e) {
    return { ok: false, error: e instanceof Error ? e.message : "network" };
  }
}
