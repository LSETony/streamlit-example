import { useParams } from "react-router-dom";
import { useAppState } from "../context/AppStateContext";
import { useI18n } from "../i18n";
import { useToast } from "../context/ToastContext";
import { PageHeader } from "../components/PageHeader";
import { EyebrowLabel } from "../components/EyebrowLabel";
import { PrimaryButton } from "../components/PrimaryButton";

export function ProductDetailScreen() {
  const { t } = useI18n();
  const { id } = useParams();
  const { products, addToCart } = useAppState();
  const { trigger } = useToast();
  const product = products.find((p) => p.id === id);

  if (!product) {
    return (
      <div className="page">
        <PageHeader />
        <div className="screen-padding">{t("Product not found.")}</div>
      </div>
    );
  }

  const theProduct = product;

  function add() {
    addToCart(theProduct);
    trigger({ icon: "🛒", title: "Added to cart", subtitle: theProduct.name, accent: "var(--accent)" });
  }

  return (
    <div className="page">
      <PageHeader />
      <div className="screen-padding stack" style={{ gap: 18 }}>
        <div className="row">
          <span className="icon-circle" style={{ width: 44, height: 44, background: "var(--accent-dim)", color: "var(--accent)", fontWeight: 700 }}>
            {product.abbr}
          </span>
          <div className="spacer" />
          <span className="pill">{t(product.tag)}</span>
        </div>
        <h1 className="brand" style={{ fontSize: 26, color: "white", margin: 0 }}>{t(product.name)}</h1>
        <span style={{ fontSize: 14, color: "rgba(255,255,255,0.85)", lineHeight: 1.5 }}>{product.desc}</span>

        <EyebrowLabel>{t("Ingredients per serving")}</EyebrowLabel>
        <div className="stack" style={{ gap: 0 }}>
          {product.ingredients.map((ing, i) => (
            <div key={ing.name} className="row" style={{ padding: "8px 0", borderBottom: i < product.ingredients.length - 1 ? "1px solid var(--line)" : "none" }}>
              <span style={{ fontSize: 13 }}>{ing.name}</span>
              <div className="spacer" />
              <span style={{ fontSize: 13, color: "var(--muted)" }}>{ing.amount}</span>
            </div>
          ))}
        </div>

        <EyebrowLabel>{t("Benefits")}</EyebrowLabel>
        <span style={{ fontSize: 13, color: "var(--muted)" }}>{product.benefits}</span>

        <EyebrowLabel color="var(--warn)">{t("Risks and cautions")}</EyebrowLabel>
        <span style={{ fontSize: 13, color: "var(--muted)" }}>{product.risks}</span>

        <EyebrowLabel color="var(--warn)">{t("Interactions")}</EyebrowLabel>
        <span style={{ fontSize: 13, color: "var(--muted)" }}>{product.interactions}</span>

        <PrimaryButton onClick={add}>Add to cart — ${product.price}</PrimaryButton>
      </div>
    </div>
  );
}
