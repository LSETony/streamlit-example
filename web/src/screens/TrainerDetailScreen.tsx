import { useState } from "react";
import { useParams } from "react-router-dom";
import { useAppState } from "../context/AppStateContext";
import { useI18n } from "../i18n";
import { PageHeader } from "../components/PageHeader";
import { EyebrowLabel } from "../components/EyebrowLabel";
import { PrimaryButton } from "../components/PrimaryButton";
import { useToast } from "../context/ToastContext";

export function TrainerDetailScreen() {
  const { t } = useI18n();
  const { id } = useParams();
  const { trainers, trainerSlots, bookZone } = useAppState();
  const { trigger } = useToast();
  const trainer = trainers.find((tr) => tr.id === id);
  const [slot, setSlot] = useState<string | null>(null);
  const [booked, setBooked] = useState(false);

  if (!trainer) {
    return (
      <div className="page">
        <PageHeader />
        <div className="screen-padding">{t("Trainer not found.")}</div>
      </div>
    );
  }

  const theTrainer = trainer;

  async function book() {
    if (!slot) return;
    await bookZone({ id: theTrainer.id, icon: "", name: theTrainer.name, subtitle: theTrainer.specialty, capacity: 1 }, slot);
    setBooked(true);
    trigger({ icon: "📅", title: t("trainer.sessionBooked"), subtitle: `${theTrainer.name} · ${slot}`, accent: "var(--accent-purple)" });
  }

  return (
    <div className="page">
      <PageHeader />
      <div className="screen-padding stack" style={{ gap: 18 }}>
        <div className="row" style={{ gap: 14 }}>
          <div className="icon-circle" style={{ width: 64, height: 64, background: "var(--accent-purple)", fontSize: 22, fontWeight: 700 }}>
            {trainer.name.split(" ").map((s) => s[0]).join("").slice(0, 2)}
          </div>
          <div className="stack" style={{ gap: 2 }}>
            <span className="brand" style={{ fontSize: 20 }}>{trainer.name}</span>
            <span style={{ fontSize: 13, color: "var(--muted)" }}>{trainer.specialty}</span>
            <span className="digital" style={{ fontSize: 13, color: "var(--accent)" }}>★ {trainer.rating} · {trainer.reviews} {t("trainer.reviews")} · {trainer.yearsExperience}</span>
          </div>
        </div>

        <div className="row" style={{ gap: 8, flexWrap: "wrap" }}>
          {trainer.tags.map((tag) => (
            <span key={tag} className="pill">{tag}</span>
          ))}
        </div>

        <span style={{ fontSize: 14, lineHeight: 1.5, color: "rgba(255,255,255,0.85)" }}>{trainer.bio}</span>

        <EyebrowLabel>{t("Next free slots")}</EyebrowLabel>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 8 }}>
          {trainerSlots.map((s) => (
            <button
              key={s}
              onClick={() => setSlot(s)}
              className="digital"
              style={{
                padding: "10px 0",
                borderRadius: "var(--r-s)",
                border: slot === s ? "2px solid var(--accent-purple)" : "1px solid var(--line)",
                background: "var(--surf)",
                color: "white",
                fontSize: 14,
                cursor: "pointer",
              }}
            >
              {s}
            </button>
          ))}
        </div>

        <PrimaryButton color="purple" disabled={!slot || booked} onClick={book}>
          {booked ? t("trainer.booked") : `${t("trainer.bookFor")} ${trainer.priceLabel}`}
        </PrimaryButton>
      </div>
    </div>
  );
}
