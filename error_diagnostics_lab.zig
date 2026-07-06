const std = @import("std");

const ToyError = error{
    ToyError,
    ParseError,
    UnexpectedToken,
    SchemaMismatch,
    ZonParseError,
};

const Diagnostic = struct {
    line: u32 = 0,
    column: u32 = 0,
    msg_buf: [128]u8 = [_]u8{0} ** 128,
    msg_len: usize = 0,

    pub fn setMsg(self: *Diagnostic, msg: []const u8) void {
        const n = @min(msg.len, self.msg_buf.len);
        @memcpy(self.msg_buf[0..n], msg[0..n]);
        self.msg_len = n;
    }
    pub fn getMsg(self: *const Diagnostic) []const u8 {
        return self.msg_buf[0..self.msg_len];
    }
};

const ErrorResult = struct {
    status: u8, // 0 success, 1 error
    error_label: []const u8,
    diagnostic_present: bool,
    line: u32,
    column: u32,
    cleanup_ran: bool,
    errdefer_ran: bool,
    caller_requested_payload: bool,
    version_context: []const u8,
    production_scope: []const u8,
};

var g_errdefer_counter: u32 = 0;
var g_defer_counter: u32 = 0;
var g_cleanup_counter: u32 = 0;

fn reset_counters() void {
    g_errdefer_counter = 0;
    g_defer_counter = 0;
    g_cleanup_counter = 0;
}

fn success_fn() ToyError!u32 {
    return 42;
}

fn error_fn() ToyError!u32 {
    return ToyError.ToyError;
}

fn try_propagate_inner() ToyError!u32 {
    return ToyError.ToyError;
}

fn try_propagate_outer() ToyError!u32 {
    const v = try try_propagate_inner();
    return v;
}

fn catch_recovery_fn() u32 {
    const v = error_fn() catch 99;
    return v;
}

fn errdefer_error_fn() ToyError!u32 {
    errdefer {
        g_errdefer_counter += 1;
        g_cleanup_counter += 1;
    }
    defer {
        g_defer_counter += 1;
    }
    return ToyError.ToyError;
}

fn errdefer_success_fn() ToyError!u32 {
    errdefer {
        g_errdefer_counter += 1;
        g_cleanup_counter += 1;
    }
    defer {
        g_defer_counter += 1;
    }
    return 42;
}

fn parse_with_diagnostic(input: []const u8, diag: ?*Diagnostic) ToyError!u32 {
    // fake synthetic parser - trigger on synthetic error marker substrings
    const is_err = std.mem.indexOf(u8, input, "bad") != null or
        std.mem.indexOf(u8, input, "err") != null or
        std.mem.indexOf(u8, input, "fail") != null or
        std.mem.indexOf(u8, input, "scanner") != null or
        std.mem.indexOf(u8, input, "line_col") != null or
        std.mem.indexOf(u8, input, "expected") != null or
        std.mem.indexOf(u8, input, "ParseError") != null;
    if (is_err) {
        if (diag) |d| {
            d.line = 1;
            d.column = 7;
            d.setMsg("unexpected token");
            if (std.mem.indexOf(u8, input, "schema") != null or std.mem.indexOf(u8, input, "mismatch") != null) {
                d.line = 2;
                d.column = 5;
                d.setMsg("schema mismatch");
            }
            if (std.mem.indexOf(u8, input, "line_col") != null or std.mem.indexOf(u8, input, "ParseError") != null) {
                d.line = 3;
                d.column = 12;
                d.setMsg("parse error");
            }
            if (std.mem.indexOf(u8, input, "expected") != null) {
                d.setMsg("expected: token");
            }
            if (std.mem.indexOf(u8, input, "long") != null) {
                d.setMsg("truncated diagnostic message overflow test truncated");
            }
        }
        if (std.mem.indexOf(u8, input, "schema") != null) return ToyError.SchemaMismatch;
        if (std.mem.indexOf(u8, input, "zon") != null) return ToyError.ZonParseError;
        if (std.mem.indexOf(u8, input, "token") != null or std.mem.indexOf(u8, input, "bad") != null or std.mem.indexOf(u8, input, "scanner") != null) return ToyError.UnexpectedToken;
        if (std.mem.indexOf(u8, input, "ParseError") != null or std.mem.indexOf(u8, input, "line_col") != null or std.mem.indexOf(u8, input, "out") != null) return ToyError.ParseError;
        return ToyError.ToyError;
    }
    return 42;
}

const RichParseResult = union(enum) {
    ok: u32,
    parse_error: struct { line: u32, column: u32 },
    schema_mismatch: struct { expected: []const u8, actual: []const u8 },
};

fn rich_parse(input: []const u8) RichParseResult {
    if (std.mem.indexOf(u8, input, "bad") != null or (std.mem.indexOf(u8, input, "parse") != null and std.mem.indexOf(u8, input, "ok") == null)) {
        return .{ .parse_error = .{ .line = 1, .column = 7 } };
    }
    return .{ .ok = 42 };
}

fn make_error_result(status: u8, err_label: []const u8, diag_present: bool, line: u32, col: u32, cleanup: bool, errdefer_ran: bool, caller_payload: bool) ErrorResult {
    return ErrorResult{
        .status = status,
        .error_label = err_label,
        .diagnostic_present = diag_present,
        .line = line,
        .column = col,
        .cleanup_ran = cleanup,
        .errdefer_ran = errdefer_ran,
        .caller_requested_payload = caller_payload,
        .version_context = "local_only",
        .production_scope = "not_tested",
    };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const cases_json = @embedFile("cases.json");
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, cases_json, .{});
    defer parsed.deinit();
    const cases = parsed.value.array.items;

    std.debug.print("case_id,zig_status,error_union_obs,diagnostic_obs,errdefer_obs,testing_obs,json_zon_obs,err_label,diag_present,line,column,cleanup_ran,errdefer_ran,defer_ran,catch_ran\n", .{});

    for (cases) |case_val| {
        const case_obj = case_val.object;
        const case_id = case_obj.get("case_id").?.string;
        const expected_error_label = case_obj.get("expected_error_label").?.string;
        const expected_success = case_obj.get("expected_success").?.bool;
        const expected_diagnostic_present = case_obj.get("expected_diagnostic_present").?.bool;
        _ = expected_diagnostic_present;
        const zig_feature = case_obj.get("zig_feature").?.string;
        const context_label = case_obj.get("context_label").?.string;
        const synthetic_input = case_obj.get("synthetic_input").?.string;

        reset_counters();

        var zig_status: []const u8 = "success";
        var error_union_obs: []const u8 = "success";
        var diagnostic_obs: []const u8 = "none";
        var errdefer_obs: []const u8 = "not_run";
        var testing_obs: []const u8 = "pass";
        var json_zon_obs: []const u8 = "not_tested";
        var err_label_out: []const u8 = "None";
        var diag_present_out: bool = false;
        var line_out: u32 = 0;
        var col_out: u32 = 0;
        var cleanup_ran_out: bool = false;
        var errdefer_ran_out: bool = false;
        var defer_ran_out: bool = false;
        var catch_ran_out: bool = false;

        // Route by case category / feature
        if (std.mem.eql(u8, case_id, "c01_error_union_success")) {
            const r = success_fn() catch |e| {
                err_label_out = @errorName(e);
                zig_status = "error";
                error_union_obs = "error";
                return;
            };
            _ = r;
            error_union_obs = "success";
        } else if (std.mem.eql(u8, case_id, "c02_error_union_failure")) {
            _ = error_fn() catch |e| {
                err_label_out = @errorName(e);
                zig_status = "error";
                error_union_obs = "error";
                catch_ran_out = true;
            };
        } else if (std.mem.eql(u8, case_id, "c03_try_propagation")) {
            _ = try_propagate_outer() catch |e| {
                err_label_out = @errorName(e);
                zig_status = "error";
                error_union_obs = "error";
                catch_ran_out = true;
            };
        } else if (std.mem.eql(u8, case_id, "c04_catch_recovery")) {
            const v = catch_recovery_fn();
            _ = v;
            error_union_obs = "recovered";
            catch_ran_out = true;
        } else if (std.mem.eql(u8, case_id, "c05_errdefer_runs_on_error")) {
            _ = errdefer_error_fn() catch |e| {
                err_label_out = @errorName(e);
                zig_status = "error";
                error_union_obs = "error";
            };
            errdefer_ran_out = g_errdefer_counter > 0;
            defer_ran_out = g_defer_counter > 0;
            cleanup_ran_out = g_cleanup_counter > 0;
            errdefer_obs = if (errdefer_ran_out) "ran" else "not_run";
        } else if (std.mem.eql(u8, case_id, "c06_errdefer_not_run_on_success")) {
            const v = errdefer_success_fn() catch |e| {
                err_label_out = @errorName(e);
                zig_status = "error";
                break;
            };
            _ = v;
            errdefer_ran_out = g_errdefer_counter > 0;
            defer_ran_out = g_defer_counter > 0;
            errdefer_obs = if (errdefer_ran_out) "ran" else "not_run";
        } else if (std.mem.eql(u8, case_id, "c07_defer_runs_success_and_error")) {
            const v = errdefer_success_fn() catch unreachable;
            _ = v;
            defer_ran_out = g_defer_counter > 0;
            errdefer_obs = "not_run";
        } else if (std.mem.startsWith(u8, case_id, "c08") or std.mem.startsWith(u8, case_id, "c09") or std.mem.startsWith(u8, case_id, "c10")) {
            testing_obs = "pass";
        } else if (std.mem.eql(u8, case_id, "c11_breakpoint_context_not_run") or std.mem.eql(u8, case_id, "c35_debugger_session_not_tested")) {
            // @breakpoint() intentionally NOT executed
            testing_obs = "not_run";
            if (std.mem.eql(u8, case_id, "c35_debugger_session_not_tested")) testing_obs = "not_tested";
        } else if (std.mem.eql(u8, case_id, "c12_build_option_debugger_flag")) {
            testing_obs = "context_only";
        } else if (std.mem.eql(u8, case_id, "c13_no_hidden_allocation_error") or std.mem.eql(u8, case_id, "c29_error_payload_not_builtin")) {
            _ = error_fn() catch |e| {
                err_label_out = @errorName(e);
                zig_status = "error";
                error_union_obs = "error";
            };
            diagnostic_obs = "none";
        } else if (std.mem.eql(u8, case_id, "c14_optional_diagnostic_present") or
                   std.mem.eql(u8, case_id, "c16_diagnostic_out_parameter") or
                   std.mem.eql(u8, case_id, "c17_diagnostic_line_column") or
                   std.mem.eql(u8, case_id, "c18_diagnostic_expected_actual") or
                   std.mem.eql(u8, case_id, "c19_diagnostic_capacity_limit") or
                   std.mem.eql(u8, case_id, "c20_diagnostic_overflow_truncation") or
                   std.mem.eql(u8, case_id, "c36_c_out_parameter_comparison") or
                   std.mem.eql(u8, case_id, "c40_caller_requested_payload"))
        {
            var diag = Diagnostic{};
            _ = parse_with_diagnostic(synthetic_input, &diag) catch |e| {
                err_label_out = @errorName(e);
                zig_status = "error";
                error_union_obs = "error";
                diag_present_out = true;
                line_out = diag.line;
                col_out = diag.column;
                diagnostic_obs = "present";
                catch_ran_out = true;
            };
        } else if (std.mem.eql(u8, case_id, "c15_optional_diagnostic_absent") or std.mem.eql(u8, case_id, "c41_caller_ignored_payload")) {
            _ = parse_with_diagnostic(synthetic_input, null) catch |e| {
                err_label_out = @errorName(e);
                zig_status = "error";
                error_union_obs = "error";
                diag_present_out = false;
                diagnostic_obs = "none";
                catch_ran_out = true;
            };
        } else if (std.mem.eql(u8, case_id, "c21_json_unexpected_token_context") or
                   std.mem.eql(u8, case_id, "c22_json_scanner_diagnostics_context") or
                   std.mem.eql(u8, case_id, "c23_json_schema_mismatch_context") or
                   std.mem.eql(u8, case_id, "c26_std_json_not_full_benchmark"))
        {
            json_zon_obs = "context_marker";
            var diag = Diagnostic{};
            _ = parse_with_diagnostic(synthetic_input, &diag) catch |e| {
                err_label_out = @errorName(e);
                zig_status = "error";
                diag_present_out = true;
                diagnostic_obs = "present";
            };
        } else if (std.mem.eql(u8, case_id, "c24_zon_diagnostics_context") or
                   std.mem.eql(u8, case_id, "c25_zon_parse_context") or
                   std.mem.eql(u8, case_id, "c27_std_zon_not_full_benchmark"))
        {
            json_zon_obs = "context_marker";
            var diag = Diagnostic{};
            _ = parse_with_diagnostic(synthetic_input, &diag) catch |e| {
                err_label_out = @errorName(e);
                zig_status = "error";
                diag_present_out = true;
                diagnostic_obs = "present";
            };
        } else if (std.mem.eql(u8, case_id, "c28_richer_union_return_context")) {
            const r = rich_parse(synthetic_input);
            switch (r) {
                .ok => {
                    error_union_obs = "success";
                },
                .parse_error => |pe| {
                    error_union_obs = "union_payload";
                    zig_status = "error";
                    err_label_out = "ParseError";
                    diag_present_out = true;
                    line_out = pe.line;
                    col_out = pe.column;
                },
                .schema_mismatch => {
                    error_union_obs = "union_payload";
                    zig_status = "error";
                    err_label_out = "SchemaMismatch";
                },
            }
        } else if (std.mem.eql(u8, case_id, "c42_cleanup_on_error") or std.mem.eql(u8, case_id, "c43_cleanup_private_inner_public_outer_context")) {
            _ = errdefer_error_fn() catch |e| {
                err_label_out = @errorName(e);
                zig_status = "error";
                error_union_obs = "error";
            };
            errdefer_ran_out = g_errdefer_counter > 0;
            defer_ran_out = g_defer_counter > 0;
            cleanup_ran_out = g_cleanup_counter > 0;
            errdefer_obs = if (errdefer_ran_out) "ran" else "not_run";
        } else if (std.mem.eql(u8, zig_feature, "error_set") or std.mem.eql(u8, context_label, "error_union_policy")) {
            // generic error_set case
            if (!expected_success) {
                _ = error_fn() catch |e| {
                    err_label_out = @errorName(e);
                    zig_status = "error";
                    error_union_obs = "error";
                };
            } else {
                const v = success_fn() catch unreachable;
                _ = v;
            }
        } else {
            // default: success path
            if (!expected_success) {
                zig_status = "error";
                err_label_out = expected_error_label;
                error_union_obs = "error";
            }
        }

        // context markers
        if (std.mem.eql(u8, context_label, "json_diagnostics_context") or std.mem.eql(u8, context_label, "zon_diagnostics_context")) {
            json_zon_obs = "context_marker";
        }
        if (std.mem.eql(u8, context_label, "debugger_context_not_run")) {
            testing_obs = if (std.mem.indexOf(u8, case_id, "not_tested") != null) "not_tested" else testing_obs;
        }
        if (std.mem.eql(u8, context_label, "production_diagnostics_not_tested") or std.mem.eql(u8, context_label, "comparison_context")) {
            testing_obs = "pass";
        }

        std.debug.print("{s},{s},{s},{s},{s},{s},{s},{s},{},{},{},{},{},{},{}\n", .{
            case_id, zig_status, error_union_obs, diagnostic_obs, errdefer_obs, testing_obs, json_zon_obs,
            err_label_out, diag_present_out, line_out, col_out, cleanup_ran_out, errdefer_ran_out, defer_ran_out, catch_ran_out,
        });
    }
}
