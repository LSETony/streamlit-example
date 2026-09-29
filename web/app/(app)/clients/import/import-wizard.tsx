"use client";
import Link from "next/link";
import { useMemo, useState } from "react";
import { FileSpreadsheet, Download, Upload, CheckCircle2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Checkbox, NativeSelect } from "@/components/ui/input";
import { Alert } from "@/components/ui/misc";
import { Table, TBody, TD, TH, THead, TR } from "@/components/ui/table";
import { importChunk, type ImportReport } from "@/app/actions/clients";
import { downloadXlsx } from "@/lib/excel";
import { chunk, FIELDS, guessMapping, prepareRows, TEMPLATE_EXAMPLE, TEMPLATE_HEADERS, type CellValue, type FieldKey, type Mapping } from "@/lib/import";
import { date, phone } from "@/lib/format";

const MAX_ROWS = 5000;

export function ImportWizard({ planNames, readOnly }: { planNames: string[]; readOnly: boolean }) {
  const [fileName, setFileName] = useState<string | null>(null);
  const [data, setData] = useState<CellValue[][] | null>(null);
  const [mapping, setMapping] = useState<Mapping>({});
  const [consent, setConsent] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [progress, setProgress] = useState<{ done: number; total: number } | null>(null);
  const [report, setReport] = useState<(ImportReport & { ms: number }) | null>(null);

  const headers = useMemo(() => (data?.[0] ?? []).map((h, i) => String(h ?? `Колонка ${i + 1}`)), [data]);
  const prepared = useMemo(() => (data ? prepareRows(data, mapping) : null), [data, mapping]);
  const unknownPlans = useMemo(() => {
    if (!prepared) return [];
    const known = new Set(planNames.map((n) => n.toLowerCase()));
    return Array.from(new Set(prepared.rows.map((r) => r.plan_name).filter((n): n is string => !!n && !known.has(n.toLowerCase()))));
  }, [prepared, planNames]);

  async function onFile(file: File) {
    setError(null);
    setReport(null);
    setFileName(file.name);
    try {
      let rows: CellValue[][];
      if (/\.csv$/i.test(file.name)) {
        const Papa = (await import("papaparse")).default;
        const textContent = await file.text();
        rows = Papa.parse<string[]>(textContent, { skipEmptyLines: true }).data;
      } else {
        const { readSheet } = await import("read-excel-file/browser");
        rows = (await readSheet(file)) as CellValue[][];
      }
      if (rows.length < 2) throw new Error("В файле нет строк с данными");
      if (rows.length - 1 > MAX_ROWS) throw new Error(`В файле ${rows.length - 1} строк — за один раз можно загрузить до ${MAX_ROWS}. Разбейте файл на части.`);
      setData(rows);
      setMapping(guessMapping(rows[0].map((h) => String(h ?? ""))));
    } catch (e) {
      setData(null);
      setError(e instanceof Error ? e.message : "Не удалось прочитать файл. Сохраните его в формате .xlsx или .csv");
    }
  }

  async function run() {
    if (!prepared) return;
    setError(null);
    const started = performance.now();
    const parts = chunk(prepared.rows, 500);
    const total: ImportReport = { created: 0, updated: 0, memberships: 0, errors: [...prepared.issues], total: prepared.rows.length + prepared.issues.length };
    setProgress({ done: 0, total: prepared.rows.length });
    let done = 0;
    for (const part of parts) {
      const res = await importChunk(part, consent);
      if (!res.ok) {
        setError(res.error.message);
        setProgress(null);
        return;
      }
      total.created += res.data.created;
      total.updated += res.data.updated;
      total.memberships += res.data.memberships;
      total.errors.push(...res.data.errors);
      done += part.length;
      setProgress({ done, total: prepared.rows.length });
    }
    total.errors.sort((a, b) => a.row - b.row);
    setReport({ ...total, ms: performance.now() - started });
    setProgress(null);
  }

  const ready = mapping.phone !== undefined && (mapping.full_name !== undefined || mapping.last_name !== undefined || mapping.first_name !== undefined);

  if (report) {
    return (
      <div className="grid gap-6">
        <Alert variant={report.errors.length ? "warning" : "success"} className="flex items-start gap-3">
          <CheckCircle2 className="mt-0.5 size-5 shrink-0" />
          <div className="grid gap-1">
            <p className="font-semibold">Импорт завершён за {(report.ms / 1000).toFixed(1)} с</p>
            <p>Новых клиентов: {report.created} · обновлено: {report.updated} · абонементов: {report.memberships} · с ошибками: {report.errors.length}</p>
          </div>
        </Alert>
        {report.errors.length ? (
          <Card>
            <CardHeader className="flex-row items-center justify-between">
              <div><CardTitle>Строки с ошибками</CardTitle><CardDescription>Исправьте их в файле и загрузите файл ещё раз — остальные клиенты не задублируются</CardDescription></div>
              <Button variant="outline" onClick={() => downloadXlsx("ошибки-импорта.xlsx", ["Строка", "Ошибка"], report.errors.map((e) => [e.row, e.error]), [10, 60])}>
                <Download /> Отчёт
              </Button>
            </CardHeader>
            <Table>
              <THead><TR><TH className="w-24">Строка</TH><TH>Причина</TH></TR></THead>
              <TBody>{report.errors.slice(0, 200).map((e, i) => <TR key={i}><TD className="tabular">{e.row}</TD><TD>{e.error}</TD></TR>)}</TBody>
            </Table>
          </Card>
        ) : null}
        <div className="flex gap-2">
          <Button asChild><Link href="/clients">К списку клиентов</Link></Button>
          <Button variant="outline" onClick={() => { setReport(null); setData(null); setFileName(null); }}>Загрузить ещё файл</Button>
        </div>
      </div>
    );
  }

  return (
    <div className="grid gap-6">
      <Card>
        <CardHeader>
          <CardTitle>1. Файл</CardTitle>
          <CardDescription>Excel (.xlsx) или CSV, до 5 000 строк. Первая строка — заголовки колонок.</CardDescription>
        </CardHeader>
        <CardContent className="flex flex-wrap items-center gap-3">
          <label className="flex h-11 cursor-pointer items-center gap-2 rounded-full bg-tint px-5 text-[15px] font-semibold text-white hover:brightness-110 active:scale-[0.97]">
            <Upload className="size-4" /> {fileName ? "Выбрать другой файл" : "Выбрать файл"}
            <input type="file" accept=".xlsx,.csv" className="sr-only" onChange={(e) => e.target.files?.[0] && onFile(e.target.files[0])} disabled={readOnly} />
          </label>
          <Button variant="outline" onClick={() => downloadXlsx("шаблон-импорта-core.xlsx", TEMPLATE_HEADERS, [TEMPLATE_EXAMPLE], [26, 18, 22, 14, 6, 14, 16, 20, 14, 16, 18, 14])}>
            <FileSpreadsheet /> Скачать шаблон
          </Button>
          {fileName ? <span className="text-sm text-muted-foreground">{fileName} · {data ? data.length - 1 : 0} строк</span> : null}
        </CardContent>
      </Card>

      {error ? <Alert variant="danger">{error}</Alert> : null}

      {data && prepared ? (
        <>
          <Card>
            <CardHeader>
              <CardTitle>2. Сопоставление колонок</CardTitle>
              <CardDescription>Мы угадали колонки по заголовкам — проверьте. Обязательны ФИО (или фамилия и имя) и телефон.</CardDescription>
            </CardHeader>
            <CardContent className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              {FIELDS.map((f) => (
                <label key={f.key} className="grid gap-1 text-sm">
                  <span className="font-medium">{f.label}{f.key === "phone" || f.key === "full_name" ? " *" : ""}</span>
                  <NativeSelect
                    value={mapping[f.key] ?? ""}
                    onChange={(e) => setMapping((m) => ({ ...m, [f.key]: e.target.value === "" ? undefined : Number(e.target.value) }) as Mapping)}
                  >
                    <option value="">— не загружать —</option>
                    {headers.map((h, i) => <option key={i} value={i}>{h}</option>)}
                  </NativeSelect>
                </label>
              ))}
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>3. Предпросмотр</CardTitle>
              <CardDescription>
                Готово к загрузке: {prepared.rows.length}. С ошибками: {prepared.issues.length} — они не помешают остальным.
              </CardDescription>
            </CardHeader>
            <Table>
              <THead><TR><TH>Строка</TH><TH>ФИО</TH><TH>Телефон</TH><TH>Абонемент</TH><TH>Период</TH><TH>Визиты</TH></TR></THead>
              <TBody>
                {prepared.rows.slice(0, 8).map((r) => (
                  <TR key={r.row}>
                    <TD className="tabular text-muted-foreground">{r.row}</TD>
                    <TD className="font-medium">{r.full_name}</TD>
                    <TD className="tabular">{phone(r.phone)}</TD>
                    <TD>{r.plan_name ?? (r.ends_on ? "Абонемент (импорт)" : "—")}</TD>
                    <TD className="tabular">{r.ends_on ? `${r.starts_on ? date(r.starts_on) : "…"} – ${date(r.ends_on)}` : "—"}</TD>
                    <TD className="tabular">{r.visits_left ?? "—"}</TD>
                  </TR>
                ))}
              </TBody>
            </Table>
            {prepared.issues.length ? (
              <CardContent className="grid gap-1 border-t border-border pt-4 text-sm">
                {prepared.issues.slice(0, 5).map((i) => <p key={i.row} className="text-destructive">Строка {i.row}: {i.error}</p>)}
                {prepared.issues.length > 5 ? <p className="text-muted-foreground">…и ещё {prepared.issues.length - 5}</p> : null}
              </CardContent>
            ) : null}
          </Card>

          {unknownPlans.length ? (
            <Alert variant="warning">
              Тарифов «{unknownPlans.slice(0, 3).join("», «")}»{unknownPlans.length > 3 ? " и др." : ""} нет в зале — абонементы загрузятся с этими названиями,
              но без лимита заморозки. Чтобы связать их с тарифами, создайте тарифы с такими же названиями до импорта.
            </Alert>
          ) : null}

          <Card>
            <CardContent className="grid gap-4 pt-5">
              <Checkbox checked={consent} onChange={(e) => setConsent(e.target.checked)}
                label="Клиенты из файла дали залу согласие на обработку персональных данных (отметка сохранится в карточках)" />
              <div className="flex items-center gap-3">
                <Button size="lg" onClick={run} disabled={!ready || !!progress || prepared.rows.length === 0 || readOnly}>
                  {progress ? `Загружаем… ${progress.done} из ${progress.total}` : `Загрузить ${prepared.rows.length} клиентов`}
                </Button>
                {!ready ? <span className="text-sm text-muted-foreground">Укажите колонки ФИО и телефона</span> : null}
              </div>
              {progress ? (
                <div className="h-2 overflow-hidden rounded-full bg-muted">
                  <div className="h-full bg-foreground transition-all" style={{ width: `${(progress.done / Math.max(progress.total, 1)) * 100}%` }} />
                </div>
              ) : null}
            </CardContent>
          </Card>
        </>
      ) : null}
    </div>
  );
}

export type { FieldKey };
