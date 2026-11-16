// Инструменты ИИ-агентов: общий каталог для настроек в кабинете, встроенного агента (Claude),
// REST API и MCP-сервера для внешних агентов. Выполняются в БД функцией private.ai_run_tool
// (кроме send_whatsapp — его отправляет сервер платформы).

export type ToolKind = "read" | "write";
export type ToolMode = "off" | "approve" | "auto";

export interface JsonSchema {
  type: "object";
  properties: Record<string, unknown>;
  required?: string[];
  additionalProperties: false;
}

export interface AgentTool {
  name: string;
  kind: ToolKind;
  /** подпись в кабинете */
  label: string;
  /** описание для модели (на английском) */
  description: string;
  inputSchema: JsonSchema;
}

const uuid = { type: "string", format: "uuid" };
const reasonProp = {
  type: "string",
  enum: ["gone", "expiring", "declining", "not_renewed", "other"],
  description: "Why the gym is reaching out: the risk reason from risk_clients, or other",
};

export const AGENT_TOOLS: AgentTool[] = [
  {
    name: "find_clients", kind: "read", label: "Поиск клиентов",
    description: "Search the gym's clients by name, phone or email. An empty query returns the most recently active clients. Returns client_id, contact details and current membership state.",
    inputSchema: { type: "object", additionalProperties: false, properties: {
      query: { type: "string", description: "Part of the name, phone or email" },
      limit: { type: "integer", minimum: 1, maximum: 100 },
    } },
  },
  {
    name: "risk_clients", kind: "read", label: "Клиенты в зоне риска",
    description: "List clients the gym may lose, most urgent first: gone (stopped visiting), expiring (membership ends soon, no renewal), declining (visits less often), not_renewed (membership ended recently). Clients contacted in the last 14 days are excluded unless include_contacted is true.",
    inputSchema: { type: "object", additionalProperties: false, properties: {
      reason: { type: "string", enum: ["gone", "expiring", "declining", "not_renewed"] },
      include_contacted: { type: "boolean" },
      limit: { type: "integer", minimum: 1, maximum: 100 },
    } },
  },
  {
    name: "client_details", kind: "read", label: "Карточка клиента",
    description: "Full card of one client: contacts, note, marketing consent, memberships (with membership_id and freeze days left), recent visits, upcoming bookings (with booking_id) and recent contacts by the gym.",
    inputSchema: { type: "object", additionalProperties: false, required: ["client_id"], properties: { client_id: uuid } },
  },
  {
    name: "schedule", kind: "read", label: "Расписание",
    description: "Upcoming group classes with class_id, time (ISO, UTC), trainer and free spots.",
    inputSchema: { type: "object", additionalProperties: false, properties: { days: { type: "integer", minimum: 1, maximum: 31 } } },
  },
  {
    name: "gym_stats", kind: "read", label: "Показатели зала",
    description: "Gym KPIs for the current month compared with the previous period: revenue, sales, visits, active clients, churn.",
    inputSchema: { type: "object", additionalProperties: false, properties: {} },
  },
  {
    name: "log_contact", kind: "write", label: "Отметить контакт с клиентом",
    description: "Record that the gym contacted the client (by phone, Telegram, WhatsApp or other). Use after a real conversation; it removes the client from the risk list for 14 days.",
    inputSchema: { type: "object", additionalProperties: false, required: ["client_id", "reason", "channel"], properties: {
      client_id: uuid, reason: reasonProp,
      channel: { type: "string", enum: ["call", "telegram", "whatsapp", "other"] },
      note: { type: "string", maxLength: 500 },
    } },
  },
  {
    name: "send_push", kind: "write", label: "Push-уведомление в приложение",
    description: "Send a push notification to the client's phone through the gym app and record the contact. Works only for clients who use the app (in_app) and gave marketing consent. Keep the text short and friendly, in the client's language.",
    inputSchema: { type: "object", additionalProperties: false, required: ["client_id", "reason", "text"], properties: {
      client_id: uuid, reason: reasonProp, text: { type: "string", maxLength: 300 },
    } },
  },
  {
    name: "send_whatsapp", kind: "write", label: "Сообщение в WhatsApp",
    description: "Send the gym's approved WhatsApp Business template message to the client and record the contact. Only for clients with marketing consent; the text is the fixed template, it cannot be changed.",
    inputSchema: { type: "object", additionalProperties: false, required: ["client_id", "reason"], properties: { client_id: uuid, reason: reasonProp } },
  },
  {
    name: "book_class", kind: "write", label: "Записать на занятие",
    description: "Book the client into a group class (class_id from schedule). Fails if the class is full or has started.",
    inputSchema: { type: "object", additionalProperties: false, required: ["client_id", "class_id"], properties: { client_id: uuid, class_id: uuid } },
  },
  {
    name: "cancel_booking", kind: "write", label: "Отменить запись",
    description: "Cancel a client's class booking (booking_id from client_details).",
    inputSchema: { type: "object", additionalProperties: false, required: ["booking_id"], properties: { booking_id: uuid } },
  },
  {
    name: "freeze_membership", kind: "write", label: "Заморозить абонемент",
    description: "Freeze a membership for a period (dates YYYY-MM-DD, inclusive). The membership end date moves by the frozen days; the freeze limit of the plan applies.",
    inputSchema: { type: "object", additionalProperties: false, required: ["membership_id", "from", "to"], properties: {
      membership_id: uuid,
      from: { type: "string", format: "date" }, to: { type: "string", format: "date" },
      reason: { type: "string", maxLength: 200 },
    } },
  },
  {
    name: "add_client_note", kind: "write", label: "Заметка в карточке клиента",
    description: "Append a short note to the client's card, visible to the gym staff (preferences, agreements, follow-ups).",
    inputSchema: { type: "object", additionalProperties: false, required: ["client_id", "note"], properties: {
      client_id: uuid, note: { type: "string", maxLength: 500 },
    } },
  },
];

export const TOOL_BY_NAME = new Map(AGENT_TOOLS.map((t) => [t.name, t]));

export function toolMode(tools: Record<string, string> | null | undefined, name: string): ToolMode {
  const v = tools?.[name];
  return v === "auto" || v === "approve" ? v : "off";
}

/** Шаблоны агентов: роль, инструкции и права по умолчанию */
export interface AgentTemplate {
  id: string;
  label: string;
  description: string;
  instructions: string;
  task: string;
  tools: Record<string, ToolMode>;
}

export const AGENT_TEMPLATES: AgentTemplate[] = [
  {
    id: "retention", label: "Удержание клиентов",
    description: "Каждый день разбирает список «В зоне риска», пишет клиентам и записывает, с кем связались",
    instructions: "Ты помогаешь залу удерживать клиентов. Разбирай клиентов в зоне риска, начиная с самых срочных. Сначала смотри карточку клиента, потом пиши тепло и лично, без давления и без скидок, если зал их не разрешил. Канал: push, если клиент пользуется приложением, иначе WhatsApp. Не пиши клиентам без согласия на рассылки и не связывайся с одним клиентом чаще раза в 14 дней.",
    task: "Разбери клиентов в зоне риска и свяжись с самыми срочными (до 10 человек). В конце коротко перечисли, с кем и почему.",
    tools: { risk_clients: "auto", client_details: "auto", find_clients: "auto", send_push: "approve", send_whatsapp: "approve", log_contact: "approve" },
  },
  {
    id: "reception", label: "Администратор записи",
    description: "Записывает на занятия, отменяет записи, замораживает абонементы по просьбе клиента",
    instructions: "Ты помогаешь ресепшену. Сначала найди клиента, проверь карточку и расписание, потом сделай ровно то, о чём просят. Если что-то неоднозначно (два клиента с одним именем, нет мест), остановись и объясни, а не угадывай.",
    task: "",
    tools: { find_clients: "auto", client_details: "auto", schedule: "auto", book_class: "approve", cancel_booking: "approve", freeze_membership: "approve", add_client_note: "auto" },
  },
  {
    id: "analyst", label: "Аналитик",
    description: "Только читает данные: показатели, отток, загрузку расписания — и объясняет, что делать",
    instructions: "Ты аналитик зала. Опирайся только на данные из инструментов. Называй конкретные цифры, сравнивай с прошлым периодом и заканчивай 2–3 практическими рекомендациями.",
    task: "Подготовь короткую сводку по залу за текущий месяц: выручка, визиты, отток, клиенты в зоне риска, и 3 рекомендации.",
    tools: { gym_stats: "auto", risk_clients: "auto", schedule: "auto", find_clients: "auto" },
  },
  {
    id: "custom", label: "Свой агент",
    description: "Задайте роль, инструкции и права сами",
    instructions: "",
    task: "",
    tools: { find_clients: "auto", client_details: "auto" },
  },
];
