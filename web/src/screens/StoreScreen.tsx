import { useNavigate } from "react-router-dom";
import { ShoppingCart } from "lucide-react";
import { useAppState } from "../context/AppStateContext";
import { useI18n } from "../i18n";
import { PageHeader } from "../components/PageHeader";

export function StoreScreen() {
  const { t } = useI18n();
  const navigate = useNavigate();
  const { products, cartCount } = useAppState();

  return (
    <div className="page">
      <PageHeader
        title={t("Store")}
        trailing={
          <button onClick={() => navigate("/cart")} style={{ position: "relative", background: "none", border: "none", color: "white", cursor: "pointer" }}>
            <ShoppingCart size={22} />
            {cartCount > 0 && (
              <span style={{ position: "absolute", top: -4, right: -6, background: "var(--accent)", borderRadius: "50%", fontSize: 10, width: 16, height: 16, display: "flex", alignItems: "center", justifyContent: "center" }}>
                {cartCount}
              </span>
            )}
          </button>
        }
      />
      <div className="screen-padding" style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
        {products.map((product) => (
          <button
            key={product.id}
            onClick={() => navigate(`/store/${product.id}`)}
            className="card stack"
            style={{ gap: 8, border: "none", cursor: "pointer", textAlign: "left", color: "white", height: 180 }}
          >
            <div className="row">
              <span className="icon-circle" style={{ width: 32, height: 32, background: "var(--accent-dim)", color: "var(--accent)", fontSize: 13, fontWeight: 700 }}>
                {product.abbr}
              </span>
              <div className="spacer" />
              <span className="pill" style={{ fontSize: 10 }}>{product.tag}</span>
            </div>
            <span className="brand" style={{ fontSize: 15 }}>{t(product.name)}</span>
            <div className="spacer" />
            <span className="digital" style={{ fontSize: 16 }}>${product.price}</span>
          </button>
        ))}
      </div>
    </div>
  );
}
