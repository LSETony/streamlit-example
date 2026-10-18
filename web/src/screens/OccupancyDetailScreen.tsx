import { useAppState } from "../context/AppStateContext";
import { useI18n } from "../i18n";
import { PageHeader } from "../components/PageHeader";

export function OccupancyDetailScreen() {
  const { t } = useI18n();
  const { occupancyPercent, occupancyInClub, occupancyCapacity } = useAppState();

  return (
    <div className="page">
      <PageHeader title={t("Club Occupancy")} />
      <div className="screen-padding stack" style={{ gap: 20, alignItems: "center", textAlign: "center", marginTop: 20 }}>
        <span className="digital" style={{ fontSize: 72 }}>{occupancyPercent}</span>
        <span style={{ color: "var(--muted)" }}>
          {occupancyInClub} of {occupancyCapacity} in the club
        </span>
        <div style={{ width: "100%", height: 10, borderRadius: 999, background: "rgba(255,255,255,0.08)" }}>
          <div style={{ height: "100%", width: `${Math.min(100, occupancyPercent)}%`, borderRadius: 999, background: "var(--accent)" }} />
        </div>
        <span style={{ fontSize: 13, color: "var(--muted)" }}>
          A typical-day estimate, refined by real check-ins from the last couple of hours.
        </span>
      </div>
    </div>
  );
}
