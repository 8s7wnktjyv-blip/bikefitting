// v.206/v.207: Werkstätten-Seite (Händlerfinder) hat den Hell/Dunkel-Knopf wie der Pass (gleiche Einstellung); „Panne unterwegs?“ nennt Krankenhaus/Karte.
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
 await q.goto(BASE+'/finder.html#w=1&cfg='+cfg); await q.waitForTimeout(1200); const txt=await q.locator('a.nr-help').innerText(); if(!/Notaufnahme/.test(txt)) bad('Panne-Karte nennt Notaufnahme');
 // v.209: ohne FYF-Partner → Knopf „Werkstätten auf der Karte“ öffnet Helfer
 await q.fill('#q','Hamburg'); await q.waitForTimeout(900); const kb=q.locator('.mk-empty a[href*="hilfe=1"], a.mk-map').first(); if(!(await kb.count())) bad('Werkstätten-Leer-Zustand mit Karten-Knopf'); else { await kb.click(); await q.waitForTimeout(1500); const tt=await q.evaluate(()=>{ const p=[...document.querySelectorAll('.tpage')].pop(); return p?p.innerText:''; }); if(!/Helfer in der Nähe/.test(tt)) bad('Karten-Knopf öffnet Helfer'); await q.goBack(); await q.waitForTimeout(800); }
 // v.207: leerer Marktplatz mit Hinweis, Suche zurücksetzen
 await q.goto(BASE+'/finder.html#markt=1&cfg='+cfg); await q.waitForTimeout(1500); if(!(await q.locator('.mk-empty').count())) bad('Marktplatz: schöner Leer-Zustand');
 await q.fill('#mq','xyzunbekannt'); await q.waitForTimeout(900); if(!(await q.locator('[data-mkreset]').count())) bad('Suche zurücksetzen sichtbar'); else { await q.click('[data-mkreset]'); await q.waitForTimeout(500); if(await q.inputValue('#mq')!=='') bad('Suche geleert'); }
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
