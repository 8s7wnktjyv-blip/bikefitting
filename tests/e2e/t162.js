// v.162: Umbau planen – Hinweis bei 12-fach-Kassette am 11-fach-Antrieb und SRAM-Schaltwerk an Shimano; kein Hinweis bei passendem Teil.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push('pass: '+e.message)); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(700);
 await q.click('#regb'); await q.fill('#rb','Canyon'); await q.fill('#rm','Endurace'); await q.fill('#rf','B'+Date.now()%100000); await q.check('#rx'); await q.click('#rg button.btn:not(#rfscan)'); await q.waitForTimeout(1300);
 const code=await q.evaluate(()=>mine()[0].code);
 await q.evaluate(c=>{ const o=X(c); o.parts={groupset:'Shimano 105 R7000 11-fach',rd:'Shimano 105 R7000'}; o.build=[{p:'Kassette',k:'cassette',to:'Shimano 105 R7100 12-fach 11-36',c:'60',g:'',d:'2026-11-22'},{p:'Schaltwerk',k:'rd',to:'SRAM Rival AXS',c:'250',g:'',d:'2026-11-22'},{p:'Kette',k:'chain',to:'Shimano HG601 11-fach',c:'25',g:'',d:'2026-11-22'}]; Xset(c,o); },code);
 await q.evaluate(c=>{ location.hash='#c='+c; },code); await q.waitForTimeout(1300); await q.evaluate(c=>toolBuild(c),code); await q.waitForTimeout(500);
 const H=await q.evaluate(()=>[...[...document.querySelectorAll('.tpage')].pop().querySelectorAll('.card.bld')].map(c=>(c.querySelector('.bld-h')||{}).innerText||'')); log(JSON.stringify(H));
 if(!/12-fach-Teil, dein Antrieb ist 11-fach/.test(H[0])) bad('Fachzahl-Hinweis'); if(!/SRAM-Schaltwerk mit Shimano/.test(H[1])) bad('Marken-Hinweis'); if(H[2]) bad('falscher Hinweis bei passender Kette');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
