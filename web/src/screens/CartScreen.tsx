import { useAppState } from "../context/AppStateContext";
import { useI18n } from "../i18n";
import { useToast } from "../context/ToastContext";
import { PageHeader } from "../components/PageHeader";
import { PrimaryButton } from "../components/PrimaryButton";

export function CartScreen() {
  const { t } = useI18n();
  const { cart, cartTotal, removeFromCart, clearCart } = useAppState();
  const { trigger } = useToast();

  async function checkout() {
    await clearCart();
    trigger({ icon: "✅", title: t("Order placed"), subtitle: t("Payment successful"), accent: "var(--good)" });
  }

  return (
    <div className="page">
      <PageHeader title={t("cart.title")} />
      <div className="screen-padding stack" style={{ gap: 14 }}>
        {cart.length === 0 && <span style={{ color: "var(--muted)" }}>{t("cart.empty")}</span>}
        {cart.map((line) => (
          <div key={line.id} className="row card" style={{ gap: 10 }}>
            <span style={{ fontSize: 14 }}>{t(line.name)}</span>
            <div className="spacer" />
            <span className="digital">${line.price}</span>
            <button onClick={() => removeFromCart(line)} style={{ background: "none", border: "none", color: "var(--muted)", cursor: "pointer", fontSize: 13 }}>
              {t("cart.remove")}
            </button>
          </div>
        ))}
        {cart.length > 0 && (
          <>
            <div className="row" style={{ padding: "10px 0" }}>
              <span style={{ fontWeight: 600 }}>{t("cart.subtotal")}</span>
              <div className="spacer" />
              <span className="digital" style={{ fontSize: 18 }}>${cartTotal}</span>
            </div>
            <PrimaryButton color="purple" onClick={checkout}>
              {t("cart.checkout")}
            </PrimaryButton>
          </>
        )}
      </div>
    </div>
  );
}
