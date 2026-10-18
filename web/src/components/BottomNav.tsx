import { Home, Calendar, Dumbbell, TrendingUp, User } from "lucide-react";
import { NavLink } from "react-router-dom";
import { useI18n } from "../i18n";

const tabs = [
  { to: "/", icon: Home, labelKey: "nav.home" as const },
  { to: "/calendar", icon: Calendar, labelKey: "Calendar" as const },
  { to: "/workouts", icon: Dumbbell, labelKey: "nav.workouts" as const },
  { to: "/progress", icon: TrendingUp, labelKey: "nav.progress" as const },
  { to: "/profile", icon: User, labelKey: "nav.profile" as const },
];

export function BottomNav() {
  const { t } = useI18n();
  return (
    <nav className="tab-bar">
      {tabs.map(({ to, icon: Icon, labelKey }) => (
        <NavLink key={to} to={to} end={to === "/"} className={({ isActive }) => `tab-item${isActive ? " active" : ""}`}>
          <Icon size={22} strokeWidth={2} />
          <span>{t(labelKey)}</span>
        </NavLink>
      ))}
    </nav>
  );
}
