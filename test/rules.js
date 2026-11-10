const {A}=require('./run.js');
const {FLOORS,TS,W}=A; let fails=0;
function ok(c,m){ console.log((c?'OK   ':'FAIL ')+m); if(!c) fails++; }
function inp(o){ return Object.assign({mx:0,my:0,run:false,aim:false,aimX:0,aimY:0,fire:false,interactHeld:false},o||{}); }
function run(w,secs,i){ for(let t=0;t<secs;t+=0.05) A.step(w,0.05,i?(typeof i==='function'?i():i):inp()); }
function place(e,fl,tx,ty){ e.floor=fl; e.x=(tx+.5)*TS; e.y=(ty+.5)*TS; e.path=null; e.pathKey=null; e.goal=null; }
function freeze(w,keep){ w.ents.forEach(e=>{ if(e.type==='bot'&&!keep.includes(e)){ e.type='frozen'; } }); }
// ---------- Escenario 1: disparo con testigo ----------
{
  const w=A.newWorld({role:'hunter',hunters:1,runners:2,minutes:12,seed:7});
  const h=w.human; const target=w.ents.find(e=>e.id===w.targets[0]);
  w.ents.forEach(e=>{ if(e.type==='bot') e.type='frozen'; });
  place(h,1,16,19); place(target,1,19,19);
  const guest=w.ents.find(e=>e.role==='civil'&&e.floor===1&&!e.fixed); place(guest,1,22,21); guest.ai.wait=99;
  w.ents.filter(e=>e.role==='civil'&&e.floor===1&&e!==guest).forEach(e=>{ e.alive=false; });
  run(w,0.2);
  A.step(w,0.05,inp({aim:true,aimX:target.x,aimY:target.y-2,fire:false}));
  A.step(w,0.05,inp({aim:true,aimX:target.x,aimY:target.y-2,fire:true}));
  ok(!target.alive,'el disparo mata al objetivo bajo la mira');
  ok(h.sus===100,'con testigo la sospecha sube al máximo');
  ok(guest.state==='call','el testigo va a llamar a la policía');
  run(w,25);
  ok(w.wanted[h.outfit.id],'el traje queda marcado como buscado tras la llamada');
  ok(w.ents.some(e=>e.role==='police'),'llega la policía');
  const tgt2=w.ents.find(e=>e.id===w.targets[1]);
  ok(w.posters.length===0||true,'(info) carteles: '+w.posters.length);
  // la policía no tiene por qué ver aún al cazador: forzar
  const pol=w.ents.find(e=>e.role==='police'); place(pol,1,24,19); pol.ai.mode='search'; pol.freeze=false;
  run(w,3, inp());
  ok(!h.alive||w.over,'la policía dispara al cazador con el traje buscado: '+(h.alive?'vivo':'muerto')+' / over='+JSON.stringify(w.over));
}
// ---------- Escenario 2: cambiar de traje cura al cazador ----------
{
  const w=A.newWorld({role:'hunter',hunters:1,runners:3,minutes:12,seed:11});
  const h=w.human; w.ents.forEach(e=>{ if(e.type==='bot') e.type='frozen'; });
  w.ents.filter(e=>e.role==='civil').forEach(e=>e.alive=false);
  w.wanted[h.outfit.id]=true; h.sus=100;
  place(h,3,30,14);
  const pol=A.newWorld; // noop
  // armario de la hab 1004? buscar un armario con stand y colocarse
  const wd=FLOORS[3].wards[0]; place(h,3,wd.stand.x,wd.stand.y);
  const before=h.outfit.id;
  const f=A.findInteract(w,h); ok(f&&f.type==='ward','junto al armario se ofrece registrarlo ('+(f&&f.type)+')');
  let i=inp({interactHeld:true}); run(w,CFGhold(),i);
  ok(h.outfit.id!==before,'tras 3 s en el armario lleva otro traje');
  ok(!A.isHot(w,h),'el nuevo traje ya no es buscado');
  ok(h.sus<=35,'la sospecha baja al cambiar ('+Math.round(h.sus)+')');
}
function CFGhold(){ return A.CFG.hold.ward+0.3; }
// ---------- Escenario 3: ropa del muerto = sangre -> sospecha -> lavado ----------
{
  const w=A.newWorld({role:'hunter',hunters:1,runners:3,minutes:12,seed:21});
  const h=w.human; w.ents.forEach(e=>{ if(e.type==='bot') e.type='frozen'; });
  w.ents.filter(e=>e.role==='civil').forEach(e=>e.alive=false);
  const victim=w.ents.find(e=>e.id===w.targets[0]);
  place(h,2,12,15); place(victim,2,14,15);
  A.step(w,0.05,inp({aim:true,aimX:victim.x,aimY:victim.y-2,fire:true}));
  ok(!victim.alive,'objetivo eliminado sin testigos');
  ok(h.sus<100,'sin testigos no hay sospecha máxima');
  place(h,2,14,15);
  const f=A.findInteract(w,h); ok(f&&f.type==='strip','junto al cadáver se ofrece coger su ropa');
  run(w,3.3,inp({interactHeld:true}));
  ok(h.outfit.blood===true,'el traje robado está manchado');
  ok(h.outfit.id===victim.outfit.id,'va vestido como la víctima');
  // un NPC lo ve
  const npc=w.ents.find(e=>e.role==='civil'); npc.alive=true; npc.floor=2; place(npc,2,16,15); npc.fixed=true; npc.ai.wait=99;
  run(w,12,inp());
  ok(h.sus>=80||npc.state==='call'||npc.state==='calling'||w.stats.calls>0,'la sangre delata ante un testigo (sus '+Math.round(h.sus)+', estado '+npc.state+')');
}
{
  const w=A.newWorld({role:'hunter',hunters:1,runners:3,minutes:12,seed:21});
  const h=w.human; w.ents.forEach(e=>{ if(e.type==='bot') e.type='frozen'; });
  w.ents.filter(e=>e.role==='civil').forEach(e=>e.alive=false);
  h.outfit.blood=true; h.inv.badge=true;
  const wa=FLOORS[0].washers[0]; place(h,0,wa.stand.x,wa.stand.y);
  const f=A.findInteract(w,h); ok(f&&f.type==='wash','junto a la lavadora con sangre se ofrece lavar');
  run(w,6.5,inp({interactHeld:true}));
  ok(h.outfit.blood===false,'tras 6 s el traje está limpio');
}
// ---------- Escenario 4: zona restringida ----------
{
  const w=A.newWorld({role:'hunter',hunters:1,runners:2,minutes:12,seed:5});
  const h=w.human; w.ents.forEach(e=>{ if(e.type==='bot') e.type='frozen'; });
  w.ents.filter(e=>e.role==='civil').forEach(e=>e.alive=false);
  const staff=w.ents.find(e=>e.role==='civil'&&e.staff&&e.floor===0); staff.alive=true; staff.fixed=true; staff.ai.wait=999;
  place(staff,0,31,10); place(h,0,29,10);
  const z=FLOORS[0].zone[10*W+29]; ok(z===2,'la lavandería es zona de personal');
  let said=false; for(let t=0;t<20;t+=0.05){ A.step(w,0.05,inp()); if(staff.bubble&&/personal/.test(staff.bubble)) said=true; }
  ok(said,'un trabajador te avisa antes de llamar a la policía');
  ok(staff.state==='call'||staff.state==='calling'||w.stats.calls>0,'si sigues dentro, llama a la policía (sus '+Math.round(h.sus)+')');
  const w2=A.newWorld({role:'hunter',hunters:1,runners:2,minutes:12,seed:5}); const h2=w2.human; w2.ents.forEach(e=>{ if(e.type==='bot') e.type='frozen'; });
  w2.ents.filter(e=>e.role==='civil').forEach(e=>e.alive=false);
  const st2=w2.ents.find(e=>e.role==='civil'&&e.staff&&e.floor===0); st2.alive=true; st2.fixed=true; st2.ai.wait=999; place(st2,0,31,10); place(h2,0,29,10); h2.inv.badge=true;
  run(w2,20); ok(w2.stats.calls===0&&h2.sus<5,'con la insignia no hay sospecha (sus '+Math.round(h2.sus)+')');
}
// ---------- Escenario 5: corredor haciendo tareas y fabricando arma ----------
{
  const w=A.newWorld({role:'runner',hunters:1,runners:3,minutes:12,seed:9});
  const r=w.human; w.ents.forEach(e=>{ if(e.type==='bot') e.type='frozen'; });
  const mkT=ids=>ids.map(id=>Object.assign({},A.TASK_DEFS.find(t=>t.id===id),{done:false,busy:0}));
  r.tasks=mkT(['registro','maletin_a','maletin_b','sobres']); A.refreshTasks(w);
  const t=r.tasks.find(x=>x.id==='registro'); place(r,t.floor,t.x,t.y);
  const f=A.findInteract(w,r); ok(f&&f.type==='task','el corredor ve la tarea');
  run(w,t.dur+0.4,inp({interactHeld:true}));
  ok(A.taskUnits(r).done===1,'tarea completada suma a tus encargos');
  const t2=r.tasks.find(x=>x.id==='maletin_b'); r.inv.masterkey=true; place(r,t2.floor,t2.x,t2.y);
  ok(!A.findInteract(w,r)||A.findInteract(w,r).type!=='task','no se puede entregar sin recoger antes');
  const a=r.tasks.find(x=>x.id==='maletin_a'); place(r,a.floor,a.x,a.y); run(w,a.dur+0.4,inp({interactHeld:true}));
  ok(r.inv.carry==='maletin_b','recoger el maletín');
  place(r,t2.floor,t2.x,t2.y); run(w,t2.dur+0.4,inp({interactHeld:true}));
  ok(A.taskUnits(r).done===2&&r.inv.carry===null,'entregar el maletín cuenta como tarea');
  w.pick.filter(p=>p.kind==='scrap').slice(0,4).forEach(p=>{ place(r,p.floor,p.x,p.y); A.step(w,0.05,inp()); });
  ok(r.inv.melee,'4 piezas fabrican el arma cuerpo a cuerpo');
  // golpear a un cazador
  const h=w.ents.find(e=>e.role==='hunter'); place(r,2,12,15); place(h,2,13,15); r.aimX=h.x; r.aimY=h.y;
  A.step(w,0.05,inp({aimX:h.x,aimY:h.y,fire:true}));
  ok(!h.alive,'el golpe mata al cazador');
}
console.log(fails?('FALLOS: '+fails):'todas las reglas OK');
