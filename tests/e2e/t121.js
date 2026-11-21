const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765'; const fs=require('fs');
(async()=>{ const b=await chromium.launch(); const c=await b.newContext({...devices['iPhone 13'],acceptDownloads:true}); const p=await c.newPage(); const errs=[]; p.on('pageerror',e=>errs.push(e.message)); p.on('dialog',d=>d.accept()); const log=(...a)=>console.log(...a);
 await p.goto(BASE+'/index.html'); await p.waitForTimeout(1500);
 const E=(src,arg)=>p.evaluate(([src,arg])=>{ const F=window.__fitframe.T118,S=F.S(),ui=F.ui(); return eval(src); },[src,arg]);
 await p.evaluate(()=>{ const S=window.__fitframe.S(); S.shop={...(S.shop||{}),name:'FYF Testladen',owner:'Dominik Böhm',addr:'Hauptstr. 1, 91080 Uttenreuth',iban:'DE02120300000000202051',bic:'BYLADEM1001',bank:'Testbank',phone:'09131 123456',email:'laden@example.de',taxNo:'216/123/45678',vatId:'DE123456789'}; window.__fitframe.save(); });
 const mk=async(name,amt)=>{ await p.evaluate(()=>window.__fitframe.ACT.invNew({dataset:{}})); await p.waitForTimeout(300); await p.fill('#iv_name',name); await p.fill('#iv_street','Weg 2'); await p.fill('#iv_zip','91054'); await p.fill('#iv_city','Erlangen'); await p.fill('#iv_email','x@example.de'); await p.fill('[name=n_0]','Inspektion'); await p.fill('[name=q_0]','1'); await p.fill('[name=p_0]',String(amt)); await p.click('form[data-form="invCreate"] button[type=submit]'); await p.waitForTimeout(400); return p.evaluate(()=>{ const i=window.__fitframe.invoices()[0]; return {id:i.id,no:i.no}; }); };
 const i1=await mk('Erika Muster',119), i2=await mk('Hans Huber',59.5), i3=await mk('Klaus Klein',200);
 await E("(F.invoices().forEach(i=>{ if([arg.a,arg.b,arg.c].includes(i.id)) i.due='2026-10-01'; }),true)",{a:i1.id,b:i2.id,c:i3.id});
 await E("(ui.route='rechnungen',F.render())"); await p.waitForTimeout(300);
 log('1 Überfällig-Liste:', await p.evaluate(()=>{ const s=[...document.querySelectorAll('section.panel')].find(x=>/Überfällige Rechnungen/.test(x.innerText)); return s?s.innerText.replace(/\s+/g,' ').slice(0,200):'FEHLT'; }));
 await E("F.ACT.invOpen({dataset:{id:arg}})",i1.id); await p.waitForTimeout(300); log('2 Mahnbox:', await p.evaluate(()=>{ const x=document.querySelector('[data-dunbox]'); return x?x.innerText.replace(/\s+/g,' ').slice(0,140):'FEHLT'; }));
 await p.click('[data-dunbox] [data-act="dunNext"]'); await p.waitForTimeout(800);
 log('3 Brief:', await p.evaluate(()=>{ const f=[...document.querySelectorAll('iframe')].pop(); const d=f&&(f.contentDocument); return d?d.body.innerText.replace(/\s+/g,' ').slice(0,330):'kein iframe'; }));
  await p.evaluate(()=>document.querySelectorAll('.docv').forEach(x=>x.remove()));
 log('3b Stufe:', await E("F.invoices().find(i=>i.id===arg).dun.map(d=>d.l+' '+d.due).join(',')",i1.id));
 // Zahlungsabgleich
 const csv='Buchungstag;Valuta;Auftraggeber/Empfänger;Verwendungszweck;Betrag\n'+`20.11.2026;20.11.2026;Erika Muster;Rechnung ${i1.no} danke;119,00\n`+`20.11.2026;20.11.2026;Hans Huber;Werkstatt;59,50\n`+`19.11.2026;19.11.2026;Klaus Klein;RE ${i3.no};100,00\n`+`18.11.2026;18.11.2026;Fremd GmbH;Miete;-500,00\n`;
 fs.writeFileSync(require('os').tmpdir()+'/konto.csv',csv); await E('F.closeDrawer()'); await E("(ui.route='rechnungen',F.render())"); await p.waitForTimeout(300);
 await p.setInputFiles('#bankF',require('os').tmpdir()+'/konto.csv'); await p.waitForTimeout(600);
 log('4 Abgleich:', await p.evaluate(()=>{ const s=[...document.querySelectorAll('section.panel')].find(x=>/Zahlungen abgleichen/.test(x.innerText)); return s?s.innerText.replace(/\s+/g,' ').slice(0,420):'FEHLT'; }));
 log('4b vorausgewählt:', await p.evaluate(()=>[...document.querySelectorAll('[data-change="bankSel"]')].map(x=>x.checked).join(',')));
 
 await p.click('[data-act="bankBook"]'); await p.waitForTimeout(500);
 log('5 Status:', await E("[arg.a,arg.b,arg.c].map(id=>{ const i=F.invoices().find(x=>x.id===id); return i.no+':'+i.status+' offen '+F.invOpenAmt(i); }).join(' | ')",{a:i1.id,b:i2.id,c:i3.id}));
 await p.setInputFiles('#bankF',require('os').tmpdir()+'/konto.csv'); await p.waitForTimeout(500); log('5b erneut importiert -> schon gebucht:', await p.evaluate(()=>(document.body.innerText.match(/schon gebucht/g)||[]).length)); await E("(ui.bank=null,F.render())");
 // Arbeitszeit + Leihrad
 const wo=await E("F.S().workshop.find(w=>!['Übergeben','Storniert'].includes(w.status)).id");
 await E("(ui.route='werkstatt',F.render())"); await p.fill('#lrn','Cube Trekking 52 blau'); await p.click('form[data-form="loanerAdd"] button[type=submit]'); await p.waitForTimeout(300);
 await E("F.woDrawer(arg)",wo); await p.waitForTimeout(300); await p.click('[data-wotime] [data-act="woTime"]'); await p.waitForTimeout(300);
 log('6 Zeit läuft:', await p.evaluate(()=>document.querySelector('[data-wotime]').innerText.replace(/\s+/g,' ').slice(0,120)));
 await E("(()=>{ const w=F.S().workshop.find(x=>x.id===arg); w.tm[0].s=new Date(Date.now()-47*6e4).toISOString(); })()",wo); await p.click('[data-wotime] [data-act="woTime"]'); await p.waitForTimeout(300);
 log('6b gestoppt:', await p.evaluate(()=>document.querySelector('[data-wotime]').innerText.replace(/\s+/g,' ').slice(0,120)));
 await p.click('[data-loan] [data-act="loanOut"]'); await p.waitForTimeout(300); log('7 Leihrad:', await p.evaluate(()=>document.querySelector('[data-loan]').innerText.replace(/\s+/g,' ')));
 
 await E("(()=>{ const w=F.S().workshop.find(x=>x.id===arg); w.status='Abholbereit'; })()",wo); log('7b Copilot:', await E("F.ACT&&JSON.stringify((window.__fitframe.copilotItems?window.__fitframe.copilotItems():[]).filter(x=>/Leihrad/.test(x.k)).map(x=>x.t))"));
 await p.click('[data-loan] [data-act="loanBack"]'); await p.waitForTimeout(300); log('7c zurück:', await p.evaluate(()=>document.querySelector('[data-loan]').innerText.replace(/\s+/g,' ')));
 await E("F.closeDrawer()"); await E("(ui.route='werkstatt',F.render())"); log('8 Werkstatt Panels:', await p.evaluate(()=>[...document.querySelectorAll('section.panel h3')].map(h=>h.textContent).filter(t=>/Leihr|Arbeitszeit/.test(t)).join(' | ')));
 for(const r of ['dashboard','rechnungen','werkstatt','termine']){ await E("(ui.route=arg,F.render())",r); await p.waitForTimeout(150); }
 log('Fehler:',errs.length?errs:'keine'); await b.close(); })();
