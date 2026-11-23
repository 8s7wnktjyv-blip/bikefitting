// v.214 (Punkt 18): „Wünsch dir was“ – eigener Wunsch (Prüfung auf persönliche Daten, Senden an wish_submit, max. 3/Tag),
// freigegebene Wünsche mit Abstimmen (keine Doppelstimme); ohne Stand 31 kein Feld. Hell + dunkel per Screenshot.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 await fetch(BASE+'/rest/v1/rpc/test_wish_seed',{method:'POST',headers:{apikey:'x','Content-Type':'application/json'},body:JSON.stringify({list:[{body:'Dunkle Karte für Nachtfahrten',votes:4},{body:'Reifendruck-Erinnerung',votes:9,status:'uebernommen'},{body:'Abgelehnt',status:'abgelehnt'},{body:'Nicht frei',public:false}]})});
 const open=async(theme,block)=>{ const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE',colorScheme:theme}); await c.addInitScript(t=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); localStorage.setItem('fyfpass:theme',t); }catch(e){} },theme);
   if(block) await c.route(/rpc\/wish_list_public/,r=>r.fulfill({status:404,contentType:'application/json',body:'{"code":"PGRST202"}'}));
   const q=await c.newPage(); q.on('pageerror',e=>errs.push(e.message)); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(1000); await q.click('[data-wish] summary'); await q.waitForTimeout(700); return {c,q}; };
 let {c,q}=await open('light');
 let r=await q.evaluate(()=>({own:!!document.querySelector('[data-wishown]'),list:[...document.querySelectorAll('[data-wv]')].map(x=>x.closest('.wish').querySelector('b').textContent+':'+x.textContent),planned:document.querySelectorAll('[data-wk]').length}));
 log('Liste:',JSON.stringify(r)); if(!r.own) bad('Feld sichtbar'); if(r.planned<4) bad('geplante Funktionen bleiben');
 if(r.list.length!==2||!/^Reifendruck/.test(r.list[0])||r.list.some(x=>/Abgelehnt|Nicht frei/.test(x))) bad('nur freigegebene Wünsche, nach Stimmen');
 await q.locator('[data-wishown]').scrollIntoViewIfNeeded(); await q.screenshot({path:'/tmp/t214-hell.png'});
 // abstimmen
 await q.click('[data-wv="1"]'); await q.waitForTimeout(400); r=await q.evaluate(()=>({t:document.querySelector('[data-wv="1"]').textContent,on:document.querySelector('[data-wv="1"]').classList.contains('on'),ls:localStorage.getItem('fyfpass:wishv')}));
 log('Stimme:',JSON.stringify(r)); if(r.t!=='✓ 5'||!r.on||!/"1"/.test(r.ls||'')) bad('Abstimmen zählt');
 await q.click('[data-wv="1"]'); await q.waitForTimeout(300); if((await q.textContent('[data-wv="1"]'))!=='✓ 5') bad('keine Doppelstimme');
 // persönliche Daten werden abgewiesen (ohne Senden)
 const ta='[data-wishown] textarea', sb='[data-wishown] button[type=submit]', msg='[data-wishown] [data-wmsg]';
 await q.fill(ta,'Ruft mich an 0911 1234567'); await q.click(sb); await q.waitForTimeout(200); if(!/keine Links/.test(await q.textContent(msg))) bad('Telefonnummer abgewiesen');
 await q.fill(ta,'siehe www.beispiel.de'); await q.click(sb); await q.waitForTimeout(200); if(!/keine Links/.test(await q.textContent(msg))) bad('Link abgewiesen');
 await q.fill(ta,'ab'); await q.click(sb); await q.waitForTimeout(200); if(!/mindestens 3/.test(await q.textContent(msg))) bad('zu kurz');
 await q.fill(ta,'Kette ölen Erinnerung nach Regenfahrt'); if(!/37\/200/.test(await q.textContent('[data-wishown] [data-wc]'))) bad('Zeichenzähler');
 await q.click(sb); await q.waitForTimeout(500); r=await q.evaluate(()=>({m:document.querySelector('[data-wishown] [data-wmsg]').textContent,v:document.querySelector('[data-wishown] textarea').value,dev:localStorage.getItem('fyfpass:devid')}));
 log('Senden:',JSON.stringify(r)); if(!/Danke/.test(r.m)||r.v!=='') bad('Wunsch gesendet'); if(!/^"[A-Za-z0-9]{24}"$/.test(r.dev||'')) bad('Gerätekennung');
 const adm=await (await fetch(BASE+'/__wish')).json(); if(!adm.some(w=>w.body==='Kette ölen Erinnerung nach Regenfahrt'&&w.status==='neu'&&!w.public)) bad('Server: neu und nicht öffentlich');
 for(const t of ['Zweiter Wunsch hier','Dritter Wunsch hier','Vierter Wunsch hier']){ await q.fill(ta,t); await q.click(sb); await q.waitForTimeout(400); }
 if(!/morgen wieder/.test(await q.textContent(msg))) bad('max. 3 am Tag');
 await c.close();
 ({c,q}=await open('dark')); await q.locator('[data-wishown]').scrollIntoViewIfNeeded(); await q.screenshot({path:'/tmp/t214-dunkel.png'});
 r=await q.evaluate(()=>{ const t=document.querySelector('[data-wishown] textarea'); return getComputedStyle(t).color; }); log('Dunkel Textfarbe:',r); if(!/rgb\((2[0-9]{2}|1[5-9][0-9])/.test(r)) bad('dunkel lesbar');
 await c.close();
 ({c,q}=await open('light',true)); if(await q.locator('[data-wishown]').count()) bad('ohne Stand 31 kein Feld'); if((await q.locator('[data-wk]').count())<4) bad('ohne Stand 31 Liste bleibt'); await c.close();
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
