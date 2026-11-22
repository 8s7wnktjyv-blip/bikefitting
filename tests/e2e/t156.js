// v.156: Fitting-Schritt „Anpassen“ zeigt Live-Skizze; nach Änderung eines Werts aktualisiert sich die Differenz.
const {chromium}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const p=await (await b.newContext({viewport:{width:1300,height:1000},locale:'de-DE'})).newPage(); p.on('pageerror',e=>errs.push(e.message)); await p.goto(BASE+'/index.html'); await p.waitForTimeout(1500);
 const r1=await p.evaluate(()=>{ const F=window.__fitframe.T118; const u=F.ui(); u.route='sitzung'; u.sess='s1'; u.sessTab='anpassung'; u.wIdx=null; F.render(); const f=document.querySelector('.fit-live .fov-t'); return f?f.innerText:''; }); log('1 Live-Skizze:',r1.replace(/\s+/g,' ')); if(!/Sattelhöhe\s*\+8 mm/.test(r1)) bad('Live-Skizze fehlt');
 const r2=await p.evaluate(()=>{ const F=window.__fitframe.T118; const s=F.S().sessions.find(x=>x.id==='s1'); s.after.saddleHeight.value=740; F.render(); const f=document.querySelector('.fit-live .fov-t'); return f?f.innerText:''; }); log('2 nach Änderung:',r2.replace(/\s+/g,' ')); if(!/Sattelhöhe\s*\+12 mm/.test(r2)) bad('aktualisiert nicht');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
