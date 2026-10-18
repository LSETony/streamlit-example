export function EyebrowLabel({ children, color }: { children: string; color?: string }) {
  return <div className="eyebrow" style={color ? { color } : undefined}>{children}</div>;
}
