// v.157: Pass – Wartungsplan je nach Teilen: 12-fach-Kette früher, SRAM-Bremse jährlich, Shimano 2 Jahre, Carbon-Punkt.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push('pass: '+e.message)); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(700);
 await q.click('#regb'); await q.fill('#rb','Canyon'); await q.fill('#rm','Grail CF 7'); await q.fill('#rf','I'+Date.now()%100000); await q.check('#rx'); await q.click('#rg button.btn:not(#rfscan)'); await q.waitForTimeout(1300);
 const code=await q.evaluate(()=>mine()[0].code);
 const plan=async parts=>q.evaluate(([c,p])=>{ const o=X(c); o.parts=p; Xset(c,o); const L=svcPlan(bikeType(c),c); const g=k=>L.find(z=>z.k===k)||{}; return {chain:g('chain').km,bleed:g('bleed').m,carbon:!!L.find(z=>z.k==='carbon'),base:svcPlan.toString().length>0}; },[code,parts]);
 const p0=await plan({}); const p1=await plan({groupset:'SRAM Rival AXS',brakes:'SRAM Rival',material:'Carbon'}); const p2=await plan({groupset:'Shimano GRX RX400',brakes:'Shimano GRX'});
 log('ohne Teile:',JSON.stringify(p0)); log('SRAM AXS/Carbon:',JSON.stringify(p1)); log('Shimano 10-fach:',JSON.stringify(p2));
 if(!(p1.chain<p0.chain)) bad('12-fach-Kette nicht früher'); if(p1.bleed!==12) bad('SRAM jährlich'); if(!p1.carbon) bad('Carbon-Punkt'); if(p2.bleed!==24||p2.chain!==p0.chain) bad('Shimano 10-fach falsch angepasst');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
