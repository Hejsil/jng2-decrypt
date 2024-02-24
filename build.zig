const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "jng2-decrypt",
        .root_source_file = .{ .path = "src/main.zig" },
        .link_libc = true,
        .target = target,
        .optimize = optimize,
    });

    exe.addCSourceFile(.{ .file = .{ .path = "lib/tiny-aes-c/aes.c" } });
    exe.defineCMacro("AES256", "1");
    exe.addIncludePath(.{ .path = "lib/tiny-aes-c/" });

    exe.addCSourceFile(.{
        .file = .{ .path = "lib/zip/src/zip.c" },
        .flags = &.{"-fno-sanitize=undefined"},
    });
    exe.addIncludePath(.{ .path = "lib/zip/src/" });

    b.installArtifact(exe);
}
