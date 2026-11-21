// v.133: Ersatzrad anfragen – Pass zeigt Knopf, wenn das Rad beim eigenen Laden in Arbeit ist; Finder füllt die Anfrage; Software zeigt freie Leihräder dazu.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
const H=(o,t)=>({method:'POST',headers:{apikey:'k','Content-Type':'application/json',...(t?{Authorization:'Bearer '+t}:{})},body:JSON.stringify(o)});
const login=async email=>{ await fetch(BASE+'/auth/v1/otp',H({email,create_user:true})); const codes=await (await fetch(BASE+'/__codes')).json(); return (await fetch(BASE+'/auth/v1/verify',H({type:'email',email,token:codes[email]}))).json(); };
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 // --- Pass ---
 const c2=await b.newContext({...devices['iPhone 13']}); await c2.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 let stat='In Arbeit'; await c2.route('**/rest/v1/rpc/pass_get',async r=>{ const res=await r.fetch(); const j=await res.json(); try{ if(j){ j.shop={name:'Leihladen',slug:'leihladen'}; j.workshop=[{shop:'Leihladen',title:'Inspektion',status:stat,due:'2026-11-25'}]; } }catch(e){} await r.fulfill({response:res,json:j}); });
 const q=await c2.newPage(); q.on('pageerror',e=>errs.push('pass: '+e.message)); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(700); await q.click('#regb'); await q.fill('#rb','Cube'); await q.fill('#rm','Attain'); await q.fill('#rf','L'+Date.now()%100000); await q.check('#rx'); await q.click('#rg button.btn:not(#rfscan)'); await q.waitForTimeout(1200);
 const code=await q.evaluate(()=>mine()[0].code);
 const look=async()=>q.evaluate(async code=>{ location.hash='#meine'; await new Promise(r=>setTimeout(r,300)); location.hash='#c='+code; await new Promise(r=>setTimeout(r,1500)); const a=document.querySelector('[data-loanreq]'); return {ws:!!document.querySelector('[data-ws]'),href:a?a.getAttribute('href'):null}; },code);
 let L=await look(); log('1 In Arbeit:',JSON.stringify(L)); if(!L.href||!/finder\.html#d=leihladen&pass=.*want=loaner/.test(L.href)) bad('Knopf Ersatzrad fehlt');
 stat='Abholbereit'; L=await look(); log('2 Abholbereit → kein Knopf:',!L.href); if(L.href) bad('Knopf bei abholbereit');
 // --- Finder ---
 const A=await login('leih'+Date.now()+'@test.de'); const t=await (await fetch(BASE+'/rest/v1/rpc/create_tenant',H({p_name:'Leihladen'},A.access_token))).json();
 await fetch(BASE+'/rest/v1/rpc/save_profile',H({p_tenant:t,p:{published:true,slug:'leihladen',name:'Leihladen',zip:'91054',city:'Erlangen',services:['Inspektion']}},A.access_token));
 const f=await c2.newPage(); await f.goto(BASE+'/finder.html#d=leihladen&pass='+code+'&want=loaner&cfg='+cfg); await f.waitForTimeout(1500);
 const msg=await f.evaluate(()=>{ const m=document.getElementById('m'); return m?m.value:'KEIN FORMULAR'; }); log('3 Finder-Anfrage:',JSON.stringify(msg)); if(!/Ersatzrad \(Leihrad\)/.test(msg)||!msg.includes(code)) bad('Finder-Text Ersatzrad');
 // --- Software ---
 await fetch(BASE+'/__schema?v=28'); const c=await b.newContext({...devices['iPhone 13']}); await c.addInitScript(([B,S,T])=>{ if(!localStorage.getItem('fyf-cloud')) localStorage.setItem('fyf-cloud',JSON.stringify({url:B,key:'sb_publishable_TESTKEY_1234567890abc',session:{...S,expires_at:Math.floor(Date.now()/1000)+3600},tenant:T,role:'admin',ver:0})); },[BASE,A,t]);
 const p=await c.newPage(); p.on('pageerror',e=>errs.push('sw: '+e.message)); await p.goto(BASE+'/index.html'); await p.waitForTimeout(3000);
 const sw=await p.evaluate(async m=>{ const F=window.__fitframe.T118, S=F.S(); S.loaners=[{id:'l1',name:'Cube Trekking 52'}]; F.NET().inq=[{id:'q9',name:'Erika',contact:'e@x.de',topic:'Werkstatt',message:m,created_at:new Date().toISOString(),status:'neu'}]; F.NET().at=Date.now(); F.ui().route='netz'; F.render(); await new Promise(r=>setTimeout(r,400)); return document.body.innerText; },msg);
 const ok=/Ersatzrad gewünscht/.test(sw)&&/Frei: Cube Trekking 52/.test(sw); log('4 Software-Hinweis:',ok); if(!ok) bad('Software zeigt Ersatzrad-Hinweis nicht');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
