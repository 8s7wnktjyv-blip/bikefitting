// v.128: Rollen Werkstattleitung, Verkauf, Filialleitung, Buchhaltung – vergebbar (ab DB-Stand 26), Server filtert je Rolle.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
const H=(o,t)=>({method:'POST',headers:{apikey:'k','Content-Type':'application/json',...(t?{Authorization:'Bearer '+t}:{})},body:JSON.stringify(o)});
const login=async email=>{ await fetch(BASE+'/auth/v1/otp',H({email,create_user:true})); const codes=await (await fetch(BASE+'/__codes')).json(); return (await fetch(BASE+'/auth/v1/verify',H({type:'email',email,token:codes[email]}))).json(); };
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const ts=Date.now(); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const A=await login('chef'+ts+'@test.de'); const t=await (await fetch(BASE+'/rest/v1/rpc/create_tenant',H({p_name:'Rollen-Laden'},A.access_token))).json();
 await fetch(BASE+'/rest/v1/rpc/save_state',H({p_tenant:t,p_expected:0,p_data:{version:3,customers:[{id:'c1',name:'Erika',body:{height:170}}],bikes:[],sessions:[],workshop:[{id:'W1',title:'Inspektion'}],invoices:[{id:'i1',no:'RE-1',status:'offen'}],payments:[{id:'p1',amount:50}],sales:[],suppliers:[{id:'l1',name:'Großhandel'}],purchaseOrders:[],invSeq:1,datev:{k:1},dunCfg:{d:1}}},A.access_token));
 const ctx=async(S,role)=>{ const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); await c.addInitScript(([B,S,T,R])=>{ if(!localStorage.getItem('fyf-cloud')) localStorage.setItem('fyf-cloud',JSON.stringify({url:B,key:'sb_publishable_TESTKEY_1234567890abc',session:{...S,expires_at:Math.floor(Date.now()/1000)+3600},tenant:T,role:R,ver:0})); },[BASE,S,t,role]); const p=await c.newPage(); p.on('pageerror',e=>errs.push(role+': '+e.message)); p.on('dialog',d=>d.accept()); return p; };
 const teamOpts=p=>p.evaluate(()=>{ const F=window.__fitframe.T118; F.ui().route='mehr'; F.render(); return new Promise(r=>setTimeout(()=>{ const s=document.getElementById('tm_role'); r(s?[...s.options].map(o=>o.value):null); },1500)); });
 // Alte Datenbank (Stand 25): nur 3 Rollen anbieten
 await fetch(BASE+'/__schema?v=25'); const pa=await ctx(A,'admin'); await pa.goto(BASE+'/index.html'); await pa.waitForTimeout(3000);
 let o=await teamOpts(pa); log('1 Rollen bei Stand 25:',JSON.stringify(o)); if(!o||o.length!==3) bad('Stand 25: 3 Rollen erwartet');
 await fetch(BASE+'/__schema?v=26'); await pa.reload(); await pa.waitForTimeout(3000);
 o=await teamOpts(pa); log('2 Rollen bei Stand 26:',JSON.stringify(o)); if(!o||!['werkstattleitung','verkauf','filialleitung','buchhaltung'].every(r=>o.includes(r))||o.length!==7) bad('Stand 26: 7 Rollen erwartet');
 log('2b Erklärung sichtbar:', await pa.evaluate(()=>/Was sieht welche Rolle/.test(document.body.innerText)));
 const st=async tok=>(await (await fetch(BASE+'/rest/v1/rpc/state_get',H({p_tenant:t},tok))).json());
 const join=async role=>{ const e=role+ts+'@test.de'; await fetch(BASE+'/rest/v1/rpc/invite_member',H({p_tenant:t,p_email:e,p_role:role},A.access_token)); const U=await login(e); await fetch(BASE+'/rest/v1/rpc/accept_invites',H({},U.access_token)); return U; };
 // Werkstattleitung: kein Geld, Lager sichtbar, Rechnungen-Ansicht gesperrt mit Rollenname
 const W=await join('werkstattleitung'); const sw=await st(W.access_token); log('3 Werkstattleitung hidden:',JSON.stringify(sw&&sw.hidden),'Lieferanten:',!!(sw&&sw.data&&sw.data.suppliers));
 if(!sw||sw.role!=='werkstattleitung'||'invoices' in sw.data||!sw.data.suppliers) bad('Werkstattleitung: Filter falsch');
 const pw=await ctx(W,'werkstattleitung'); await pw.goto(BASE+'/index.html'); await pw.waitForTimeout(4000); await pw.evaluate(()=>window.__fitframe.ACT.cloudTakeServer()); await pw.waitForTimeout(1500);
 await pw.evaluate(()=>{ const F=window.__fitframe.T118; F.ui().route='rechnungen'; F.render(); }); await pw.waitForTimeout(300);
 const tw=await pw.evaluate(()=>document.body.innerText); log('4 Werkstattleitung Rechnungen:', /Für deine Rolle gesperrt/.test(tw)&&/Rolle Werkstattleitung/.test(tw)?'gesperrt-Hinweis':'NICHT markiert');
 await pw.evaluate(()=>{ const S=window.__fitframe.S(); S.workshop[0].title='Inspektion [WL]'; window.__fitframe.save(); }); await pw.waitForTimeout(4500);
 const s2=await st(A.access_token); const ok2=(s2.data.invoices||[]).length===1&&s2.data.datev&&s2.data.dunCfg&&(s2.data.payments||[]).length===1&&/\[WL\]/.test(s2.data.workshop[0].title);
 log('5 nach Speichern Werkstattleitung: Auftrag geändert + Geld unverändert:',!!ok2); if(!ok2) bad('Werkstattleitung-Speichern verliert/ändert Daten');
 // Verkauf: Rechnungen ja, DATEV/Mahnwesen nein; Buchhaltung/Filialleitung: alles
 const V=await join('verkauf'); const sv=await st(V.access_token); log('6 Verkauf hidden:',JSON.stringify(sv.hidden),'Rechnungen:',(sv.data.invoices||[]).length); if(!sv.data.invoices||'datev' in sv.data) bad('Verkauf: Filter falsch');
 const B=await join('buchhaltung'); const sb=await st(B.access_token); log('7 Buchhaltung hidden:',JSON.stringify(sb.hidden)); if(sb.hidden.length||!sb.data.datev) bad('Buchhaltung: soll alles sehen');
 const L=await join('filialleitung'); const sl=await st(L.access_token); log('8 Filialleitung hidden:',JSON.stringify(sl.hidden)); if(sl.hidden.length) bad('Filialleitung: soll alles sehen');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
