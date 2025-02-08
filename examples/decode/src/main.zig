const std = @import("std");
const png = @import("jaune:png");

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

    const image_file = try std.fs.cwd().openFile(image_path, .{});
    defer image_file.close();

    var image = try png.decodeFile(allocator, image_file);
    defer image.deinit(allocator);

    std.log.info("{s}: {}", .{ image_path, image.pixel_format });

    const pixel = try image.get(25, 25);
    std.log.info("25,25: 0x{x}", .{pixel});

    _ = try image.get(@intCast(image.width - 1), @intCast(image.height - 1));

    // for (0..image.height) |y| {
    //     for (0..image.width) |x| {
    //         const p = try image.get(@intCast(x), @intCast(y));
    //         // std.log.info("{},{}: {x}", .{ x, y, p });
    //         _ = p;
    //     }
    // }
}
