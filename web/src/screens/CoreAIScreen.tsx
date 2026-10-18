import { Sparkles } from "lucide-react";
import { useI18n } from "../i18n";
import { PageHeader } from "../components/PageHeader";

export function CoreAIScreen() {
  const { t } = useI18n();
  return (
    <div className="page">
      <PageHeader title={t("coreAI.title")} />
      <div className="screen-padding stack" style={{ gap: 16, alignItems: "center", textAlign: "center", marginTop: 40 }}>
        <Sparkles size={36} color="var(--accent-purple)" />
        <span style={{ fontSize: 14, color: "var(--muted)", lineHeight: 1.5, maxWidth: 380 }}>{t("coreAI.unavailable")}</span>
      </div>
    </div>
  );
}
