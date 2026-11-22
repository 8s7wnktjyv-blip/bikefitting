// v.186: Klarheit – Räder zuerst in der Garage, Sicherung nur als „Nächster Schritt“ (einmal), Konto/Erinnerungen als aufklappbare Zeilen.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push(e.message)); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(700);
 await q.click('#regb'); await q.fill('#rb','Canyon'); await q.fill('#rm','Test'); await q.fill('#rf','S'+Math.floor(Math.random()*1e6)); await q.check('#rx'); await q.click('#rg button.btn:not(#rfscan)'); await q.waitForTimeout(1300);
 await q.evaluate(()=>{ location.hash='#meine'; }); await q.waitForTimeout(1500);
 const r=await q.evaluate(()=>{ const kids=[...document.querySelector('.garage').parentElement.children].filter(x=>getComputedStyle(x).display!=='none'&&x.tagName!=='STYLE'); const ig=kids.indexOf(document.querySelector('.garage')), ih=kids.findIndex(x=>x.tagName==='H1'), ins=kids.indexOf(document.querySelector('[data-ns-gar]'));
   const ns=[...document.querySelectorAll('[data-ns-gar] .ns b')].map(x=>x.textContent); const sb=document.querySelector('[data-setupb]');
   return {first:ig===ih+1,nsAfter:ins>ig,setup:ns.filter(t=>/Daten sichern/.test(t)).length,banner:!!sb&&getComputedStyle(sb).display!=='none',grp:[...document.querySelectorAll('details.cl-grp summary b')].map(x=>x.textContent)}; });
 log(JSON.stringify(r)); if(!r.first) bad('Räder direkt unter der Überschrift'); if(!r.nsAfter) bad('Nächste Schritte nach den Rädern'); if(r.setup!==1) bad('Sicherung genau einmal'); if(r.banner) bad('großer Sicherungs-Kasten ausgeblendet');
 if(!r.grp.includes('Konto & Sicherung')||!r.grp.includes('Erinnerungen')) bad('Konto/Erinnerungen als Zeilen');
 await q.click('[data-ns-gar] [data-ns="setup"]'); await q.waitForTimeout(400); const sh=await q.evaluate(()=>!!document.querySelector('[data-setup]')); log('Sicherung öffnet:',sh); if(!sh) bad('Schritt öffnet Sicherung');
 await q.evaluate(()=>document.querySelector('[data-setup]').remove());
 await q.click('details.cl-grp summary'); await q.waitForTimeout(200); const kb=await q.evaluate(()=>{ const d=document.querySelector('details.cl-grp'); const bt=[...d.querySelectorAll('button')].find(x=>/Konto anlegen/.test(x.textContent)); return !!bt&&bt.offsetHeight>0; }); log('Konto-Knopf sichtbar:',kb); if(!kb) bad('Konto anlegen erreichbar');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
