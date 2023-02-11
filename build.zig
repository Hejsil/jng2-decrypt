const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const strip = b.option(bool, "strip", "") orelse false;

    const exe = b.addExecutable(.{
        .name = "jng2-decrypt",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.addCSourceFile("lib/tiny-aes-c/aes.c", &.{});
    exe.defineCMacro("AES256", "1");
    exe.addIncludePath("lib/tiny-aes-c/");

    exe.addCSourceFile("lib/zip/src/zip.c", &.{"-fno-sanitize=undefined"});
    exe.addIncludePath("lib/zip/src/");

    exe.linkLibC();
    exe.strip = strip;
    exe.install();
}
