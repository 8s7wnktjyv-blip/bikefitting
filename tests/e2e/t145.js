// v.145: Zustandsbericht mit Urteil – Teile-Verschleiß, eigene Schäden, Kaufbeleg; Urteil auch oben in „Verkaufen“.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push('pass: '+e.message)); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(700);
 await q.click('#regb'); await q.fill('#rb','Cube'); await q.fill('#rm','Nuroad'); await q.fill('#rf','V'+Date.now()%100000); await q.check('#rx'); await q.click('#rg button.btn:not(#rfscan)'); await q.waitForTimeout(1300);
 const code=await q.evaluate(()=>mine()[0].code);
 const verdict=async()=>q.evaluate(c=>{ const R=healthReport(c); const V=healthVerdict(R); return {v:V&&V.t,f:R.F.map(f=>f[0]+':'+f[1]).join(', ')}; },code);
 await q.evaluate(c=>{ const o=X(c); o.km=5000; o.parts={chain:'KMC X11'}; o.partsHist=[{k:'chain',to:'KMC X11',km:1000,d:'2025-01-01'}]; Xset(c,o); },code);
 let V=await verdict(); log('1 Kette überfällig:',JSON.stringify(V)); if(V.v!=='Wartungsstau') bad('Wartungsstau erwartet');
 await q.evaluate(c=>{ const o=X(c); o.dmg=[{id:'x1',t:'Sturz',d:'2026-10-01',st:'offen',log:[]}]; Xset(c,o); },code);
 V=await verdict(); log('2 offener Schaden:',V.v); if(V.v!=='Risiko bei Verkauf') bad('Risiko erwartet');
 await q.evaluate(c=>{ const o=X(c); o.dmg[0].st='repariert'; o.partsHist=[{k:'chain',to:'KMC X11',km:4800,d:'2026-11-01'}]; Xset(c,o); },code);
 V=await verdict(); log('3 repariert, Kette neu:',JSON.stringify(V)); if(!/Schäden:ok/.test(V.f)||!/Verschleißteile \(km\):ok/.test(V.f)||!/Kaufbeleg:warn/.test(V.f)) bad('Faktoren falsch'); if(V.v==='Verkaufsbereit') bad('ohne Kaufbeleg nicht verkaufsbereit');
 await q.evaluate(c=>{ location.hash='#c='+c; },code); await q.waitForTimeout(1500);
 const hs=await q.evaluate(()=>document.querySelector('[data-cockpit]')?.innerText.replace(/\s+/g,' ')||''); log('4 Cockpit:',hs); if(!/(Fast verkaufsbereit|Zu wenig Daten|Wartungsstau|Verkaufsbereit)/i.test(hs)) bad('Urteil fehlt im Bericht');
 await q.evaluate(c=>toolSell(c),code); await q.waitForTimeout(400); const sc=await q.evaluate(()=>[...document.querySelectorAll('.tpage')].pop().querySelector('.hv-card')?.innerText.replace(/\s+/g,' ')||''); log('5 Verkaufen-Kopf:',sc.slice(0,160)); if(!/Kaufbeleg/.test(sc)) bad('Urteil/To-dos fehlen in Verkaufen');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
