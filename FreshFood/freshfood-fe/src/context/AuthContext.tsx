import React, { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { User } from '../types';

interface AuthContextType {
  user: User | null;
  login: (payload: { user: User; token: string; expiresInSeconds?: number }) => void;
  logout: () => void;
  isAuthenticated: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

type PersistedAuth = {
  user: User;
  token: string;
  expiresAt: number; // epoch ms
};

const AUTH_STORAGE_KEY = 'freshfood_auth';
const LEGACY_USER_STORAGE_KEY = 'freshfood_user';
const AUTH_TTL_MS = 24 * 60 * 60 * 1000; // 24h

function readPersistedAuth(): PersistedAuth | null {
  try {
    const raw = localStorage.getItem(AUTH_STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as PersistedAuth;
    if (!parsed?.user || typeof parsed.expiresAt !== 'number' || typeof (parsed as any).token !== 'string') return null;
    if (Date.now() >= parsed.expiresAt) return null;
    return parsed;
  } catch {
    return null;
  }
}

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<User | null>(() => {
    // Prefer new storage format; fallback to legacy key if present.
    const persisted = readPersistedAuth();
    if (persisted) return persisted.user;

    // Legacy: previously we stored plain user object forever.
    try {
      const legacy = localStorage.getItem(LEGACY_USER_STORAGE_KEY);
      if (!legacy) return null;
      const legacyUser = JSON.parse(legacy) as User;
      // Migrate to expiring auth on first load after update.
      const migrated: PersistedAuth = { user: legacyUser, token: '', expiresAt: Date.now() + AUTH_TTL_MS };
      localStorage.setItem(AUTH_STORAGE_KEY, JSON.stringify(migrated));
      localStorage.removeItem(LEGACY_USER_STORAGE_KEY);
      return legacyUser;
    } catch {
      localStorage.removeItem(LEGACY_USER_STORAGE_KEY);
      return null;
    }
  });

  const expiresAt = useMemo(() => {
    const persisted = readPersistedAuth();
    return persisted?.expiresAt ?? null;
  }, [user]);

  const login = (payload: { user: User; token: string; expiresInSeconds?: number }) => {
    const ttlMs =
      typeof payload.expiresInSeconds === 'number' && Number.isFinite(payload.expiresInSeconds) && payload.expiresInSeconds > 60
        ? payload.expiresInSeconds * 1000
        : AUTH_TTL_MS;
    setUser(payload.user);
    const persisted: PersistedAuth = { user: payload.user, token: payload.token, expiresAt: Date.now() + ttlMs };
    localStorage.setItem(AUTH_STORAGE_KEY, JSON.stringify(persisted));
  };

  const logout = () => {
    setUser(null);
    localStorage.removeItem(AUTH_STORAGE_KEY);
    localStorage.removeItem(LEGACY_USER_STORAGE_KEY);
  };

  useEffect(() => {
    // If persisted token expired (or was removed), ensure we clear state.
    const persisted = readPersistedAuth();
    if (!persisted && user) {
      setUser(null);
      localStorage.removeItem(AUTH_STORAGE_KEY);
      localStorage.removeItem(LEGACY_USER_STORAGE_KEY);
      return;
    }

    if (!persisted?.expiresAt) return;
    const msLeft = persisted.expiresAt - Date.now();
    if (msLeft <= 0) {
      logout();
      return;
    }
    const t = window.setTimeout(() => {
      logout();
    }, msLeft);
    return () => window.clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user]);

  return (
    <AuthContext.Provider value={{ user, login, logout, isAuthenticated: !!user }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be used within an AuthProvider');
  return context;
};
