import { useI18n } from "../i18n";
import { PageHeader } from "../components/PageHeader";
import { EyebrowLabel } from "../components/EyebrowLabel";

const SECTIONS = [
  {
    icon: "🏋️",
    title: "Equipment Rules",
    rules: [
      "Re-rack weights and plates after every set.",
      "Wipe down benches and machines after use.",
      "Ask before working in on shared equipment.",
      "Never drop weights — lower them under control.",
    ],
  },
  {
    icon: "🧍",
    title: "Personal Safety",
    rules: [
      "Warm up for at least 5–10 minutes before lifting.",
      "Use a spotter for heavy bench, squat, or overhead work.",
      "Wear closed-toe athletic shoes on the gym floor.",
      "Stay hydrated — water stations are on every floor.",
    ],
  },
  {
    icon: "🤝",
    title: "Facility Etiquette",
    rules: [
      "Share machines during peak hours — work in sets.",
      "Keep phone calls off the training floor.",
      "No filming other members without their consent.",
      "Return dumbbells and accessories to their racks.",
    ],
  },
  {
    icon: "⛑️",
    title: "Emergency Procedures",
    rules: [
      "First aid kits and the AED are at reception.",
      "Alert any staff member immediately in an emergency.",
      "Emergency exits are marked at both ends of the floor.",
      "For anything life-threatening, call 911, then notify staff.",
    ],
  },
];

export function GymSafetyScreen() {
  const { t } = useI18n();
  return (
    <div className="page">
      <PageHeader />
      <div className="screen-padding stack" style={{ gap: 22 }}>
        <div className="stack" style={{ gap: 8 }}>
          <EyebrowLabel color="var(--accent-purple)">{t("Club Guide")}</EyebrowLabel>
          <h1 className="brand" style={{ fontSize: 32, color: "white", margin: 0 }}>{t("Gym Safety")}</h1>
          <span style={{ fontSize: 14, color: "var(--muted)" }}>{t("Rules and equipment guide for using the club safely.")}</span>
        </div>

        {SECTIONS.map((section) => (
          <div key={section.title} className="glass" style={{ padding: 18 }}>
            <div className="row" style={{ gap: 10, marginBottom: 12 }}>
              <span className="icon-circle" style={{ width: 34, height: 34, background: "rgba(89,0,255,0.5)" }}>{section.icon}</span>
              <h2 className="brand" style={{ fontSize: 18, margin: 0 }}>{t(section.title)}</h2>
            </div>
            {section.rules.map((rule, i) => (
              <div key={rule} className="row" style={{ gap: 10, padding: "10px 0", borderTop: i > 0 ? "1px solid var(--line)" : "none" }}>
                <span style={{ color: "var(--accent)" }}>✓</span>
                <span style={{ fontSize: 14, opacity: 0.9, lineHeight: 1.4 }}>{t(rule)}</span>
              </div>
            ))}
          </div>
        ))}
      </div>
    </div>
  );
}
