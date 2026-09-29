import { cn } from "@/lib/utils";

// Логотип core. (вектор по фирменному файлу, повторяет public/brand/logo.svg). Цвет — currentColor, размер — по высоте через className.
export function Logo({ className, title = "core." }: { className?: string; title?: string }) {
  return (
    <svg viewBox="40 40 1420 357" role="img" aria-label={title} className={cn("h-6 w-auto", className)}>
      <path fill="currentColor" fillRule="evenodd" d="M392.7 190A176.5 176.5 0 1 0 393.3 243L307.7 243A92.5 92.5 0 1 1 306.5 190ZM585 42.0A176.5 176.5 0 1 0 585 395.0A176.5 176.5 0 1 0 585 42.0ZM585 126.0A92.5 92.5 0 1 1 585 311.0A92.5 92.5 0 1 1 585 126.0ZM776 46H858V390H776ZM858 92C885 58 925 42 972 42V125C925 125 886 140 858 172ZM1339.2 240A176.5 176.5 0 1 0 1333.4 268L1242.1 268A92.5 92.5 0 0 1 1074 240ZM1084 172A92.5 92.5 0 0 1 1244 172ZM1410 299A48 48 0 1 0 1410 395A48 48 0 1 0 1410 299Z" />
    </svg>
  );
}
