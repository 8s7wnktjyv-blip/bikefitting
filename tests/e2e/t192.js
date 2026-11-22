// v.192: Leere Garage mit Nutzen-Chips und 1-Minuten-Knopf; Ringe-Animation registriert; Vibration beim Speichern.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); window.__vib=[]; navigator.vibrate=ms=>{ window.__vib.push(ms); return true; }; }catch(e){} });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push(e.message)); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(900);
 let r=await q.evaluate(()=>({h:(document.querySelector('.empty h2')||{}).textContent,chips:[...document.querySelectorAll('.em-chips span')].map(x=>x.textContent),btn:(document.querySelector('#regb')||{}).textContent,konto:(document.querySelector('.cl-grp .cl-note')||{}).textContent}));
 log(JSON.stringify(r)); if(r.h!=='Gib deinem Rad einen Ausweis.') bad('Überschrift'); if(r.chips.length!==3) bad('3 Nutzen-Chips'); if(!/1 Minute/.test(r.btn||'')) bad('1-Minuten-Knopf'); if(r.konto&&r.konto!=='optional') bad('ohne Rad keine Konto-Warnung');
 await q.click('#regb'); await q.fill('#rb','Canyon'); await q.fill('#rm','Grail'); await q.fill('#rf','S'+Math.floor(Math.random()*1e6)); await q.check('#rx'); await q.click('#rg button.btn:not(#rfscan)'); await q.waitForTimeout(1300);
 await q.evaluate(()=>toast('Gespeichert')); const v=await q.evaluate(()=>window.__vib.length); log('Vibration:',v); if(!v) bad('Vibration beim Speichern');
 const anim=await q.evaluate(()=>[...document.styleSheets].some(s=>{ try{ return [...s.cssRules].some(x=>x.cssText&&/fyfRing/.test(x.cssText)); }catch(e){ return false; } })); if(!anim) bad('Ring-Animation');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
