s=open('index.html',encoding='utf-8').read()
assert 'init();\n\n})();' in s
s=s.replace('init();\n\n})();','init();\nwindow.__T={UI:UI,FLOORS:FLOORS,step:step,CFG:CFG,startGame:startGame,REN:REN,SET:SET,drawActor:drawActor,newGuest:newGuest,newStaff:newStaff,newPolice:newPolice,newUnder:newUnder,openModal:openModal,drawPortrait:drawPortrait,setView:setView};\n})();')
open('index_test.html','w',encoding='utf-8').write('<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head><body>'+s+'</body></html>')
