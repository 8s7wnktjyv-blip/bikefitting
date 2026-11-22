// v.164: Pass – Foto je Bauteil in „Was ist verbaut?“, wird als Beleg (Teilfoto) gespeichert und als Vorschau gezeigt.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765'; const fs=require('fs');
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push('pass: '+e.message)); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(700);
 await q.click('#regb'); await q.fill('#rb','Cube'); await q.fill('#rm','Attain'); await q.fill('#rf','F'+Date.now()%100000); await q.check('#rx'); await q.click('#rg button.btn:not(#rfscan)'); await q.waitForTimeout(1300);
 const code=await q.evaluate(()=>mine()[0].code); await q.evaluate(c=>{ const o=X(c); o.parts={chain:'KMC X11',saddle:'Ergon SR'}; Xset(c,o); location.hash='#c='+c; },code); await q.waitForTimeout(1500);
 await q.click('.gl-comp'); await q.waitForTimeout(500);
 const img={name:'kette.png',mimeType:'image/png',buffer:Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAFElEQVR4nGP4z8DwHwMRgYGBgQEAqP4P8dN7ZhAAAAAASUVORK5CYII=','base64')};
 await q.setInputFiles('.tpage [data-pk="chain"]',img); await q.waitForTimeout(1200);
 const d=await q.evaluate(c=>(X(c).docs||[]).filter(x=>x.pk),code); log('1 gespeichert:',JSON.stringify(d.map(x=>[x.name,x.pk]))); if(d.length!==1||d[0].pk!=='chain') bad('Teilfoto nicht gespeichert');
 await q.waitForTimeout(500); const shown=await q.evaluate(()=>{ const i=[...document.querySelectorAll('.tpage')].pop().querySelector('[data-pkimg]'); return !!(i&&i.src); }); log('2 Vorschau:',shown); if(!shown) bad('Vorschau fehlt');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
