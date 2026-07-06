# zig-stdlib-error-diagnostics-lab

Tiny local correctness lab about Zig stdlib error diagnostics, inspired by [HN 44812985 – "Zig Error Patterns"](https://news.ycombinator.com/item?id=44812985).

## Hacker News thread access

**The HN thread was read via the Hacker News API CLI (`hackernews get-item --id 44812985`) before writing this sentiment summary.** See `hn_thread_evidence.md` and `hn_comments_sanitized.json` for auditable evidence.

## What HN users were actually debating

The linked article ([glfmn.io/posts/zig-error-patterns](https://glfmn.io/posts/zig-error-patterns/)) is about using `errdefer`, `std.debug.print`, `@breakpoint`, and Zig build options (`-Ddebugger`) to improve debugging for tests.

The HN discussion broadens far beyond that article into Zig's error design itself:

- **Error payloads missing** – Top comment asks how people deal with Zig errors carrying no payload data. Parsing JSON, getting `UnexpectedToken` with no context, isn't very helpful. Are libraries supposed to accept an optional error-storage input?
- **Optional diagnostic / out-parameter structs** – The idiomatic Zig answer: return a simple unadorned error, but accept an optional pointer (`?*ErrorInfo`) where the callee can fill in detailed error data. Caller arranges memory, no hidden allocation. Caller may omit the diagnostic parameter entirely if they don't want details.
- **No hidden allocation** – This is a fundamental Zig design element. The compiler never triggers implicit memory allocation for error returns. The tradeoff: caller must allocate space for error payload even if the error is very unlikely.
- **JSON diagnostics / schema mismatch** – Stdlib's `std.json` has a separate `Scanner.Diagnostics` object, but AndyKelley (Zig BDFL) says std.json "is not a good example of proper error handling" – schema mismatch reports a failure code without populating diagnostics, "painful and useless".
- **ZON diagnostics** – The `std.zon` author did it right: `std.zon.parse.fromSlice` takes an optional `Diagnostics` struct with all the info you need, including a format method for human-readable messages.
- **Errors are for control flow** – Several commenters: errors are for control flow; if you need other information, return it directly, via an out parameter, or in context.
- **Rust `Result` / `anyhow` comparison** – With arbitrary error payloads, functions need compatible error types (refactor bubbling), or box everything like `anyhow`. "Does it help you solve real problems? Opinions vary, but I think it mostly makes your life harder." Callers bubbling errors up usually don't have context to handle metadata anyway.
- **Union return when callers care** – If callers actually need to inspect failure details, return a `union` type. That's the right API.
- **`errdefer` praised** – "Wow, errdefer sounds like the kind of thing every language ought to have." `errdefer` patterns in tests are super nice. Lets you put cleanup code right next to where it's relevant, happy path reads top-to-bottom.
- **C-style out parameters** – "So… pretty much how C does it." Counterpoint: C doesn't have error result types baked into the language.
- **Culture and coding standards** – C _can_ do out-parameter diagnostics but it's not normal. If Zig fosters a culture of this, it'll become the community norm.
- **Odin comparison** – "cannot attach data to [Zig] error … Odin is much better here"
- **Debugger / build options** – The linked article's debugger integration in `build.zig` was praised – avoids grepping the cache directory for the exe.
- **Caller-requested payloads** – Some authors let callers specify the return type, avoiding work (e.g. parse failure line numbers) if not requested.

HN commenters were split: some liked Zig's explicitness and no-hidden-allocation guarantee; others found payload-less errors painful. The debate touched C out-parameters, Rust `Result`/`anyhow`, Odin error payloads, stack traces, `try`/`catch`/`errdefer`, debugger ergonomics, build-system flags, and whether the real issue is Zig's error design, stdlib diagnostic API maturity, or expectations carried over from languages with richer error payloads.

## What this lab does

A tiny local Zig stdlib harness (error_diagnostics_lab.zig, Zig 0.14.0) exercising:

- error sets, error unions, `try`, `catch`, `errdefer`, `defer`
- `std.testing.expect`, `std.debug.print`
- optional diagnostic structs, out-parameter diagnostic capture
- no-hidden-allocation error context (caller-owned bounded buffers)
- JSON diagnostics context markers, ZON diagnostics context markers
- compile-time debugger flag markers, `@breakpoint` not-run markers
- richer union-return context markers
- Rust/Odin/C comparison context markers
- project-local error-result structs

50 deterministic synthetic cases, no real files, no real network, no real debugger, no secrets.

## What this lab does NOT do

Not a real JSON parser, ZON parser, debugger harness, logging system, Rust/Odin/C implementation, fuzzer, sanitizer, or static analyzer. Does not prove production diagnostic quality, all Zig error handling across versions, debugger correctness, or that any one error policy is right for every Zig program.

## Running

```bash
python3 -m py_compile generate_cases.py run_lab.py
python3 generate_cases.py
python3 run_lab.py
# with zig in PATH:
zig version
zig fmt --check error_diagnostics_lab.zig
zig build-exe error_diagnostics_lab.zig -O ReleaseSafe
./error_diagnostics_lab
```

See `RESULTS.md`, `results_rows.csv`, `results_rows.json`, `VERIFY.md`.

## Results (Zig 0.14.0)

- 50 cases, 18 methods, 455 result rows
- 454 pass / 1 fail (the 1 fail is the intentional naive_error_policy case)
- Zig harness validated: yes

Zig errors are lightweight named values. `try` propagates, `catch` recovers, `errdefer` runs only on error, `defer` runs always. Optional diagnostic structs carry richer info without hidden allocation – caller chooses whether to request them. JSON/ZON diagnostic APIs exist but vary in ergonomics (per HN: std.json schema mismatch diagnostics are weak, std.zon is better). Returning a tagged union is appropriate when callers need detailed failure variants. No-hidden-allocation is a real design constraint. `@breakpoint` / debugger integration were not executed in this toy harness.

This lab distinguishes local observations from HN opinions, linked-article claims, and production API design. It does NOT prove all Zig error APIs are ergonomic, nor that Rust/Odin/C are better/worse.
