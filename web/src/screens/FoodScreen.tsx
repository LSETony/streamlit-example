import { useAppState } from "../context/AppStateContext";
import { useI18n } from "../i18n";
import { PageHeader } from "../components/PageHeader";

export function FoodScreen() {
  const { t } = useI18n();
  const { foodRecipes } = useAppState();

  return (
    <div className="page">
      <PageHeader title={t("Food")} />
      <div className="screen-padding stack" style={{ gap: 12 }}>
        {foodRecipes.map((recipe) => (
          <div
            key={recipe.id}
            className="row card"
            style={{
              gap: 14,
              background: recipe.imageURL ? `linear-gradient(90deg, rgba(20,20,23,0.4), rgba(20,20,23,0.95)), url(${recipe.imageURL}) center/cover` : "var(--surf)",
              minHeight: 90,
            }}
          >
            <div className="stack" style={{ gap: 4 }}>
              <span className="brand" style={{ fontSize: 16 }}>{recipe.name}</span>
              <span style={{ fontSize: 12, color: "var(--muted)" }}>{recipe.ingredients.join(", ")}</span>
            </div>
            <div className="spacer" />
            <span className="digital" style={{ fontSize: 16 }}>${recipe.price}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
