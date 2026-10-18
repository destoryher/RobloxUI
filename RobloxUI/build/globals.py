import re, sys, pathlib
KNOWN = set('Enum Instance UDim UDim2 Vector2 Vector3 Color3 ColorSequence ColorSequenceKeypoint NumberSequence\nNumberSequenceKeypoint TweenInfo Random CFrame Rect Region3 Ray DateTime Font BrickColor NumberRange PhysicalProperties\nAxes Faces Vector2int16 Vector3int16 OverlapParams RaycastParams'.split())

def strip(src):
    src = re.sub('--\\[(=*)\\[.*?\\]\\1\\]', '', src, flags=re.S)
    src = re.sub('--[^\\n]*', '', src)
    src = re.sub('"(?:\\\\.|[^"\\\\\\n])*"', '""', src)
    src = re.sub("'(?:\\\\.|[^'\\\\\\n])*'", "''", src)
    return src
bad = 0
for file in sys.argv[1:]:
    src = strip(pathlib.Path(file).read_text())
    declared = set(re.findall('\\blocal\\s+([A-Za-z_]\\w*)', src))
    for group in re.findall('\\blocal\\s+((?:[A-Za-z_]\\w*\\s*,\\s*)+[A-Za-z_]\\w*)', src):
        declared |= {n.strip() for n in group.split(',')}
    declared |= set(re.findall('\\bfunction\\s+([A-Za-z_]\\w*)\\s*\\(', src))
    declared |= set(re.findall('\\bfor\\s+([A-Za-z_]\\w*(?:\\s*,\\s*[A-Za-z_]\\w*)*)\\s+in', src) and [n.strip() for g in re.findall('\\bfor\\s+([A-Za-z_]\\w*(?:\\s*,\\s*[A-Za-z_]\\w*)*)\\s+in', src) for n in g.split(',')])
    for m in re.finditer('(?<![\\w.:])([A-Z][A-Za-z0-9_]*)\\s*[.:(]', src):
        name = m.group(1)
        if name in KNOWN or name in declared:
            continue
        line = src.count('\n', 0, m.start()) + 1
        print(f"{file}:{line}: '{name}' is not declared")
        bad += 1
print('ok: no undeclared capitalized identifiers' if not bad else f'{bad} problem(s)')
sys.exit(1 if bad else 0)
