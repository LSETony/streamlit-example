import { useAppState } from "../context/AppStateContext";
import { useI18n } from "../i18n";

export function CalendarScreen() {
  const { t } = useI18n();
  const { bookedSessions, cancelSession } = useAppState();
  const sorted = [...bookedSessions].sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());

  return (
    <div className="screen-padding stack" style={{ gap: 18, paddingTop: "calc(16px + env(safe-area-inset-top))", paddingBottom: 20 }}>
      <h1 className="brand" style={{ fontSize: 28, color: "white", margin: 0 }}>{t("Calendar")}</h1>

      {sorted.length === 0 && <span style={{ color: "var(--muted)" }}>{t("Log your first session")}</span>}

      <div className="stack" style={{ gap: 10 }}>
        {sorted.map((session) => {
          const date = new Date(session.date);
          return (
            <div key={session.id} className="row card" style={{ gap: 12 }}>
              <div className="stack" style={{ alignItems: "center", width: 48 }}>
                <span className="digital" style={{ fontSize: 18 }}>{date.getDate()}</span>
                <span style={{ fontSize: 10, color: "var(--muted)" }}>{date.toLocaleDateString(undefined, { month: "short" })}</span>
              </div>
              <div className="stack" style={{ gap: 2 }}>
                <span style={{ fontSize: 14, fontWeight: 600 }}>{session.title}</span>
                <span style={{ fontSize: 12, color: "var(--muted)" }}>
                  {session.trainerName} · {date.toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" })}
                </span>
              </div>
              <div className="spacer" />
              <button onClick={() => cancelSession(session)} style={{ background: "none", border: "none", color: "var(--warn)", fontSize: 12, cursor: "pointer" }}>
                {t("Cancel")}
              </button>
            </div>
          );
        })}
      </div>
    </div>
  );
}
