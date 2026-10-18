import { useNavigate } from "react-router-dom";
import { useAppState } from "../context/AppStateContext";
import { useI18n } from "../i18n";
import { PageHeader } from "../components/PageHeader";

export function BookZoneScreen() {
  const { t } = useI18n();
  const navigate = useNavigate();
  const { gymZones } = useAppState();

  return (
    <div className="page">
      <PageHeader title={t("Book a Zone")} />
      <div className="screen-padding stack" style={{ gap: 10 }}>
        {gymZones.map((zone) => (
          <button
            key={zone.id}
            onClick={() => navigate(`/book/${zone.id}`)}
            className="row card"
            style={{ gap: 14, border: "none", cursor: "pointer", textAlign: "left", color: "white" }}
          >
            <span className="icon-circle" style={{ width: 48, height: 48, background: "var(--accent-purple)" }}>🏋️</span>
            <div className="stack" style={{ gap: 2 }}>
              <span style={{ fontSize: 15, fontWeight: 600 }}>{t(zone.name)}</span>
              <span style={{ fontSize: 12, color: "var(--muted)" }}>{t(zone.subtitle)}</span>
            </div>
            <div className="spacer" />
            <div className="stack" style={{ alignItems: "flex-end" }}>
              <span className="digital" style={{ fontSize: 15 }}>{zone.capacity}</span>
              <span style={{ fontSize: 10, color: "var(--muted)" }}>{t("cap.")}</span>
            </div>
          </button>
        ))}
      </div>
    </div>
  );
}
