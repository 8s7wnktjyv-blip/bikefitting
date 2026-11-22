// v.183: Nächste Schritte – Garage und Radseite zeigen fällige Punkte (Kette über Richtwert zuerst), Antippen öffnet Werkzeug; Offline-Hinweis erscheint.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push(e.message)); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(700);
 await q.click('#regb'); await q.fill('#rb','Canyon'); await q.fill('#rm','Grail'); await q.fill('#rf','N'+Date.now()%100000); await q.check('#rx'); await q.click('#rg button.btn:not(#rfscan)'); await q.waitForTimeout(1300);
 const code=await q.evaluate(()=>mine()[0].code); await q.evaluate(c=>{ const o=X(c); o.km=4000; o.parts={chain:'KMC'}; o.partsHist=[{k:'chain',to:'KMC',km:500,d:'2026-01-01'}]; Xset(c,o); location.hash='#meine'; },code); await q.waitForTimeout(1000);
 const g=await q.evaluate(()=>[...document.querySelectorAll('[data-ns-gar] .ns b')].map(x=>x.textContent)); log('1 Garage:',JSON.stringify(g)); if(g[0]!=='Daten sichern (1 Minute)'||!/Kette tauschen/.test(g[1]||'')||g.length>3) bad('Garage-Schritte'); /* v.186: Sicherung steht als erster Schritt */
 await q.evaluate(c=>{ location.hash='#c='+c; },code); await q.waitForTimeout(1600);
 const r=await q.evaluate(()=>[...document.querySelectorAll('[data-ns-rad] .ns b')].map(x=>x.textContent)); log('2 Rad:',JSON.stringify(r)); if(!/Kette tauschen/.test(r[1]||'')) bad('Rad-Schritte');
 await q.click('[data-ns-rad] [data-ns="comp"]'); await q.waitForTimeout(500); const h=await q.evaluate(()=>[...document.querySelectorAll('.tpage h1')].pop()?.textContent); log('3 öffnet:',h); if(h!=='Was ist verbaut?') bad('Antippen öffnet nicht');
 await c.setOffline(true); await q.evaluate(()=>dispatchEvent(new Event('offline'))); await q.waitForTimeout(200); const ob=await q.evaluate(()=>!!document.getElementById('offBar')); log('4 Offline-Hinweis:',ob); if(!ob) bad('Offline-Hinweis'); await c.setOffline(false);
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
