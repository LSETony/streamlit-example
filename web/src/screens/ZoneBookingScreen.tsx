import { useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { useAppState } from "../context/AppStateContext";
import { useI18n } from "../i18n";
import { PageHeader } from "../components/PageHeader";
import { EyebrowLabel } from "../components/EyebrowLabel";
import { PrimaryButton } from "../components/PrimaryButton";
import { useToast } from "../context/ToastContext";

export function ZoneBookingScreen() {
  const { t } = useI18n();
  const { zoneId } = useParams();
  const navigate = useNavigate();
  const { gymZones, trainerSlots, bookZone } = useAppState();
  const { trigger } = useToast();
  const zone = gymZones.find((z) => z.id === zoneId);
  const [slot, setSlot] = useState<string | null>(null);

  if (!zone) {
    return (
      <div className="page">
        <PageHeader />
        <div className="screen-padding">{t("Zone not found.")}</div>
      </div>
    );
  }

  const theZone = zone;

  async function book() {
    if (!slot) return;
    await bookZone(theZone, slot);
    trigger({ icon: "📅", title: t("Special booked!"), subtitle: `${theZone.name} · ${slot}`, accent: "var(--accent-purple)" });
    navigate("/calendar");
  }

  return (
    <div className="page">
      <PageHeader />
      <div className="screen-padding stack" style={{ gap: 18 }}>
        <div className="row" style={{ gap: 14 }}>
          <span className="icon-circle" style={{ width: 56, height: 56, background: "var(--accent-purple)" }}>🏋️</span>
          <div className="stack">
            <span className="brand" style={{ fontSize: 22 }}>{t(zone.name)}</span>
            <span style={{ fontSize: 13, color: "var(--muted)" }}>{t(zone.subtitle)}</span>
          </div>
        </div>

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

        <PrimaryButton color="purple" disabled={!slot} onClick={book}>
          {t("zone.confirmBooking")}
        </PrimaryButton>
      </div>
    </div>
  );
}
