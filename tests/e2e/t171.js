// v.171: Kundenliste zeigt Handlungsbedarf am Namen (Nachkontrolle überfällig, offene Aufträge).
const {chromium}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const p=await (await b.newContext({viewport:{width:1300,height:800},locale:'de-DE'})).newPage(); p.on('pageerror',e=>errs.push(e.message)); await p.goto(BASE+'/index.html'); await p.waitForTimeout(1500);
 const r=await p.evaluate(()=>{ const F=window.__fitframe.T118; F.ui().route='kunden'; F.render(); const o={}; document.querySelectorAll('tr[data-act="openCustomer"]').forEach(tr=>{ const f=tr.querySelector('.cl-flags'); o[tr.querySelector('.avatar').nextElementSibling.firstElementChild.textContent]=f?f.innerText.replace(/\s+/g,' '):''; }); return o; }); log(JSON.stringify(r));
 if(!/Nachkontrolle überfällig/.test(r['Lena Hoffmann']||'')) bad('Lena: Nachkontrolle'); if(r['Dominik Böhm']) bad('Dominik: kein Hinweis erwartet');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
