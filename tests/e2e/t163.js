// v.163: Keine Doppelstruktur – „Unfall / Sturz“ nur noch über „Schäden & Unfälle“; Unfall-Einträge nicht löschbar (Fehleintrag), offene Unfälle zählen auf der Kachel.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push('pass: '+e.message)); q.on('dialog',d=>d.accept()); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(700);
 await q.click('#regb'); await q.fill('#rb','Cube'); await q.fill('#rm','Stereo'); await q.fill('#rf','A'+Date.now()%100000); await q.check('#rx'); await q.click('#rg button.btn:not(#rfscan)'); await q.waitForTimeout(1300);
 const code=await q.evaluate(()=>mine()[0].code); await q.evaluate(c=>{ const o=X(c); o.acc=[{id:'a1',d:'2026-10-01',what:'Sturz',parts:['Schaltwerk'],n:0}]; Xset(c,o); location.hash='#c='+c; },code); await q.waitForTimeout(1500);
 const r=await q.evaluate(()=>{ const sm=document.querySelector('[data-tmore] summary').innerText; const n=document.querySelectorAll('[data-tmore] .tool').length; return {acc:!!document.querySelector('[data-tool="acc"]'),sm,n,dmg:(document.querySelector('[data-tool="dmg"] .ts')||{}).textContent}; }); log('1',JSON.stringify(r));
 if(r.acc) bad('Kachel Unfall/Sturz noch doppelt'); if(!new RegExp('\\('+r.n+'\\)').test(r.sm)) bad('Zähler Mehr stimmt nicht'); if(!/1 offen/.test(r.dmg||'')) bad('offener Unfall zählt nicht');
 await q.evaluate(()=>{ document.querySelector('[data-tmore]').open=true; }); await q.click('[data-tool="dmg"]'); await q.waitForTimeout(400); await q.click('.tpage #dmgAcc'); await q.waitForTimeout(600);
 const del=await q.locator('.tpage [data-accdel]').count(); const txt=await q.evaluate(()=>[...document.querySelectorAll('.tpage')].pop().innerText); log('2 Unfall-Seite, Knopf:',del,/Fehleintrag/.test(txt),/Löschen/.test(txt)); if(!del||/>Löschen</.test(txt)) bad('Löschen statt Fehleintrag');
 await q.locator('.tpage [data-accdel]').first().click(); await q.waitForTimeout(500); const a=await q.evaluate(c=>X(c).acc,code); log('3 nach Fehleintrag:',JSON.stringify(a)); if(!a||a.length!==1||!a[0].void) bad('Eintrag gelöscht statt markiert');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
