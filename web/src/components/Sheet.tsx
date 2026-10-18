import type { ReactNode } from "react";
import { useI18n } from "../i18n";

interface SheetProps {
  onClose: () => void;
  title?: string;
  children: ReactNode;
  footer?: ReactNode;
}

/// Bottom sheet modal — stand-in for SwiftUI's `.sheet(isPresented:)`.
export function Sheet({ onClose, title, children, footer }: SheetProps) {
  const { t } = useI18n();
  return (
    <div className="sheet-overlay" onClick={onClose}>
      <div className="sheet" onClick={(e) => e.stopPropagation()}>
        <div className="row screen-padding" style={{ paddingTop: 16, paddingBottom: 8, position: "sticky", top: 0, background: "var(--bg)", zIndex: 1 }}>
          {title && <h2 className="brand" style={{ fontSize: 20, margin: 0 }}>{title}</h2>}
          <div className="spacer" />
          <button
            onClick={onClose}
            aria-label={t("common.close")}
            style={{
              background: "rgba(255,255,255,0.1)",
              border: "none",
              borderRadius: "50%",
              width: 32,
              height: 32,
              color: "white",
              fontSize: 16,
              cursor: "pointer",
            }}
          >
            ✕
          </button>
        </div>
        <div className="screen-padding" style={{ paddingTop: 8, paddingBottom: 24 }}>
          {children}
        </div>
        {footer && <div className="screen-padding" style={{ paddingBottom: 20 }}>{footer}</div>}
      </div>
    </div>
  );
}
