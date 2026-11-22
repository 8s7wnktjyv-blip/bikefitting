// v.179: Pass dunkel als Standard; Umschalter Dunkel/Hell/Automatisch in der Garage, Wahl bleibt nach Neuladen; Händlerfinder folgt.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE',colorScheme:'light'}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push(e.message)); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(900);
 const st=()=>q.evaluate(()=>({t:document.documentElement.getAttribute('data-theme'),bg:getComputedStyle(document.documentElement).getPropertyValue('--bg').trim()}));
 let s=await st(); log('1 Standard:',JSON.stringify(s)); if(s.t!=='dark'||s.bg!=='#07090c') bad('nicht dunkel als Standard');
 await q.click('[data-themeset="light"]'); s=await st(); log('2 Hell:',JSON.stringify(s)); if(s.t!=='light'||s.bg==='#07090c') bad('Hell greift nicht');
 await q.reload(); await q.waitForTimeout(800); s=await st(); log('3 nach Neuladen:',s.t); if(s.t!=='light') bad('Wahl nicht gespeichert');
 const f=await c.newPage(); await f.goto(BASE+'/finder.html#cfg='+cfg); await f.waitForTimeout(800); const ft=await f.evaluate(()=>document.documentElement.getAttribute('data-theme')); log('4 Finder:',ft); if(ft!=='light') bad('Finder folgt nicht');
 await q.click('[data-themeset="auto"]'); s=await st(); log('5 Automatisch (Handy hell):',s.t); if(s.t!=='light') bad('Automatisch');
 await q.click('[data-themeset="dark"]'); s=await st(); if(s.t!=='dark') bad('zurück auf Dunkel');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
