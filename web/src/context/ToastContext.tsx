import { createContext, useCallback, useContext, useMemo, useRef, useState, type ReactNode } from "react";

export interface ToastSpec {
  icon?: string;
  title: string;
  subtitle?: string;
  accent?: string;
  duration?: number;
}

interface Toast extends ToastSpec {
  id: number;
}

interface ToastContextValue {
  trigger: (toast: ToastSpec) => void;
}

const ToastContext = createContext<ToastContextValue | null>(null);

/// Web stand-in for DynamicNotificationCenter — there's no Dynamic Island
/// on the web, so this surfaces the same triggers as a stack of toasts
/// pinned to the top of the viewport instead.
export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);
  const nextId = useRef(0);

  const trigger = useCallback((toast: ToastSpec) => {
    const id = nextId.current++;
    setToasts((prev) => [...prev, { ...toast, id }]);
    const duration = (toast.duration ?? 3) * 1000;
    setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== id));
    }, duration);
  }, []);

  const value = useMemo(() => ({ trigger }), [trigger]);

  return (
    <ToastContext.Provider value={value}>
      {children}
      <div className="toast-stack">
        {toasts.map((toast) => (
          <div className="toast" key={toast.id}>
            <span
              className="icon-circle"
              style={{ width: 28, height: 28, background: toast.accent ?? "var(--accent)", flexShrink: 0 }}
            >
              {toast.icon ?? "●"}
            </span>
            <div className="stack" style={{ minWidth: 0 }}>
              <span style={{ fontSize: 13, fontWeight: 600, color: "white", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
                {toast.title}
              </span>
              {toast.subtitle && (
                <span style={{ fontSize: 11, color: "rgba(255,255,255,0.7)", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
                  {toast.subtitle}
                </span>
              )}
            </div>
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}

export function useToast(): ToastContextValue {
  const ctx = useContext(ToastContext);
  if (!ctx) throw new Error("useToast must be used within a ToastProvider");
  return ctx;
}
