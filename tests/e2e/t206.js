// v.206: Werkstätten-Seite (Händlerfinder) hat den Hell/Dunkel-Knopf wie der Pass (gleiche Einstellung); „Panne unterwegs?“ nennt Krankenhaus/Karte.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); const q=await c.newPage(); q.on('pageerror',e=>errs.push(e.message));
 await q.goto(BASE+'/finder.html#w=1&cfg='+cfg); await q.waitForTimeout(1500);
 const t=()=>q.evaluate(()=>document.documentElement.getAttribute('data-theme'));
 const box=await q.locator('.thm-tg').boundingBox(); if(!box||box.y>60||box.x<300) bad('Knopf oben rechts');
 const t0=await t(); await q.click('.thm-tg'); const t1=await t(); log('Design:',t0,'→',t1); if(t0===t1) bad('Knopf schaltet um');
 const sv=await q.evaluate(()=>localStorage.getItem('fyfpass:theme')); if(sv!==t1) bad('Wahl gespeichert');
 await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(800); if(await t()!==t1) bad('Pass übernimmt die Wahl');
 await q.goto(BASE+'/finder.html#w=1&cfg='+cfg); await q.waitForTimeout(1200); const txt=await q.locator('a.nr-help').innerText(); if(!/Krankenhaus/.test(txt)) bad('Panne-Karte nennt Krankenhaus');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
