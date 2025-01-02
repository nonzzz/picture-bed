const std = @import("std");
const builtin = @import("builtin");

// zig build system guide
// https://ziglang.org/learn/build-system/
pub fn build(b: *std.Build) !void {

    // All top-level steps you can invoke on the command line.

    const build_steps = .{
        .zig_ini_test = b.step("zig-ini:test", "Run zig-ini unit test"),
        .bindings_wasm = b.step("bindings:wasm", "Build wasm bindings"),
    };

    const optimize = b.standardOptimizeOption(.{});
    const zig_ini_module = build_zig_ini_module(b);
    build_wasm_bindings(b, build_steps.bindings_wasm, .{
        .zig_ini_module = zig_ini_module,
        .target = try resolve_target(b, .{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        }),
        .optimize = optimize,
    });

    build_zig_ini_test(b, build_steps.zig_ini_test, .{
        .zig_ini_module = zig_ini_module,
        .target = try resolve_target(b, .{}),
        .optimize = optimize,
    });
}

fn build_zig_ini_module(b: *std.Build) *std.Build.Module {
    const zig_ini_module = b.addModule("zig-ini", .{
        .root_source_file = b.path("src/ini.zig"),
    });
    return zig_ini_module;
}

fn build_wasm_bindings(
    b: *std.Build,
    step_wasm_bindings: *std.Build.Step,
    options: struct {
        zig_ini_module: *std.Build.Module,
        target: std.Build.ResolvedTarget,
        optimize: std.builtin.OptimizeMode,
    },
) void {
    const wasm_bindings_generate = b.addExecutable(.{
        .name = "zig-ini",
        .root_source_file = b.path("bindings/wasm/src/wasm_bindings.zig"),
        .target = options.target,
        .optimize = .ReleaseSmall,
    });

    wasm_bindings_generate.root_module.addImport("zig-ini", options.zig_ini_module);
    wasm_bindings_generate.rdynamic = true;
    wasm_bindings_generate.entry = .disabled;

    step_wasm_bindings.dependOn(&b.addInstallArtifact(wasm_bindings_generate, .{
        .dest_dir = .{
            .override = .{ .custom = b.dupePath("bindings/wasm") },
        },
    }).step);

    var write_build_script = b.addSystemCommand(&.{ "node", "./bindings/wasm/esbuild.js" });

    step_wasm_bindings.dependOn(&write_build_script.step);
}

fn build_zig_ini_test(
    b: *std.Build,
    step_zig_ini_test: *std.Build.Step,
    options: struct {
        zig_ini_module: *std.Build.Module,
        target: std.Build.ResolvedTarget,
        optimize: std.builtin.OptimizeMode,
    },
) void {
    const zig_init_test = b.addTest(.{
        .root_source_file = b.path("src/test.zig"),
        .target = b.resolveTargetQuery(.{}),
        .optimize = options.optimize,
    });
    const run_ini_unit_test = b.addRunArtifact(zig_init_test);
    step_zig_ini_test.dependOn(&run_ini_unit_test.step);
}

fn resolve_target(b: *std.Build, target_requested: std.Target.Query) !std.Build.ResolvedTarget {
    var target: std.Target.Query = .{
        .cpu_arch = builtin.target.cpu.arch,
        .os_tag = builtin.target.os.tag,
    };

    if (target_requested.cpu_arch) |cpu_arch| {
        target.cpu_arch = cpu_arch;
    }

    if (target_requested.os_tag) |os_tag| {
        target.os_tag = os_tag;
    }

    const targets: []const std.Target.Query = &.{
        .{ .cpu_arch = .aarch64, .os_tag = .macos },
        .{ .cpu_arch = .x86_64, .os_tag = .linux },
        .{ .cpu_arch = .x86_64, .os_tag = .windows },
        .{ .cpu_arch = .aarch64, .os_tag = .windows },
        .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
    };
    for (targets) |query| {
        if (query.cpu_arch == target.cpu_arch and query.os_tag == target.os_tag) {
            return b.resolveTargetQuery(query);
        }
    }
    return error.UnsupportedTarget;
}
