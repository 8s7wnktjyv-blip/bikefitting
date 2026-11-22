// v.187: Zustands-Check mit Fragen (Gebrauchtrad) – ohne Pass über „Rad prüfen“, mit Pass im Kauf-Check; regelbasiertes Urteil; Garage-Karten mit Fahrer-Etikett.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push(e.message)); await q.goto(BASE+'/rad.html#pruefen&cfg='+cfg); await q.waitForTimeout(900);
 await q.click('[data-cqfree]'); await q.waitForTimeout(300);
 let v=await q.evaluate(()=>document.querySelector('.cq-v').textContent); log('leer:',v); if(v!=='Fragen beantworten') bad('Startzustand');
 const pick=async(k,a)=>{ await q.click(`.tpage [data-q="${k}"][data-a="${a}"]`); await q.waitForTimeout(80); };
 for(const k of ['frame','hs','bb','drive','shift','brake','wheel','tire','noise']) await pick(k,0); await pick('sus',3); await pick('pivot',3); await pick('ebike',3);
 v=await q.evaluate(()=>document.querySelector('.cq-v').textContent); log('alles gut:',v); if(v!=='Guter Zustand') bad('Urteil gut');
 await pick('sus',2); v=await q.evaluate(()=>[document.querySelector('.cq-v').textContent,document.querySelectorAll('.cq-todo li').length]); log('Federung schlecht:',JSON.stringify(v)); if(!/Reparaturen nötig/.test(v[0])||v[1]!==1) bad('Urteil Reparatur');
 await pick('frame',2); v=await q.evaluate(()=>[document.querySelector('.cq-v').textContent,document.querySelector('.cq-todo li b').textContent]); log('Riss:',JSON.stringify(v)); if(!/Nicht ohne Werkstatt/.test(v[0])||v[1]!=='Rahmen & Gabel') bad('Urteil kritisch, kritisch zuerst');
 const saved=await q.evaluate(()=>Object.keys(JSON.parse(localStorage.getItem('fyfpass:cq:frei'))).length); log('gespeichert:',saved); if(saved!==12) bad('Antworten gespeichert');
 // mit Pass: Kauf-Check
 await q.evaluate(()=>{ document.querySelectorAll('.tpage').forEach(x=>x.remove()); document.body.style.overflow=''; location.hash='#meine'; }); await q.waitForTimeout(800);
 await q.click('#regb'); await q.fill('#rb','Canyon'); await q.fill('#rm','Grail'); await q.fill('#rf','S'+Math.floor(Math.random()*1e6)); await q.check('#rx'); await q.click('#rg button.btn:not(#rfscan)'); await q.waitForTimeout(1300);
 const code=await q.evaluate(()=>mine()[0].code); await q.evaluate(c=>{ const o=X(c); o.rider='Dominik'; Xset(c,o); location.hash='#pruefen'; },code); await q.waitForTimeout(400); await q.evaluate(()=>{ location.hash='#meine'; }); await q.waitForTimeout(1400);
 const rd=await q.evaluate(()=>{ const x=document.querySelector('a.bikecard .gc-rider'); return x&&x.textContent; }); log('Fahrer-Etikett:',rd); if(rd!=='Dominik') bad('Fahrer-Etikett');
 await q.evaluate(c=>buyCheck(c),code); await q.waitForTimeout(500); const e=await q.evaluate(()=>!!document.querySelector('.tpage [data-cqgo]')); log('Kauf-Check Einstieg:',e); if(!e) bad('Einstieg im Kauf-Check');
 await q.click('.tpage [data-cqgo]'); await q.waitForTimeout(300); v=await q.evaluate(()=>document.querySelector('.cq-k').textContent); log('Kopf:',v); if(!/Canyon Grail/.test(v)) bad('Radname im Check');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
