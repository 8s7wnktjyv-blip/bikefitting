// v.148: Verlauf & Vergleich – überlagerte Seitenansicht A/B mit Differenzen; Handy ohne Querscroll.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 for(const [n,o] of [['Bildschirm',{viewport:{width:1440,height:1000},locale:'de-DE'}],['iPhone',{...devices['iPhone 13'],locale:'de-DE'}]]){ const p=await (await b.newContext(o)).newPage(); p.on('pageerror',e=>errs.push(n+': '+e.message)); await p.goto(BASE+'/index.html'); await p.waitForTimeout(1500);
  const r=await p.evaluate(()=>{ const F=window.__fitframe.T118; F.ui().route='verlauf'; F.render(); const f=document.querySelector('.fov'); return {svg:!!(f&&f.querySelector('svg g')),txt:f?f.innerText.replace(/\s+/g,' '):'',ov:document.documentElement.scrollWidth>innerWidth+1}; });
  log(n,'Überlagerung:',r.svg,r.txt.slice(0,90),'Querscroll:',r.ov); if(!r.svg||!/Sattelhöhe -3 mm/.test(r.txt)) bad(n+': Überlagerung/Differenz'); if(r.ov) bad(n+': Querscroll'); }
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
