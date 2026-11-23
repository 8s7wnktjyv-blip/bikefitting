// v.196: Kopfbild mit freigestelltem Rad – Text unter dem Bild (überdeckt das Rad nicht), Fahrer + Laufräder-Knopf als Zeile, in Hell dunkle Schrift; Hell/Dunkel-Knopf scrollt mit.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push(e.message)); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(700);
 await q.click('#regb'); await q.fill('#rb','Canyon'); await q.fill('#rm','Grail CF 7'); await q.fill('#rf','S'+Math.floor(Math.random()*1e6)); await q.check('#rx'); await q.click('#rg button.btn:not(#rfscan)'); await q.waitForTimeout(1300);
 const code=await q.evaluate(()=>mine()[0].code);
 await q.evaluate(c=>{ const cv=document.createElement('canvas'); cv.width=400; cv.height=240; const g=cv.getContext('2d'); g.fillStyle='#345'; g.fillRect(20,20,360,200); localStorage.setItem('fyfpass:imgt:'+c,cv.toDataURL('image/png')); localStorage.setItem('fyfpass:imgtrim:'+c,'1'); localStorage.setItem('fyfpass:theme','light'); },code);
 await q.reload(); await q.evaluate(c=>{ location.hash='#c='+c; },code); await q.waitForTimeout(2000);
 const r=await q.evaluate(()=>{ const h=document.querySelector('.hero'), pic=h.querySelector('.bikepic'), m=h.querySelector('.meta'), t=m.querySelector('h1'); const acts=m.querySelector('.hero-acts');
   return {st:h.classList.contains('hero-st'), below:t.getBoundingClientRect().top>=pic.getBoundingClientRect().bottom-1, col:getComputedStyle(t).color, rider:!!(acts&&acts.querySelector('[data-rider]')), wheel:!!(acts&&acts.querySelector('.st-wheel')), oneRow:acts&&[...acts.children].every(x=>Math.abs(x.getBoundingClientRect().top-acts.children[0].getBoundingClientRect().top)<4)}; });
 log(JSON.stringify(r)); if(!r.st) bad('Studio-Kopfbild erkannt'); if(!r.below) bad('Titel unter dem Bild'); if(r.col==='rgb(255, 255, 255)') bad('Hell: dunkle Schrift'); if(!r.rider) bad('Fahrer-Zeile im Kopf'); if(!r.wheel) bad('Laufräder-Knopf im Kopf'); if(!r.oneRow) bad('eine Zeile');
 await q.click('.hero-acts .st-wheel'); await q.waitForTimeout(800); if(!(await q.locator('.wcc').count())) bad('Laufräder-Knopf öffnet Werkzeug');
 const pos=await q.evaluate(()=>getComputedStyle(document.querySelector('.thm-tg')).position); if(pos!=='absolute') bad('Hell/Dunkel-Knopf scrollt mit');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
