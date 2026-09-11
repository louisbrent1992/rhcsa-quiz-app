#!/usr/bin/env python3
"""Validate assets/questions/*.json against assets/syllabus.json.

Run from the project root:  python3 tool/validate_bank.py
Exits non-zero if any question is malformed.
"""
import json, glob, os, re, sys, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
syl = json.load(open(os.path.join(ROOT, 'assets/syllabus.json')))
chapters = {c['num']: c for c in syl['chapters']}
valid_objectives = {o['id'] for o in syl['objectives']}

def _safe(p):
    try:
        re.compile(p); return True
    except re.error:
        return False


errors, warnings = [], []
seen_ids, prompts = set(), collections.defaultdict(list)
per_chapter = collections.Counter()
per_type = collections.Counter()
per_difficulty = collections.Counter()
objective_cover = collections.Counter()

for path in sorted(glob.glob(os.path.join(ROOT, 'assets/questions/ch*.json'))):
    name = os.path.basename(path)
    expected_ch = int(re.match(r'ch(\d+)\.json', name).group(1))
    try:
        bank = json.load(open(path))
    except json.JSONDecodeError as e:
        errors.append(f'{name}: invalid JSON — {e}')
        continue

    for i, q in enumerate(bank):
        tag = f"{name}[{i}] {q.get('id', '?')}"

        for field in ('id', 'chapter', 'topic', 'type', 'difficulty', 'prompt', 'explanation'):
            if field not in q:
                errors.append(f'{tag}: missing field "{field}"')
        if 'id' not in q:
            continue

        if q['id'] in seen_ids:
            errors.append(f'{tag}: duplicate id')
        seen_ids.add(q['id'])

        if q.get('chapter') != expected_ch:
            errors.append(f"{tag}: chapter {q.get('chapter')} but lives in {name}")
        chapter = chapters.get(q.get('chapter'))
        if chapter is None:
            errors.append(f'{tag}: unknown chapter')
            continue

        if q.get('topic') not in chapter['topics']:
            errors.append(f"{tag}: topic not in chapter {expected_ch} — {q.get('topic')!r}")

        for o in q.get('objectives', []):
            if o not in valid_objectives:
                errors.append(f'{tag}: unknown objective {o}')
            elif o not in chapter['objectives']:
                warnings.append(f'{tag}: objective {o} is not mapped to chapter {expected_ch}')
            objective_cover[o] += 1

        if q.get('difficulty') not in (1, 2, 3):
            errors.append(f"{tag}: difficulty must be 1-3, got {q.get('difficulty')}")

        qtype = q.get('type')
        options, answer = q.get('options', []), q.get('answer', [])
        accept, canonical = q.get('accept', []), q.get('canonical')

        if qtype in ('mcq', 'multi'):
            if len(options) < 3:
                errors.append(f'{tag}: needs at least 3 options, got {len(options)}')
            if len(set(options)) != len(options):
                errors.append(f'{tag}: duplicate option text')
            if any(a < 0 or a >= len(options) for a in answer):
                errors.append(f'{tag}: answer index out of range')
            if len(set(answer)) != len(answer):
                errors.append(f'{tag}: duplicate answer index')
            if qtype == 'mcq' and len(answer) != 1:
                errors.append(f'{tag}: mcq must have exactly 1 answer, got {len(answer)}')
            if qtype == 'multi':
                if len(answer) < 2:
                    errors.append(f'{tag}: multi should have 2+ answers, got {len(answer)}')
                if len(answer) == len(options):
                    errors.append(f'{tag}: multi has every option correct')
            if accept or canonical:
                warnings.append(f'{tag}: accept/canonical ignored for {qtype}')
        elif qtype == 'command':
            if options or answer:
                errors.append(f'{tag}: command questions must have empty options/answer')
            if not accept:
                errors.append(f'{tag}: command question has no accept patterns')
            if not canonical:
                errors.append(f'{tag}: command question has no canonical answer')
            for p in accept:
                try:
                    re.compile(f'^(?:{p})$')
                except re.error as e:
                    errors.append(f'{tag}: bad accept regex {p!r} — {e}')
            # The canonical answer must itself be graded correct.
            if canonical:
                norm = re.sub(r'\s+', ' ', canonical.strip())
                norm = re.sub(r'^[#$]\s*', '', norm)
                norm = re.sub(r'^sudo\s+', '', norm)
                if not any(re.match(f'^(?:{p})$', norm) for p in accept if _safe(p)):
                    errors.append(f'{tag}: canonical {canonical!r} does not match its own accept patterns')
        else:
            errors.append(f'{tag}: unknown type {qtype!r}')

        if len(q.get('explanation', '')) < 40:
            warnings.append(f'{tag}: explanation looks too short')

        prompts[q.get('prompt', '').strip().lower()].append(q['id'])
        per_chapter[expected_ch] += 1
        per_type[qtype] += 1
        per_difficulty[q.get('difficulty')] += 1

for prompt, ids in prompts.items():
    if len(ids) > 1:
        errors.append(f'duplicate prompt across {ids}')



print(f'{sum(per_chapter.values())} questions across {len(per_chapter)} chapters')
missing = [n for n in sorted(chapters) if per_chapter[n] == 0]
thin = [f'ch{n}={per_chapter[n]}' for n in sorted(chapters) if 0 < per_chapter[n] < 15]
print('  by type:      ', dict(per_type))
print('  by difficulty:', dict(sorted(per_difficulty.items())))
if missing:
    print('  chapters with no questions:', missing)
if thin:
    print('  thin chapters:', ', '.join(thin))
uncovered = sorted(valid_objectives - set(objective_cover))
if uncovered:
    print('  objectives with no questions:', uncovered)

for w in warnings:
    print('WARN ', w)
for e in errors:
    print('ERROR', e)
print(f'\n{len(errors)} error(s), {len(warnings)} warning(s)')
sys.exit(1 if errors else 0)
