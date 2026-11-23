// v.197/v.198: Kacheln „Zustand der Teile“ / „Jahresziel“ ohne Daten: ruhige Zeile ohne Umbruch, beide Spalten gleich breit.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push(e.message)); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(700);
 await q.click('#regb'); await q.fill('#rb','Canyon'); await q.fill('#rm','Grail CF 7'); await q.fill('#rf','S'+Math.floor(Math.random()*1e6)); await q.check('#rx'); await q.click('#rg button.btn:not(#rfscan)'); await q.waitForTimeout(1300); await q.evaluate(()=>{ location.hash='#c='+mine()[0].code; }); await q.waitForTimeout(1800);
 const r=await q.evaluate(()=>{ const a=document.querySelector('.gl-comp'), g=document.querySelector('.gl-goal'); const v=a&&a.querySelector('.gl-v');
   return {emp:!!(a&&a.classList.contains('gl-empty')&&g&&g.classList.contains('gl-empty')), oneLine:v&&v.getBoundingClientRect().height<34, same:a&&g&&Math.abs(a.offsetWidth-g.offsetWidth)<3}; });
 log(JSON.stringify(r)); if(!r.emp) bad('leere Kacheln markiert'); if(!r.oneLine) bad('„Teile eintragen“ in einer Zeile'); if(!r.same) bad('gleich breite Kacheln');
 const ic=await q.evaluate(()=>{ const L=[...document.querySelectorAll('[data-ns-rad] .ns-i')]; return {n:L.length,svg:L.every(x=>x.querySelector('svg')),bang:L.some(x=>x.textContent.trim()==='!')}; }); log('Schritte:',JSON.stringify(ic)); if(!ic.n||!ic.svg||ic.bang) bad('Nächste Schritte mit Symbolen statt „!“ (v.198)');
 await q.click('.gl-goal'); await q.waitForTimeout(500); if(!(await q.locator('.goal-hero').count())) bad('Jahresziel öffnet');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
