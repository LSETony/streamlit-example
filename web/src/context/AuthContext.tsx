import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { supabase } from "../lib/supabase";

export interface AuthUser {
  id: string;
  name: string;
  email: string | null;
}

const PERSISTED_USER_KEY = "core.auth.persistedUser";

function loadPersistedUser(): AuthUser | null {
  try {
    const raw = localStorage.getItem(PERSISTED_USER_KEY);
    return raw ? (JSON.parse(raw) as AuthUser) : null;
  } catch {
    return null;
  }
}

function persistUser(user: AuthUser | null) {
  try {
    if (user) localStorage.setItem(PERSISTED_USER_KEY, JSON.stringify(user));
    else localStorage.removeItem(PERSISTED_USER_KEY);
  } catch {
    // Ignore — worst case the member has to sign in again next visit.
  }
}

interface AuthContextValue {
  user: AuthUser | null;
  isAuthenticated: boolean;
  isBusy: boolean;
  error: string | null;
  clearError: () => void;
  startEmailRegistration: (email: string) => Promise<boolean>;
  verifyEmailCode: (name: string, email: string, code: string) => Promise<boolean>;
  signOut: () => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

/// Web port of AuthService.swift. Apple/Google sign-in need a native shell
/// or OAuth app registration this project doesn't have on the web, so this
/// only wires up email OTP — the one provider that's genuinely identical
/// on every platform, since it's just Supabase Auth over HTTPS.
export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(() => loadPersistedUser());
  const [isBusy, setIsBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    persistUser(user);
  }, [user]);

  // Quietly catch a persisted sign-in that's no longer backed by a real
  // Supabase session (expired token, etc.) — same idea as
  // AuthService.validatePersistedSession() on iOS.
  useEffect(() => {
    if (!user) return;
    supabase.auth.getSession().then(({ data }) => {
      if (!data.session) {
        setUser(null);
      }
    });
  }, [user]);

  const clearError = useCallback(() => setError(null), []);

  const startEmailRegistration = useCallback(async (email: string) => {
    setError(null);
    setIsBusy(true);
    try {
      const { error: err } = await supabase.auth.signInWithOtp({ email });
      if (err) throw err;
      return true;
    } catch (err) {
      setError(friendlyMessage(err));
      return false;
    } finally {
      setIsBusy(false);
    }
  }, []);

  const verifyEmailCode = useCallback(async (name: string, email: string, code: string) => {
    setError(null);
    setIsBusy(true);
    try {
      const { error: err } = await supabase.auth.verifyOtp({ email, token: code, type: "email" });
      if (err) throw err;
      const trimmed = name.trim();
      setUser({ id: email, name: trimmed.length > 0 ? trimmed : "Member", email });
      return true;
    } catch (err) {
      setError(friendlyMessage(err));
      return false;
    } finally {
      setIsBusy(false);
    }
  }, []);

  const signOut = useCallback(() => {
    supabase.auth.signOut().catch(() => {});
    setUser(null);
  }, []);

  const value = useMemo(
    () => ({
      user,
      isAuthenticated: user !== null,
      isBusy,
      error,
      clearError,
      startEmailRegistration,
      verifyEmailCode,
      signOut,
    }),
    [user, isBusy, error, clearError, startEmailRegistration, verifyEmailCode, signOut]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

function friendlyMessage(err: unknown): string {
  const message = err instanceof Error ? err.message : String(err);
  if (message.toLowerCase().includes("rate limit")) {
    return "Too many sign-in emails sent recently — wait a few minutes and try again.";
  }
  return message;
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within an AuthProvider");
  return ctx;
}
