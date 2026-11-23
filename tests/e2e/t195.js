// v.195: Hell/Dunkel-Knopf oben rechts auf jeder Seite, schaltet um, bleibt nach Neuladen, Fußzeile bleibt synchron.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push(e.message)); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(900);
 const t=()=>q.evaluate(()=>document.documentElement.getAttribute('data-theme'));
 const box=await q.locator('.thm-tg').boundingBox(); log('Knopf:',JSON.stringify(box)); if(!box||box.y>60||box.x<300) bad('Knopf oben rechts sichtbar');
 if(await t()!=='dark') bad('Start dunkel');
 await q.click('.thm-tg'); if(await t()!=='light') bad('Knopf schaltet auf Hell');
 await q.screenshot({path:'/tmp/t195-hell.png'});
 await q.reload(); await q.waitForTimeout(700); if(await t()!=='light') bad('Hell bleibt nach Neuladen');
 const fw=await q.evaluate(()=>getComputedStyle(document.querySelector('p [data-themeset="light"]')).fontWeight); if(+fw<700) bad('Fußzeile zeigt Hell');
 await q.click('.thm-tg'); if(await t()!=='dark') bad('zurück auf Dunkel');
 await q.goto(BASE+'/rad.html#pruefen&cfg='+cfg); await q.waitForTimeout(600); if(!(await q.locator('.thm-tg').isVisible())) bad('Knopf auch auf Prüfen-Seite');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
