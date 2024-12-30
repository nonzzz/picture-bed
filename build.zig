const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const ini_test = b.addTest(.{
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_ini_test = b.addRunArtifact(ini_test);
    const test_ini_step = b.step("test", "Run ini module test");
    test_ini_step.dependOn(&run_ini_test.step);
}
