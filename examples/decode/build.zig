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

    // const images_paths = [_][]const u8{
    //     "./images/rectangles.png",
    //     "./images/pink.png",
    // };

    // for (images_paths) |images_path| {
    //     const run_exe = b.addRunArtifact(exe);

    //     run_exe.step.dependOn(b.getInstallStep());

    //     run_exe.addArg(images_path);

    //     run_step.dependOn(&run_exe.step);
    // }

    const run_pngsuite_step = b.step("run_pngsuite", "Run pngsuite");

    const pngsuite_dir_path = b.path("./images/pngsuite/png").getPath(b);
    const pngsuite_json_dir_path = b.path("./images/pngsuite/json").getPath(b);

    var pngsuite_dir = try std.fs.openDirAbsolute(pngsuite_dir_path, .{ .iterate = true });
    defer pngsuite_dir.close();

    var it = pngsuite_dir.iterate();

    while (try it.next()) |entry| {
        if (entry.kind == .file) {
            if (!checkFilename(entry.name)) {
                continue;
            }

            const images_path = try std.fs.path.join(b.allocator, &[_][]const u8{ pngsuite_dir_path, entry.name });
            defer b.allocator.free(images_path);

            const basename = entry.name[0..(entry.name.len - 4)];

            const bit_depth = basename[(basename.len - 2)..];
            const color_type = basename[(basename.len - 4)..(basename.len - 3)];
            const interlaced = basename[basename.len - 5] == 'i';

            // NOTE: Skip interlaced
            if (interlaced) {
                continue;
            }

            // NOTE: Skip palette
            if (try std.fmt.parseInt(u8, color_type, 10) == 3) {
                continue;
            }

            const json_filename = try std.fmt.allocPrint(b.allocator, "{s}.json", .{basename});
            defer b.allocator.free(json_filename);

            const json_path = try std.fs.path.join(b.allocator, &[_][]const u8{ pngsuite_json_dir_path, json_filename });
            defer b.allocator.free(images_path);

            std.fs.accessAbsolute(json_path, .{ .mode = .read_only }) catch {
                continue;
            };

            const run_exe = b.addRunArtifact(exe);

            run_exe.step.dependOn(b.getInstallStep());

            run_exe.addArg(images_path);

            run_exe.addArg(color_type);
            run_exe.addArg(bit_depth);

            run_exe.addArg(json_path);

            run_pngsuite_step.dependOn(&run_exe.step);
        }
    }

    run_step.dependOn(run_pngsuite_step);
}

fn checkFilename(name: []const u8) bool {
    return std.mem.startsWith(u8, name, "basn") or std.mem.startsWith(u8, name, "bgan") or std.mem.startsWith(u8, name, "z0");
}
