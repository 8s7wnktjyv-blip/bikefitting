// v.198: „Panne unterwegs?“ direkt unter Werkstätten (ohne angelegtes Rad) öffnet „Helfer in der Nähe“ im Pass.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push(e.message)); await q.goto(BASE+'/finder.html#w=1&cfg='+cfg); await q.waitForTimeout(1500);
 const a=q.locator('a.nr-help'); if(!(await a.count())) bad('Knopf „Panne unterwegs?“ unter Werkstätten');
 else { const href=await a.getAttribute('href'); if(!/rad\.html#hilfe=1/.test(href)) bad('Link auf Helfer'); await a.click(); await q.waitForTimeout(1500);
   const t=await q.evaluate(()=>{ const p=[...document.querySelectorAll('.tpage')].pop(); return p?p.textContent:''; });
   if(!/Helfer in der Nähe/.test(t)) bad('Helfer-Seite offen (ohne Rad)'); if(!/Meinen Standort verwenden/.test(t)) bad('Standort-Knopf'); }
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
