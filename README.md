# ChocoPy compiler, PA1: lexing and parsing (group 5)

Compiler Construction Lab, winter semester 2026/27, Chair of Software Engineering I, University of Passau.

This is our PA1: a JFlex lexer and a CUP parser that turn ChocoPy programs into the JSON AST, with the same
locations as the reference implementation. We also keep everything for the presentation here (slides, notes,
the demo), so all three of us work from the same files.

Team: Mithulram Gunasekaran, Mohamed Nuhuman Mohamed Nafeel, Rajapaksha Mudiyanselage Dinodi Divyanjana Rajapaksha

| What | When |
|---|---|
| Submission on Stud.IP (`SubmissionsDir`) | Wed 04.11.2026, 23:59 |
| Presentation (15 min + 10 min questions) | Thu 12.11.2026, backup date 19.11.2026 |

## Where we are

| Check | Result |
|---|---|
| Provided sample tests | 33/33 |
| Our edge cases (`src/test/data/pa1/edge_cases/`) | 44/44 |
| Compared with the reference on 3,511 files (same rule as grading) | all identical |
| Grammar conflicts | 0 |
| `good.py` / `bad.py` | 0 errors / one error for each of the 9 mistakes |
| Error recovery, one mistake per program (346 programs) | 1.37 errors per mistake (reference: 2.01), never gave up (reference: 3 times) |
| Submission zip | built and tested by `scripts/make_submission.sh` |

Things that still need doing, or that we know aren't perfect, are in the
[issues](https://github.com/mithulram/chocopy-pa1-group5/issues), sorted into the milestones
"PA1 submission" and "PA1 presentation".

## What's where

```
.
├── chocopy-pa1/                         the Maven project, this is what we submit
│   ├── src/main/jflex/chocopy/pa1/ChocoPy.jflex   lexer
│   ├── src/main/cup/chocopy/pa1/ChocoPy.cup       grammar, AST, error recovery
│   ├── src/test/data/pa1/sample/                  33 provided tests
│   ├── src/test/data/pa1/edge_cases/              our 44 tests (+ expected .ast from the reference)
│   ├── src/test/data/pa1/student_contributed/     good.py and bad.py (graded)
│   ├── tools/                                     difftest.py, fuzz.py, recovery_quality.py, ast_tree.py
│   └── README.md                                  the write-up is at the end
├── presentation/                        slides (.pptx with speaker notes, and a PDF copy)
├── docs/                                the four prep documents (PDF, HTML sources in docs/src/)
├── demo/                                demo.sh and five small programs for the live demo
├── scripts/                             make_submission.sh, render_docs.sh
└── submission/pa1_group_5.zip           the file we upload
```

## Running it

You need JDK 8 or newer and Maven 3.3.9 or newer. Python 3 is only needed for our test scripts and the demo.
On Windows use `;` instead of `:` in the classpath.

```bash
cd chocopy-pa1
mvn clean package

# provided tests and our edge cases
java -cp "chocopy-ref.jar:target/assignment.jar" chocopy.ChocoPy --pass=s --dir src/test/data/pa1/sample --test
java -cp "chocopy-ref.jar:target/assignment.jar" chocopy.ChocoPy --pass=s --dir src/test/data/pa1/edge_cases --test

# one file, ours (s) or the reference (r)
java -cp "chocopy-ref.jar:target/assignment.jar" chocopy.ChocoPy --pass=s src/test/data/pa1/sample/coverage.py

# random programs, compared with the reference
python3 tools/fuzz.py /tmp/fuzz 200 42 && python3 tools/difftest.py /tmp/fuzz
```

For the live demo run `bash demo/demo.sh` from the top folder. It waits for Enter before each of the 8 steps
and takes about 3 minutes.

## What to read before the presentation

1. [Team prep pack](docs/03_team_prep_pack.pdf): the one-minute summary, who presents which slide, where
   everything is in the code, checklists.
2. [Challenges and solutions](docs/01_challenges_and_solutions.pdf): the 24 problems we ran into, how we found
   and fixed them, and what's still open.
3. The two source files. The comments explain why things are the way they are.
4. [Q&A preparation](docs/02_qa_preparation.pdf): 60 questions we might get, with answers.
5. [Run and demo runbook](docs/04_run_and_demo_runbook.pdf): setup, all the commands, the demo, what to do if
   something breaks.

The graded write-up is at the end of [chocopy-pa1/README.md](chocopy-pa1/README.md#submission-write-up).

## Slides

[`presentation/PA1_Group5_Presentation.pptx`](presentation/PA1_Group5_Presentation.pptx), with a PDF next to it.

We used the look of the lab's own slides from the chair (dark header, orange progress bar, chair name on the
title slide) and the usual thesis talk order: outline, motivation, approach, lexer, parser, error recovery,
evaluation, limitations, conclusion, backup slides. There's no university logo on purpose. The
[corporate design page](https://www.uni-passau.de/kommunikation/corporate-design) says students can't use it
on their papers, and the official PowerPoint templates are only on the university intranet. The font is Arial,
which the corporate design lists as the replacement for Stone Sans.

Who talks when: Mithulram slides 1-8, Nafeel 9-12, Dinodi 13-20, Nafeel again 21-23. That's about 13:40 in
total. The speaker notes have the full text for each slide.

## If you find a mistake

- Comment on the issue for your part (labels: `lexer`, `parser`, `error-recovery`, `docs`, `presentation`,
  `submission`).
- If there's no issue for it yet, open one with the "Correction" template. If you don't understand something,
  use "Question". Better we find out now than during the Q&A.
- For changes, make a branch and open a pull request. For code changes, run `mvn clean package` and check that
  all sample and edge-case tests still pass. If line numbers move, fix the ones quoted in the write-up. After
  editing a document in `docs/src/`, run `bash scripts/render_docs.sh`. After any change in `chocopy-pa1/`, run
  `bash scripts/make_submission.sh` so the zip is up to date.
- One of us uploads the zip before the deadline and the other two download it again and check it (issue #6).

## For other students

This is our own solution to a graded assignment, so please don't copy it. The course expects every group
member to understand and defend every part of their code anyway.

## Credits

The starter code, the AST classes and `chocopy-ref.jar` come from the ChocoPy project at UC Berkeley, adapted by
the teaching team (BSD licence, see [`chocopy-pa1/LICENSE`](chocopy-pa1/LICENSE)).
