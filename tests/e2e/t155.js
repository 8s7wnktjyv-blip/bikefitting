// v.155: Fitting-Bericht – Kopf, nummerierte Abschnitte, Skizze vorher/nachher im Vorher-Nachher-Vergleich; Handy ohne Querscroll.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 for(const [n,o] of [['Bildschirm',{viewport:{width:1300,height:1000},locale:'de-DE'}],['iPhone',{...devices['iPhone 13'],locale:'de-DE'}]]){ const p=await (await b.newContext(o)).newPage(); p.on('pageerror',e=>errs.push(n+': '+e.message)); await p.goto(BASE+'/index.html'); await p.waitForTimeout(1500);
  await p.evaluate(()=>window.__fitframe.T118.ACT.openReport({dataset:{id:'s1'}})); await p.waitForTimeout(800);
  const r=await p.evaluate(()=>{ const e=document.querySelector('.report'); return e?{rh:getComputedStyle(e.querySelector('.rh')).backgroundColor,fov:!!e.querySelector('.fov svg g'),diff:(e.querySelector('.fov-t')||{}).innerText||'',ov:document.documentElement.scrollWidth>innerWidth+1}:null; });
  log(n,JSON.stringify(r)); if(!r||!r.fov||!/Sattelhöhe\s*\+8 mm/.test(r.diff)) bad(n+': Skizze im Bericht'); if(r&&r.rh!=='rgb(15, 20, 25)') bad(n+': Kopf'); if(r&&r.ov) bad(n+': Querscroll'); }
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
