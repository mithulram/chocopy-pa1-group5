# ChocoPy Compiler — PA1: Lexing & Parsing (Group 5)

Compiler Construction Lab, Winter Semester 2026/27 · Chair of Software Engineering I · University of Passau

A JFlex lexer and a CUP LALR(1) parser that turn ChocoPy programs into a JSON AST, matching the staff reference
implementation down to every line and column. This repository also holds everything we need for the PA1
presentation: slides, the challenge log, Q&A preparation, the team prep pack, and a live demo.

**Team:** Mithulram Gunasekaran · Mohamed Nuhuman Mohamed Nafeel · Rajapaksha Mudiyanselage Dinodi Divyanjana Rajapaksha

| Deadline | Date |
|---|---|
| PA1 submission (Stud.IP, `SubmissionsDir`) | **Wed 04.11.2026, 23:59** |
| PA1 presentation (15 min + 10 min Q&A) | **Thu 12.11.2026** (backup date 19.11.2026) |

---

## Status

| Check | Result |
|---|---|
| Provided sample tests | **33 / 33** pass |
| Our own edge-case tests (`src/test/data/pa1/edge_cases/`) | **44 / 44** pass |
| Differential test against the reference (grader's rule, 3,511 files) | **all identical** |
| LALR conflicts in the grammar | **0** |
| `good.py` / `bad.py` | 0 errors / exactly one error for each of its 9 mistakes |
| Error recovery, one real mistake per program (346 programs) | **1.37** errors per mistake (reference 2.01), **0** aborted parses (reference 3) |
| Submission zip | built and tested from a clean unzip by `scripts/make_submission.sh` |

Open points and review tasks are tracked as [GitHub issues](https://github.com/mithulram/chocopy-pa1-group5/issues), grouped by the milestones
**PA1 submission** and **PA1 presentation**.

---

## Repository map

```
.
├── chocopy-pa1/                         the Maven project = what we submit
│   ├── src/main/jflex/chocopy/pa1/ChocoPy.jflex   our lexer (INDENT/DEDENT, strings, EOF)
│   ├── src/main/cup/chocopy/pa1/ChocoPy.cup       our grammar, AST actions, error recovery
│   ├── src/test/data/pa1/sample/                  33 provided tests
│   ├── src/test/data/pa1/edge_cases/              44 own tests (+ expected .ast from the reference)
│   ├── src/test/data/pa1/student_contributed/     good.py, bad.py (graded)
│   ├── tools/                                     difftest.py, fuzz.py, recovery_quality.py, ast_tree.py
│   └── README.md                                  the required write-up (end of the file)
├── presentation/                        slides (.pptx with speaker notes, + .pdf backup)
├── docs/                                the four prep documents (PDF; HTML sources in docs/src/)
├── demo/                                demo.sh + five demo programs for the live demo
├── scripts/                             make_submission.sh, render_docs.sh
└── submission/pa1_group_5.zip           the file to upload
```

---

## Quick start

Requirements: JDK 8+, Maven 3.3.9+, Python 3 (only for the test tools and the demo).
On Windows, use `;` instead of `:` in the classpath.

```bash
cd chocopy-pa1
mvn clean package                    # JFlex + CUP + javac -> target/assignment.jar

# provided tests and our own edge cases
java -cp "chocopy-ref.jar:target/assignment.jar" chocopy.ChocoPy --pass=s --dir src/test/data/pa1/sample --test
java -cp "chocopy-ref.jar:target/assignment.jar" chocopy.ChocoPy --pass=s --dir src/test/data/pa1/edge_cases --test

# one file with our parser (s) or the reference (r)
java -cp "chocopy-ref.jar:target/assignment.jar" chocopy.ChocoPy --pass=s src/test/data/pa1/sample/coverage.py

# differential testing on fresh random programs
python3 tools/fuzz.py /tmp/fuzz 200 42 && python3 tools/difftest.py /tmp/fuzz
```

Live demo (8 steps, about 3 minutes, pauses before each step): `bash demo/demo.sh` from the repository root.

---

## What to read (in this order)

| # | Document | What it is for |
|---|---|---|
| 1 | [Team prep pack](docs/03_team_prep_pack.pdf) | 60-second summary, who presents which slide, code map, concepts, checklists |
| 2 | [Challenges & solutions](docs/01_challenges_and_solutions.pdf) | the 24 problems we hit: symptom, root cause, how found, fix, where in the code; open problems |
| 3 | The two source files | every design decision is explained in the comments |
| 4 | [Q&A preparation](docs/02_qa_preparation.pdf) | 60 likely questions with answers to say out loud |
| 5 | [Run & demo runbook](docs/04_run_and_demo_runbook.pdf) | install, open in IntelliJ/VS Code, every command, demo script, troubleshooting |
| — | [Write-up](chocopy-pa1/README.md#submission-write-up) | the graded write-up: team, acknowledgements, hours, contributions, Q1/Q2, bug report |

---

## The presentation

[`presentation/PA1_Group5_Presentation.pptx`](presentation/PA1_Group5_Presentation.pptx) (PDF backup next to it)

- **Format:** the University of Passau / Chair of Software Engineering I lecture format (the look of the lab's own
  slides: dark slate header, Passau-orange progress bar, page numbers, chair named on the title slide)
  with a thesis-defence structure: Outline → Motivation → Approach → Lexer → Parser → Error recovery →
  Evaluation → Limitations & future work → Conclusion → Backup. Each section opens with an outline slide.
- **No university logo**, on purpose: the official corporate-design rules
  ([uni-passau.de/kommunikation/corporate-design](https://www.uni-passau.de/kommunikation/corporate-design))
  restrict the logo to university units, and the official PowerPoint templates are only downloadable from the
  university network. Colours follow the official palette and the chair's slides; the typeface is Arial,
  the corporate design's substitute for Stone Sans.
- **Speakers:** Mithulram (slides 1–8) → Nafeel (9–12) → Dinodi (13–20) → Nafeel (21–23). About 13:40 in total.
  The speaker notes contain the full talk track for every slide.

---

## How to review and propose corrections

1. **Pick an issue** assigned to you (or labelled with your area: `lexer`, `parser`, `error-recovery`,
   `docs`, `presentation`, `submission`), read the linked files, and comment there.
2. **Found a mistake that isn't tracked yet?** Open a new issue with the *Correction* template
   (file, line/slide, what is wrong, suggested fix). Use the *Question* template if something is unclear —
   if one of us doesn't understand a part, the Q&A will find out.
3. **Changing something:** create a branch, commit, and open a pull request. Rules of thumb:
   - code changes: `mvn clean package`, then all sample and edge-case tests must still pass, and
     `python3 chocopy-pa1/tools/difftest.py chocopy-pa1/src/test/data/pa1/sample` must report 0 differences;
   - if code line numbers move, update the citations in `chocopy-pa1/README.md` (Q1/Q2, error recovery);
   - document changes: edit `docs/src/*.html`, then run `bash scripts/render_docs.sh`;
   - anything inside `chocopy-pa1/`: run `bash scripts/make_submission.sh` again so the zip is current.
4. **Before 04.11:** one of us uploads `submission/pa1_group_5.zip`; the others download it from Stud.IP and
   check it (see the *Upload* issue).

---

## Note for other students

This is our group's own solution for a graded assignment. Please don't copy it for your own submission —
the course requires that every group member understands and can defend every part of the code.

## Acknowledgements and licence

The starter code, AST classes and `chocopy-ref.jar` come from the ChocoPy project of UC Berkeley, adapted by the
teaching team (BSD licence, see [`chocopy-pa1/LICENSE`](chocopy-pa1/LICENSE)). Our use of outside resources,
including AI tools, is declared in the [write-up](chocopy-pa1/README.md#submission-write-up).
