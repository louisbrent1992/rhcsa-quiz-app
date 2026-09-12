# RHCSA Quiz

A Flutter quiz app for preparing for the Red Hat Certified System Administrator
exam (EX200), built from *RHCSA Red Hat Enterprise Linux 10: Training and Exam
Preparation Guide, Fourth Edition* by Asghar Ghori.

> **Edition note.** The question bank targets **RHEL 10 / EX200 Fourth Edition**,
> which is what the linked epub contains. It is *not* the RHEL 9 edition — notably,
> Chapter 12 (Flatpak) and objectives 14–15 are new in RHEL 10, and the package,
> networking and boot chapters differ in detail from the RHEL 9 book.

## What it does

- **478 questions across all 22 chapters**, covering **all 62 official exam objectives**.
- **Three filter axes** — quiz by chapter, by topic (159 chapter learning objectives),
  or by official exam objective. Any combination can be multi-selected.
- **Three question formats** — multiple choice, select-all-that-apply, and
  command entry, where you type the actual command and it is graded against a
  set of accepted patterns.
- **Practice and exam modes.** Practice reveals the answer and an explanation
  after each question; exam mode defers all feedback to the end and runs a
  countdown, like the real sitting.
- **Progress tracking** — lifetime accuracy, per-chapter mastery, session
  history, and a "weak areas" drill that re-asks only what you last got wrong.
  Scoring uses the RHCSA 70% pass mark.
- **Learn mode** — the second tab is for reading, not grading. Open any
  chapter, topic or objective to get a command reference grouped by program
  (every `usermod` form in one place), tap-to-flip flashcards, and the chapter
  notes if you have generated them. Each ends with "Quiz me on this" so the
  hand-off from reading to being tested is one tap. Quizzes start from the
  Practice tab only.
- **Progress is written as you answer**, not when a session ends, so a crash,
  a force-quit or walking out of a quiet quiz keeps everything answered up to
  that point. Two resets are available on the Progress tab: clear the
  weak-areas list on its own, or reset accuracy and history from scratch.

## Study notes (optional, local only)

Learn mode's Notes tab reads `assets/notes/chNN.json`. Those files are **not in
this repository** — they are the textbook's prose, and this repo is public — so
they are gitignored and generated locally from your own copy of the book:

```
python3 tool/extract_notes.py                # uses the repo's epub symlink
python3 tool/extract_notes.py --epub /path/to/book.epub
python3 tool/extract_notes.py --dry-run      # report what it would extract
```

Roughly 89,000 words across the 22 chapters. Prose, headings and bullet lists
carry over; terminal transcripts do not, because the book renders them as
images — the Commands tab covers that ground from the question bank instead.
The app works fine without any of this: the Notes tab just points you at the
command above.

**Do not commit what it produces.** Release builds get the notes from a
separate private repository, `rhcsa-quiz-notes`, which the iOS release workflow
checks out with a read-only deploy key (`NOTES_DEPLOY_KEY`) and copies into
`assets/notes/` before building. That keeps this repository public and free of
the book's prose while still shipping the Learn tab complete. After
regenerating, sync them:

```
cp assets/notes/*.json <path-to>/rhcsa-quiz-notes/notes/
```

## Platforms

Android, iOS, and Linux desktop. iOS project files are present but building or
running them requires macOS with Xcode — they cannot be built from Linux.

```
flutter run -d linux            # desktop preview
flutter run                     # connected Android device
flutter build apk --release     # Android
```

The Linux target exists to preview a phone app, so its window defaults to a
portrait, phone-shaped 420x880. Override it to check other form factors:

```
flutter build linux --debug
RHCSA_WINDOW_SIZE=320x568 ./build/linux/x64/debug/bundle/rhcsa_quiz
```

## Project layout

```
assets/
  syllabus.json           chapters, topics, and the 62 exam objectives, cross-mapped
  questions/ch01..22.json the question bank, one file per chapter
  notes/                  study notes, generated locally and gitignored
lib/
  models/                 Question, Syllabus, Notes, QuizConfig/QuizItem/QuizResult
  data/repository.dart    loads syllabus + bank + optional notes from assets
  data/quiz_builder.dart  filters the pool and draws a balanced session
  data/study_builder.dart turns the bank into a command reference + flashcards
  services/               progress persistence (shared_preferences)
  screens/                home, learn browse, study, quiz setup, quiz, results, stats
  widgets/                answer option, command field, explanation panel
tool/validate_bank.py     schema + cross-reference checker for the bank
tool/extract_notes.py     epub -> assets/notes (local only, see above)
test/                     grading, progress persistence, and app-flow tests
```

## App icon

A root shell prompt — `#` with a block cursor — on the app's red. It deliberately
avoids anything resembling Red Hat's trademarked logo.

Source images are generated, not hand-drawn, so the mark can be adjusted in one
place and re-rendered:

```
python3 tool/make_icon.py        # -> icon/icon.png, icon/foreground.png, icon/icon_rounded.png
dart run flutter_launcher_icons  # -> Android mipmaps + adaptive icon, iOS AppIcon set
```

`tool/make_icon.py` measures the drawn glyph rather than trusting font metrics,
and sizes the adaptive foreground to fill ~58% of Android's guaranteed-visible
area after the launcher's 16% inset — the arithmetic is in the script.

Linux gets its window/taskbar icon from `icon/icon.png`, which ships in the asset
bundle and is loaded by `linux/runner/my_application.cc`; Flutter's Linux runner
does not set one on its own.

## Question format

```jsonc
{
  "id": "ch15-q17",
  "chapter": 15,
  "topic": "...",            // must match a topic in assets/syllabus.json
  "objectives": [39],        // official exam objective numbers
  "type": "mcq",             // mcq | multi | command
  "difficulty": 3,           // 1 recall, 2 applied, 3 exam-hard
  "prompt": "...",
  "options": ["..."],        // mcq/multi only
  "answer": [0],             // indices into options
  "accept": ["lvextend ..."],// command only: regexes, anchored at both ends
  "canonical": "lvextend ...",
  "explanation": "..."
}
```

Command answers are normalised before grading: whitespace is collapsed, and a
leading `#`/`$` prompt or `sudo` is stripped. Multi-select is graded all-or-nothing.

## Adding or editing questions

Edit the relevant `assets/questions/chNN.json`, then run:

```
python3 tool/validate_bank.py    # checks schema, topics, objectives, regexes, duplicates
flutter test                     # checks grading logic and bank consistency
```

The validator also reports coverage gaps — chapters or objectives with no
questions, and chapters with thin coverage.

## Testing constraints on this machine

`flutter test` runs the Dart-only suites (`bank_test.dart`, `grading_test.dart`)
in about a second. Widget tests are the problem: the **first** `testWidgets` in a
file passes in milliseconds and **every subsequent one hangs** until the 10-minute
timeout, regardless of what it does. That is a flutter_tester issue here, not an
app fault, so `app_flow_test.dart` deliberately holds exactly one widget test.

Layout at phone sizes is verified against the running desktop build instead —
launch it at a given size, then dump the render tree over the Dart VM service and
grep for overflow markers. At 320x568 the render tree reports `Size(320.0, 568.0)`
and zero overflow.

The Android emulator does not run on this machine either (`KVM: entry failed,
hardware error 0x0`), so device testing means a physical phone.
