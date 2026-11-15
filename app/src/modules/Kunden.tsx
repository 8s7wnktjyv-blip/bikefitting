import React, { useEffect, useMemo, useState } from 'react';
import { legacyData, LegacyCustomer } from '../lib/api';

type Data = Awaited<ReturnType<typeof legacyData>>;
const isFirm = (c: LegacyCustomer) => c.kind === 'firma' || (!c.kind && !!c.invAddr?.company);
const fmt = (d?: string) => (d ? new Date(d + 'T12:00:00').toLocaleDateString('de-DE') : '–');
const today = () => new Date().toISOString().slice(0, 10);

export default function Kunden({ tenant, legacyApp }: { tenant: string; legacyApp: string }) {
  const [d, setD] = useState<Data | 'err' | null>(null);
  const [q, setQ] = useState(''); const [kind, setKind] = useState<'alle' | 'privat' | 'firma'>('alle'); const [sel, setSel] = useState<string | null>(null);
  useEffect(() => { legacyData(tenant).then(setD).catch(() => setD('err')); }, [tenant]);
  const list = useMemo(() => {
    if (!d || d === 'err') return [];
    const s = q.trim().toLowerCase();
    return d.customers.filter(c => (kind === 'alle' || (kind === 'firma') === isFirm(c)) &&
      (!s || [c.name, c.company, c.email, c.phone].some(v => (v || '').toLowerCase().includes(s))))
      .sort((a, b) => a.name.localeCompare(b.name, 'de'));
  }, [d, q, kind]);
  if (d === null) return <p className="muted">Lade …</p>;
  if (d === 'err' || !d) return <div className="panel np-pad"><p>Kunden konnten nicht gelesen werden. Ist die Cloud-Speicherung in der bisherigen App eingerichtet?</p></div>;
  const c = sel ? d.customers.find(x => x.id === sel) : null;
  return (<>
    <div className="pagehead"><h1>Kunden</h1><p className="muted">{d.customers.length} Kunden · nur lesen. Bearbeiten weiter in der bisherigen App, bis die Tabellen aktiv sind.</p></div>
    <div className="panel np-pad np-tools">
      <input className="input" type="search" placeholder="Name, Firma, E-Mail, Telefon" aria-label="Kunden suchen" value={q} onChange={e => setQ(e.target.value)} />
      <div className="np-seg" role="group" aria-label="Kundentyp">{(['alle', 'privat', 'firma'] as const).map(k =>
        <button key={k} className={'btn sm ' + (kind === k ? 'primary' : 'ghost')} aria-pressed={kind === k} onClick={() => setKind(k)}>{k === 'alle' ? 'Alle' : k === 'privat' ? 'Privat' : 'Firmen'}</button>)}</div>
    </div>
    {c ? <CustomerCard c={c} d={d} back={() => setSel(null)} legacyApp={legacyApp} /> :
      <div className="panel"><div className="list">{list.length ? list.map(x => {
        const bikes = d.bikes.filter(b => b.customerId === x.id).length, open = d.workshop.filter(w => w.customerId === x.id && !['Übergeben', 'Storniert'].includes(w.status)).length;
        const due = (x.wv || []).filter(w => !w.done && w.due <= today()).length;
        return <button key={x.id} className="li np-row" onClick={() => setSel(x.id)}>
          <span className="np-grow"><b>{x.name}</b>{isFirm(x) && (x.company || x.invAddr?.company) ? <span className="faint"> · {x.company || x.invAddr?.company}</span> : null}<br />
            <span className="faint">{[x.email, x.phone].filter(Boolean).join(' · ') || '–'}</span></span>
          <span className="np-chips">{isFirm(x) && <span className="chip nodot c-acc">Firma</span>}{bikes > 0 && <span className="chip nodot">{bikes} {bikes > 1 ? 'Räder' : 'Rad'}</span>}{open > 0 && <span className="chip nodot c-acc">{open} offen</span>}{due > 0 && <span className="chip nodot c-bad">Wiedervorlage</span>}</span>
        </button>; }) : <p className="muted np-pad">Keine Treffer.</p>}</div></div>}
  </>);
}

function CustomerCard({ c, d, back, legacyApp }: { c: LegacyCustomer; d: NonNullable<Data>; back: () => void; legacyApp: string }) {
  const bikes = d.bikes.filter(b => b.customerId === c.id), wos = d.workshop.filter(w => w.customerId === c.id), invs = d.invoices.filter(i => i.customerId === c.id);
  const wv = (c.wv || []).filter(w => !w.done).sort((a, b) => a.due.localeCompare(b.due));
  return (<div className="stack np-gap">
    <div><button className="btn ghost sm" onClick={back}>‹ Alle Kunden</button></div>
    <div className="panel np-pad">
      <h2 className="np-h2">{c.name}</h2>
      {isFirm(c) && <p><span className="chip nodot c-acc">Geschäftskunde</span> <b>{c.company || c.invAddr?.company}</b>{c.vatId ? <span className="mono"> · {c.vatId}</span> : null}</p>}
      <dl className="dl"><dt>E-Mail</dt><dd>{c.email ? <a href={'mailto:' + c.email}>{c.email}</a> : '–'}</dd><dt>Telefon</dt><dd>{c.phone ? <a href={'tel:' + c.phone.replace(/[^\d+]/g, '')}>{c.phone}</a> : '–'}</dd>
        <dt>Anschrift</dt><dd>{c.address || '–'}</dd><dt>Kunde seit</dt><dd>{fmt(c.since)}</dd><dt>Einwilligung</dt><dd>{c.consent ? 'liegt vor' : 'fehlt'}</dd></dl>
      {(c.contacts || []).length > 0 && <><h3>Ansprechpartner</h3><div className="list">{c.contacts!.map((p, i) => <div key={i} className="li np-row"><b>{p.name}</b><span className="faint">{[p.role, p.phone, p.email].filter(Boolean).join(' · ')}</span></div>)}</div></>}
    </div>
    <div className="panel np-pad"><h3>Wiedervorlagen</h3>{wv.length ? <div className="list">{wv.map(w => <div key={w.id} className="li np-row"><span className={'chip nodot ' + (w.due <= today() ? 'c-bad' : '')}>{fmt(w.due)}</span><span className="np-grow">{w.text}</span></div>)}</div> : <p className="muted">Keine offenen.</p>}</div>
    <div className="panel np-pad"><h3>Fahrräder ({bikes.length})</h3>{bikes.length ? <div className="list">{bikes.map(b => <div key={b.id} className="li np-row"><span className="np-grow"><b>{[b.brand, b.model].filter(Boolean).join(' ') || 'Fahrrad'}</b><span className="faint"> {[b.type, b.size].filter(Boolean).join(' · ')}</span></span>{b.qr?.code && <span className="chip nodot">Pass {b.qr.code}</span>}</div>)}</div> : <p className="muted">Keine.</p>}</div>
    <div className="panel np-pad"><h3>Werkstatt ({wos.length}) · Rechnungen ({invs.length})</h3>{wos.length ? <div className="list">{wos.slice(0, 10).map(w => <div key={w.id} className="li np-row"><span className="np-grow"><b>{w.id}</b> {w.title}</span><span className="chip nodot">{w.status}</span></div>)}</div> : <p className="muted">Keine Aufträge.</p>}</div>
    <div><a className="btn primary" href={legacyApp + '#kunden'}>In der bisherigen App bearbeiten</a></div>
  </div>);
}
