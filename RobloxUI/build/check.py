import pathlib
import sys
OPEN = {'function', 'if', 'for', 'while', 'repeat'}
PAIRS = {')': '(', ']': '[', '}': '{'}

def tokens(src):
    i, n, line = (0, len(src), 1)
    while i < n:
        c = src[i]
        if c == '\n':
            line += 1
            i += 1
        elif c.isspace():
            i += 1
        elif src.startswith('--', i):
            j = i + 2
            if src.startswith('[', j):
                k = j + 1
                while k < n and src[k] == '=':
                    k += 1
                if k < n and src[k] == '[':
                    close = ']' + '=' * (k - j - 1) + ']'
                    end = src.find(close, k)
                    end = n if end < 0 else end + len(close)
                    line += src.count('\n', i, end)
                    i = end
                    continue
            end = src.find('\n', i)
            i = n if end < 0 else end
        elif c in '"\'':
            j = i + 1
            while j < n and src[j] != c:
                if src[j] == '\\':
                    j += 1
                if j < n and src[j] == '\n':
                    yield ('error', 'unterminated string', line)
                    break
                j += 1
            i = j + 1
        elif c == '[' and (src.startswith('[[', i) or src.startswith('[=', i)):
            k = i + 1
            while k < n and src[k] == '=':
                k += 1
            if k < n and src[k] == '[':
                close = ']' + '=' * (k - i - 1) + ']'
                end = src.find(close, k)
                end = n if end < 0 else end + len(close)
                line += src.count('\n', i, end)
                i = end
            else:
                yield ('sym', '[', line)
                i += 1
        elif c.isalpha() or c == '_':
            j = i
            while j < n and (src[j].isalnum() or src[j] == '_'):
                j += 1
            yield ('word', src[i:j], line)
            i = j
        elif c.isdigit():
            j = i
            while j < n and (src[j].isalnum() or src[j] in '._'):
                j += 1
            i = j
        else:
            two = src[i:i + 2]
            if two in ('!=', '&&', '||'):
                yield ('error', f'non-Lua operator {two}', line)
                i += 2
            else:
                yield ('sym', c, line)
                i += 1

def check(path):
    src = pathlib.Path(path).read_text()
    problems, stack, brackets = ([], [], [])
    for kind, value, line in tokens(src):
        if kind == 'error':
            problems.append(f'{path}:{line}: {value}')
        elif kind == 'word':
            if value in OPEN:
                stack.append([value, line, value in ('for', 'while')])
            elif value == 'do':
                if stack and stack[-1][2]:
                    stack[-1][2] = False
                else:
                    stack.append(['do', line, False])
            elif value in ('elseif', 'else'):
                if not stack or stack[-1][0] != 'if':
                    problems.append(f"{path}:{line}: '{value}' outside an if block")
            elif value == 'end':
                if not stack or stack[-1][0] == 'repeat':
                    problems.append(f"{path}:{line}: unexpected 'end'")
                else:
                    stack.pop()
            elif value == 'until':
                if not stack or stack[-1][0] != 'repeat':
                    problems.append(f"{path}:{line}: unexpected 'until'")
                else:
                    stack.pop()
        elif value in '([{':
            brackets.append((value, line))
        elif value in PAIRS:
            if not brackets or brackets[-1][0] != PAIRS[value]:
                problems.append(f"{path}:{line}: unmatched '{value}'")
            else:
                brackets.pop()
    for kind, line, _ in stack:
        problems.append(f"{path}:{line}: block '{kind}' never closed")
    for value, line in brackets:
        problems.append(f"{path}:{line}: '{value}' never closed")
    return problems
if __name__ == '__main__':
    bad = []
    for file in sys.argv[1:]:
        bad += check(file)
    print('\n'.join(bad) if bad else f'ok: {len(sys.argv) - 1} file(s), no structural problems found')
    sys.exit(1 if bad else 0)
