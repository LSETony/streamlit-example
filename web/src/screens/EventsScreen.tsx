import { useState } from "react";
import { useI18n } from "../i18n";
import { PageHeader } from "../components/PageHeader";
import { EyebrowLabel } from "../components/EyebrowLabel";

const EVENTS = [
  {
    icon: "🔥",
    title: "HIIT Circuit Night",
    dateLabel: "Fri",
    timeLabel: "18:00",
    description: "A 45-minute group HIIT session on the studio floor — bodyweight and kettlebell circuits, all levels welcome.",
  },
  {
    icon: "🏋️",
    title: "Powerlifting Seminar",
    dateLabel: "Sat",
    timeLabel: "10:00",
    description: "Squat/bench/deadlift technique breakdown with the strength floor coaches, plus a form-check Q&A.",
  },
  {
    icon: "🌿",
    title: "Mobility & Recovery Workshop",
    dateLabel: "Sun",
    timeLabel: "09:00",
    description: "Guided stretching, foam rolling and breathing work to help recovery between heavy training blocks.",
  },
  {
    icon: "🎉",
    title: "Member Social + New Gear Reveal",
    dateLabel: "Next Fri",
    timeLabel: "19:00",
    description: "Meet other members, try the new equipment on the strength floor, light snacks and drinks provided.",
  },
];

export function EventsScreen() {
  const { t } = useI18n();
  const [joined, setJoined] = useState<Set<string>>(new Set());

  function join(title: string) {
    setJoined((prev) => new Set(prev).add(title));
  }

  return (
    <div className="page">
      <PageHeader />
      <div className="screen-padding stack" style={{ gap: 18 }}>
        <EyebrowLabel color="var(--accent-purple)">{t("This Month")}</EyebrowLabel>
        <h1 className="brand" style={{ fontSize: 32, color: "white", margin: 0 }}>{t("Events")}</h1>

        {EVENTS.map((event) => {
          const isJoined = joined.has(event.title);
          return (
            <div key={event.title} className="glass stack" style={{ padding: 18, gap: 10 }}>
              <div className="row" style={{ gap: 10 }}>
                <span className="icon-circle" style={{ width: 36, height: 36, background: "rgba(89,0,255,0.5)" }}>{event.icon}</span>
                <div className="stack" style={{ gap: 2 }}>
                  <span className="brand" style={{ fontSize: 17 }}>{t(event.title)}</span>
                  <span className="pill" style={{ alignSelf: "flex-start" }}>{event.dateLabel} · {event.timeLabel}</span>
                </div>
              </div>
              <span style={{ fontSize: 13, color: "var(--muted)", lineHeight: 1.4 }}>{t(event.description)}</span>
              <button
                onClick={() => join(event.title)}
                disabled={isJoined}
                className="btn-primary purple"
                style={{ width: "auto", padding: "10px 18px", fontSize: 14, alignSelf: "flex-start" }}
              >
                {isJoined ? t("Joined") : t("Join")}
              </button>
            </div>
          );
        })}
      </div>
    </div>
  );
}
