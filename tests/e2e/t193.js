// v.193: „Kurz erklärt“ – 6 Ratgeber (E-Bike-Akku nur bei E-Bikes), aufklappbar, zählt anonym.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push(e.message)); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(700);
 await q.click('#regb'); await q.fill('#rb','Canyon'); await q.fill('#rm','Grail'); await q.fill('#rf','S'+Math.floor(Math.random()*1e6)); await q.check('#rx'); await q.click('#rg button.btn:not(#rfscan)'); await q.waitForTimeout(1300);
 const code=await q.evaluate(()=>mine()[0].code); await q.evaluate(c=>{ location.hash='#c='+c; },code); await q.waitForTimeout(1500);
 if(!await q.evaluate(()=>!!document.querySelector('[data-tool="tips"]'))) bad('Werkzeug');
 await q.evaluate(c=>TOOLFN.tips(c),code); await q.waitForTimeout(300);
 let r=await q.evaluate(()=>[...document.querySelectorAll('.tpage [data-tip]')].map(d=>d.dataset.tip)); log('Rennrad:',JSON.stringify(r)); if(r.length!==5||r.includes('battery')) bad('ohne E-Bike-Tipp');
 await q.click('.tpage [data-tip="chain"] summary'); await q.waitForTimeout(200); r=await q.evaluate(()=>({n:document.querySelectorAll('.tpage [data-tip="chain"] li').length,hit:localStorage.getItem('fyfpass:hit:tipp_chain')})); log(JSON.stringify(r)); if(r.n!==4||!r.hit) bad('Aufklappen und Zählen');
 await q.evaluate(()=>{ document.querySelectorAll('.tpage').forEach(x=>x.remove()); document.body.style.overflow=''; });
 await q.evaluate(c=>{ const o=X(c); o.eb={m:'Bosch'}; Xset(c,o); TOOLFN.tips(c); },code); await q.waitForTimeout(300); r=await q.evaluate(()=>document.querySelectorAll('.tpage [data-tip]').length); log('E-Bike:',r); if(r!==6) bad('E-Bike-Tipp');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
