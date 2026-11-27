// v.218: Paket 2 – Seitenkopf mit Untertitel in allen Werkzeugen des Passes; keine grauen confirm()-Fenster in der Software.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
  const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
  const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); }catch(e){} });
  const q=await c.newPage(); q.on('pageerror',e=>errs.push('pass: '+e.message)); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(800);
  await q.click('#regb'); await q.fill('#rb','Canyon'); await q.fill('#rm','Grail'); await q.fill('#rf','U'+Date.now()%100000); await q.check('#rx'); await q.click('#rg button.btn:not(#rfscan)'); await q.waitForTimeout(1300);
  const code=await q.evaluate(()=>mine()[0].code); await q.evaluate(c=>{ location.hash='#c='+c; },code); await q.waitForTimeout(1500);
  const open=async t=>{ await q.evaluate(t=>{ const b=document.querySelector(`[data-tool="${t}"]`); if(b) b.click(); },t); await q.waitForTimeout(500);
    const r=await q.evaluate(()=>{ const p=[...document.querySelectorAll('.tpage')].pop(); if(!p) return null; return {h:(p.querySelector('h1')||{}).textContent||'',sub:(p.querySelector('h1 ~ p.muted')||{}).textContent||''}; });
    await q.evaluate(()=>document.querySelectorAll('.tpage').forEach(e=>e.remove())); await q.waitForTimeout(200); return r; };
  const list=[['svc','Service','Was jetzt fällig ist'],['fit','Sitzposition','Deine Werte in mm'],['tire','Reifendruck','Startwert für vorne und hinten'],['parts','Ausstattung','Was verbaut ist'],['docs','Belege & Garantie','Rechnungen und Garantiefristen'],['sell','Verkaufen','Anzeige, Kaufvertrag und Übergabe']];
  for(const [t,titel,anfang] of list){ const r=await open(t); if(!r){ bad('Werkzeug '+t+' öffnet nicht'); continue; }
    log('•',t,'→',r.h.trim(),'·',r.sub.trim().slice(0,48));
    if(r.h.trim()!==titel) bad('Titel '+t+' statt '+titel); if(!r.sub.trim().startsWith(anfang)) bad('Untertitel fehlt bei '+titel); }
  const s=await c.newPage(); s.on('pageerror',e=>errs.push('software: '+e.message)); await s.goto(BASE+'/index.html'); await s.waitForTimeout(2200);
  const gone=await s.evaluate(()=>typeof confirmDel==='undefined'&&typeof fyfAsk==='function'); log('Software: confirmDel weg, fyfAsk da →',gone); if(!gone) bad('Software nutzt noch confirmDel');
  const ov=await q.evaluate(()=>document.documentElement.scrollWidth>innerWidth+1); if(ov) bad('Querscroll');
  log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
