const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
const H=(o,t)=>({method:'POST',headers:{apikey:'k','Content-Type':'application/json',...(t?{Authorization:'Bearer '+t}:{})},body:JSON.stringify(o)});
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const email='rev'+Date.now()+'@test.de'; await fetch(BASE+'/auth/v1/otp',H({email,create_user:true})); const codes=await (await fetch(BASE+'/__codes')).json(); const s=await (await fetch(BASE+'/auth/v1/verify',H({type:'email',email,token:codes[email]}))).json();
 const t=await (await fetch(BASE+'/rest/v1/rpc/create_tenant',H({p_name:'Testladen'},s.access_token))).json(); await fetch(BASE+'/__schema?v=24');
 const pr=await (await fetch(BASE+'/rest/v1/rpc/save_profile',H({p_tenant:t,p:{slug:'testladen',name:'Testladen',city:'Uttenreuth',zip:'91080',published:true,services:['Werkstatt']}},s.access_token))).text(); log('0 Profil:',pr.slice(0,60));
 await fetch(BASE+'/__rev',H({list:[]}));
 // Pass: Bewertung abgeben
 const c=await b.newContext({...devices['iPhone 13']}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} }); const p=await c.newPage(); p.on('pageerror',e=>errs.push('pass: '+e.message));
 await p.goto(BASE+'/rad.html#meine&cfg='+cfg); await p.waitForTimeout(700); await p.click('#regb'); await p.fill('#rb','Cube'); await p.fill('#rm','Attain'); await p.fill('#rf','K'+Date.now()%100000); await p.check('#rx'); await p.click('#rg button.btn:not(#rfscan)'); await p.waitForTimeout(1200);
 const code=await p.evaluate(()=>mine()[0].code); await p.evaluate(c=>{ location.hash='#c='+c; },code); await p.waitForTimeout(1200);
 log('0b own vorhanden:', await p.evaluate(c=>!!ownGet(c),code));
 await p.evaluate(c=>localStorage.setItem('fyfpass:own:'+c,'TESTCODE1234'),code); await p.route(/rpc\/pass_get(_owner)?$/, async route=>{ const req=route.request(); const own=/pass_get_owner$/.test(req.url()); const r=await route.fetch(own?{url:req.url().replace(/pass_get_owner$/,'pass_get'),postData:JSON.stringify({p_code:JSON.parse(req.postData()).p_code})}:undefined); const j=await r.json(); if(j&&!j.error){ j.limited=false; const d=new Date().toISOString().slice(0,10); j.entries=(j.entries||[]).concat([{id:701,shop:'Testladen',kind:'Inspektion',text:'Bremsen, Kette',date:d,trust:'shop'},{id:702,shop:'Besitzer',kind:'Service',text:'selbst',date:d,trust:'self'}]); } route.fulfill({response:r,json:j}); });
 await p.evaluate(c=>{ location.hash='#c='+c+'&r=1'; },code); await p.waitForTimeout(1800);
 log('1 Karte:', await p.evaluate(()=>{ const x=document.querySelector('[data-rev]'); return x?x.innerText.replace(/\s+/g,' ').slice(0,160):'FEHLT'; }));
 await p.click('[data-revgo="701"]'); await p.waitForTimeout(300); await p.click('[data-st="4"]'); await p.fill('#revT','Schnell und freundlich'); await p.click('#revS'); await p.waitForTimeout(800);
 log('2 nach Senden:', await p.evaluate(()=>{ const x=document.querySelector('[data-rev]'); return x?(/★★★★☆/.test(x.innerText)?'4 Sterne angezeigt':'NICHT markiert'):'FEHLT'; }));
 // Finder
 await fetch(BASE+'/__rev',H({list:[{id:1,entry:701,code,stars:4,text:'Schnell und freundlich',at:new Date().toISOString(),reply:null,slug:'testladen'},{id:2,entry:9,code:'X',stars:5,text:'Top',at:new Date().toISOString(),reply:'Danke!',slug:'testladen'},{id:3,entry:10,code:'Y',stars:3,text:null,at:new Date().toISOString(),reply:null,slug:'testladen'}]}));
 const f=await c.newPage(); f.on('pageerror',e=>errs.push('finder: '+e.message)); await f.goto(BASE+'/finder.html#cfg='+cfg); await f.waitForTimeout(1500);
 log('3 Liste:', await f.evaluate(()=>{ const x=document.querySelector('[data-rv]'); return x?x.innerText:'FEHLT'; }));
 await f.click('a[data-d="testladen"]'); await f.waitForTimeout(1000); log('4 Laden-Seite:', await f.evaluate(()=>{ const x=document.getElementById('revs'); return x?x.innerText.replace(/\s+/g,' ').slice(0,220):'FEHLT'; }));
 // Händlersoftware
 const d=await b.newContext({...devices['iPhone 13']}); await d.addInitScript(([B,S,T])=>{ if(!localStorage.getItem('fyf-cloud')) localStorage.setItem('fyf-cloud',JSON.stringify({url:B,key:'sb_publishable_TESTKEY_1234567890abc',session:{...S,expires_at:Math.floor(Date.now()/1000)+3600},tenant:T,role:'admin',ver:0})); },[BASE,s,t]);
 const q=await d.newPage(); q.on('pageerror',e=>errs.push('laden: '+e.message)); q.on('dialog',x=>x.accept('Test')); await q.goto(BASE+'/index.html'); await q.waitForTimeout(2000);
 await q.evaluate(()=>{ const F=window.__fitframe.T118; F.ui().route='netz'; F.render(); }); await q.waitForTimeout(1500);
 log('5 Laden-Panel:', await q.evaluate(()=>{ const s=[...document.querySelectorAll('section.panel')].find(x=>/Bewertungen/.test(x.innerText)); return s?s.innerText.replace(/\s+/g,' ').slice(0,200):'FEHLT'; }));
 await q.evaluate(()=>{ document.querySelectorAll('section.panel details').forEach(x=>x.open=true); }); const tid=await q.evaluate(()=>document.querySelector('form[data-form="revReply"]').dataset.id);
 await q.fill(`#rr${tid}`,'Danke für das Lob!'); await q.click(`form[data-form="revReply"][data-id="${tid}"] button[type=submit]`); await q.waitForTimeout(1200);
 log('6 Antwort gespeichert:', await q.evaluate(()=>/Danke für das Lob/.test(document.body.innerText)));
 log('Fehler:',errs.length?errs:'keine'); await b.close(); })();
