#!/usr/bin/env python3
"""List Claude Code sessions for the fzf picker and write a preview file per session."""
import glob
import json
import os
import re
import time

CACHE = os.environ.get('CLAUDE_PICKER_CACHE') or os.path.join(
    os.environ.get('XDG_CACHE_HOME', os.path.expanduser('~/.cache')), 'claude-picker')
INDEX = os.path.join(CACHE, 'index.json')
SESSIONS = os.path.expanduser('~/.claude/projects/*/*.jsonl')
LIVE = os.path.expanduser('~/.claude/sessions/*.json')
KEEP_PROMPTS = 40
BOLD, DIM, GREEN, RESET = '\033[1m', '\033[2m', '\033[32m', '\033[0m'
CWD_RE = re.compile(r'"cwd":"([^"]*)"')
NOISE_CMDS = re.compile(r'/(compact|clear|exit|quit|model|help|cost|status|resume|usage|login|config|permissions|rename)\b')


def text_of(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return '\n'.join(p.get('text', '') for p in content
                         if isinstance(p, dict) and p.get('type') == 'text')
    return ''


def real_prompt(d):
    # Skip injected context, shell echoes and interruptions; keep what the user typed.
    if d.get('isMeta') or d.get('isCompactSummary'):
        return None
    t = text_of((d.get('message') or {}).get('content')).strip()
    m = re.search(r'<command-name>(/\S+)</command-name>', t)
    if m:
        t = m.group(1)
    if not t or t.startswith('<') or t.startswith('[Request interrupted'):
        return None
    if NOISE_CMDS.match(t):
        return None
    return t


def scan(path):
    # cwd: the directory the session was last in, so a !cd carries over on resume.
    # root: where it started, kept for the preview.
    s = dict(root=None, cwd=None, branch=None, custom=None, ai=None, prompts=[],
             last=None, reply=None, turns=0, cost=None, started=None)
    store = os.path.basename(os.path.dirname(path))
    with open(path, encoding='utf-8', errors='ignore') as fh:
        for line in fh:
            m = CWD_RE.search(line)
            if m:
                s['cwd'] = m.group(1)
                if not s['root'] or (s['cwd'].replace('/', '-') == store and s['root'].replace('/', '-') != store):
                    s['root'] = s['cwd']
            if '"type":"' not in line:
                continue
            if '"type":"assistant"' in line and '"type":"text"' not in line:
                continue
            try:
                d = json.loads(line)
            except ValueError:
                continue
            t = d.get('type')
            if t == 'user':
                s['branch'] = d.get('gitBranch') or s['branch']
                s['started'] = s['started'] or d.get('timestamp')
                p = real_prompt(d)
                if p:
                    s['turns'] += 1
                    s['prompts'].append(' '.join(p.split())[:300])
                    s['prompts'] = s['prompts'][:1] + s['prompts'][1:][-KEEP_PROMPTS:]
            elif t == 'assistant':
                r = text_of((d.get('message') or {}).get('content')).strip()
                if r:
                    s['reply'] = r[:1200]
            elif t == 'custom-title':
                s['custom'] = d.get('customTitle')
            elif t == 'ai-title':
                s['ai'] = d.get('aiTitle')
            elif t == 'last-prompt':
                s['last'] = d.get('lastPrompt')
            elif t == 'cost-state':
                s['cost'] = d.get('totalCostUSD')
    return s


def load_index():
    try:
        with open(INDEX) as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {}


def collect():
    old, new = load_index(), {}
    for path in glob.glob(SESSIONS):
        try:
            st = os.stat(path)
        except OSError:
            continue
        key = [st.st_mtime, st.st_size]
        hit = old.get(path)
        if hit and hit.get('key') == key:
            new[path] = hit
            continue
        try:
            new[path] = dict(key=key, data=scan(path))
        except OSError:
            continue
    os.makedirs(CACHE, exist_ok=True)
    tmp = INDEX + '.tmp'
    with open(tmp, 'w') as fh:
        json.dump(new, fh)
    os.replace(tmp, INDEX)
    return new


def live_sessions():
    out = {}
    for f in glob.glob(LIVE):
        try:
            with open(f) as fh:
                d = json.load(fh)
        except (OSError, ValueError):
            continue
        if d.get('sessionId') and os.path.exists(f'/proc/{d.get("pid")}'):
            out[d['sessionId']] = d.get('status') or 'open'
    return out


def one_line(s, n):
    s = ' '.join((s or '').split())
    return s if len(s) <= n else s[:n - 1] + '…'


def clip(s, n):
    s = (s or '').strip()
    return s if len(s) <= n else s[:n].rstrip() + ' …'


def title(d):
    first = d['prompts'][0] if d['prompts'] else ''
    return d['custom'] or d['ai'] or one_line(first, 70) or '(untitled)'


def when_str(ts):
    return time.strftime('%a %b %d %H:%M', time.localtime(ts))


def preview(sid, d, mtime, live):
    cost = f"${d['cost']:.2f}" if d['cost'] is not None else '-'
    started = '-'
    if d['started']:
        try:
            started = time.strftime('%b %d', time.strptime(d['started'][:10], '%Y-%m-%d'))
        except ValueError:
            pass
    out = [f"{BOLD}{title(d)}{RESET}"]
    if live:
        out.append(f"{GREEN}● already open in another window ({live}){RESET}")
    out += [
        '',
        f"{DIM}directory{RESET}  {d['cwd']}",
        f"{DIM}started in{RESET} {d['root']}",
        f"{DIM}branch{RESET}     {d['branch'] or '-'}",
        f"{DIM}active{RESET}     {started} to {when_str(mtime)}",
        f"{DIM}prompts{RESET}    {d['turns']}    {DIM}cost{RESET} {cost}    {DIM}id{RESET} {sid[:8]}",
        '',
        f"{BOLD}WHAT YOU ASKED{RESET}",
    ]
    prompts = d['prompts']
    shown = prompts if len(prompts) <= 10 else prompts[:1] + ['…'] + prompts[-8:]
    for p in shown:
        out.append('  ' + p if p == '…' else f"  {DIM}·{RESET} {one_line(p, 220)}")
    if not prompts:
        out.append('  -')
    out += ['', f"{BOLD}LAST REPLY{RESET}", clip(d['reply'], 900) or '-']
    return '\n'.join(out) + '\n'


def haystack(d):
    parts = [title(d), d['cwd'] or '', d['branch'] or ''] + d['prompts']
    return one_line(' '.join(parts).lower().replace('\t', ' '), 3000)


def main():
    live = live_sessions()
    rows = []
    for path, ent in collect().items():
        d = ent['data']
        if not d['cwd'] or (d['turns'] == 0 and not d['custom'] and not d['ai']):
            continue
        rows.append((ent['key'][0], os.path.basename(path)[:-6], d))
    rows.sort(key=lambda r: r[0], reverse=True)

    home = os.path.expanduser('~')
    with open(os.path.join(CACHE, '__NEW__.txt'), 'w') as fh:
        fh.write(f"{BOLD}New session{RESET}\n\nStarts claude in {home}.\n"
                 f"Ctrl-N on any row starts a new session in that row's project instead.\n")
    print(f"__NEW__\t{home}\t+ start a new session\tnew")

    for mtime, sid, d in rows:
        with open(os.path.join(CACHE, sid + '.txt'), 'w') as fh:
            fh.write(preview(sid, d, mtime, live.get(sid)))
        proj = os.path.basename(d['cwd'].rstrip('/')) or d['cwd']
        mark = f'{GREEN}●{RESET}' if sid in live else ' '
        when = time.strftime('%m-%d %H:%M', time.localtime(mtime))
        print(f"{sid}\t{d['cwd']}\t{mark} {DIM}{when}{RESET}  {proj:<18.18}  {one_line(title(d), 80)}\t{haystack(d)}")


if __name__ == '__main__':
    main()
