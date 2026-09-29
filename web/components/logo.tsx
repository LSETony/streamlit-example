import { useId } from "react";
import { cn } from "@/lib/utils";

// Логотип core. (вектор, повторяет public/brand/logo.svg). Цвет — currentColor, размер — по высоте через className.
export function Logo({ className, title = "core." }: { className?: string; title?: string }) {
  // у каждого экземпляра своя маска: ссылка на маску внутри скрытого (display:none) логотипа не рисуется
  const maskId = `core-logo-${useId().replace(/[^a-zA-Z0-9_-]/g, "")}`;
  return (
    <svg viewBox="228 444 622 168" role="img" aria-label={title} className={cn("h-7 w-auto", className)}>
      <defs>
        <mask id={maskId} maskUnits="userSpaceOnUse" x="228" y="444" width="622" height="168">
          <rect x="228" y="444" width="622" height="168" fill="#fff" />
          <rect x="340" y="516" width="48" height="23" fill="#000" />
          <rect x="700" y="537" width="80" height="11" fill="#000" />
        </mask>
      </defs>
      <g fill="currentColor" mask={`url(#${maskId})`}>
        <path fillRule="evenodd" d="M310 452a76 76 0 1 0 0.01 0Zm0 36a40 40 0 1 1 -0.01 0Z" />
        <path fillRule="evenodd" d="M467 452a76 76 0 1 0 0.01 0Zm0 36a40 40 0 1 1 -0.01 0Z" />
        <path fillRule="evenodd" d="M702 452a62 76 0 1 0 0.01 0Zm0 36a26 40 0 1 1 -0.01 0Z" />
      </g>
      <g fill="currentColor">
        <rect x="550" y="454" width="35" height="147" />
        <path d="M585 510C595 495 612 488 633 488V452C609 452 593 461 581 476Z" />
        <rect x="650" y="509" width="114" height="28" />
        <circle cx="821" cy="583" r="21" />
      </g>
    </svg>
  );
}
