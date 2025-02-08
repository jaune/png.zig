const std = @import("std");
const png = @import("png.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip(); // skip arg 0

    const image_path = args.next() orelse {
        return error.MissingImagePathArgument;
    };

    const file = try std.fs.cwd().openFile(image_path, .{});
    defer file.close();

    const metadata = try png.readMetadataFromFile(file);

    std.log.info("{s}:", .{image_path});
    std.log.info("  width: {}", .{metadata.width});
    std.log.info("  height: {}", .{metadata.height});
}
