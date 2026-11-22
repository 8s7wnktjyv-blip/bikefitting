// v.147: Dashboard je Ladentyp – Werkstatt zeigt „Braucht Aufmerksamkeit“ direkt nach der Begrüßung; eigene Anpassung bleibt Vorrang.
const {chromium}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const p=await (await b.newContext({viewport:{width:1440,height:900},locale:'de-DE'})).newPage(); p.on('pageerror',e=>errs.push(e.message)); await p.goto(BASE+'/index.html'); await p.waitForTimeout(1500);
 const order=async st=>p.evaluate(st=>{ const F=window.__fitframe.T118, S=F.S(); S.settings=S.settings||{}; S.settings.shopType=st; delete S.settings.dash; F.ui().route='dashboard'; F.render(); return [...document.querySelectorAll('.dgrid>.dw')].map(d=>(d.innerText||'').split('\n').filter(Boolean)[0]).slice(0,3); },st);
 let o=await order('werkstatt'); log('1 Werkstatt:',JSON.stringify(o)); if(!/Aufmerksamkeit/.test(o[1]||'')) bad('Werkstatt: Aufmerksamkeit an 2. Stelle');
 o=await order('studio'); log('2 Studio:',JSON.stringify(o)); if(/Aufmerksamkeit/.test(o[1]||'')) bad('Studio: Kennzahlen zuerst');
 const own=await p.evaluate(()=>{ const F=window.__fitframe.T118, S=F.S(); S.settings.shopType='werkstatt'; S.settings.dash=[{id:'activity',on:true}]; F.render(); return [...document.querySelectorAll('.dgrid>.dw')].map(d=>(d.innerText||'').split('\n').filter(Boolean)[0])[0]; }); log('3 eigene Reihenfolge zuerst:',own); if(!/Aktivit/.test(own||'')) bad('eigene Anpassung überschrieben');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
