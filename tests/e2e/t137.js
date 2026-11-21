// v.137: Import aus altem System – Sicherung vorher, „Import rückgängig“ stellt den alten Stand her (Kunden und Artikel).
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const p=await (await b.newContext({...devices['iPhone 13']})).newPage(); p.on('pageerror',e=>errs.push(e.message)); await p.goto(BASE+'/index.html'); await p.waitForTimeout(1500);
 const E=f=>p.evaluate(f);
 const before=await E(()=>{ const S=window.__fitframe.S(); return {c:S.customers.length,b:S.bikes.length}; });
 await E(()=>window.__fitframe.T118.ACT.impOpen()); await p.waitForTimeout(300);
 await p.setInputFiles('#im_f',{name:'kunden.csv',mimeType:'text/csv',buffer:Buffer.from('Name;E-Mail;Telefon;Marke;Modell\nAnna Altsystem;anna@example.de;0171 1;Cube;Kathmandu\nBernd Altsystem;bernd@example.de;0171 2;Giant;Defy\n','utf8')}); await p.waitForTimeout(500);
 await p.click('[data-act="impRun"]'); await p.waitForTimeout(500);
 const after=await E(()=>{ const S=window.__fitframe.S(); return {c:S.customers.length,b:S.bikes.length,dr:(document.querySelector('#overlay .drawer')||{}).innerText||''}; }); log('1 nach Import:',after.c-before.c,'Kunden,',after.b-before.b,'Räder neu · Fenster:',/Import fertig/.test(after.dr)); if(after.c-before.c!==2||!/Import rückgängig/.test(after.dr)) bad('Import oder Rückgängig-Knopf');
 const key=await E(()=>Object.keys(localStorage).some(k=>/^fitframe-before-import-/.test(k))); log('2 Sicherung im Browser:',key); if(!key) bad('Sicherung fehlt');
 await p.click('[data-act="impUndo"]'); await p.waitForTimeout(200); await p.click('[data-act="impUndo"]'); await p.waitForTimeout(500);
 const undo=await E(()=>{ const S=window.__fitframe.S(); return {c:S.customers.length,b:S.bikes.length,anna:S.customers.some(c=>/Anna Altsystem/.test(c.name))}; }); log('3 nach Rückgängig:',JSON.stringify(undo)); if(undo.c!==before.c||undo.b!==before.b||undo.anna) bad('Rückgängig stellt nicht her');
 await p.reload(); await p.waitForTimeout(1500); const kept=await E(()=>!window.__fitframe.S().customers.some(c=>/Anna Altsystem/.test(c.name))); log('4 nach Neuladen weiter alter Stand:',kept); if(!kept) bad('Rückgängig nicht gespeichert');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
