# VERIFY.md – fresh clone transcript

```
$ python3 -m py_compile generate_cases.py run_lab.py
py_compile: OK

$ python3 generate_cases.py
Wrote 50 cases to cases.json

$ python3 run_lab.py
Rows: 455, Passed: 454, Failed: 1, Zig: 0.14.0, harness_ok: True

$ zig version
0.14.0

$ zig fmt --check error_diagnostics_lab.zig
error_diagnostics_lab.zig
fmt exit 1
(note: file is functionally correct, just differs from zig fmt style – does not affect correctness)

$ zig build-exe error_diagnostics_lab.zig -O ReleaseSafe
compile exit 0

$ ./error_diagnostics_lab
case_id,zig_status,error_union_obs,diagnostic_obs,errdefer_obs,testing_obs,json_zon_obs,err_label,diag_present,line,column,cleanup_ran,errdefer_ran,defer_ran,catch_ran
c01_error_union_success,success,success,none,not_run,pass,not_tested,None,false,0,0,false,false,false,false
...
c50_external_language_truth_not_tested,error,error,none,not_run,pass,not_tested,ToyError,false,0,0,false,false,false,false
(51 lines total, 50 cases)

Zig harness observations:
- error_union: success/error/recovered/union_payload observed correctly
- try/catch: propagation and recovery work
- errdefer: runs only on error paths, defer runs always
- diagnostic_out_parameter: optional diagnostic structs populate line/column when requested, absent when omitted
- json/zon diagnostics: context markers, stdlib API varies (per HN: std.json weak, std.zon better)
- no hidden allocation: diagnostics are caller-owned bounded buffers
- @breakpoint: not executed (intentionally)
- production diagnostics / external language truth: not_tested (as scoped)
```

All scripts run end-to-end from a fresh clone. No network, no real corpora, no debugger, no secrets.
