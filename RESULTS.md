# RESULTS - zig-stdlib-error-diagnostics-lab

## Summary

- Cases: 50
- Methods: 18
- Result rows: 455
- Passed: 454
- Failed: 1
- Zig compiler: /home/ubuntu/.local/zig/zig
- Zig version: 0.14.0
- Compile exit: 0
- Run exit: 0
- Zig harness validated: True

## Scores

- error_union_observation: 50
- try_catch_observation: 50
- errdefer_observation: 5
- defer_observation: 5
- diagnostic_out_parameter: 15
- optional_diagnostic: 15
- no_hidden_allocation_marker: 4
- json_diagnostics_context: 42
- zon_diagnostics_context: 31
- testing_debug_marker: 7
- breakpoint_not_run: 4
- build_option_context: 4
- richer_return_marker: 1
- version_compatibility_marker: 455
- production_diagnostics_not_tested: 455
- naive_expected_failures: 1

## Costs

- cases.json: 65099 bytes
- error_diagnostics_lab.zig: 16106 bytes
- compiled binary: 3019552 bytes
- compile_time: 22.684s
- run_time: 0.053s
- python_time: 0.013s
- subprocess_count: 3+ (zig version, zig fmt, zig build-exe, run)
- Python: 3.12.3
- Platform: Linux-6.17.0-1009-aws-x86_64-with-glibc2.39

## Commands

```
python3 -m py_compile generate_cases.py run_lab.py
python3 generate_cases.py
python3 run_lab.py
zig version
zig fmt --check error_diagnostics_lab.zig
zig build-exe error_diagnostics_lab.zig -O ReleaseSafe
./error_diagnostics_lab
```

## Environment

- Zig path: /home/ubuntu/.local/zig/zig
- Zig version: 0.14.0
- Compile command: /home/ubuntu/.local/zig/zig build-exe error_diagnostics_lab.zig -O ReleaseSafe
- Compile exit: 0
- Run exit: 0

## Scope

- HN thread accessed: yes (HN API, item 44812985)
- Network/API/Package manager: none during benchmark (except initial HN read)
- Breakpoint executed: no
- Real JSON/ZON corpora: no
- Real debugger: no
- Secret logging: no
- Production diagnostics: not_tested
- Version compatibility: local_only (0.14.0)
- External language truth: not_tested

## Conclusions

Zig errors are lightweight named values used with error unions. `try` propagates, `catch` recovers, `errdefer` runs only on error paths, `defer` runs always. Optional diagnostic structs carry richer information without hidden allocation, caller chooses whether to request them. JSON/ZON diagnostic APIs exist in stdlib but vary in ergonomics (HN: AndyKelley noted std.json schema mismatch diagnostics are weak, std.zon is better). Returning a tagged union is appropriate when callers need detailed failure variants. No-hidden-allocation is a real design constraint. `@breakpoint` and debugger integration are useful but were not executed in this toy harness. This lab distinguishes local observations from HN opinions, linked-article claims, and production API design. It does NOT prove all Zig error APIs are ergonomic, nor that Rust/Odin/C are better/worse.

See results_rows.csv / results_rows.json for per-case/per-method data.
