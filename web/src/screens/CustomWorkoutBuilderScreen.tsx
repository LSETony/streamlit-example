import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Check } from "lucide-react";
import { workoutZones, exercisePool } from "../lib/exercisePool";
import { useAppState } from "../context/AppStateContext";
import { useI18n } from "../i18n";
import { PageHeader } from "../components/PageHeader";
import { PrimaryButton } from "../components/PrimaryButton";

export function CustomWorkoutBuilderScreen() {
  const { t } = useI18n();
  const navigate = useNavigate();
  const { recordWorkoutCompletion } = useAppState();
  const [zoneId, setZoneId] = useState(workoutZones[0].id);
  const [selected, setSelected] = useState<Set<string>>(new Set());

  const exercises = exercisePool[zoneId] ?? [];

  function toggle(name: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(name)) next.delete(name);
      else next.add(name);
      return next;
    });
  }

  async function start() {
    const chosen = exercises.filter((e) => selected.has(e.name));
    const totalSets = chosen.reduce((sum, e) => sum + e.sets, 0);
    const minutes = Math.max(15, chosen.length * 6);
    await recordWorkoutCompletion(`My ${t(workoutZones.find((z) => z.id === zoneId)?.name ?? "")} Workout`, totalSets, minutes, Math.round(totalSets * 8));
    navigate("/workouts");
  }

  return (
    <div className="page">
      <PageHeader title={t("Build Your Own")} />
      <div className="screen-padding stack" style={{ gap: 16 }}>
        <div className="scroll-x">
          {workoutZones.map((zone) => {
            const isOn = zoneId === zone.id;
            return (
              <button
                key={zone.id}
                onClick={() => setZoneId(zone.id)}
                style={{
                  flexShrink: 0,
                  border: "none",
                  borderRadius: 999,
                  padding: "10px 14px",
                  fontSize: 13,
                  fontWeight: 600,
                  cursor: "pointer",
                  background: isOn ? "var(--accent-purple)" : "rgba(255,255,255,0.08)",
                  color: isOn ? "white" : "var(--muted)",
                }}
              >
                {t(zone.name)}
              </button>
            );
          })}
        </div>

        <div className="stack" style={{ gap: 0 }}>
          {exercises.map((ex, i) => {
            const isOn = selected.has(ex.name);
            return (
              <button
                key={ex.name}
                onClick={() => toggle(ex.name)}
                className="row"
                style={{
                  gap: 12,
                  padding: "12px 0",
                  borderBottom: i < exercises.length - 1 ? "1px solid var(--line)" : "none",
                  background: "none",
                  border: "none",
                  width: "100%",
                  textAlign: "left",
                  cursor: "pointer",
                  color: isOn ? "var(--accent-purple)" : "white",
                }}
              >
                <span style={{ fontSize: 20 }}>{ex.icon}</span>
                <div className="stack">
                  <span style={{ fontSize: 14, fontWeight: 500 }}>{t(ex.name)}</span>
                  <span style={{ fontSize: 12, color: "var(--muted)" }}>{ex.sets} sets · {ex.reps}</span>
                </div>
                <div className="spacer" />
                {isOn ? <Check size={19} /> : <span style={{ width: 19, height: 19, borderRadius: "50%", border: "1px solid rgba(255,255,255,0.3)" }} />}
              </button>
            );
          })}
        </div>

        <PrimaryButton color="purple" disabled={selected.size === 0} onClick={start}>
          {selected.size === 0 ? t("Select exercises to start") : `Start Workout · ${selected.size} exercises`}
        </PrimaryButton>
      </div>
    </div>
  );
}
