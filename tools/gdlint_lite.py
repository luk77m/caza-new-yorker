"""Comprobaciones básicas del GDScript sin Godot: sangría, paréntesis,
dos puntos en bloques y que existan las funciones/constantes estáticas usadas."""
import re, sys, glob, os
root = sys.argv[1] if len(sys.argv) > 1 else 'godot/scripts'
files = sorted(glob.glob(root + '/**/*.gd', recursive=True))
classes, members, problems = {}, {}, []
for f in files:
    src = open(f, encoding='utf-8').read()
    m = re.search(r'^class_name (\w+)', src, re.M)
    name = m.group(1) if m else os.path.basename(f)
    classes[name] = f
    mem = set(re.findall(r'^(?:static )?func (\w+)', src, re.M)) | set(re.findall(r'^(?:static )?(?:var|const) (\w+)', src, re.M))
    mem |= set(re.findall(r'^class (\w+)', src, re.M))
    for inner in re.findall(r'^class (\w+):', src, re.M):
        pass
    members[name] = mem
BLOCK = re.compile(r'^\s*(if|elif|else|for|while|func|static func|match|class)\b')
for f in files:
    lines = open(f, encoding='utf-8').read().split('\n')
    depth = 0; cont = False
    for i, L in enumerate(lines, 1):
        code = re.sub(r'"(?:[^"\\]|\\.)*"', '""', L)
        code = code.split('#')[0].rstrip()
        if not code.strip():
            continue
        lead = re.match(r'^[\t ]*', L).group(0)
        if ' ' in lead and depth == 0:
            problems.append(f'{f}:{i}: sangría con espacios')
        opened = code.count('(') + code.count('[') + code.count('{') - code.count(')') - code.count(']') - code.count('}')
        if depth == 0 and BLOCK.match(code) and not code.rstrip().endswith(':') and opened == 0:
            if not re.search(r':\s*\S', code):
                problems.append(f'{f}:{i}: falta ":" al final del bloque')
        depth += opened
        if depth < 0:
            problems.append(f'{f}:{i}: paréntesis de más'); depth = 0
    if depth != 0:
        problems.append(f'{f}: paréntesis sin cerrar ({depth})')
    src = '\n'.join(lines)
    for cls, mem in re.findall(r'\b(Sim|Hotel|Nav|Painter|Rng|Cfg|Outfit|Items|Goal|Hud|Minimap)\.(\w+)', src):
        if mem in ('new',): continue
        if mem not in members.get(cls, set()):
            problems.append(f'{f}: {cls}.{mem} no existe')
# miembros de Ent usados con prefijo ai_
ent = members['Ent']
for f in files:
    for m in set(re.findall(r'\.(ai_\w+)', open(f, encoding='utf-8').read())):
        if m not in ent: problems.append(f'{f}: Ent.{m} no existe')
KW = {'pass','when','super','trait','namespace','yield','breakpoint','assert','await','preload','self','signal','match','class','enum','const','static','var','func','break','continue','return','extends','is','as','in','not','and','or','void'}
for f in files:
    for i, L in enumerate(open(f, encoding='utf-8'), 1):
        for kw in re.findall(r'(?:\bvar|\.)\s*(\w+)', L.split('#')[0]):
            if kw in KW: problems.append(f'{f}:{i}: palabra reservada usada como nombre: {kw}')
print('\n'.join(problems) or 'sin problemas')
print(len(files), 'ficheros:', ', '.join(sorted(classes)))

# variables locales que se vuelven a declarar dentro de su propio ámbito (error en GDScript)
import re as _re
shadow = []
for f in files:
    vis = []      # (indent, name, kind)
    for i, L in enumerate(open(f, encoding='utf-8').read().split('\n'), 1):
        code = L.split('#')[0].rstrip()
        if not code.strip():
            continue
        ind = len(code) - len(code.lstrip('\t'))
        m = _re.match(r'(?:static )?func \w+\((.*?)\)', code)
        if ind == 0:
            vis = []
            if m:
                for p in _re.findall(r'(?:^|,)\s*(\w+)', m.group(1)):
                    vis.append((0, p, 'param'))
            continue
        vis = [(d, n, k) for (d, n, k) in vis if (k == 'param') or (k == 'var' and ind >= d) or (k == 'for' and ind > d)]
        for n in _re.findall(r'^\s*var (\w+)', code):
            if any(x[1] == n for x in vis):
                shadow.append(f'{f}:{i}: "{n}" ya está declarada en este ámbito')
            vis.append((ind, n, 'var'))
        for n in _re.findall(r'^\s*for (\w+) in', code):
            if any(x[1] == n for x in vis):
                shadow.append(f'{f}:{i}: "{n}" ya está declarada en este ámbito')
            vis.append((ind, n, 'for'))
print('\n'.join(shadow) or 'sin redeclaraciones')
