import { QRCodeSVG } from "qrcode.react";
import { useAppState } from "../context/AppStateContext";
import { useI18n } from "../i18n";
import { deviceUserId } from "../lib/deviceUser";
import { PageHeader } from "../components/PageHeader";

export function QRPassScreen() {
  const { t } = useI18n();
  const { fullName, membershipPlanName } = useAppState();

  return (
    <div className="page">
      <PageHeader title={t("QR Pass")} />
      <div className="screen-padding stack" style={{ gap: 16, alignItems: "center", textAlign: "center", marginTop: 20 }}>
        <div style={{ background: "white", borderRadius: 20, padding: 20 }}>
          <QRCodeSVG value={`core-member:${deviceUserId}`} size={220} />
        </div>
        <span className="brand" style={{ fontSize: 20, color: "white" }}>{fullName}</span>
        <span className="pill">{membershipPlanName}</span>
        <span style={{ fontSize: 13, color: "var(--muted)" }}>{t("Show this at reception to check in.")}</span>
      </div>
    </div>
  );
}
