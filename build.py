import os
d = os.path.dirname(os.path.abspath(__file__))
rd = lambda n: open(os.path.join(d, 'src', n), encoding='utf-8').read()
mods = ['core.js', 'settings.js', 'map.js', 'outfits.js', 'nav.js', 'sim.js', 'tex.js', 'render.js', 'view.js', 'title.js', 'ui.js']
js = '\n'.join(rd(m) for m in mods)
js = js.replace('</script', '<\\/script')
html = rd('head.html') + '\n<script>\n(function(){\n' + js + '\n})();\n</script>\n'
open(os.path.join(d, 'index.html'), 'w', encoding='utf-8').write(html)
open(os.path.join(d, 'bundle.js'), 'w', encoding='utf-8').write('(function(){\n' + js + '\n})();\n')
print('ok', len(html))
