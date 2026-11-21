// v.139: Pass auf Englisch (Stufe 1) – Umschalten, Hauptseiten und Werkzeuge ohne deutsche Reste aus dem Wörterbuch, keine Fehler, zurück auf Deutsch.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push(e.message)); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(800);
 log('1 Standard Deutsch:',await q.evaluate(()=>window.FYF_LANG)); await q.click('#regb'); await q.fill('#rb','Cube'); await q.fill('#rm','Attain'); await q.fill('#rf','EN'+Date.now()%100000); await q.check('#rx'); await q.click('#rg button.btn:not(#rfscan)'); await q.waitForTimeout(1500);
 const code=await q.evaluate(()=>mine()[0].code); await q.evaluate(()=>{ location.hash='#meine'; }); await q.waitForTimeout(800);
 await q.click('[data-lang="en"]'); await q.waitForTimeout(1500); log('2 nach Umschalten:',await q.evaluate(()=>window.FYF_LANG),'Wörterbuch:',await q.evaluate(()=>window.FYF_EN&&window.FYF_EN.count()));
 const left=async()=>q.evaluate(()=>{ const out=new Set(); const w=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT); let n; while(n=w.nextNode()){ const t=n.nodeValue.replace(/\s+/g,' ').trim(); if(t&&n.parentElement&&!n.parentElement.closest('[data-notr],script,style')){ const x=window.FYF_EN.T(t); if(x!=null&&x!==t) out.add(t); } } return [...out]; });
 let L=await left(); log('3 Garage – deutsche Reste:',L.length,L.slice(0,3)); if(L.length) bad('Garage nicht übersetzt');
 const gt=await q.evaluate(()=>document.body.innerText); if(!/Register bike|Your bike|Garage/.test(gt)) bad('Garage zeigt kein Englisch');
 await q.evaluate(c=>{ location.hash='#c='+c; },code); await q.waitForTimeout(1800); L=await left(); log('4 Radseite – Reste:',L.length,L.slice(0,3)); if(L.length) bad('Radseite nicht übersetzt');
 for(const t of ['svc','theft','parts','docs']){ await q.evaluate(()=>document.querySelectorAll('.tpage,.sheet').forEach(e=>e.remove())); await q.evaluate(t=>{ const b=document.querySelector(`[data-tool="${t}"]`); if(b) b.click(); },t); await q.waitForTimeout(900); await q.evaluate(()=>document.querySelectorAll('details').forEach(d=>d.open=true)); await q.waitForTimeout(300); L=await left(); log('5 Werkzeug',t,'– Reste:',L.length,L.slice(0,2)); if(L.length) bad('Werkzeug '+t+' nicht übersetzt'); }
 const ov=await q.evaluate(()=>document.documentElement.scrollWidth>innerWidth+1); if(ov) bad('Querscroll');
 await q.evaluate(()=>document.querySelectorAll('.tpage,.sheet').forEach(e=>e.remove())); await q.evaluate(()=>{ location.hash='#meine'; }); await q.waitForTimeout(800); await q.click('[data-lang="de"]'); await q.waitForTimeout(1500);
 const de=await q.evaluate(()=>({l:window.FYF_LANG,en:!!window.FYF_EN,t:document.body.innerText})); log('6 zurück:',de.l,'Englisch geladen:',de.en); if(de.l!=='de'||de.en||!/Rad registrieren|Garage/.test(de.t)) bad('Zurückschalten');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
