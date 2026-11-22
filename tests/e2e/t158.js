// v.158: Fitting-Ergebnis zeigt Kurzkarte Rahmen-Finder; Knopf wechselt zum Reiter „Größe & Sattel“ mit Rahmen-Finder.
const {chromium}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const p=await (await b.newContext({viewport:{width:1300,height:1000},locale:'de-DE'})).newPage(); p.on('pageerror',e=>errs.push(e.message)); await p.goto(BASE+'/index.html'); await p.waitForTimeout(1500);
 const t=await p.evaluate(()=>{ const F=window.__fitframe.T118; const u=F.ui(); u.route='sitzung'; u.sess='s1'; u.sessTab='ergebnis'; u.resTab='vergleich'; u.wIdx=null; F.render(); const e=document.querySelector('.ff-teaser'); return e?e.innerText.replace(/\s+/g,' '):''; }); log('1 Kurzkarte:',t); if(!/Rahmen/.test(t)) bad('Kurzkarte fehlt');
 await p.click('.ff-teaser [data-act="resTab"]'); await p.waitForTimeout(400); const f=await p.evaluate(()=>/Rahmen-Finder/.test(document.getElementById('view').innerText)&&window.__fitframe.T118.ui().resTab); log('2 Reiter:',f); if(f!=='groesse') bad('Wechsel zum Rahmen-Finder');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
