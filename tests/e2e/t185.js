// v.185: Studio-Look – freigestelltes Rad (PNG mit Transparenz) wird im Lichtkegel mit Spiegelung gezeigt; normales Foto bekommt den Knopf „✨ Studio-Look“.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push(e.message)); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(700);
 await q.click('#regb'); await q.fill('#rb','Canyon'); await q.fill('#rm','Grail CF 7'); await q.fill('#rf','S'+Math.floor(Math.random()*1e6)); await q.check('#rx'); await q.click('#rg button.btn:not(#rfscan)'); await q.waitForTimeout(1300);
 const code=await q.evaluate(()=>mine()[0].code);
 // 1) normales Foto → Knopf Studio-Look, kein Studio
 await q.evaluate(c=>{ const cv=document.createElement('canvas'); cv.width=400; cv.height=300; const g=cv.getContext('2d'); g.fillStyle='#887'; g.fillRect(0,0,400,300); localStorage.setItem('fyfpass:img:'+c,cv.toDataURL('image/jpeg')); location.hash='#c='+c; },code); await q.waitForTimeout(1500);
 let r=await q.evaluate(()=>({studio:!!document.querySelector('.hero .bikepic.studio'),nudge:!!document.querySelector('.hero .st-nudge')})); log('normal:',JSON.stringify(r));
 if(r.studio) bad('normales Foto darf kein Studio sein'); if(!r.nudge) bad('Knopf Studio-Look');
 await q.click('.st-nudge'); await q.waitForTimeout(400); const menu=await q.evaluate(()=>/Freigestelltes Rad einfügen/.test(document.body.innerText)); log('Menü:',menu); if(!menu) bad('Foto-Menü mit Einfügen');
 // 2) freigestelltes Rad → Studio mit Spiegelung, Garage auch
 await q.evaluate(c=>{ const cv=document.createElement('canvas'); cv.width=400; cv.height=300; const g=cv.getContext('2d'); g.fillStyle='#456'; g.fillRect(100,100,200,100); localStorage.setItem('fyfpass:imgt:'+c,cv.toDataURL('image/png')); location.hash='#meine'; },code); await q.waitForTimeout(400);
 await q.evaluate(c=>{ location.hash='#c='+c; },code); await q.waitForTimeout(1500);
 r=await q.evaluate(()=>{ const p=document.querySelector('.hero .bikepic.studio'); const i=p&&p.querySelector('.st-bike'); return {studio:!!p,refl:!!(p&&p.querySelector('.st-refl')),bg:i&&getComputedStyle(i).backgroundColor,nudge:!!document.querySelector('.hero .st-nudge:not(.st-wheel)')}; }); log('studio:',JSON.stringify(r));
 if(!r.studio||!r.refl) bad('Studio-Ansicht'); if(r.bg!=='rgba(0, 0, 0, 0)') bad('Hintergrund durchsichtig'); if(r.nudge) bad('Knopf soll bei Studio fehlen');
 await q.evaluate(()=>{ location.hash='#meine'; }); await q.waitForTimeout(1200); const g=await q.evaluate(()=>!!document.querySelector('.bikecard .bikepic.studio')); log('Garage:',g); if(!g) bad('Garage-Karte Studio');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
