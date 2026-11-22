// v.140: Kalender mit Zeitraster (Desktop) – Termin als Block, freie Fläche antippen öffnet Formular mit Tag/Uhrzeit; Schnellauswahl setzt Werte; Speichern legt Termin an. Handy: Tageskarten.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const c=await b.newContext({viewport:{width:1440,height:900},locale:'de-DE'}); const p=await c.newPage(); p.on('pageerror',e=>errs.push(e.message)); await p.goto(BASE+'/index.html'); await p.waitForTimeout(1500);
 const mon=await p.evaluate(()=>{ const F=window.__fitframe.T118, S=F.S(); const d=new Date(); const wd=d.getDay()||7; d.setDate(d.getDate()-wd+1); const m=F.iso(d); S.appts=(S.appts||[]).filter(a=>a.id!=='z1'); S.appts.push({id:'z1',kind:'Fitting',date:m,start:'10:00',dur:90,name:'Zeitraster Test'}); F.ui().route='termine'; F.ui().calMode='woche'; F.render(); return m; });
 await p.waitForTimeout(400);
 const ev=await p.evaluate(()=>{ const e=[...document.querySelectorAll('.tg-ev')].find(x=>/Zeitraster Test/.test(x.textContent)); return e?{h:e.getBoundingClientRect().height,vis:getComputedStyle(document.querySelector('.tg-wrap')).display}:null; }); log('1 Termin als Block:',JSON.stringify(ev)); if(!ev||ev.h<60) bad('Block fehlt/zu klein');
 const cards=await p.evaluate(()=>getComputedStyle(document.querySelector('.tg-cards')).display); if(cards!=='none') bad('Karten auf Desktop sichtbar');
 await p.click(`.tg-slot[data-d="${mon}"][data-s="14:00"]`); await p.waitForTimeout(400);
 const f=await p.evaluate(()=>({d:document.getElementById('ap_d').value,s:document.getElementById('ap_s').value,chips:document.querySelectorAll('#drawerBody .qp-b').length})); log('2 Formular aus freier Fläche:',JSON.stringify(f)); if(f.d!==mon||f.s!=='14:00'||f.chips<10) bad('Vorbelegung/Schnellauswahl');
 await p.click('#drawerBody .qp-b[data-qp="kind"][data-v="Beratung"]'); await p.click('#drawerBody .qp-b[data-qp="dur"][data-v="30"]'); await p.fill('#ap_n','Schnell Kunde');
 const v=await p.evaluate(()=>({k:document.getElementById('ap_k').value,u:document.getElementById('ap_u').value})); log('3 Schnellauswahl:',JSON.stringify(v)); if(v.k!=='Beratung'||v.u!=='30') bad('Schnellauswahl setzt Werte nicht');
 await p.click('form[data-form="apptSave"] button[type=submit]'); await p.waitForTimeout(500);
 const a=await p.evaluate(m=>{ const x=window.__fitframe.T118.appts().find(a=>a.name==='Schnell Kunde'); return x&&x.date===m&&x.start==='14:00'&&x.kind==='Beratung'&&Number(x.dur)===30; },mon); log('4 gespeichert:',a); if(!a) bad('Speichern');
 const ov=await p.evaluate(()=>document.documentElement.scrollWidth>innerWidth+1); if(ov) bad('Querscroll Desktop');
 const q=await (await b.newContext({...devices['iPhone 13'],locale:'de-DE'})).newPage(); q.on('pageerror',e=>errs.push('handy: '+e.message)); await q.goto(BASE+'/index.html'); await q.waitForTimeout(1200); await q.evaluate(()=>{ const F=window.__fitframe.T118; F.ui().route='termine'; F.ui().calMode='woche'; F.render(); }); await q.waitForTimeout(300);
 const hm=await q.evaluate(()=>({grid:getComputedStyle(document.querySelector('.tg-wrap')).display,cards:getComputedStyle(document.querySelector('.tg-cards')).display,ov:document.documentElement.scrollWidth>innerWidth+1})); log('5 Handy:',JSON.stringify(hm)); if(hm.grid!=='none'||hm.cards==='none'||hm.ov) bad('Handy-Ansicht');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
