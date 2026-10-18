import { useState } from "react";
import { useAppState } from "../context/AppStateContext";
import { useI18n } from "../i18n";
import { EyebrowLabel } from "../components/EyebrowLabel";

const TABS = ["Overview", "Body", "History"] as const;

const MUSCLE_MASS = [32.4, 32.9, 33.1, 33.6, 34.0, 34.5];
const INBODY = { bodyFatPercent: 16.2, totalBodyWaterPercent: 58.4, visceralFatIndex: 7, basalMetabolicRate: 1720 };

export function ProgressScreen() {
  const { t } = useI18n();
  const appState = useAppState();
  const [tab, setTab] = useState<(typeof TABS)[number]>("Overview");

  return (
    <div className="screen-padding stack" style={{ gap: 20, paddingTop: "calc(16px + env(safe-area-inset-top))", paddingBottom: 20 }}>
      <h1 className="brand" style={{ fontSize: 28, color: "white", margin: 0 }}>{t("Your Progress")}</h1>

      <div className="glass row" style={{ padding: 4, gap: 4 }}>
        {TABS.map((tb) => (
          <button
            key={tb}
            onClick={() => setTab(tb)}
            style={{
              flex: 1,
              border: "none",
              borderRadius: 999,
              padding: "8px 0",
              fontSize: 13,
              fontWeight: 600,
              cursor: "pointer",
              background: tab === tb ? "var(--accent)" : "transparent",
              color: tab === tb ? "white" : "var(--muted)",
            }}
          >
            {t(tb)}
          </button>
        ))}
      </div>

      {tab === "Overview" && (
        <div className="stack" style={{ gap: 20 }}>
          <div className="card stack" style={{ gap: 10, alignItems: "center", textAlign: "center" }}>
            <EyebrowLabel>{t("Streak")}</EyebrowLabel>
            <span className="digital" style={{ fontSize: 56, color: "var(--accent)" }}>{appState.streakDays}</span>
            <span style={{ color: "var(--muted)", fontSize: 13 }}>days in a row</span>
          </div>

          <div className="row" style={{ gap: 10 }}>
            <MiniStat label={t("Sets")} value={`${appState.totalSetsThisWeek}`} />
            <MiniStat label={t("Time")} value={`${appState.totalMinutesThisWeek}m`} />
            <MiniStat label={t("Calories")} value={`${appState.totalCaloriesThisWeek}`} />
          </div>

          <div className="stack" style={{ gap: 10 }}>
            <EyebrowLabel>{t("Achievements")}</EyebrowLabel>
            <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 12 }}>
              {appState.achievements.map((a) => (
                <div key={a.title} className="stack" style={{ alignItems: "center", gap: 6, opacity: a.isUnlocked ? 1 : 0.4 }}>
                  <span className="icon-circle" style={{ width: 56, height: 56, background: a.isUnlocked ? "rgba(249,44,0,0.3)" : "rgba(255,255,255,0.08)", fontSize: 22 }}>
                    {a.icon}
                  </span>
                  <span style={{ fontSize: 11, fontWeight: 600, textAlign: "center" }}>{t(a.title)}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {tab === "Body" && (
        <div className="stack" style={{ gap: 20 }}>
          <div className="stack" style={{ gap: 10 }}>
            <EyebrowLabel>{t("Body Composition")}</EyebrowLabel>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
              <MiniStat label={t("Body Fat")} value={`${INBODY.bodyFatPercent}%`} />
              <MiniStat label={t("Total Body Water")} value={`${INBODY.totalBodyWaterPercent}%`} />
              <MiniStat label={t("Visceral Fat Index")} value={`${INBODY.visceralFatIndex}`} />
              <MiniStat label={t("Basal Metabolic Rate")} value={`${INBODY.basalMetabolicRate}`} />
            </div>
          </div>

          <div className="stack" style={{ gap: 10 }}>
            <EyebrowLabel>{t("Muscle Mass")}</EyebrowLabel>
            <div className="card">
              <MuscleMassChart values={MUSCLE_MASS} />
            </div>
          </div>
        </div>
      )}

      {tab === "History" && (
        <div className="stack" style={{ gap: 10 }}>
          <EyebrowLabel>{t("Workout history")}</EyebrowLabel>
          {appState.workoutHistory.map((entry, i) => (
            <div key={i} className="row card" style={{ gap: 10 }}>
              <div className="stack">
                <span style={{ fontSize: 14, fontWeight: 600 }}>{entry.title}</span>
                <span style={{ fontSize: 12, color: "var(--muted)" }}>{entry.date} · {entry.sets} sets · {entry.minutes}m</span>
              </div>
              <div className="spacer" />
              <span className="digital" style={{ color: "var(--accent)" }}>{entry.calories}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function MiniStat({ label, value }: { label: string; value: string }) {
  return (
    <div className="card stack" style={{ gap: 4, flex: 1 }}>
      <span style={{ fontSize: 12, color: "var(--muted)" }}>{label}</span>
      <span className="digital" style={{ fontSize: 20 }}>{value}</span>
    </div>
  );
}

function MuscleMassChart({ values }: { values: number[] }) {
  const width = 280;
  const height = 100;
  const min = Math.min(...values);
  const max = Math.max(...values);
  const range = max - min || 1;
  const points = values
    .map((v, i) => {
      const x = (i / (values.length - 1)) * width;
      const y = height - ((v - min) / range) * height;
      return `${x},${y}`;
    })
    .join(" ");
  return (
    <svg width="100%" viewBox={`0 0 ${width} ${height}`} preserveAspectRatio="none" style={{ display: "block" }}>
      <polyline points={points} fill="none" stroke="var(--accent)" strokeWidth={2.5} strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}
