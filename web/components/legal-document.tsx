import type { LegalDoc } from "@/lib/legal/documents";
import { COMPANY } from "@/lib/legal/company";

export function LegalDocument({ doc, updatedLabel }: { doc: LegalDoc; updatedLabel: string }) {
  return (
    <article className="grid gap-8">
      <header className="grid gap-3">
        <h1 className="text-[34px] font-bold leading-[41px] tracking-[-0.02em]">{doc.title}</h1>
        <p className="text-sm text-muted-foreground">{updatedLabel}: {COMPANY.updated}</p>
        <p className="text-[17px] leading-relaxed text-muted-foreground">{doc.intro}</p>
      </header>
      {doc.sections.map((s) => (
        <section key={s.h} className="grid gap-3">
          <h2 className="text-[20px] font-semibold tracking-tight">{s.h}</h2>
          {s.p.map((p) => <p key={p} className="text-[16px] leading-relaxed">{p}</p>)}
        </section>
      ))}
    </article>
  );
}
