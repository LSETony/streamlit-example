import { useNavigate } from "react-router-dom";
import { Calendar, User, Salad, ShoppingCart, ScanLine, Sparkles, Wallet, Shield, PartyPopper } from "lucide-react";
import { useAppState } from "../context/AppStateContext";
import { useI18n } from "../i18n";
import { EyebrowLabel } from "../components/EyebrowLabel";

const QUICK_ACTIONS = [
  { icon: Calendar, title: "Book", to: "/book" },
  { icon: User, title: "Trainers", to: "/trainers" },
  { icon: Salad, title: "Food", to: "/food" },
  { icon: ShoppingCart, title: "Store", to: "/store" },
  { icon: ScanLine, title: "Scan", to: "/scan" },
  { icon: Sparkles, title: "Core AI", to: "/core-ai" },
];

export function HomeScreen() {
  const { t } = useI18n();
  const navigate = useNavigate();
  const appState = useAppState();

  return (
    <div className="stack">
      <div
        style={{
          height: 260,
          background: "linear-gradient(180deg, rgba(0,0,0,0) 0%, rgba(0,0,0,0.75) 100%), linear-gradient(135deg, #3a1d6e, #16151a)",
          position: "relative",
          borderRadius: "0 0 var(--r) var(--r)",
        }}
      >
        <div className="row screen-padding" style={{ paddingTop: "calc(16px + env(safe-area-inset-top))" }}>
          <button onClick={() => navigate("/subscriptions")} className="icon-circle glass-pill" style={{ width: 40, height: 40, border: "none", cursor: "pointer" }}>
            <Wallet size={18} color="white" />
          </button>
          <div className="spacer" />
        </div>
        <div style={{ position: "absolute", bottom: 16, left: 0, right: 0 }} className="screen-padding">
          <EyebrowLabel color="rgba(255,255,255,0.75)">core.</EyebrowLabel>
          <h1 className="brand" style={{ fontSize: 26, color: "white", margin: "2px 0 0" }}>{appState.clubName}</h1>
        </div>
      </div>

      <div className="screen-padding stack" style={{ gap: 16, marginTop: -40 }}>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
          <button onClick={() => navigate("/occupancy")} className="glass" style={{ border: "none", padding: 18, height: 196, textAlign: "left", color: "white", cursor: "pointer", display: "flex", flexDirection: "column" }}>
            <span className="brand" style={{ fontSize: 16 }}>{t("Occupancy")}</span>
            <span className="digital" style={{ fontSize: 48, marginTop: 4 }}>{appState.occupancyPercent}%</span>
            <div className="spacer" />
            <span className="pill" style={{ alignSelf: "flex-start" }}>{t("View more")}</span>
          </button>

          <button onClick={() => navigate("/specials")} className="glass" style={{ border: "none", padding: 18, height: 196, textAlign: "left", color: "white", cursor: "pointer", display: "flex", flexDirection: "column", background: "rgba(89,0,255,0.35)" }}>
            <span className="brand" style={{ fontSize: 16 }}>{t("home.specialsForToday")}</span>
            {appState.todaysSpecials.length > 0 && (
              <span style={{ fontSize: 12, opacity: 0.8, marginTop: 4 }}>
                {appState.todaysSpecials.length} {t("home.unbookedSlots")}
              </span>
            )}
            <div className="spacer" />
            <span className="pill" style={{ alignSelf: "flex-start" }}>{t("Check out")}</span>
          </button>
        </div>

        <button onClick={() => navigate("/progress")} className="card" style={{ border: "none", width: "100%", cursor: "pointer", color: "white" }}>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 10 }}>
            <StatTile label={t("Sets")} value={`${appState.trainingSetsToday}`} />
            <StatTile label={t("Time")} value={`${appState.trainingMinutesToday}m`} />
            <StatTile label={t("Calories")} value={`${appState.trainingCaloriesToday}`} />
          </div>
        </button>

        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 10 }}>
          {QUICK_ACTIONS.map(({ icon: Icon, title, to }) => (
            <button
              key={to}
              onClick={() => navigate(to)}
              className="card"
              style={{ border: "none", height: 100, cursor: "pointer", color: "white", display: "flex", flexDirection: "column", justifyContent: "space-between", alignItems: "flex-start" }}
            >
              <Icon size={24} />
              <span className="brand" style={{ fontSize: 13 }}>{t(title)}</span>
            </button>
          ))}
        </div>

        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
          <button onClick={() => navigate("/gym-safety")} style={{ border: "none", height: 140, borderRadius: "var(--r)", background: "linear-gradient(135deg, rgba(89,0,255,0.85), var(--accent-purple))", color: "white", textAlign: "left", padding: 16, cursor: "pointer", display: "flex", flexDirection: "column" }}>
            <Shield size={22} />
            <div className="spacer" />
            <span className="brand" style={{ fontSize: 16 }}>{t("Rules")}</span>
            <span style={{ fontSize: 11, opacity: 0.75 }}>{t("Rules & equipment guide")}</span>
          </button>
          <button onClick={() => navigate("/events")} style={{ border: "none", height: 140, borderRadius: "var(--r)", background: "linear-gradient(135deg, rgba(89,0,255,0.85), var(--accent-purple))", color: "white", textAlign: "left", padding: 16, cursor: "pointer", display: "flex", flexDirection: "column" }}>
            <PartyPopper size={22} />
            <div className="spacer" />
            <span className="brand" style={{ fontSize: 16 }}>{t("Events")}</span>
            <span style={{ fontSize: 11, opacity: 0.75 }}>{t("What's on this month")}</span>
          </button>
        </div>
      </div>
    </div>
  );
}

function StatTile({ label, value }: { label: string; value: string }) {
  return (
    <div className="stack" style={{ gap: 6, textAlign: "left" }}>
      <span className="brand" style={{ fontSize: 14 }}>{label}</span>
      <span className="digital" style={{ fontSize: 22 }}>{value}</span>
    </div>
  );
}
