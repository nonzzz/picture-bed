const std = @import("std");

// zig build system guide
// https://ziglang.org/learn/build-system/
pub fn build(b: *std.Build) void {

    // All top-level steps you can invoke on the command line.

    const build_steps = .{
        .zig_ini_test = b.step("zig-ini:test", "Run zig-ini unit test"),
        .bindings_wasm = b.step("bindings:wasm", "Build wasm bindings"),
    };

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const zig_ini_module = build_zig_ini_module(b);
    build_wasm_bindings(b, build_steps.bindings_wasm, .{
        .zig_ini_module = zig_ini_module,
        .target = target,
        .optimize = optimize,
    });

    build_zig_ini_test(b, build_steps.zig_ini_test, .{
        .zig_ini_module = zig_ini_module,
        .target = target,
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
        .name = "wasm_bindings",
        .root_source_file = b.path("bindings/wasm/wasm_bindings.zig"),
        .target = options.target,
        .optimize = options.optimize,
    });
    wasm_bindings_generate.root_module.addImport("zig-ini", options.zig_ini_module);
    // const run_wasm_bindings = b.addRunArtifact(wasm_bindings_generate);
    // b.installArtifact(wasm_bindings_generate);
    // b.addInstallArtifact(wasm, options: Step.InstallArtifact.Options)
    step_wasm_bindings.dependOn(&b.addInstallArtifact(wasm_bindings_generate, .{}).step);
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
        .target = options.target,
        .optimize = options.optimize,
    });
    const run_ini_unit_test = b.addRunArtifact(zig_init_test);
    step_zig_ini_test.dependOn(&run_ini_unit_test.step);
}

fn resolve_target(b: *std.Build) !std.Build.ResolvedTarget {
    const cpus = .{};
    _ = cpus; // autofix
    return b.resolveTargetQuery();
}
