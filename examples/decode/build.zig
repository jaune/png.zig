const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "decode",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    const png_dep = b.dependency("jaune:png", .{});
    exe.root_module.addImport("jaune:png", png_dep.module("root"));

    const run_step = b.step("run", "Run");

    const images_paths = [_][]const u8{
        "./images/rectangles.png",
        "./images/pink.png",
    };

    for (images_paths) |images_path| {
        const run_exe = b.addRunArtifact(exe);

        run_exe.step.dependOn(b.getInstallStep());

        run_exe.addArg(images_path);

        run_step.dependOn(&run_exe.step);
    }

    const run_pngsuite_step = b.step("run_pngsuite", "Run pngsuite");

    const pngsuite_dir_path = b.path("./images/pngsuite/png").getPath(b);

    var pngsuite_dir = try std.fs.openDirAbsolute(pngsuite_dir_path, .{ .iterate = true });
    defer pngsuite_dir.close();

    var it = pngsuite_dir.iterate();

    while (try it.next()) |entry| {
        if (entry.kind == .file and std.mem.startsWith(u8, entry.name, "basn")) {
            const images_path = try std.fs.path.join(b.allocator, &[_][]const u8{ pngsuite_dir_path, entry.name });
            defer b.allocator.free(images_path);

            const run_exe = b.addRunArtifact(exe);

            run_exe.step.dependOn(b.getInstallStep());

            run_exe.addArg(images_path);

            run_pngsuite_step.dependOn(&run_exe.step);
        }
    }

    run_step.dependOn(run_pngsuite_step);
}
