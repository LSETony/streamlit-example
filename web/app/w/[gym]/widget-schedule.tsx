"use client";
import { ClassList, type ClassItem } from "@/components/class-list";

/** Запись из виджета: открывает приложение клиента в новой вкладке — внутри iframe вход и cookies сайта не работают */
export function WidgetSchedule({ items, tz, gymId }: { items: ClassItem[]; tz: string; gymId: string }) {
  return (
    <ClassList items={items} tz={tz}
      onAction={() => window.open(`/m?gym=${gymId}`, "_blank", "noopener")} />
  );
}
