// v.221: Software – Service-Erinnerung per WhatsApp (Rundmail und einzeln) und Service-Intervall für Leasingräder.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
  const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'});
  const q=await c.newPage(); q.on('pageerror',e=>errs.push('software: '+e.message)); await q.goto(BASE+'/index.html'); await q.waitForTimeout(2200);
  const set=await q.evaluate(()=>{ const c=S.customers[0]; if(!c) return false; c.phone='+4915112345678'; c.consentInfo={remind:true};
    const b=S.bikes.find(x=>x.customerId===c.id)||S.bikes[0]; if(!b) return false; b.customerId=c.id; b.qr={code:'ABCD2345',vis:'public',at:'2026-11-20'}; b.svc={every:12,from:'2024-01-10',incl:true};
    save(); render(); return true; });
  if(!set) bad('Demodaten fehlen'); await q.waitForTimeout(400);
  await q.evaluate(()=>{ try{ go('erinnerung'); }catch(e){ const n=document.querySelector('[data-nav="erinnerung"]'); if(n) n.click(); } }); await q.waitForTimeout(800);
  const txt=await q.evaluate(()=>document.body.innerText.replace(/\s+/g,' ')); log('1 Seite:',txt.slice(0,120));
  if(!/Service-Erinnerung/.test(txt)) bad('Seite Service-Erinnerung fehlt');
  if(!/Rundmail per WhatsApp/.test(txt)) bad('Rundmail fehlt');
  if(!/Service-Intervall \(auch Leasing\)/.test(txt)) bad('Panel Service-Intervall fehlt');
  const href=await q.evaluate(()=>{ const L=[...document.querySelectorAll('a[href^="https://wa.me/"]')].map(a=>a.getAttribute('href')); return L.find(h=>/ABCD2345/.test(decodeURIComponent(h)))||''; });
  log('2 WhatsApp-Link:',href.slice(0,90));
  if(!href) bad('WhatsApp-Link mit Pass-Code fehlt'); else { const t=decodeURIComponent(href.split('text=')[1]||'');
    if(!/want=service/.test(t)) bad('Buchungslink fehlt im Text'); if(!/Leasing-Inspektion|Service/i.test(t)) bad('Anlass fehlt im Text'); if(!/Stopp/.test(t)) bad('Abmelde-Hinweis fehlt'); }
  const plan=await q.evaluate(()=>{ try{ const b=S.bikes.find(x=>x.qr&&x.qr.code==='ABCD2345'); const p=passPayload(b); return JSON.stringify((p&&p.plan)||[]); }catch(e){ return 'ERR '+e.message; } });
  log('3 Plan im Pass:',plan.slice(0,120));
  if(!/Leasing-Inspektion/.test(plan)) bad('Intervall steht nicht im Pass-Plan'); if(!/2025-01-10/.test(plan)===false){} 
  const ov=await q.evaluate(()=>document.documentElement.scrollWidth>innerWidth+1); if(ov) bad('Querscroll');
  log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
