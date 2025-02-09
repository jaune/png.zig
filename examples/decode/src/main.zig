const std = @import("std");
const png = @import("jaune:png");

fn decodeValue(value: u16, bit_depth: u8) !f32 {
    return switch (bit_depth) {
        1 => @as(f32, @floatFromInt(value)) / std.math.maxInt(u8),
        2 => @as(f32, @floatFromInt(value)) / std.math.maxInt(u8),
        4 => @as(f32, @floatFromInt(value)) / std.math.maxInt(u8),
        8 => @as(f32, @floatFromInt(value)) / std.math.maxInt(u8),
        16 => @as(f32, @floatFromInt(value)) / std.math.maxInt(u16),
        else => {
            return error.UnsupportedBitDepth;
        },
    };
}

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

    const color_type_raw = args.next() orelse {
        return error.MissingColorTypeArgument;
    };
    const color_type = try std.fmt.parseInt(u8, color_type_raw, 10);

    const bit_depth_raw = args.next() orelse {
        return error.MissingBitDepthArgument;
    };
    const bit_depth = try std.fmt.parseInt(u8, bit_depth_raw, 10);

    const json_path = args.next() orelse {
        return error.MissingJsonPathArgument;
    };

    const image_file = try std.fs.cwd().openFile(image_path, .{});
    defer image_file.close();

    const json_data = try std.fs.cwd().readFileAlloc(allocator, json_path, 1024 * 1024);
    defer allocator.free(json_data);

    const parsed = try std.json.parseFromSlice([]u16, allocator, json_data, .{});
    defer parsed.deinit();

    var image = try png.decodeFile(allocator, image_file);
    defer image.deinit(allocator);

    const pixel_format = try png.PixelFormat.fromRaw(color_type, bit_depth);

    if (image.pixel_format != pixel_format) {
        return error.PixelFormatNotMatching;
    }

    std.log.info("{s}: color_type={} bit_depth={}", .{ json_path, color_type, bit_depth });
    std.log.info("{s}: {}, width={}, height={}", .{ image_path, image.pixel_format, image.width, image.height });

    if ((image.width * image.height * 4) != parsed.value.len) {
        std.log.err("{s}: size: {}x{}, expected={}, given={}", .{ json_path, image.width, image.height, image.width * image.height, parsed.value.len });

        return error.InvalidLength;
    }

    for (0..image.height) |y| {
        for (0..image.width) |x| {
            const given = try image.get(@intCast(x), @intCast(y));
            const i = (x + (y * image.width)) * 4;

            const expected = png.NormalizedColor{
                .red = try decodeValue(parsed.value[i], bit_depth),
                .green = try decodeValue(parsed.value[i + 1], bit_depth),
                .blue = try decodeValue(parsed.value[i + 2], bit_depth),
                .alpha = try decodeValue(parsed.value[i + 3], bit_depth),
            };

            if (!(given.red == expected.red and given.green == expected.green and given.blue == expected.blue and given.alpha == expected.alpha)) {
                std.log.err("{s}: {},{} ({}):\n  expected={}\n  given={}", .{ image_path, x, y, i, expected, given });
                return error.ValueNotMatching;
            }
        }
    }
}
