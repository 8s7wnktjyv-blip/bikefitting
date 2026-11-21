// v.129: Kündigung – Plattform-Admin schließt einen Laden; ehemaliges Mitglied sieht „Zugang beendet“ und kann Daten sichern; Wieder öffnen.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
const H=(o,t)=>({method:'POST',headers:{apikey:'k','Content-Type':'application/json',...(t?{Authorization:'Bearer '+t}:{})},body:JSON.stringify(o)});
const login=async email=>{ await fetch(BASE+'/auth/v1/otp',H({email,create_user:true})); const codes=await (await fetch(BASE+'/__codes')).json(); return (await fetch(BASE+'/auth/v1/verify',H({type:'email',email,token:codes[email]}))).json(); };
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const ts=Date.now(); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 await fetch(BASE+'/__schema?v=27');
 // Plattform-Admin mit eigenem Laden, Kunde „Kündiger-Laden“ mit Admin
 const pe='plat'+ts+'@test.de', P=await login(pe); const tp=await (await fetch(BASE+'/rest/v1/rpc/create_tenant',H({p_name:'FYF Plattform'},P.access_token))).json(); await fetch(BASE+'/__verify?admin='+encodeURIComponent(pe));
 const K=await login('kd'+ts+'@test.de'); const tk=await (await fetch(BASE+'/rest/v1/rpc/create_tenant',H({p_name:'Kündiger-Laden'},K.access_token))).json();
 await fetch(BASE+'/rest/v1/rpc/save_state',H({p_tenant:tk,p_expected:0,p_data:{version:3,customers:[{id:'c1',name:'Erika'}],bikes:[],sessions:[],workshop:[]}},K.access_token));
 const ctx=async(S,T,role)=>{ const c=await b.newContext({...devices['iPhone 13'],acceptDownloads:true,locale:'de-DE'}); await c.addInitScript(([B,S,T,R])=>{ if(!localStorage.getItem('fyf-cloud')) localStorage.setItem('fyf-cloud',JSON.stringify({url:B,key:'sb_publishable_TESTKEY_1234567890abc',session:{...S,expires_at:Math.floor(Date.now()/1000)+3600},tenant:T,role:R,ver:0})); },[BASE,S,T,role]); const p=await c.newPage(); p.on('pageerror',e=>errs.push(role+': '+e.message)); return p; };
 const pp=await ctx(P,tp,'admin'); await pp.goto(BASE+'/index.html'); await pp.waitForTimeout(3000);
 const openNet=async()=>{ await pp.evaluate(()=>{ const F=window.__fitframe.T118; F.ui().route='netz'; F.render(); }); await pp.waitForTimeout(2500); await pp.evaluate(()=>{ window.__fitframe.T118.render(); }); await pp.waitForTimeout(800); };
 await openNet(); const n1=await pp.locator('[data-act="platClose"]').count(); log('1 Knöpfe „Laden schließen“:',n1); if(n1<1) bad('Knopf Laden schließen fehlt');
 pp.once('dialog',d=>d.accept('Kündigung zum 31.12.2026')); await pp.click(`[data-act="platClose"][data-id="${tk}"]`); await pp.waitForTimeout(2500); await openNet();
 const t2=await pp.evaluate(()=>document.body.innerText); const ok2=/Geschlossen seit/.test(t2)&&/Kündigung zum 31\.12\.2026/.test(t2)&&/Wieder öffnen/.test(t2); log('2 Plattform zeigt geschlossen + Grund:',ok2); if(!ok2) bad('Status geschlossen nicht sichtbar');
 // Ehemaliger Admin: Server gibt nichts mehr, App zeigt „Zugang beendet“ mit Sichern-Knopf
 const r=await fetch(BASE+'/rest/v1/rpc/state_get',H({p_tenant:tk},K.access_token)); log('3 Server für Ex-Admin:',r.status); if(r.status<400) bad('Ex-Admin bekommt noch Daten');
 const pk=await ctx(K,tk,'admin'); await pk.goto(BASE+'/index.html'); await pk.waitForTimeout(4500);
 await pk.evaluate(()=>{ const F=window.__fitframe.T118; F.ui().route='mehr'; F.render(); }); await pk.waitForTimeout(500);
 const t4=await pk.evaluate(()=>document.body.innerText); const ok4=/Zugang für „Kündiger-Laden“ ist beendet/.test(t4)&&/Daten als Datei sichern/.test(t4); log('4 Ex-Admin sieht Hinweis + Sichern:',ok4); if(!ok4) bad('Hinweis Zugang beendet fehlt');
 const [dl]=await Promise.all([pk.waitForEvent('download',{timeout:5000}).catch(()=>null),pk.click('text=Daten als Datei sichern').catch(()=>{})]); log('4b Sicherung als Datei:',dl?dl.suggestedFilename():'KEINE'); if(!dl) bad('Sichern liefert keine Datei');
 log('4c lokale Daten noch da:', await pk.evaluate(()=>window.__fitframe.S().customers.length>0));
 // Wieder öffnen
 pp.once('dialog',d=>d.accept()); await pp.click(`[data-act="platReopen"][data-id="${tk}"]`); await pp.waitForTimeout(2000);
 const r2=await fetch(BASE+'/rest/v1/rpc/state_get',H({p_tenant:tk},K.access_token)); log('5 nach Wieder öffnen Server:',r2.status); if(r2.status>=400) bad('Wieder öffnen gibt Zugang nicht zurück');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
