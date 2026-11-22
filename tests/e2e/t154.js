// v.154: Pass – Tour-Check: Knopf erst aktiv, wenn alle Punkte abgehakt; Eintrag wird gespeichert; fällige Wartung erscheint als Punkt.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push('pass: '+e.message)); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(700);
 await q.click('#regb'); await q.fill('#rb','Cube'); await q.fill('#rm','Attain'); await q.fill('#rf','U'+Date.now()%100000); await q.check('#rx'); await q.click('#rg button.btn:not(#rfscan)'); await q.waitForTimeout(1300);
 const code=await q.evaluate(()=>mine()[0].code); await q.evaluate(c=>{ location.hash='#c='+c; },code); await q.waitForTimeout(1500);
 await q.evaluate(()=>{ const d=document.querySelector('[data-tmore]'); if(d) d.open=true; }); await q.click('[data-tool="tour"]'); await q.waitForTimeout(400);
 const n=await q.locator('.tpage [data-tc]').count(); const dis=await q.evaluate(()=>[...document.querySelectorAll('.tpage #tcOk')].pop().disabled); log('1 Punkte:',n,'Knopf gesperrt:',dis); if(n<6||!dis) bad('Liste/Knopf');
 for(let i=0;i<n;i++){ await q.locator('.tpage [data-tc]').nth(i).check(); await q.waitForTimeout(60); }
 const en=await q.evaluate(()=>[...document.querySelectorAll('.tpage #tcOk')].pop().disabled===false); log('2 alle abgehakt → Knopf frei:',en); if(!en) bad('Knopf bleibt gesperrt');
 await q.click('.tpage #tcOk'); await q.waitForTimeout(400); const t=await q.evaluate(c=>X(c).tour,code); log('3 gespeichert:',JSON.stringify(t)); if(!t||t.length!==1) bad('Tour-Check nicht gespeichert');
 const open=await q.locator('.tpage').count(); log('4 Seite geschlossen:',!open); if(open) bad('Seite bleibt offen');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
