// v.159: Pass – „Verkauf in 5 Schritten“: Preis, Anzeige teilen/kopieren, Kaufvertrag, Zustand bestätigen zählen hoch.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE',permissions:['clipboard-read','clipboard-write']}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push('pass: '+e.message)); q.on('dialog',d=>d.accept()); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(700);
 await q.click('#regb'); await q.fill('#rb','Cube'); await q.fill('#rm','Nuroad'); await q.fill('#rf','S'+Date.now()%100000); await q.check('#rx'); await q.click('#rg button.btn:not(#rfscan)'); await q.waitForTimeout(1300);
 const code=await q.evaluate(()=>mine()[0].code); await q.evaluate(c=>{ location.hash='#c='+c; },code); await q.waitForTimeout(1200);
 await q.evaluate(c=>toolSell(c),code); await q.waitForTimeout(400);
 const cnt=async()=>q.evaluate(()=>{ const e=[...document.querySelectorAll('.tpage [data-sst]')].pop(); return e?e.querySelector('.muted.small').textContent:''; });
 log('1 Start:',await cnt()); if(!/0 von 5|1 von 5/.test(await cnt())) bad('Startzustand');
 await q.fill('.tpage #slP','900'); await q.dispatchEvent('.tpage #slP','input'); await q.dispatchEvent('.tpage #slP','change'); await q.waitForTimeout(300); log('2 nach Preis:',await cnt());
 await q.click('.tpage #slCp'); await q.waitForTimeout(300); log('3 nach Kopieren:',await cnt());
 await q.click('.tpage [data-szust]'); await q.waitForTimeout(300); const n=await cnt(); log('4 nach Zustand:',n);
 const o=await q.evaluate(c=>X(c).sell,code); log('5 gespeichert:',JSON.stringify(o)); if(!o.price||!o.shared||!o.okCond) bad('Schritte nicht gespeichert'); if(!/3 von 5/.test(n)) bad('Zähler falsch');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
