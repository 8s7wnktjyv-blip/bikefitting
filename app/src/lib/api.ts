// Verbindung zur FYF-Datenbank (Supabase, Region Frankfurt).
// Nur der öffentliche Schlüssel steht im Code. Geheime Schlüssel gehören nie in die App.
export const CONFIG = {
  url: 'https://tyfilehmrnibtoalwflf.supabase.co',
  key: 'sb_publishable_DUIWZF8H-BD-HaBUMvTg-A_pbpz1mgT',
};

// Zum Testen mit dem lokalen Testserver: ?api=http://localhost:8765 (nur localhost erlaubt)
(() => {
  try {
    const p = new URLSearchParams(location.search).get('api');
    if (p && /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(p)) CONFIG.url = p;
  } catch { /* egal */ }
})();

export type Session = { access_token: string; refresh_token: string; expires_at: number; user: { id: string; email?: string } };
const SKEY = 'fyf2:session';

export function loadSession(): Session | null {
  try { const s = JSON.parse(localStorage.getItem(SKEY) || 'null'); return s && s.access_token ? s : null; } catch { return null; }
}
function saveSession(s: Session | null) {
  try { s ? localStorage.setItem(SKEY, JSON.stringify(s)) : localStorage.removeItem(SKEY); } catch { /* privat-Modus */ }
}

async function raw(path: string, init: RequestInit = {}, token?: string) {
  const headers: Record<string, string> = { apikey: CONFIG.key, 'Content-Type': 'application/json', ...(init.headers as Record<string, string> || {}) };
  if (token) headers.Authorization = 'Bearer ' + token;
  const r = await fetch(CONFIG.url + path, { ...init, headers });
  const txt = await r.text();
  let body: unknown = null; try { body = txt ? JSON.parse(txt) : null; } catch { body = txt; }
  if (!r.ok) {
    const b = body as { message?: string; msg?: string; error_description?: string } | null;
    throw new Error((b && (b.message || b.msg || b.error_description)) || ('Fehler ' + r.status));
  }
  return body;
}

function toSession(b: any): Session {
  return { access_token: b.access_token, refresh_token: b.refresh_token, expires_at: b.expires_at || Math.floor(Date.now() / 1000) + (b.expires_in || 3600), user: b.user };
}

export async function sendCode(email: string) {
  await raw('/auth/v1/otp', { method: 'POST', body: JSON.stringify({ email, create_user: true }) });
}
export async function verifyCode(email: string, token: string) {
  const b = await raw('/auth/v1/verify', { method: 'POST', body: JSON.stringify({ type: 'email', email, token }) });
  const s = toSession(b); saveSession(s); return s;
}
export async function validToken(): Promise<string | null> {
  const s = loadSession(); if (!s) return null;
  if (s.expires_at - 60 > Date.now() / 1000) return s.access_token;
  try {
    const b = await raw('/auth/v1/token?grant_type=refresh_token', { method: 'POST', body: JSON.stringify({ refresh_token: s.refresh_token }) });
    const n = toSession(b); saveSession(n); return n.access_token;
  } catch { saveSession(null); return null; }
}
export function logout() { saveSession(null); }

export async function select<T = any>(table: string, query: string): Promise<T[]> {
  const t = await validToken(); if (!t) throw new Error('Nicht angemeldet');
  return (await raw(`/rest/v1/${table}?${query}`, { method: 'GET' }, t)) as T[];
}
export async function rpc<T = any>(fn: string, args: Record<string, unknown> = {}): Promise<T> {
  const t = await validToken(); if (!t) throw new Error('Nicht angemeldet');
  return (await raw(`/rest/v1/rpc/${fn}`, { method: 'POST', body: JSON.stringify(args) }, t)) as T;
}

export type Membership = { tenant_id: string; role: string; tenants?: { name?: string } | null };
export async function myMemberships(): Promise<Membership[]> {
  const s = loadSession(); if (!s) return [];
  return select<Membership>('memberships', `user_id=eq.${encodeURIComponent(s.user.id)}&select=tenant_id,role,tenants(name)`);
}

// Liest Kennzahlen aus dem bisherigen Speicher (ein Datensatz je Laden) – nur lesen, nichts ändern.
export async function legacyCounts(tenant: string) {
  const rows = await select<any>('tenant_state', `tenant_id=eq.${encodeURIComponent(tenant)}&select=version,updated_at,customers:data->customers,bikes:data->bikes,workshop:data->workshop,invoices:data->invoices`);
  const r = rows[0]; if (!r) return null;
  const n = (x: unknown) => (Array.isArray(x) ? x.length : 0);
  return { version: r.version as number, updated: r.updated_at as string, customers: n(r.customers), bikes: n(r.bikes), workshop: n(r.workshop), invoices: n(r.invoices) };
}

// Bisheriger Speicher: Kunden, Räder, Aufträge, Rechnungen lesen (nur lesen, bis die Tabellen aktiv sind)
export type LegacyCustomer = { id: string; name: string; email?: string; phone?: string; kind?: string; company?: string; vatId?: string; address?: string;
  contacts?: { name?: string; role?: string; phone?: string; email?: string }[]; wv?: { id: string; due: string; text: string; done?: string }[]; consent?: boolean; since?: string; discipline?: string; invAddr?: { company?: string } };
export type LegacyBike = { id: string; customerId: string; brand?: string; model?: string; type?: string; size?: string; qr?: { code?: string } };
export type LegacyWO = { id: string; customerId: string; bikeId?: string; title: string; status: string; due?: string };
export type LegacyInvoice = { id: string; no?: string; customerId?: string; date?: string; type?: string };
export async function legacyData(tenant: string) {
  const rows = await select<any>('tenant_state', `tenant_id=eq.${encodeURIComponent(tenant)}&select=version,updated_at,customers:data->customers,bikes:data->bikes,workshop:data->workshop,invoices:data->invoices`);
  const r = rows[0]; if (!r) return null;
  const a = <T,>(x: unknown) => (Array.isArray(x) ? (x as T[]) : []);
  return { version: r.version as number, customers: a<LegacyCustomer>(r.customers), bikes: a<LegacyBike>(r.bikes), workshop: a<LegacyWO>(r.workshop), invoices: a<LegacyInvoice>(r.invoices) };
}
