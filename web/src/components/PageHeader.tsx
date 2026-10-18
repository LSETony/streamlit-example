import { ChevronLeft } from "lucide-react";
import { useNavigate } from "react-router-dom";
import type { ReactNode } from "react";

interface PageHeaderProps {
  title?: string;
  trailing?: ReactNode;
  onBack?: () => void;
}

/// Top bar for a pushed screen (anything not one of the 5 main tabs) —
/// back chevron + optional title + trailing action, same role as
/// `.navigationBarTitleDisplayMode(.inline)` + a toolbar button on iOS.
export function PageHeader({ title, trailing, onBack }: PageHeaderProps) {
  const navigate = useNavigate();
  return (
    <div
      className="row screen-padding"
      style={{ paddingTop: "calc(14px + env(safe-area-inset-top))", paddingBottom: 10, position: "relative" }}
    >
      <button
        onClick={onBack ?? (() => navigate(-1))}
        aria-label="Back"
        style={{ background: "none", border: "none", color: "var(--accent)", cursor: "pointer", padding: 4, display: "flex" }}
      >
        <ChevronLeft size={26} />
      </button>
      {title && <h1 className="brand" style={{ fontSize: 17, margin: "0 auto", position: "absolute", left: "50%", transform: "translateX(-50%)" }}>{title}</h1>}
      <div className="spacer" />
      {trailing}
    </div>
  );
}
