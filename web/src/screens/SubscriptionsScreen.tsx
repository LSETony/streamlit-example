import { useAppState } from "../context/AppStateContext";
import { useI18n } from "../i18n";
import { PageHeader } from "../components/PageHeader";
import { EyebrowLabel } from "../components/EyebrowLabel";
import { PrimaryButton } from "../components/PrimaryButton";

export function SubscriptionsScreen() {
  const { t } = useI18n();
  const { subscriptionPlans, membershipPlanName, membershipPlanNameSet, membershipRenewDate } = useAppState();
  const currentPlan = subscriptionPlans.find((p) => p.name === membershipPlanName);

  return (
    <div className="page">
      <PageHeader title={t("Membership")} />
      <div className="screen-padding stack" style={{ gap: 20 }}>
        <div className="card" style={{ background: "var(--accent-purple)" }}>
          <EyebrowLabel color="rgba(255,255,255,0.85)">{t("Membership")}</EyebrowLabel>
          <div className="digital" style={{ fontSize: 30, marginTop: 4 }}>{t(membershipPlanName)}</div>
          {currentPlan && <span style={{ fontSize: 14, opacity: 0.85 }}>${currentPlan.price}/{currentPlan.period}</span>}
        </div>

        <div className="card stack" style={{ gap: 6 }}>
          <EyebrowLabel>{t("Active until")}</EyebrowLabel>
          <span className="digital" style={{ fontSize: 24 }}>{membershipRenewDate}</span>
          <span style={{ fontSize: 13, color: "var(--muted)" }}>{t("Your membership auto-renews on this date unless cancelled.")}</span>
        </div>

        <div className="stack" style={{ gap: 12 }}>
          <EyebrowLabel>{t("Change plan")}</EyebrowLabel>
          {subscriptionPlans.map((plan) => {
            const isCurrent = plan.name === membershipPlanName;
            return (
              <div key={plan.id} className="card stack" style={{ gap: 10, border: plan.recommended ? "1px solid var(--accent)" : undefined }}>
                <div className="row">
                  <span className="brand" style={{ fontSize: 17 }}>{t(plan.name)}</span>
                  <div className="spacer" />
                  <span className="digital">${plan.price}/{plan.period}</span>
                </div>
                <div className="stack" style={{ gap: 4 }}>
                  {plan.perks.map((perk) => (
                    <span key={perk} style={{ fontSize: 13, color: "var(--muted)" }}>✓ {perk}</span>
                  ))}
                </div>
                <PrimaryButton color={isCurrent ? "accent" : "purple"} disabled={isCurrent} onClick={() => membershipPlanNameSet(plan.name)}>
                  {isCurrent ? t("Current plan") : `${t("subscriptions.switchTo")} ${t(plan.name)}`}
                </PrimaryButton>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
