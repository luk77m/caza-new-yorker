const fs=require('fs');
const src=['core','map','outfits','nav','sim'].map(n=>fs.readFileSync(__dirname+'/../src/'+n+'.js','utf8')).join('\n');
globalThis.__EXPOSE=1;
(0,eval)('(function(){'+src+'\n})()');
const A=globalThis.__API;
const {FLOORS,T,W,H,TS,SOLIDT}=A;
let bad=0;
// 1) reachability of every point on every floor from the elevator spawn
function reach(f){ const sp=f.spawn; const seen=new Uint8Array(W*H); const q=[[sp.x,sp.y]]; seen[sp.y*W+sp.x]=1;
 while(q.length){const [x,y]=q.pop(); for(const [dx,dy] of [[1,0],[-1,0],[0,1],[0,-1]]){const nx=x+dx,ny=y+dy; if(nx<0||ny<0||nx>=W||ny>=H)continue; const k=ny*W+nx; if(f.pass[k]&&!seen[k]){seen[k]=1;q.push([nx,ny]);}}} return seen;}
const R=FLOORS.map(reach);
const chk=(name,fl,x,y)=>{ const k=y*W+x; if(!FLOORS[fl].pass[k]){console.log('NOT PASSABLE',name,fl,x,y);bad++;return;} if(!R[fl][k]){console.log('UNREACHABLE',name,fl,x,y);bad++;}};
A.TASK_DEFS.forEach(t=>chk('task '+t.id,t.floor,t.x,t.y));
A.KEY_SPOTS.masterkey.forEach(s=>chk('masterkey',s.f,s.x,s.y)); A.KEY_SPOTS.badge.forEach(s=>chk('badge',s.f,s.x,s.y));
A.SCRAP_SPOTS.forEach(s=>chk('scrap',s.f,s.x,s.y));
FLOORS.forEach((f,i)=>{
  f.wards.forEach(w=>{ if(!w.stand||!R[i][w.stand.y*W+w.stand.x]){console.log('ward no stand',i,w.x,w.y);bad++;} });
  f.sinks.forEach(w=>{ if(!w.stand||!R[i][w.stand.y*W+w.stand.x]){console.log('sink no stand',i,w.x,w.y);bad++;} });
  f.washers.forEach(w=>{ if(!w.stand||!R[i][w.stand.y*W+w.stand.x]){console.log('washer no stand',i,w.x,w.y);bad++;} });
  f.rooms.forEach(r=>{ if(r.door) chk('door '+r.name,i,r.door.x,r.door.y); });
  if(f.phone) chk('phone',i,f.phone.x,f.phone.y);
  // every room tile in rooms list reachable
  Object.keys(f.roomTiles).forEach(n=>f.roomTiles[n].forEach(t=>{ if(!R[i][t.y*W+t.x]){ console.log('isolated tile',i,n,t.x,t.y);bad++; } }));
  f.tilesPub.forEach(t=>{ if(!R[i][t.y*W+t.x]){ console.log('isolated pub tile',i,t.x,t.y);bad++; } });
  console.log('floor',i,f.label,'wards',f.wards.length,'sinks',f.sinks.length,'washers',f.washers.length,'lamps',f.lamps.length);
});
// stairs & start
const lob=FLOORS[1]; chk('start',1,lob.start.x,lob.start.y);
console.log('static problems:',bad);
module.exports={A};
