// v.169: Seitenfenster am Handy per Wischen nach rechts schließen; Wischen in einem Eingabefeld schließt nicht.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const p=await (await b.newContext({...devices['iPhone 13'],locale:'de-DE'})).newPage(); p.on('pageerror',e=>errs.push(e.message)); await p.goto(BASE+'/index.html'); await p.waitForTimeout(1500);
 const swipe=sel=>p.evaluate(sel=>{ const el=document.querySelector(sel); const r=el.getBoundingClientRect(); const mk=(x,y)=>new Touch({identifier:1,target:el,clientX:x,clientY:y}); el.dispatchEvent(new TouchEvent('touchstart',{touches:[mk(r.left+40,r.top+40)],changedTouches:[mk(r.left+40,r.top+40)],bubbles:true})); el.dispatchEvent(new TouchEvent('touchend',{touches:[],changedTouches:[mk(r.left+220,r.top+50)],bubbles:true})); },sel);
 await p.evaluate(()=>window.__fitframe.T118.apptDrawer(null)); await p.waitForTimeout(400);
 await swipe('#overlay .drawer input'); await p.waitForTimeout(200); const still=await p.evaluate(()=>!!document.querySelector('#overlay .drawer')); log('1 Wischen im Feld → bleibt offen:',still); if(!still) bad('schließt beim Wischen im Feld');
 await swipe('#overlay .drawer-h h2'); await p.waitForTimeout(200); const closed=await p.evaluate(()=>!document.querySelector('#overlay .drawer')); log('2 Wischen am Kopf → geschlossen:',closed); if(!closed) bad('Wischen schließt nicht');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
