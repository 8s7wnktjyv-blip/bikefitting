// v.160: Pass offline – eigenes Rad öffnet auch ohne Netz und ohne frühere Online-Ansicht; Diebstahl-Status wird nicht behauptet; Software startet offline.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE',serviceWorkers:'allow'}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push('pass: '+e.message)); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(800);
 await q.click('#regb'); await q.fill('#rb','Cube'); await q.fill('#rm','Nuroad'); await q.fill('#rf','O'+Date.now()%100000); await q.check('#rx'); await q.click('#rg button.btn:not(#rfscan)'); await q.waitForTimeout(1500);
 const code=await q.evaluate(()=>mine()[0].code); await q.evaluate(c=>{ const o=X(c); o.km=2222; Xset(c,o); },code); await q.waitForTimeout(2500);
 const sw=await q.evaluate(()=>!!(navigator.serviceWorker&&navigator.serviceWorker.controller)); log('0 Service-Worker:',sw); if(!sw) bad('Service-Worker');
 await c.setOffline(true); await q.goto(BASE+'/rad.html#c='+code).catch(()=>{}); await q.waitForTimeout(2000);
 const r=await q.evaluate(()=>({rad:/Cube Nuroad/.test(document.body.innerText),glance:!!document.querySelector('.glance'),off:/Offline – deine eigenen Einträge/.test(document.body.innerText),claim:/Keine Diebstahlmeldung/.test(document.body.innerText)})); log('1 Pass offline:',JSON.stringify(r));
 if(!r.rad||!r.glance) bad('eigenes Rad offline nicht sichtbar'); if(!r.off) bad('Offline-Hinweis'); if(r.claim) bad('Diebstahl-Status wird offline behauptet');
 const p=await c.newPage(); await p.goto(BASE+'/index.html').catch(()=>{}); await p.waitForTimeout(2000); const sw2=await p.evaluate(()=>!!window.__fitframe&&document.querySelectorAll('.side .navbtn').length>5).catch(()=>false); log('2 Software offline:',sw2); if(!sw2) bad('Software offline');
 await c.setOffline(false); log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
