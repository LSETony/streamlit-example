import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Check } from "lucide-react";
import { useI18n } from "../i18n";
import { PrimaryButton } from "../components/PrimaryButton";

const TOTAL_STEPS = 4;

function OptionRow({ title, isSelected, onClick }: { title: string; isSelected: boolean; onClick: () => void }) {
  return (
    <button onClick={onClick} className="row" style={{ background: "var(--option-row-fill)", border: "none", borderRadius: 999, padding: isSelected ? "6px 18px" : "18px", minHeight: 72, width: "100%", color: "white", cursor: "pointer" }}>
      <span className="brand" style={{ fontSize: 16 }}>{title}</span>
      <div className="spacer" />
      {isSelected && (
        <span className="icon-circle" style={{ width: 34, height: 34, background: "var(--accent)" }}>
          <Check size={16} />
        </span>
      )}
    </button>
  );
}

function LevelCard({ title, subtitle, isSelected, onClick }: { title: string; subtitle: string; isSelected: boolean; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      style={{
        background: isSelected ? "var(--accent-purple)" : "transparent",
        border: isSelected ? "none" : "1px solid rgba(255,255,255,0.5)",
        borderRadius: "var(--r)",
        padding: 16,
        minHeight: 193,
        textAlign: "left",
        color: "white",
        cursor: "pointer",
        display: "flex",
        flexDirection: "column",
        gap: 8,
      }}
    >
      <span className="brand" style={{ fontSize: 16 }}>{title}</span>
      <div className="spacer" />
      <span className="brand" style={{ fontSize: 12, color: isSelected ? "rgba(255,255,255,0.9)" : "var(--muted)", whiteSpace: "pre-line" }}>
        {subtitle}
      </span>
    </button>
  );
}

export function OnboardingScreen() {
  const { t } = useI18n();
  const navigate = useNavigate();
  const [step, setStep] = useState(0);
  const [gender, setGender] = useState<string | null>(null);
  const [goal, setGoal] = useState<string | null>(null);
  const [contraOptions, setContraOptions] = useState(["Allergic", "Diabetes", "Astma"]);
  const [selectedContra, setSelectedContra] = useState<Set<string>>(new Set());
  const [note, setNote] = useState("");
  const [level, setLevel] = useState<string | null>(null);

  const stepTitle = [t("Tell us about yourself"), t("What's your goal?"), t("Tell us about yourself"), t("Choose your level")][step];
  const stepSubtitle = [
    t("This tailor plans and your experience"),
    t("We're here to help you out"),
    t("Give us more details, so we can better assist you"),
    t("Almost done"),
  ][step];

  const canContinue = [gender !== null, goal !== null, true, level !== null][step];

  function advance() {
    if (step < TOTAL_STEPS - 1) {
      setStep(step + 1);
    } else {
      navigate("/");
    }
  }

  function submitNote() {
    const trimmed = note.trim();
    if (!trimmed) return;
    if (!contraOptions.includes(trimmed)) setContraOptions((prev) => [...prev, trimmed]);
    setSelectedContra((prev) => new Set(prev).add(trimmed));
    setNote("");
  }

  return (
    <div className="page screen-padding" style={{ paddingTop: "calc(24px + env(safe-area-inset-top))", display: "flex", flexDirection: "column", minHeight: "100vh" }}>
      <div className="stack" style={{ gap: 4, marginBottom: 22 }}>
        <h1 className="brand" style={{ fontSize: 32, margin: 0 }}>{stepTitle}</h1>
        <span className="brand" style={{ fontSize: 13, color: "var(--muted)" }}>{stepSubtitle}</span>
      </div>

      <div className="row" style={{ gap: 10, marginBottom: 22 }}>
        <div style={{ flex: 1, height: 6, borderRadius: 999, background: "rgba(138,138,147,0.35)", position: "relative" }}>
          <div style={{ position: "absolute", inset: 0, width: `${((step + 1) / TOTAL_STEPS) * 100}%`, background: "var(--accent)", borderRadius: 999 }} />
        </div>
        <span className="brand" style={{ fontSize: 12, color: "var(--muted)" }}>{step + 1}/{TOTAL_STEPS}</span>
      </div>

      <div style={{ flex: 1 }}>
        {step === 0 && (
          <div className="stack" style={{ gap: 12 }}>
            <OptionRow title={t("Men")} isSelected={gender === "Men"} onClick={() => setGender("Men")} />
            <OptionRow title={t("Women")} isSelected={gender === "Women"} onClick={() => setGender("Women")} />
          </div>
        )}
        {step === 1 && (
          <div className="stack" style={{ gap: 12 }}>
            {["Muscle Built", "Lose Weight", "Stay Fit & Healthy", "Get Stronger"].map((g) => (
              <OptionRow key={g} title={t(g)} isSelected={goal === g} onClick={() => setGoal(g)} />
            ))}
          </div>
        )}
        {step === 2 && (
          <div className="stack" style={{ gap: 24 }}>
            <h2 className="brand" style={{ fontSize: 22, textAlign: "center", whiteSpace: "pre-line", margin: 0 }}>
              {t("Do you have any\ncontradictions?")}
            </h2>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 10 }}>
              {contraOptions.map((item) => {
                const on = selectedContra.has(item);
                return (
                  <span
                    key={item}
                    onClick={() => {
                      setSelectedContra((prev) => {
                        const next = new Set(prev);
                        if (on) next.delete(item);
                        else next.add(item);
                        return next;
                      });
                    }}
                    className="brand"
                    style={{
                      padding: "12px 18px",
                      borderRadius: 999,
                      background: on ? "var(--accent)" : "var(--option-row-fill)",
                      border: on ? "none" : "1px solid var(--line)",
                      fontSize: 14,
                      cursor: "pointer",
                    }}
                  >
                    {t(item)}
                  </span>
                );
              })}
            </div>
            <div className="row" style={{ gap: 10 }}>
              <input
                type="text"
                placeholder={t("Type here…")}
                value={note}
                onChange={(e) => setNote(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && submitNote()}
                style={{ borderRadius: 999 }}
              />
              <button onClick={submitNote} className="icon-circle" style={{ width: 48, height: 48, background: "var(--accent-purple)", border: "none", flexShrink: 0, cursor: "pointer" }}>
                →
              </button>
            </div>
          </div>
        )}
        {step === 3 && (
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
            <LevelCard title={t("Beginner")} subtitle={"This means\nyou've just started"} isSelected={level === "Beginner"} onClick={() => setLevel("Beginner")} />
            <LevelCard title={t("Intermediate")} subtitle={t("Have an\nexperience")} isSelected={level === "Intermediate"} onClick={() => setLevel("Intermediate")} />
            <LevelCard title={t("Amateur")} subtitle={t("I workout all\nthe time")} isSelected={level === "Amateur"} onClick={() => setLevel("Amateur")} />
            <LevelCard title={t("Advanced")} subtitle={t("I know\neverything")} isSelected={level === "Advanced"} onClick={() => setLevel("Advanced")} />
          </div>
        )}
      </div>

      <div style={{ marginTop: 24, marginBottom: 24 }}>
        <PrimaryButton color="purple" disabled={!canContinue} onClick={advance}>
          {t("Continue")}
        </PrimaryButton>
      </div>
    </div>
  );
}
