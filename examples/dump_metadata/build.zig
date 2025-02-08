const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "dump_head",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    const png_dep = b.dependency("png.zig", .{});
    exe.root_module.addImport("png.zig", png_dep.module("root"));

    const run_step = b.step("run", "Run");

    const images_paths = [_][]const u8{
        "./images/rectangles.png",
    };

    for (images_paths) |images_path| {
        const run_exe = b.addRunArtifact(exe);

        run_exe.step.dependOn(b.getInstallStep());

        run_exe.addArg(images_path);

        run_step.dependOn(&run_exe.step);
    }
}
