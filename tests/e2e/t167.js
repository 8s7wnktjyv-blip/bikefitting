// v.167: Status-Chips in der Werkstatt-Liste haben je Status eine eigene Farbe (Regression aus v.143 behoben).
const {chromium}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const p=await (await b.newContext({viewport:{width:1300,height:800},locale:'de-DE'})).newPage(); p.on('pageerror',e=>errs.push(e.message)); await p.goto(BASE+'/index.html'); await p.waitForTimeout(1500);
 const c=await p.evaluate(()=>{ const F=window.__fitframe.T118; F.ui().route='werkstatt'; F.render(); const o={}; document.querySelectorAll('td .chip').forEach(x=>{ o[x.textContent.trim()]=getComputedStyle(x).color; }); return o; }); log(JSON.stringify(c));
 const cols=Object.entries(c).filter(([k])=>/Angenommen|Freigabe|In Arbeit|Abholbereit/.test(k)).map(([,v])=>v); if(new Set(cols).size<cols.length||cols.length<3) bad('Status-Farben nicht unterschiedlich');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
