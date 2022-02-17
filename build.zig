const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    b.setPreferredReleaseMode(.ReleaseSafe);
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const strip = b.option(bool, "strip", "") orelse false;

    const exe = b.addExecutable("jng2-decrypt", "src/main.zig");

    exe.addCSourceFile("lib/tiny-aes-c/aes.c", &.{});
    exe.defineCMacro("AES256", "1");
    exe.addIncludePath("lib/tiny-aes-c/");

    exe.addCSourceFile("lib/zip/src/zip.c", &.{
        "-fno-sanitize=undefined",
    });
    exe.addIncludePath("lib/zip/src/");

    exe.linkLibC();
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.strip = strip;
    exe.install();

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
