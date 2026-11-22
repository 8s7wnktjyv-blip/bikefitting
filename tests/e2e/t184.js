// v.184: Lebenslauf – Ereignisse aus Wartung, Teiletausch, Schaden, Kauf, neueste zuerst, „Alle anzeigen“ ab 7.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push(e.message)); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(700);
 await q.click('#regb'); await q.fill('#rb','Canyon'); await q.fill('#rm','Grail'); await q.fill('#rf','L'+Date.now()%100000); await q.check('#rx'); await q.click('#rg button.btn:not(#rfscan)'); await q.waitForTimeout(1300);
 const code=await q.evaluate(()=>mine()[0].code);
 await q.evaluate(c=>{ const o=X(c); o.svc={chain:{d:'2026-09-10',km:3600}}; o.partsHist=[{k:'chain',from:'A',to:'B',km:3600,d:'2026-09-11'},{k:'tires',to:'T1',d:'2026-04-02'},{k:'saddle',to:'S1',d:'2026-03-02'},{k:'pedals',to:'P1',d:'2026-02-02'}]; o.dmg=[{id:'x',t:'Sturz',d:'2026-07-14',st:'repariert',log:[]}]; o.docs=[{id:'d1',name:'Kaufbeleg Rad',date:'2025-03-01',amount:'2.499'}]; Xset(c,o); location.hash='#c='+c; },code); await q.waitForTimeout(1600);
 const r=await q.evaluate(()=>{ const L=[...document.querySelectorAll('[data-life] li')]; return {n:L.length,vis:L.filter(l=>getComputedStyle(l).display!=='none').length,first:L[0]&&L[0].querySelector('b').textContent,last:L[L.length-1]&&L[L.length-1].querySelector('b').textContent,btn:!!document.querySelector('[data-lifeall]')}; }); log(JSON.stringify(r));
 if(r.n!==7||r.vis!==6||!r.btn) bad('Anzahl/Einklappen'); if(!/Kette: A → B/.test(r.first)) bad('neueste zuerst'); if(r.last!=='Rad gekauft') bad('Kauf als ältestes');
 await q.click('[data-lifeall]'); const v=await q.evaluate(()=>[...document.querySelectorAll('[data-life] li')].filter(l=>getComputedStyle(l).display!=='none').length); log('nach Alle:',v); if(v!==7) bad('Alle anzeigen');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
