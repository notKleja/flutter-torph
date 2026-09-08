# Status

- Milestone: M9 audit complete + RTL/bidi audit complete (spec/RTL_AUDIT.md) — release candidate 0.1.3 (Torph d79a5aa)
- Integrated commit: master HEAD (see `git log`)
- Passing parity categories: all 25 rows of DONE.md
- Failing: none. P0/P1: none open
- Test suite: 3309 pass, 12 skipped (8 bidi-control corpus cases have no comparable visual box) (ICU dictionary scripts, DEV-001); analyze clean
- Oracle: semantic fixtures (15 files, reproducible) + 168 browser traces (150 + 18 RTL) + RTL corpus 162 static captures and 148 motion traces (oracle/fixtures/rtl) matched by the engine (runtime_trace_parity) and the widget (widget_trace_parity)
- RTL-002 (upstream's logical-order placement) fixed for users by DEV-006: `bidi` defaults to true; upstream-parity suites run with `bidi: false`
- Known P2 (documented): DEV-001..DEV-005, RTL-003; update cost ~26 ms for a 700-char/100-word morph inside the build phase (spec/PERFORMANCE.md) — optimisation candidate, not a parity item
- Open questions: none blocking (Q-029 engine time freezes while idle, harmless; Q-031 TickerMode ageing pinned by test)
- Agents: all finished
- Next automatic action: none — see spec/RELEASE_CANDIDATE.md
