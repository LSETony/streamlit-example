import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Sliders, ChevronRight } from "lucide-react";
import { useAppState } from "../context/AppStateContext";
import { useI18n } from "../i18n";
import type { WorkoutCard } from "../lib/models";

const FILTERS = ["All", "Strength", "Cardio", "Flexibility"];

function WorkoutTile({ card, onClick }: { card: WorkoutCard; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      style={{
        border: "none",
        cursor: "pointer",
        width: 170,
        height: 200,
        flexShrink: 0,
        borderRadius: "var(--r)",
        padding: 12,
        display: "flex",
        flexDirection: "column",
        justifyContent: "flex-end",
        alignItems: "flex-start",
        textAlign: "left",
        color: "white",
        background: card.imageURL
          ? `linear-gradient(180deg, rgba(0,0,0,0.1), rgba(0,0,0,0.85)), url(${card.imageURL}) center/cover`
          : "linear-gradient(135deg, #3a1d6e, #16151a)",
      }}
    >
      <span className="brand" style={{ fontSize: 15 }}>{card.title}</span>
      <div className="row" style={{ gap: 6, marginTop: 4 }}>
        <span className="brand" style={{ fontSize: 10, color: "var(--accent)" }}>{card.duration}</span>
        <span className="brand" style={{ fontSize: 10, color: "rgba(255,255,255,0.85)" }}>{card.level}</span>
      </div>
    </button>
  );
}

export function WorkoutsScreen() {
  const { t } = useI18n();
  const navigate = useNavigate();
  const { beginnerPlanCards, topWorkoutCards, importantCards } = useAppState();
  const [filter, setFilter] = useState("All");

  const filteredBeginner = useMemo(
    () => (filter === "All" ? beginnerPlanCards : beginnerPlanCards.filter((c) => c.category === filter)),
    [beginnerPlanCards, filter]
  );
  const filteredTop = useMemo(
    () => (filter === "All" ? topWorkoutCards : topWorkoutCards.filter((c) => c.category === filter)),
    [topWorkoutCards, filter]
  );

  return (
    <div className="screen-padding stack" style={{ gap: 22, paddingTop: "calc(16px + env(safe-area-inset-top))" }}>
      <h1 className="brand" style={{ fontSize: 32, color: "white", margin: 0 }}>{t("nav.workouts")}</h1>

      <button
        onClick={() => navigate("/workouts/builder")}
        className="glass"
        style={{ border: "none", padding: 14, textAlign: "left", color: "white", cursor: "pointer", display: "flex", alignItems: "center", gap: 12 }}
      >
        <span className="icon-circle" style={{ width: 40, height: 40, background: "rgba(89,0,255,0.6)" }}>
          <Sliders size={17} />
        </span>
        <div className="stack" style={{ gap: 2 }}>
          <span className="brand" style={{ fontSize: 15 }}>{t("Build Your Own Workout")}</span>
          <span style={{ fontSize: 12, color: "var(--muted)" }}>{t("Pick a zone, choose your exercises")}</span>
        </div>
        <div className="spacer" />
        <ChevronRight size={16} color="var(--muted)" />
      </button>

      <div className="scroll-x">
        {FILTERS.map((f) => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className="brand"
            style={{
              flexShrink: 0,
              minWidth: 89,
              minHeight: 50,
              borderRadius: 999,
              border: "none",
              fontSize: 16,
              cursor: "pointer",
              background: filter === f ? "var(--accent)" : "rgba(30,30,30,0.2)",
              color: filter === f ? "white" : "var(--ink)",
            }}
          >
            {t(f)}
          </button>
        ))}
      </div>

      {filteredBeginner.length > 0 && (
        <div className="stack" style={{ gap: 10 }}>
          <h2 className="brand" style={{ fontSize: 20, color: "white", margin: 0 }}>{t("Beginner's Plan")}</h2>
          <div className="scroll-x">
            {filteredBeginner.map((c) => (
              <WorkoutTile key={c.id} card={c} onClick={() => navigate(`/workouts/${c.id}`)} />
            ))}
          </div>
        </div>
      )}

      {filteredTop.length > 0 && (
        <div className="stack" style={{ gap: 10 }}>
          <h2 className="brand" style={{ fontSize: 20, color: "white", margin: 0 }}>{t("Top 10 workouts")}</h2>
          <div className="scroll-x">
            {filteredTop.map((c) => (
              <WorkoutTile key={c.id} card={c} onClick={() => navigate(`/workouts/${c.id}`)} />
            ))}
          </div>
        </div>
      )}

      {filteredBeginner.length === 0 && filteredTop.length === 0 && (
        <span style={{ color: "var(--muted)", fontSize: 14 }}>{t(`workouts.noneYet.${filter.toLowerCase()}`)}</span>
      )}

      <div className="stack" style={{ gap: 10 }}>
        <h2 className="brand" style={{ fontSize: 20, color: "white", margin: 0 }}>{t("Important")}</h2>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
          {importantCards.map((card) => (
            <button
              key={card.title}
              onClick={() => navigate(card.title === "Events" ? "/events" : "/gym-safety")}
              style={{
                border: "none",
                height: 200,
                borderRadius: "var(--r)",
                background: "linear-gradient(135deg, rgba(89,0,255,0.85), var(--accent-purple))",
                color: "white",
                textAlign: "left",
                padding: 16,
                cursor: "pointer",
                display: "flex",
                flexDirection: "column",
              }}
            >
              <span className="icon-circle" style={{ width: 44, height: 44, background: "rgba(255,255,255,0.16)" }}>
                !
              </span>
              <div className="spacer" />
              <span className="brand" style={{ fontSize: 16 }}>{t(card.title)}</span>
              <span style={{ fontSize: 11, opacity: 0.75 }}>{card.subtitle}</span>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
