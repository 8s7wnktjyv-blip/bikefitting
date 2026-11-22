// v.161: Englisch Stufe 2/3 – Händlerfinder auf Englisch (Liste + Anfrage), Pass-Werkzeuge ohne deutsche Reste, Rückschalten auf Deutsch.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); if(!localStorage.getItem('fyfpass:lang')) localStorage.setItem('fyfpass:lang','en'); }catch(e){} });
 const f=await c.newPage(); f.on('pageerror',e=>errs.push('finder: '+e.message)); await f.goto(BASE+'/finder.html#cfg='+cfg); await f.waitForTimeout(1800);
 const t1=await f.evaluate(()=>document.body.innerText); log('1 Finder EN:',/FYF partners near you/.test(t1),/Town or postcode/.test(t1)); if(!/FYF partners near you/.test(t1)||/Ort oder PLZ/.test(t1)) bad('Finder nicht englisch');
 const q=await c.newPage(); q.on('pageerror',e=>errs.push('pass: '+e.message)); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(900);
 await q.click('#regb'); await q.fill('#rb','Cube'); await q.fill('#rm','Attain'); await q.fill('#rf','E'+Date.now()%100000); await q.check('#rx'); await q.click('#rg button.btn:not(#rfscan)'); await q.waitForTimeout(1500);
 const code=await q.evaluate(()=>mine()[0].code); await q.evaluate(c=>{ location.hash='#c='+c; },code); await q.waitForTimeout(1500);
 await q.click('.gl-goal'); await q.waitForTimeout(500); const t2=await q.evaluate(()=>[...document.querySelectorAll('.tpage')].pop().innerText); log('2 Ziele EN:',/Goals & badges/.test(t2),/Goal for \d{4}/.test(t2)); if(!/Goals & badges/.test(t2)||!/Goal for \d{4}/.test(t2)) bad('Ziel-Seite nicht englisch');
 await q.evaluate(()=>{ localStorage.setItem('fyfpass:lang','de'); }); await f.reload(); await f.waitForTimeout(1500); const t3=await f.evaluate(()=>document.body.innerText); log('3 zurück Deutsch:',/Ort oder PLZ/.test(t3)); if(!/Ort oder PLZ/.test(t3)) bad('Rückschalten');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
