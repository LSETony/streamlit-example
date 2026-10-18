import { useEffect } from "react";
import { useAppState } from "../context/AppStateContext";
import { useI18n } from "../i18n";
import { PageHeader } from "../components/PageHeader";

export function LeaderboardScreen() {
  const { t } = useI18n();
  const { leaderboard, refreshLeaderboard } = useAppState();

  useEffect(() => {
    refreshLeaderboard();
  }, [refreshLeaderboard]);

  return (
    <div className="page">
      <PageHeader title={t("Leaderboard")} />
      <div className="screen-padding stack" style={{ gap: 8 }}>
        {leaderboard.length === 0 && <span style={{ color: "var(--muted)" }}>{t("No members yet — be the first to check in.")}</span>}
        {leaderboard.map((entry, i) => (
          <div
            key={entry.id}
            className="row card"
            style={{ gap: 12, background: entry.isMe ? "rgba(249,44,0,0.15)" : "var(--surf)" }}
          >
            <span className="digital" style={{ width: 28, textAlign: "center" }}>{i + 1}</span>
            <div className="stack">
              <span style={{ fontSize: 14, fontWeight: 600 }}>{entry.displayName}{entry.isMe ? " (you)" : ""}</span>
              <span style={{ fontSize: 12, color: "var(--muted)" }}>{entry.streakDays} day streak</span>
            </div>
            <div className="spacer" />
            <span className="digital" style={{ color: "var(--accent)" }}>{entry.totalVisits}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
