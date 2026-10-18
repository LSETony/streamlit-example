import { useAppState } from "../context/AppStateContext";
import { useI18n } from "../i18n";
import { PageHeader } from "../components/PageHeader";
import { PrimaryButton } from "../components/PrimaryButton";

export function TodaysSpecialsScreen() {
  const { t } = useI18n();
  const { todaysSpecials, bookTrainerSpecial } = useAppState();

  return (
    <div className="page">
      <PageHeader title={t("home.specialsForToday")} />
      <div className="screen-padding stack" style={{ gap: 12 }}>
        {todaysSpecials.length === 0 && <span style={{ color: "var(--muted)" }}>{t("No discounted slots left today.")}</span>}
        {todaysSpecials.map((special) => (
          <div key={special.id} className="card stack" style={{ gap: 10 }}>
            <div className="row">
              <div className="stack">
                <span className="brand" style={{ fontSize: 16 }}>{special.trainer.name}</span>
                <span style={{ fontSize: 12, color: "var(--muted)" }}>{special.trainer.specialty} · {special.time}</span>
              </div>
              <div className="spacer" />
              <div className="stack" style={{ alignItems: "flex-end" }}>
                <span style={{ textDecoration: "line-through", color: "var(--muted)", fontSize: 12 }}>${special.originalPrice}</span>
                <span className="digital" style={{ fontSize: 18, color: "var(--accent)" }}>${special.discountedPrice}</span>
              </div>
            </div>
            <PrimaryButton color="purple" onClick={() => bookTrainerSpecial(special)}>
              {t("specials.bookOff")} {special.discountPercent}{t("specials.percentOff")}
            </PrimaryButton>
          </div>
        ))}
      </div>
    </div>
  );
}
