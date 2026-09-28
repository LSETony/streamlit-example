"use client";
// Выгрузка в Excel (FR-2.5, FR-6.4). Библиотека подгружается только при нажатии «Выгрузить».
export type Cell = string | number | Date | null | undefined;

export async function downloadXlsx(fileName: string, headers: string[], rows: Cell[][], widths?: number[]) {
  const { default: writeExcelFile } = await import("write-excel-file/browser");
  const data = [
    headers.map((h) => ({ value: h, fontWeight: "bold" as const })),
    ...rows.map((r) => r.map((v) => (v === null || v === undefined ? null : v instanceof Date ? { value: v, format: "dd.mm.yyyy" } : { value: v }))),
  ];
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  await writeExcelFile(data as any, { columns: (widths ?? headers.map(() => 18)).map((width) => ({ width })) }).toFile(fileName);
}
