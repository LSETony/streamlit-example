import { useMemo, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { useAppState } from "../context/AppStateContext";
import { useI18n } from "../i18n";
import { PageHeader } from "../components/PageHeader";
import { PrimaryButton } from "../components/PrimaryButton";
import { EyebrowLabel } from "../components/EyebrowLabel";

export function WorkoutDetailScreen() {
  const { t } = useI18n();
  const navigate = useNavigate();
  const { id } = useParams();
  const { beginnerPlanCards, topWorkoutCards, recordWorkoutCompletion } = useAppState();
  const card = useMemo(
    () => [...beginnerPlanCards, ...topWorkoutCards].find((c) => c.id === id),
    [beginnerPlanCards, topWorkoutCards, id]
  );

  const [isActive, setIsActive] = useState(false);
  const [exerciseIndex, setExerciseIndex] = useState(0);
  const [currentSet, setCurrentSet] = useState(1);

  if (!card) {
    return (
      <div className="page">
        <PageHeader />
        <div className="screen-padding">{t("Workout not found.")}</div>
      </div>
    );
  }

  const workoutCard = card;
  const exercise = workoutCard.exercises[exerciseIndex];

  function completeSet() {
    if (!exercise) return;
    if (currentSet < exercise.sets) {
      setCurrentSet(currentSet + 1);
      return;
    }
    if (exerciseIndex < workoutCard.exercises.length - 1) {
      setExerciseIndex(exerciseIndex + 1);
      setCurrentSet(1);
    } else {
      finish();
    }
  }

  async function finish() {
    const totalSets = workoutCard.exercises.reduce((sum, e) => sum + e.sets, 0);
    const minutes = parseInt(workoutCard.duration, 10) || 20;
    await recordWorkoutCompletion(workoutCard.title, totalSets, minutes, Math.round(totalSets * 8.5));
    navigate("/workouts");
  }

  if (isActive && exercise) {
    return (
      <div className="page">
        <PageHeader title={card.title} onBack={() => setIsActive(false)} />
        <div className="screen-padding stack" style={{ gap: 24, alignItems: "center", textAlign: "center", marginTop: 20 }}>
          <EyebrowLabel>{`Exercise ${exerciseIndex + 1} of ${card.exercises.length}`}</EyebrowLabel>
          <h2 className="brand" style={{ fontSize: 26, margin: 0 }}>{t(exercise.name)}</h2>
          <span className="digital" style={{ fontSize: 60 }}>{currentSet}/{exercise.sets}</span>
          <span style={{ color: "var(--muted)" }}>{exercise.reps} {t("workout.reps")}</span>
          <div style={{ width: "100%" }}>
            <PrimaryButton onClick={completeSet}>
              {currentSet < exercise.sets
                ? t("Complete Set")
                : exerciseIndex < card.exercises.length - 1
                ? t("Next Exercise")
                : t("workout.finishWorkout")}
            </PrimaryButton>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="page">
      <PageHeader />
      <div className="screen-padding stack" style={{ gap: 18 }}>
        <h1 className="brand" style={{ fontSize: 28, color: "white", margin: 0 }}>{card.title}</h1>
        <div className="row" style={{ gap: 8 }}>
          <span className="pill">{t(card.level)}</span>
          <span className="pill">{card.duration}</span>
          <span className="pill">{card.exercises.length} exercises</span>
        </div>

        <EyebrowLabel>{t("Exercises")}</EyebrowLabel>
        <div className="stack" style={{ gap: 0 }}>
          {card.exercises.map((ex, i) => (
            <div key={`${ex.name}-${i}`} className="row" style={{ gap: 12, padding: "10px 0", borderBottom: i < card.exercises.length - 1 ? "1px solid var(--line)" : "none" }}>
              <span className="digital" style={{ width: 28, height: 28, borderRadius: "50%", background: "var(--accent-dim)", color: "var(--accent)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 14 }}>
                {i + 1}
              </span>
              <div className="stack">
                <span style={{ fontSize: 14, fontWeight: 600 }}>{t(ex.name)}</span>
                <span style={{ fontSize: 12, color: "var(--muted)" }}>{ex.sets} sets · {ex.reps}</span>
              </div>
            </div>
          ))}
        </div>

        <PrimaryButton
          color="purple"
          onClick={() => {
            setIsActive(true);
            setExerciseIndex(0);
            setCurrentSet(1);
          }}
        >
          {t("Start Workout")}
        </PrimaryButton>
      </div>
    </div>
  );
}
