import type { ReactNode } from "react";

interface PrimaryButtonProps {
  children: ReactNode;
  onClick?: () => void;
  disabled?: boolean;
  isLoading?: boolean;
  color?: "accent" | "purple";
  type?: "button" | "submit";
}

export function PrimaryButton({ children, onClick, disabled, isLoading, color = "accent", type = "button" }: PrimaryButtonProps) {
  return (
    <button
      type={type}
      className={`btn-primary ${color === "purple" ? "purple" : ""}`}
      onClick={onClick}
      disabled={disabled || isLoading}
    >
      {isLoading ? "…" : children}
    </button>
  );
}
