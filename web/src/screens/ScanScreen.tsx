import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { ScanLine } from "lucide-react";
import { useAppState } from "../context/AppStateContext";
import { useI18n } from "../i18n";
import { PageHeader } from "../components/PageHeader";

export function ScanScreen() {
  const { t } = useI18n();
  const navigate = useNavigate();
  const { products } = useAppState();
  const [query, setQuery] = useState("");

  const results = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return [];
    return products.filter((p) => p.name.toLowerCase().includes(q) || p.abbr.toLowerCase().includes(q));
  }, [products, query]);

  return (
    <div className="page">
      <PageHeader title={t("scan.title")} />
      <div className="screen-padding stack" style={{ gap: 18 }}>
        <div className="glass stack" style={{ padding: 16, gap: 8, alignItems: "center", textAlign: "center" }}>
          <ScanLine size={28} color="var(--muted)" />
          <span style={{ fontSize: 13, color: "var(--muted)" }}>{t("scan.noCamera")}</span>
        </div>

        <input type="search" placeholder={t("scan.searchPlaceholder")} value={query} onChange={(e) => setQuery(e.target.value)} />

        <div className="stack" style={{ gap: 10 }}>
          {results.map((product) => (
            <button
              key={product.id}
              onClick={() => navigate(`/store/${product.id}`)}
              className="row card"
              style={{ gap: 12, border: "none", cursor: "pointer", textAlign: "left", color: "white" }}
            >
              <span className="icon-circle" style={{ width: 36, height: 36, background: "var(--accent-dim)", color: "var(--accent)", fontWeight: 700, fontSize: 12 }}>
                {product.abbr}
              </span>
              <span style={{ fontSize: 14 }}>{t(product.name)}</span>
              <div className="spacer" />
              <span className="digital">${product.price}</span>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
