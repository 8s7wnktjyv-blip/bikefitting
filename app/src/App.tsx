import React, { useEffect, useState } from 'react';
import { loadSession, sendCode, verifyCode, logout, myMemberships, legacyCounts, Membership } from './lib/api';
import { MODULES, STATUS_TEXT, Mod } from './modules/registry';
import Kunden from './modules/Kunden';

const LEGACY_APP = '../index.html';
const chip = (s: Mod['status']) => (s === 'neu' ? 'c-ok' : s === 'alt' ? 'c-acc' : 'c-bad');

function useHash() {
  const [h, setH] = useState(location.hash.replace(/^#\/?/, '') || 'cockpit');
  useEffect(() => { const f = () => setH(location.hash.replace(/^#\/?/, '') || 'cockpit'); addEventListener('hashchange', f); return () => removeEventListener('hashchange', f); }, []);
  return h;
}

function Login({ onDone }: { onDone: () => void }) {
  const [email, setEmail] = useState(''); const [code, setCode] = useState(''); const [sent, setSent] = useState(false);
  const [busy, setBusy] = useState(false); const [err, setErr] = useState('');
  const go = async (e: React.FormEvent) => {
    e.preventDefault(); setErr(''); setBusy(true);
    try { if (!sent) { await sendCode(email.trim()); setSent(true); } else { await verifyCode(email.trim(), code.trim()); onDone(); } }
    catch (x) { setErr((x as Error).message || 'Fehler'); } finally { setBusy(false); }
  };
  return (
    <div className="np-center"><form className="panel np-login" onSubmit={go}>
      <h1>Anmelden</h1>
      <p className="muted">Neue FYF-Plattform (Vorschau). Gleiches Konto wie in der bisherigen App.</p>
      <div className="field"><label htmlFor="em">E-Mail</label><input id="em" className="input" type="email" required autoComplete="email" value={email} onChange={e => setEmail(e.target.value)} disabled={sent} /></div>
      {sent && <div className="field"><label htmlFor="cd">Code aus der E-Mail</label><input id="cd" className="input" inputMode="numeric" required value={code} onChange={e => setCode(e.target.value)} /></div>}
      {err && <p className="np-err" role="alert">{err}</p>}
      <button className="btn primary" type="submit" disabled={busy}>{busy ? 'Bitte warten …' : sent ? 'Anmelden' : 'Code schicken'}</button>
      <a className="btn ghost" href={LEGACY_APP}>‹ Zur bisherigen App</a>
    </form></div>
  );
}

function Cockpit({ m }: { m: Membership }) {
  const [c, setC] = useState<Awaited<ReturnType<typeof legacyCounts>> | 'err' | null>(null);
  useEffect(() => { legacyCounts(m.tenant_id).then(setC).catch(() => setC('err')); }, [m.tenant_id]);
  return (<>
    <div className="pagehead"><h1>Cockpit</h1><p className="muted">{m.tenants?.name || 'Dein Laden'} · Rolle: {m.role}</p></div>
    <div className="notice warn"><span><b>Vorschau der neuen Plattform.</b> Deine Daten liegen weiter im bisherigen Speicher und werden hier nur gelesen. Gearbeitet wird bis zur Freigabe in der bisherigen App.</span></div>
    <div className="panel np-pad"><h3>Daten im bisherigen Speicher</h3>
      {c === null ? <p className="muted">Lade …</p> : c === 'err' ? <p className="muted">Konnte nicht gelesen werden (keine Cloud-Speicherung eingerichtet?).</p> : !c ? <p className="muted">Noch kein Stand in der Cloud gespeichert.</p> :
        <div className="np-kpis">{[['Kunden', c.customers], ['Fahrräder', c.bikes], ['Werkstattaufträge', c.workshop], ['Rechnungen', c.invoices]].map(([l, v]) =>
          <div key={l as string} className="np-kpi"><span className="label">{l}</span><b>{v as number}</b></div>)}
          <p className="faint np-full">Stand {c.version} · gespeichert {new Date(c.updated).toLocaleString('de-DE')}</p></div>}
    </div>
    <div className="panel np-pad"><h3>Stand der Übertragung</h3>
      <div className="list">{MODULES.map(x => (
        <div key={x.id} className="li np-li"><div><b>{x.area}. {x.label}</b><div className="faint">{x.note}</div></div><span className={'chip nodot ' + chip(x.status)}>{STATUS_TEXT[x.status]}</span></div>))}</div>
    </div>
  </>);
}

function ModPage({ mod }: { mod: Mod }) {
  return (<>
    <div className="pagehead"><h1>{mod.label}</h1><p className="muted">{mod.note}</p></div>
    <div className="panel np-pad">
      <p><span className={'chip nodot ' + chip(mod.status)}>{STATUS_TEXT[mod.status]}</span></p>
      {mod.status === 'alt' && <><p>Dieses Modul ist noch nicht in die neue Plattform übertragen. Bitte in der bisherigen App arbeiten, dort ist alles vorhanden.</p>
        <a className="btn primary" href={`${LEGACY_APP}#${mod.legacy || ''}`}>In der bisherigen App öffnen</a></>}
      {mod.status === 'fehlt' && <p>Dieses Modul gibt es noch nicht. Es ist im Entwicklungsplan eingeplant.</p>}
    </div>
  </>);
}

export default function App() {
  const [session, setSession] = useState(loadSession());
  const [mem, setMem] = useState<Membership[] | null>(null); const [err, setErr] = useState('');
  const route = useHash();
  useEffect(() => { if (!session) return; myMemberships().then(setMem).catch(e => setErr((e as Error).message)); }, [session]);
  if (!session) return <Login onDone={() => setSession(loadSession())} />;
  const m = mem && mem[0];
  const mod = MODULES.find(x => x.id === route) || MODULES[0];
  return (
    <div className="np-app">
      <nav className="np-side" aria-label="Module">
        <div className="np-brand"><b>FYF</b><span className="faint">Plattform · Vorschau</span></div>
        {MODULES.map(x => <a key={x.id} href={'#/' + x.id} className={'np-nav' + (x.id === mod.id ? ' on' : '')} aria-current={x.id === mod.id ? 'page' : undefined}>
          <span>{x.label}</span>{x.status !== 'neu' && <span className="np-dot" title={STATUS_TEXT[x.status]} />}</a>)}
        <div className="np-foot"><a className="btn ghost sm" href={LEGACY_APP}>‹ Bisherige App</a><button className="btn ghost sm" onClick={() => { logout(); setSession(null); setMem(null); }}>Abmelden</button></div>
      </nav>
      <main className="np-main">
        {err ? <div className="notice"><span>{err}</span></div> :
          mem === null ? <p className="muted">Lade …</p> :
            !m ? <div className="panel np-pad"><h2>Noch kein Laden</h2><p>Dein Konto gehört noch zu keinem Laden. Bitte zuerst in der bisherigen App unter „Mehr → Cloud-Speicherung“ einrichten oder dich einladen lassen.</p><a className="btn primary" href={LEGACY_APP}>Zur bisherigen App</a></div> :
              mod.id === 'cockpit' ? <Cockpit m={m} /> : mod.id === 'kunden' ? <Kunden tenant={m.tenant_id} legacyApp={LEGACY_APP} /> : <ModPage mod={mod} />}
      </main>
    </div>
  );
}
