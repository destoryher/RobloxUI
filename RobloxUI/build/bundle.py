import hashlib
import pathlib
import re
import sys
ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / 'src'
OUT = ROOT / 'dist' / 'ui.lua'

def main():
    version = (ROOT / 'VERSION').read_text().strip()
    modules = {}
    for path in sorted(SRC.rglob('*.lua')):
        name = path.relative_to(SRC).with_suffix('').as_posix()
        modules[name] = path.read_text()
    digest = hashlib.sha256()
    for name in sorted(modules):
        digest.update(name.encode())
        digest.update(modules[name].encode())
    build = digest.hexdigest()[:12]
    errors = []
    for name, source in modules.items():
        for target in re.findall('require\\("([^"]+)"\\)', source):
            if target not in modules:
                errors.append(f"{name}: require('{target}') has no matching module")
    if 'init' not in modules:
        errors.append('src/init.lua is missing')
    if errors:
        print('\n'.join(errors))
        sys.exit(1)
    parts = ['local __defs, __loaded = {}, {}', 'local function require(name)', '\tlocal cached = __loaded[name]', '\tif cached == nil then', '\t\tlocal define = __defs[name]', '\t\tif not define then', '\t\t\terror("[UI] missing module " .. tostring(name), 2)', '\t\tend', '\t\tcached = define()', '\t\t__loaded[name] = cached', '\tend', '\treturn cached', 'end', '']
    for name in sorted(modules, key=lambda n: (n == 'init', n)):
        source = modules[name].replace('@VERSION@', version).replace('@BUILD@', build)
        parts.append(f'__defs["{name}"] = function()')
        parts.append(source.rstrip())
        parts.append('end')
        parts.append('')
    parts.append('return require("init")')
    parts.append('')
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text('\n'.join(parts))
    print(f'wrote {OUT.relative_to(ROOT)}: {len(modules)} modules, version {version}, build {build}, {OUT.stat().st_size} bytes')
main()
