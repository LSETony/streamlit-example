import { useNavigate } from "react-router-dom";
import { ChevronRight, LogOut, Trophy, UserPlus } from "lucide-react";
import { useAppState } from "../context/AppStateContext";
import { useAuth } from "../context/AuthContext";
import { useI18n, languageNativeName } from "../i18n";
import { EyebrowLabel } from "../components/EyebrowLabel";

export function ProfileScreen() {
  const { t } = useI18n();
  const { language } = useI18n();
  const navigate = useNavigate();
  const { signOut } = useAuth();
  const appState = useAppState();

  return (
    <div className="screen-padding stack" style={{ gap: 20, paddingTop: "calc(16px + env(safe-area-inset-top))", paddingBottom: 20 }}>
      <div className="row" style={{ gap: 14 }}>
        <button
          onClick={() => {}}
          className="icon-circle"
          style={{ width: 64, height: 64, background: "var(--accent-purple)", fontSize: 22, fontWeight: 700, border: "none", color: "white", cursor: "pointer" }}
        >
          {appState.initials}
        </button>
        <div className="stack" style={{ gap: 2 }}>
          <span className="brand" style={{ fontSize: 20, color: "white" }}>{appState.fullName}</span>
          <span style={{ fontSize: 12, color: "var(--muted)" }}>{t("profile.memberSince")} {appState.memberSince}</span>
        </div>
      </div>

      <div className="row" style={{ gap: 10 }}>
        <PlainStat value={`${appState.septemberVisits}`} label={t("visits")} />
        <PlainStat value={`${appState.scansThisMonth}`} label={t("scans")} />
        <PlainStat value={`${appState.ptSessionsLeft}`} label={t("pt left")} />
      </div>

      <div className="row" style={{ gap: 10 }}>
        <CommunityTile icon={<UserPlus size={18} />} title="Invite a friend" onClick={() => navigate("/referral")} />
        <CommunityTile icon={<Trophy size={18} />} title="Leaderboard" onClick={() => navigate("/leaderboard")} />
      </div>

      <button onClick={() => navigate("/subscriptions")} className="card" style={{ border: "none", width: "100%", cursor: "pointer", textAlign: "left", color: "white", background: "var(--accent-purple)" }}>
        <EyebrowLabel color="rgba(255,255,255,0.75)">{t("Membership")}</EyebrowLabel>
        <div className="digital" style={{ fontSize: 26, marginTop: 4 }}>{t(appState.membershipPlanName)}</div>
      </button>

      <div className="card stack" style={{ gap: 0 }}>
        <Row label={t("Apple Health")} onClick={() => navigate("/health")} />
        <div className="divider" />
        <Row label={t("Language")} value={languageNativeName[language]} onClick={() => navigate("/language")} />
        <div className="divider" />
        <Row label={t("profile.progressAndAchievements")} onClick={() => navigate("/progress")} />
        <div className="divider" />
        <Row label={t("QR Pass")} onClick={() => navigate("/qr-pass")} />
        <div className="divider" />
        <Row label={t("Check In")} onClick={() => navigate("/checkin")} />
      </div>

      <button
        onClick={signOut}
        className="btn-primary purple"
        style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 8 }}
      >
        <LogOut size={16} /> Logout
      </button>
    </div>
  );
}

function PlainStat({ value, label }: { value: string; label: string }) {
  return (
    <div className="stack" style={{ flex: 1, gap: 4, padding: 16, border: "0.5px solid rgba(255,255,255,0.5)", borderRadius: "var(--r)" }}>
      <span className="digital" style={{ fontSize: 26 }}>{value}</span>
      <span className="brand" style={{ fontSize: 16 }}>{label}</span>
    </div>
  );
}

function CommunityTile({ icon, title, onClick }: { icon: React.ReactNode; title: string; onClick: () => void }) {
  const { t } = useI18n();
  return (
    <button onClick={onClick} className="stack" style={{ flex: 1, gap: 10, padding: 16, background: "rgba(0,0,0,0.2)", border: "none", borderRadius: "var(--r)", color: "var(--accent)", textAlign: "left", cursor: "pointer" }}>
      {icon}
      <span className="brand" style={{ fontSize: 15, color: "white" }}>{t(title)}</span>
    </button>
  );
}

function Row({ label, value, onClick }: { label: string; value?: string; onClick: () => void }) {
  return (
    <button onClick={onClick} className="row" style={{ padding: "14px 0", background: "none", border: "none", width: "100%", color: "white", cursor: "pointer" }}>
      <span style={{ fontSize: 15 }}>{label}</span>
      <div className="spacer" />
      {value && <span style={{ fontSize: 14, color: "var(--muted)" }}>{value}</span>}
      <ChevronRight size={16} color="var(--muted)" />
    </button>
  );
}
