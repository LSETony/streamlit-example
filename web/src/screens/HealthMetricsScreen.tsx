import { HeartPulse } from "lucide-react";
import { useI18n } from "../i18n";
import { PageHeader } from "../components/PageHeader";

export function HealthMetricsScreen() {
  const { t } = useI18n();
  return (
    <div className="page">
      <PageHeader title={t("health.title")} />
      <div className="screen-padding stack" style={{ gap: 16, alignItems: "center", textAlign: "center", marginTop: 40 }}>
        <HeartPulse size={36} color="var(--accent)" />
        <span style={{ fontSize: 14, color: "var(--muted)", lineHeight: 1.5, maxWidth: 380 }}>{t("health.unavailable")}</span>
      </div>
    </div>
  );
}
