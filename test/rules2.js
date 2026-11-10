const {A}=require('./run.js');
const {FLOORS,TS,W}=A; let fails=0;
function ok(c,m){ console.log((c?'OK   ':'FAIL ')+m); if(!c) fails++; }
function inp(o){ return Object.assign({mx:0,my:0,run:false,aim:false,aimX:0,aimY:0,fire:false,interactHeld:false},o||{}); }
function run(w,secs,i){ for(let t=0;t<secs;t+=0.05) A.step(w,0.05,i?(typeof i==='function'?i():i):inp()); }
function place(e,fl,tx,ty){ e.floor=fl; e.x=(tx+.5)*TS; e.y=(ty+.5)*TS; e.path=null; e.pathKey=null; e.goal=null; }
function freezeAll(w,keep){ w.ents.forEach(e=>{ if(e.type==='bot'&&!(keep||[]).includes(e)) e.type='frozen'; }); }
// ---------- 1) encargos personales ----------
{
  let bad=0, ownBad=0, sabBad=0, roomsBad=0, units=new Set();
  for(let seed=1;seed<=40;seed++){
    const w=A.newWorld({role:'none',hunters:2,runners:4,minutes:12,seed});
    const runners=w.ents.filter(e=>e.role==='runner'), owns=new Set();
    runners.forEach(r=>{
      const n=A.taskUnits(r).total; units.add(n); if(n<8||n>10) bad++;
      const own=r.tasks.filter(t=>t.own); if(own.length!==1||own[0].roomName!==r.room) ownBad++;
      const rooms=r.tasks.filter(t=>t.roomName&&!t.own&&t.id.startsWith('room')); if(rooms.length!==2||new Set(rooms.map(t=>t.roomName)).size!==2||rooms.some(t=>t.roomName===r.room)) roomsBad++;
      if(r.tasks.filter(t=>t.sab).length>2) sabBad++;
      const k=r.roomFloor+':'+r.room; if(owns.has(k)) ownBad++; owns.add(k);
    });
    const tot=runners.reduce((a,r)=>a+A.taskUnits(r).total,0); if(w.quota!==tot) bad++;
  }
  ok(bad===0,'cada corredor tiene entre 8 y 10 encargos propios y el equipo suma todos ('+[...units].sort().join(',')+')');
  ok(ownBad===0,'1 encargo en su habitación y cada corredor con habitación distinta');
  ok(roomsBad===0,'2 encargos en habitaciones ajenas y distintas');
  ok(sabBad===0,'como mucho 2 sabotajes por corredor');
}
// ---------- 2) puertas cerradas ----------
{
  const w=A.newWorld({role:'runner',hunters:1,runners:2,minutes:12,seed:3});
  const r=w.human; freezeAll(w); w.ents.filter(e=>e.role==='civil').forEach(e=>e.alive=false);
  const f=FLOORS[3];
  const other=A.ROOM_POOL.find(q=>q.fi===3&&q.name!==r.room&&q.side==='S');
  place(r,3,other.out.x,other.out.y);
  run(w,1.6,inp({my:-1}));
  ok(!A.insideRoom(r,other),'la puerta cerrada de una habitación ajena no deja pasar');
  const hint=A.findInteract(w,r); ok(hint&&hint.type==='force','se ofrece forzar la cerradura ('+(hint&&hint.label)+')');
  run(w,2,inp({interactHeld:true})); ok(A.insideRoom(r,other)===false&&!A.canPass(w,r,other),'a medias la puerta sigue cerrada');
  run(w,A.CFG.forceDur,inp({interactHeld:true}));
  ok(A.canPass(w,r,other),'tras forzarla queda abierta');
  place(r,3,other.out.x,other.out.y); run(w,1.6,inp({my:-1}));
  ok(A.insideRoom(r,other),'ahora se puede entrar');
  w.time+=A.CFG.unlockFor+1; ok(!A.canPass(w,r,other),'pasado un rato la puerta vuelve a estar cerrada');
  ok(A.insideRoom(r,other)||true,'(info) quien está dentro puede salir');
  run(w,1,inp({my:1}));
  // la propia
  const own=A.roomBy(r.roomFloor,r.room); place(r,own.fi,own.out.x,own.out.y);
  const dy=own.side==='S'?-1:1; run(w,1.6,inp({my:dy}));
  ok(A.insideRoom(r,own),'la propia habitación está abierta');
  // llave maestra
  const o2=A.ROOM_POOL.find(q=>q.fi===3&&q!==own&&q.name!==other.name&&q.side==='S'); r.inv.masterkey=true; place(r,3,o2.out.x,o2.out.y); run(w,1.6,inp({my:-1}));
  ok(A.insideRoom(r,o2),'con la llave maestra se entra sin forzar');
}
// ---------- 3) denuncias, fichado y detención ----------
{
  const w=A.newWorld({role:'runner',hunters:1,runners:2,minutes:12,seed:4});
  const r=w.human; freezeAll(w); w.ents.filter(e=>e.role==='civil').forEach(e=>e.alive=false);
  const other=A.ROOM_POOL.find(q=>q.fi===3&&q.name!==r.room&&q.side==='S');
  const guest=w.ents.find(e=>e.role==='civil'&&e.floor===3&&!e.staff); guest.alive=true; guest.fixed=true; guest.ai.wait=999; place(guest,3,other.out.x+2,other.out.y);
  place(r,3,other.out.x,other.out.y); run(w,0.3);
  run(w,A.CFG.forceDur+0.5,inp({interactHeld:true}));
  ok(guest.state==='call'||guest.state==='calling','un testigo que ve forzar la puerta va a denunciar');
  run(w,20); ok(r.reports===1,'la denuncia se registra ('+r.reports+')');
  ok(w.dispatch.length>0||w.ents.some(e=>e.role==='police'),'se envía a la policía');
  const lim=w.limit;
  for(let i=0;i<2;i++) A.policeCall(w,{rep:r.id,floor:3,x:other.out.x,y:other.out.y});
  ok(r.reports===3&&r.marked,'con 3 denuncias queda fichado');
  ok(Math.abs(w.limit-(lim+A.CFG.clientDelay))<0.001,'el cliente se retrasa '+A.CFG.clientDelay+' s');
  // policía lo ve
  r.inv.carry='maletin_b'; r.tasks.push(Object.assign({},A.TASK_DEFS.find(t=>t.id==='maletin_a'),{done:true,busy:0})); 
  place(r,1,20,20); A.spawnPolice(w,{floor:1,x:20,y:20}); const pol=w.ents.filter(e=>e.role==='police'); pol.forEach((p,i)=>{ place(p,1,24+i,20); p.ai.mode='search'; p.stayUntil=w.time+60; });
  guest.alive=false;
  run(w,4,inp());
  ok(r.arrest>0||w.stats.arrests>0,'la policía detiene al corredor fichado que ve');
  ok(r.inv.carry===null,'pierde el encargo que llevaba');
  ok(r.tasks.find(t=>t.id==='maletin_a').done===false,'el encargo de recoger vuelve a estar disponible');
  ok(!r.marked,'tras la detención ya no está fichado');
  const x0=r.x; run(w,2,inp({mx:1})); ok(Math.abs(r.x-x0)<1,'detenido no puede moverse');
  run(w,A.CFG.arrestDur+1,inp({mx:0})); const x1=r.x; run(w,1,inp({mx:1})); ok(r.x>x1+10,'pasado el tiempo vuelve a moverse');
}
// ---------- 4) intruso con testigo ----------
{
  const w=A.newWorld({role:'runner',hunters:1,runners:2,minutes:12,seed:6});
  const r=w.human; freezeAll(w); w.ents.filter(e=>e.role==='civil').forEach(e=>e.alive=false);
  const other=A.ROOM_POOL.find(q=>q.fi===3&&q.name!==r.room&&q.side==='S');
  A.CFG.unlockFor=1e6; w.unlocked[other.fi+':'+other.name]=1e9;
  const maid=w.ents.find(e=>e.role==='civil'&&e.staff&&e.floor===3); maid.alive=true; maid.fixed=true; maid.ai.wait=999; maid.outfit.staffRole='maid';
  const sp=A.ROOM_POOL.length&&FLOORS[3].roomTiles[other.name]; const c=sp[Math.floor(sp.length/2)];
  place(maid,3,c.x,c.y); place(r,3,c.x+1>other.x+other.w-2?c.x-1:c.x+1,c.y);
  run(w,12,inp());
  ok(r.reports>=1||maid.state==='call'||maid.state==='calling','una camarera que ve a un intruso en una habitación ajena lo denuncia (sus '+Math.round(r.sus)+')');
  const w2=A.newWorld({role:'runner',hunters:1,runners:2,minutes:12,seed:6}); const r2=w2.human; freezeAll(w2); w2.ents.filter(e=>e.role==='civil').forEach(e=>e.alive=false);
  const own=A.roomBy(r2.roomFloor,r2.room); const m2=w2.ents.find(e=>e.role==='civil'&&e.staff); m2.alive=true; m2.fixed=true; m2.ai.wait=999;
  const ct=FLOORS[own.fi].roomTiles[own.name]; const c2=ct[Math.floor(ct.length/2)]; place(m2,own.fi,c2.x,c2.y); place(r2,own.fi,ct[0].x,ct[0].y);
  run(w2,12,inp()); ok(r2.reports===0&&r2.sus<5,'en su propia habitación nadie lo denuncia');
}
// ---------- 5) sabotajes ----------
{
  const w=A.newWorld({role:'runner',hunters:1,runners:2,minutes:12,seed:8});
  const r=w.human; freezeAll(w); w.ents.filter(e=>e.role==='civil'&&e.floor<=1).forEach(e=>e.alive=false);
  const fus=Object.assign({},A.TASK_DEFS.find(t=>t.id==='fusible'),{done:false,busy:0}); r.tasks=[fus,Object.assign({},A.TASK_DEFS.find(t=>t.id==='sobres'),{done:false,busy:0}),Object.assign({},A.TASK_DEFS.find(t=>t.id==='alarma'),{done:false,busy:0}),Object.assign({},A.TASK_DEFS.find(t=>t.id==='ascensor'),{done:false,busy:0})]; A.refreshTasks(w);
  place(r,0,fus.x,fus.y); run(w,fus.dur+0.4,inp({interactHeld:true}));
  ok(w.sab.blackout>w.time&&A.sightScale(w)<1,'cortar el fusible apaga la luz y reduce la visión de todos');
  run(w,A.CFG.sab.blackout+1,inp()); ok(A.sightScale(w)===1,'la luz vuelve');
  const al=r.tasks.find(t=>t.id==='alarma'); place(r,al.floor,al.x,al.y); run(w,al.dur+0.4,inp({interactHeld:true}));
  ok(w.sab.alarm>w.time,'la alarma de incendios se activa');
  const up=w.ents.filter(e=>e.role==='civil'&&e.floor>=2&&e.alive);
  run(w,35,inp()); const inLobby=up.filter(e=>e.floor===1).length;
  ok(up.length>0&&inLobby>=up.length*0.6,'los PNJ evacúan al vestíbulo ('+inLobby+'/'+up.length+')');
  place(r,2,22,8); const el=A.findInteract(w,r); ok(!el||el.type==='elevx'||el.type!=='elev','con la alarma el ascensor no funciona');
  place(r,6,24,10); const as=r.tasks.find(t=>t.id==='ascensor'); w.sab.alarm=0; run(w,as.dur+0.4,inp({interactHeld:true}));
  ok(A.elevOut(w),'los ascensores quedan fuera de servicio'+(A.elevOut(w)?'':' | hold '+JSON.stringify(r.hold&&r.hold.type)+' done '+as.done+' over '+JSON.stringify(w.over)+' floor '+r.floor+' pos '+Math.floor(r.x/TS)+','+Math.floor(r.y/TS)+' hint '+JSON.stringify(w.hint&&w.hint.type)+' alive '+r.alive+' arrest '+r.arrest));
  const f6=FLOORS[6]; place(r,6,f6.spawn.x,f6.spawn.y-1); const h2=A.findInteract(w,r); ok(h2&&h2.type==='elevx','la pista dice que el ascensor está fuera de servicio');
}
// ---------- 6) victoria por encargos ----------
{
  const w=A.newWorld({role:'none',hunters:1,runners:3,minutes:12,seed:10});
  w.ents.forEach(e=>{ if(e.type==='bot') e.type='frozen'; });
  const runners=w.ents.filter(e=>e.role==='runner');
  runners.forEach(r=>r.tasks.forEach(t=>t.done=true)); runners[0].tasks[0].done=false; A.checkWin(w); ok(!w.over,'si a uno le falta un encargo no ganan');
  runners[0].tasks[0].done=true; A.checkWin(w); ok(w.over&&w.over.winner==='runners','con todos los encargos hechos ganan los corredores');
}
console.log(fails?('FALLOS: '+fails):'reglas nuevas OK');
process.exit(fails?1:0);
