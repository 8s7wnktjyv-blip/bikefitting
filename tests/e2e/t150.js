// v.150: Pass – Jahresziel mit Fortschritt aus km-Verlauf, Abzeichen, Kachel auf „Mein Rad“.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push('pass: '+e.message)); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(700);
 await q.click('#regb'); await q.fill('#rb','Rose'); await q.fill('#rm','Backroad'); await q.fill('#rf','G'+Date.now()%100000); await q.check('#rx'); await q.click('#rg button.btn:not(#rfscan)'); await q.waitForTimeout(1300);
 const code=await q.evaluate(()=>mine()[0].code); const y=new Date().getFullYear();
 await q.evaluate(([c,y])=>{ const o=X(c); o.km=2500; o.kmAt=y+'-11-01'; o.kmLog=[{d:y+'-01-05',km:1000,src:'manuell'},{d:y+'-11-01',km:2500,src:'manuell'}]; Xset(c,o); },[code,y]);
 await q.evaluate(c=>{ location.hash='#c='+c; },code); await q.waitForTimeout(1500);
 let g=await q.evaluate(()=>document.querySelector('.gl-goal')?.innerText.replace(/\s+/g,' ')||''); log('1 Kachel ohne Ziel:',g); if(!/Ziel setzen/.test(g)) bad('Kachel Ziel setzen');
 await q.click('.gl-goal'); await q.waitForTimeout(400); await q.click('.tpage [data-gl="3000"]'); await q.waitForTimeout(300);
 const t=await q.evaluate(()=>[...document.querySelectorAll('.tpage')].pop().innerText.replace(/\s+/g,' ')); log('2 Seite:',t.slice(0,160)); if(!/1\.500 \/ 3\.000 km/.test(t)||!/50 %/.test(t)) bad('Fortschritt 1.500/3.000 = 50 %');
 const on=await q.locator('.tpage .bdg.on').count(); log('3 Abzeichen erreicht:',on); if(on<1) bad('Abzeichen 1.000 km fehlt');
 await q.evaluate(()=>{ document.querySelectorAll('.tpage .tp-back').forEach(x=>x.click()); }); await q.waitForTimeout(400);
 g=await q.evaluate(()=>document.querySelector('.gl-goal')?.innerText.replace(/\s+/g,' ')||''); log('4 Kachel danach:',g); if(!/50 %/.test(g)) bad('Kachel aktualisiert nicht');
 const ov=await q.evaluate(()=>document.documentElement.scrollWidth>innerWidth+1); if(ov) bad('Querscroll');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
