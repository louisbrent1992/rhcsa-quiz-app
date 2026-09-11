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
lib/
  models/                 Question, Syllabus, QuizConfig/QuizItem/QuizResult
  data/repository.dart    loads syllabus + bank from assets
  data/quiz_builder.dart  filters the pool and draws a balanced session
  services/               progress persistence (shared_preferences)
  screens/                home, syllabus browse, quiz setup, quiz, results, stats
  widgets/                answer option, command field, explanation panel
tool/validate_bank.py     schema + cross-reference checker for the bank
test/                     grading logic and app-flow tests
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
