// v.214 (Punkt 17 Stufe 2 + Punkt 18): Software → Plattform – Laden-Anfragen bestätigen/ablehnen, Wünsche freigeben/ablehnen.
// Bestätigtes „Entfernen“ blendet den Laden öffentlich aus; freigegebener Wunsch erscheint öffentlich. Nicht-Admins sehen nichts; Stand < 31 keine Bereiche.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
const H=(o,t)=>({method:'POST',headers:{apikey:'k','Content-Type':'application/json',...(t?{Authorization:'Bearer '+t}:{})},body:JSON.stringify(o)});
const login=async email=>{ await fetch(BASE+'/auth/v1/otp',H({email,create_user:true})); const codes=await (await fetch(BASE+'/__codes')).json(); return (await fetch(BASE+'/auth/v1/verify',H({type:'email',email,token:codes[email]}))).json(); };
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const ts=Date.now(); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 await fetch(BASE+'/__schema?v=31');
 const pe='plat'+ts+'@test.de', P=await login(pe); const tp=await (await fetch(BASE+'/rest/v1/rpc/create_tenant',H({p_name:'FYF Plattform'},P.access_token))).json(); await fetch(BASE+'/__verify?admin='+encodeURIComponent(pe));
 const osm='n'+String(ts).slice(-9);
 await fetch(BASE+'/rest/v1/rpc/shop_claim_submit',H({p_osm:osm,p_name:'Radhaus Test',p_kind:'entfernen',p_contact_name:'Max Muster',p_contact:'0911 123456',p_note:'Laden geschlossen'}));
 await fetch(BASE+'/rest/v1/rpc/test_wish_seed',H({list:[]})); await fetch(BASE+'/rest/v1/rpc/wish_submit',H({p_body:'Wunsch zum Freigeben',p_device:'devtest12345'})); await fetch(BASE+'/rest/v1/rpc/wish_submit',H({p_body:'Wunsch zum Ablehnen',p_device:'devtest12345'}));
 const deny=await (await fetch(BASE+'/rest/v1/rpc/shop_claims_list',H({}))).json(); if(deny.length) bad('ohne Admin keine Anfragen');
 const ctx=async(S,T)=>{ const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); await c.addInitScript(([B,S,T])=>{ if(!localStorage.getItem('fyf-cloud')) localStorage.setItem('fyf-cloud',JSON.stringify({url:B,key:'sb_publishable_TESTKEY_1234567890abc',session:{...S,expires_at:Math.floor(Date.now()/1000)+3600},tenant:T,role:'admin',ver:0})); },[BASE,S,T]); const p=await c.newPage(); p.on('pageerror',e=>errs.push(e.message)); p.on('dialog',d=>d.accept()); return [c,p]; };
 let [c,pp]=await ctx(P,tp); await pp.goto(BASE+'/index.html'); await pp.waitForTimeout(3000);
 const openNet=async()=>{ await pp.evaluate(()=>{ const F=window.__fitframe.T118; F.ui().route='netz'; F.render(); }); await pp.waitForTimeout(2500); await pp.evaluate(()=>window.__fitframe.T118.render()); await pp.waitForTimeout(800); };
 await openNet(); let t=await pp.evaluate(()=>document.body.innerText);
 if(!/Laden-Anfragen \(1 offen\)/.test(t)||!/Radhaus Test/.test(t)||!/Entfernen lassen/.test(t)) bad('Anfrage sichtbar'); if(!/Wünsche aus dem Pass \(2 neu\)/.test(t)) bad('Wünsche sichtbar');
 await pp.locator('[data-pclm]').scrollIntoViewIfNeeded(); await pp.screenshot({path:'/tmp/t215-hell.png'});
 await pp.click('[data-act="pclmSet"][data-s="bestaetigt"]'); await pp.waitForTimeout(2500); await pp.evaluate(()=>window.__fitframe.T118.render()); await pp.waitForTimeout(500);
 const hid=await (await fetch(BASE+'/rest/v1/rpc/shop_hidden_osm',H({}))).json(); log('ausgeblendet:',JSON.stringify(hid)); if(!hid.includes(osm)) bad('Bestätigt → ausgeblendet');
 if(!(await pp.locator('[data-act="pclmSet"][data-s="offen"]').count())) bad('Wieder offen möglich');
 const wid=async body=>(await (await fetch(BASE+'/__wish')).json()).find(w=>w.body===body).id;
 const w1=await wid('Wunsch zum Freigeben'), w2=await wid('Wunsch zum Ablehnen');
 await pp.click(`[data-act="pwishSet"][data-id="${w1}"][data-p="1"][data-s="neu"]`); await pp.waitForTimeout(2500);
 await pp.evaluate(()=>window.__fitframe.T118.render()); await pp.waitForTimeout(500);
 await pp.click(`[data-act="pwishSet"][data-id="${w2}"][data-s="abgelehnt"]`); await pp.waitForTimeout(2500);
 const pub=await (await fetch(BASE+'/rest/v1/rpc/wish_list_public',H({}))).json(); log('öffentlich:',JSON.stringify(pub)); if(pub.length!==1||pub[0].body!=='Wunsch zum Freigeben') bad('nur freigegebener Wunsch öffentlich');
 await pp.evaluate(()=>window.__fitframe.T118.render()); await pp.waitForTimeout(500); t=await pp.evaluate(()=>document.body.innerText); if(!/Öffentlich\n/.test(t)||!/Abgelehnt/.test(t)) bad('Status angezeigt');
 await pp.evaluate(()=>document.documentElement.setAttribute('data-theme','dark')); await pp.emulateMedia({colorScheme:'dark'}); await pp.locator('[data-pwish]').scrollIntoViewIfNeeded(); await pp.screenshot({path:'/tmp/t215-dunkel.png'});
 const qx=await pp.evaluate(()=>document.documentElement.scrollWidth>innerWidth+2); if(qx) bad('kein Querscrollen');
 await c.close();
 // Stand 30: keine Bereiche
 await fetch(BASE+'/__schema?v=30'); [c,pp]=await ctx(P,tp); await pp.goto(BASE+'/index.html'); await pp.waitForTimeout(3000); await openNet(); if(await pp.locator('[data-pclm]').count()) bad('Stand 30: keine Laden-Anfragen'); await c.close();
 await fetch(BASE+'/__schema?v=');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
