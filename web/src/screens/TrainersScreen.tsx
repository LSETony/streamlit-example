import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Search } from "lucide-react";
import { useAppState } from "../context/AppStateContext";
import { useI18n } from "../i18n";
import { PageHeader } from "../components/PageHeader";

export function TrainersScreen() {
  const { t } = useI18n();
  const navigate = useNavigate();
  const { trainers } = useAppState();
  const [search, setSearch] = useState("");

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return trainers;
    return trainers.filter(
      (tr) => tr.name.toLowerCase().includes(q) || tr.specialty.toLowerCase().includes(q) || tr.tags.some((tag) => tag.toLowerCase().includes(q))
    );
  }, [trainers, search]);

  return (
    <div className="page">
      <PageHeader title={t("Trainers")} />
      <div className="screen-padding stack" style={{ gap: 16 }}>
        <div className="glass row" style={{ padding: "10px 16px", gap: 8 }}>
          <Search size={16} color="var(--muted)" />
          <input
            type="search"
            placeholder={t("search")}
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            style={{ background: "none", border: "none", padding: 0 }}
          />
        </div>

        <div className="stack" style={{ gap: 10 }}>
          {filtered.map((trainer) => (
            <button
              key={trainer.id}
              onClick={() => navigate(`/trainers/${trainer.id}`)}
              className="row card"
              style={{ gap: 12, border: "none", cursor: "pointer", textAlign: "left", color: "white" }}
            >
              <div className="icon-circle" style={{ width: 52, height: 52, background: "var(--accent-purple)", fontSize: 18, fontWeight: 700, flexShrink: 0 }}>
                {trainer.name.split(" ").map((s) => s[0]).join("").slice(0, 2)}
              </div>
              <div className="stack" style={{ gap: 2, minWidth: 0 }}>
                <span className="brand" style={{ fontSize: 16 }}>{trainer.name}</span>
                <span style={{ fontSize: 12, color: "var(--muted)" }}>{trainer.specialty} · {trainer.yearsExperience}</span>
                <div className="row" style={{ gap: 6, marginTop: 2 }}>
                  <span className="digital" style={{ fontSize: 13, color: "var(--accent)" }}>★ {trainer.rating}</span>
                  <span style={{ fontSize: 12, color: "var(--muted)" }}>({trainer.reviews})</span>
                </div>
              </div>
              <div className="spacer" />
              <span className="digital" style={{ fontSize: 15 }}>{trainer.priceLabel}</span>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
