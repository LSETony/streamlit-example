"use client";
import { useState } from "react";
import { Download } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { createClient } from "@/lib/supabase/client";
import { downloadXlsx } from "@/lib/excel";
import type { ClientRow } from "@/lib/types";

const STATE: Record<string, string> = { active: "Действует", frozen: "Заморожен", future: "Начнётся", expired: "Закончился", none: "Нет" };

/** FR-2.5 Экспорт списка клиентов в Excel (с текущими фильтрами) */
export function ExportClientsButton({ gymId, filters }: { gymId: string; filters: { q: string; state: string; tag: string; risk: boolean } }) {
  const [busy, setBusy] = useState(false);
  async function run() {
    setBusy(true);
    try {
      const supabase = createClient();
      const all: ClientRow[] = [];
      let riskIds: string[] | null = null;
      if (filters.risk) {
        const { data } = await supabase.from("v_client_risk").select("client_id").eq("gym_id", gymId);
        riskIds = (data ?? []).map((r) => r.client_id);
      }
      for (let from = 0; ; from += 1000) {
        let q = supabase.from("v_clients").select("*").eq("gym_id", gymId);
        if (filters.q) q = q.ilike("full_name", `%${filters.q}%`);
        if (filters.state) q = q.eq("membership_state", filters.state);
        if (filters.tag) q = q.contains("tags", [filters.tag]);
        if (riskIds) q = q.in("id", riskIds.length ? riskIds : ["00000000-0000-0000-0000-000000000000"]);
        const { data, error } = await q.order("full_name").range(from, from + 999);
        if (error) throw error;
        all.push(...((data ?? []) as ClientRow[]));
        if (!data || data.length < 1000) break;
      }
      await downloadXlsx(
        `клиенты-${new Date().toISOString().slice(0, 10)}.xlsx`,
        ["ФИО", "Телефон", "Email", "Абонемент", "Статус", "Действует до", "Осталось визитов", "Последний визит", "Источник", "Теги", "В приложении"],
        all.map((c) => [
          c.full_name, c.phone, c.email, c.plan_name, STATE[c.membership_state], c.membership_ends_on,
          c.visits_left, c.last_visit_at ? new Date(c.last_visit_at) : null, c.source, c.tags.join(", "), c.in_app ? "да" : "нет",
        ]),
        [28, 16, 24, 20, 14, 14, 10, 16, 16, 20, 12],
      );
    } catch {
      toast.error("Не удалось выгрузить список");
    } finally {
      setBusy(false);
    }
  }
  return <Button variant="outline" onClick={run} disabled={busy}><Download /> {busy ? "Готовим…" : "Excel"}</Button>;
}
