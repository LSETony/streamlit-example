import { Check } from "lucide-react";
import { useI18n, languageNativeName, type Language } from "../i18n";
import { EyebrowLabel } from "../components/EyebrowLabel";
import { Sheet } from "../components/Sheet";
import { PageHeader } from "../components/PageHeader";

const LANGUAGES: Language[] = ["en", "ru"];

function Rows({ onPick }: { onPick?: () => void }) {
  const { language, setLanguage } = useI18n();
  return (
    <div className="stack" style={{ gap: 8 }}>
      {LANGUAGES.map((lang) => (
        <button
          key={lang}
          onClick={() => {
            setLanguage(lang);
            onPick?.();
          }}
          className="row"
          style={{
            background: "var(--surf)",
            border: "none",
            borderRadius: "var(--r-s)",
            padding: "14px 16px",
            color: "white",
            fontSize: 16,
            cursor: "pointer",
          }}
        >
          <span>{languageNativeName[lang]}</span>
          <div className="spacer" />
          {language === lang && <Check size={18} color="var(--accent)" />}
        </button>
      ))}
    </div>
  );
}

export function LanguagePickerScreen({ onClose, asSheet }: { onClose?: () => void; asSheet?: boolean }) {
  const { t } = useI18n();
  if (asSheet && onClose) {
    return (
      <Sheet onClose={onClose} title={t("Language")}>
        <Rows onPick={onClose} />
      </Sheet>
    );
  }
  return (
    <div className="page">
      <PageHeader title={t("Language")} />
      <div className="screen-padding stack" style={{ gap: 16 }}>
        <EyebrowLabel>{t("Settings")}</EyebrowLabel>
        <Rows />
      </div>
    </div>
  );
}
