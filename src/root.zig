const std = @import("std");
const crc32reader = @import("crc32_reader.zig");

pub const ImageUnmanaged = struct {
    const Self = @This();

    height: u32,
    width: u32,
    pixel_format: PixelFormat,
    data: []u8,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32, pixel_format: PixelFormat) !Self {
        const w: usize = width;
        const bpp: usize = pixel_format.getBitsPerPixel();
        const line_size: usize = (w * bpp + 7) / 8;
        const data_size: usize = line_size * height;

        std.log.debug("ImageUnmanaged.init(): image_size: {}", .{data_size});

        return .{
            .width = width,
            .height = height,
            .pixel_format = pixel_format,
            .data = try allocator.alloc(u8, data_size),
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
        self.* = undefined;
    }

    pub fn get(self: *const Self, x: u32, y: u32) !u64 {
        if (x >= self.width) {
            return error.OutOfBounds;
        }
        if (y >= self.height) {
            return error.OutOfBounds;
        }

        const i: usize = x + (y * self.width);

        switch (self.pixel_format) {
            .greyscale_1 => {
                const slice = std.PackedIntSliceEndian(std.meta.Int(.unsigned, PixelFormat.getBitsPerPixel(.greyscale_1)), .big).init(self.data, self.width * self.height);

                return slice.get(i);
            },
            .greyscale_2 => {
                const slice = std.PackedIntSliceEndian(std.meta.Int(.unsigned, PixelFormat.getBitsPerPixel(.greyscale_2)), .big).init(self.data, self.width * self.height);

                return slice.get(i);
            },
            .greyscale_4 => {
                const slice = std.PackedIntSliceEndian(std.meta.Int(.unsigned, PixelFormat.getBitsPerPixel(.greyscale_4)), .big).init(self.data, self.width * self.height);

                return slice.get(i);
            },
            .greyscale_8 => {
                const slice = std.PackedIntSliceEndian(std.meta.Int(.unsigned, PixelFormat.getBitsPerPixel(.greyscale_8)), .big).init(self.data, self.width * self.height);

                return slice.get(i);
            },
            .greyscale_16 => {
                const slice = std.PackedIntSliceEndian(std.meta.Int(.unsigned, PixelFormat.getBitsPerPixel(.greyscale_16)), .big).init(self.data, self.width * self.height);

                return slice.get(i);
            },
            .truecolour_8 => {
                const bpp = comptime PixelFormat.getBitsPerPixel(.truecolour_8);
                const Int = comptime std.meta.Int(.unsigned, bpp);

                return std.mem.readPackedInt(Int, self.data, i * bpp, .big);
            },
            .truecolour_16 => {
                const slice = std.PackedIntSliceEndian(std.meta.Int(.unsigned, PixelFormat.getBitsPerPixel(.truecolour_16)), .big).init(self.data, self.width * self.height);

                return slice.get(i);
            },
            .indexed_colour_1 => {
                const slice = std.PackedIntSliceEndian(std.meta.Int(.unsigned, PixelFormat.getBitsPerPixel(.indexed_colour_1)), .big).init(self.data, self.width * self.height);

                return slice.get(i);
            },
            .indexed_colour_2 => {
                const slice = std.PackedIntSliceEndian(std.meta.Int(.unsigned, PixelFormat.getBitsPerPixel(.indexed_colour_2)), .big).init(self.data, self.width * self.height);

                return slice.get(i);
            },
            .indexed_colour_4 => {
                const slice = std.PackedIntSliceEndian(std.meta.Int(.unsigned, PixelFormat.getBitsPerPixel(.indexed_colour_4)), .big).init(self.data, self.width * self.height);

                return slice.get(i);
            },
            .indexed_colour_8 => {
                const slice = std.PackedIntSliceEndian(std.meta.Int(.unsigned, PixelFormat.getBitsPerPixel(.indexed_colour_8)), .big).init(self.data, self.width * self.height);

                return slice.get(i);
            },
            .greyscale_with_alpha_8 => {
                const slice = std.PackedIntSliceEndian(std.meta.Int(.unsigned, PixelFormat.getBitsPerPixel(.greyscale_with_alpha_8)), .big).init(self.data, self.width * self.height);

                return slice.get(i);
            },
            .greyscale_with_alpha_16 => {
                const slice = std.PackedIntSliceEndian(std.meta.Int(.unsigned, PixelFormat.getBitsPerPixel(.greyscale_with_alpha_16)), .big).init(self.data, self.width * self.height);

                return slice.get(i);
            },
            .truecolour_with_alpha_8 => {
                const slice = std.PackedIntSliceEndian(std.meta.Int(.unsigned, PixelFormat.getBitsPerPixel(.truecolour_with_alpha_8)), .big).init(self.data, self.width * self.height);

                return slice.get(i);
            },
            .truecolour_with_alpha_16 => {
                const slice = std.PackedIntSliceEndian(std.meta.Int(.unsigned, PixelFormat.getBitsPerPixel(.truecolour_with_alpha_16)), .big).init(self.data, self.width * self.height);

                return slice.get(i);
            },
        }
    }
};

const signature = [_]u8{ 137, 80, 78, 71, 13, 10, 26, 10 };

pub fn decodeBytes(allocator: std.mem.Allocator, bytes: []const u8) !ImageUnmanaged {
    const stream = std.io.fixedBufferStream(bytes);

    return decodeReader(allocator, stream.reader());
}

pub fn decodeFile(allocator: std.mem.Allocator, file: std.fs.File) !ImageUnmanaged {
    try file.seekTo(0);

    return decodeReader(allocator, file.reader());
}

fn decodeReader(allocator: std.mem.Allocator, file_reader: anytype) !ImageUnmanaged {
    const s = try file_reader.readBoundedBytes(signature.len);

    if (!std.mem.eql(u8, s.slice(), &signature)) {
        return error.InvalidSignature;
    }

    const image_header = try readImageHeaderChunk(file_reader);

    if (image_header.interlace_method != .none) {
        return error.UnsupportedInterlaceMethod;
    }

    var physical_pixel_dimensions: ?PhysicalPixelDimensions = null;
    var standard_rgb_colour_space: ?StandardRgbColourSpace = null;
    var image_gamma: ?ImageGamma = null;
    var significant_bits: ?SignificantBits = null;
    var palette: ?Palette = null;

    var image = try ImageUnmanaged.init(
        allocator,
        image_header.width,
        image_header.height,
        image_header.pixel_format,
    );
    errdefer image.deinit(allocator);

    var reconstructor = ImageReconstructor.init(image);

    var end: bool = false;

    while (!end) {
        const head = try readChunkHeader(file_reader);

        var crc32_chunk = std.hash.Crc32.init();

        crc32_chunk.update(head.type.toRaw());

        const crc32_reader = crc32reader.crc32Reader(file_reader, &crc32_chunk);
        var limited_reader = std.io.limitedReader(crc32_reader, head.length);

        const chunk_reader = limited_reader.reader();

        switch (head.type) {
            .IEND => {
                end = true;
            },
            .pHYs => {
                if (physical_pixel_dimensions != null) {
                    return error.OnlyOnePhysicalPixelDimensionsChunkAllowed;
                }
                physical_pixel_dimensions = try readPhysicalPixelDimensionsChunk(chunk_reader);
            },
            .sRGB => {
                if (standard_rgb_colour_space != null) {
                    return error.OnlyOneStandardRgbColourSpaceChunkAllowed;
                }
                standard_rgb_colour_space = try readStandardRgbColourSpaceChunk(chunk_reader);
            },
            .gAMA => {
                if (image_gamma != null) {
                    return error.OnlyOneImageGammaChunkAllowed;
                }
                image_gamma = try readImageGammaChunk(chunk_reader);
            },
            .sBIT => {
                if (significant_bits != null) {
                    return error.OnlyOneSignificantBitsChunkAllowed;
                }
                significant_bits = try readSignificantBitsChunk(chunk_reader, .{
                    .pixel_format = image_header.pixel_format,
                });
            },
            .IDAT => {
                var decompressor = std.compress.zlib.decompressor(chunk_reader);

                while (try decompressor.next()) |buffer| {
                    try reconstructor.reconstruct(buffer);
                }
            },
            .PLTE => {
                if (palette != null) {
                    return error.OnlyOnePaletteChunkAllowed;
                }
                if (head.length % 3 != 0) {
                    return error.InvalidPaletteSize;
                }
                palette = try readPaletteChunk(chunk_reader, head.length / 3);
            },
            .unknown => |u| {
                std.log.info("ignore unknown chunk: {s} length={}", .{ u, head.length });
                try file_reader.skipBytes(@intCast(head.length), .{});
            },
            else => {
                std.log.err("{s}: unsupported chunk", .{head.type.toRaw()});
                return error.UnsupportedChunk;
            },
        }

        if (limited_reader.bytes_left != 0) {
            std.log.err("{s}: {} unreaded bytes", .{ head.type.toRaw(), limited_reader.bytes_left });
            return error.BytesLeftToRead;
        }

        const given_crc = try file_reader.readInt(u32, .big);
        const expected_crc = crc32_chunk.final();

        if (given_crc != expected_crc) {
            return error.InvalidChunkCrc;
        }
    }

    return image;
}

const Palette = struct {
    const Entry = struct {
        red: u8,
        green: u8,
        blue: u8,
    };
    const Entries = std.BoundedArray(Entry, 256);

    entries: Entries,

    fn init(len: usize) !Palette {
        return .{
            .entries = try Entries.init(len),
        };
    }
};

fn readPaletteChunk(reader: anytype, size: usize) !Palette {
    var palette = try Palette.init(0);

    for (0..size) |_| {
        try palette.entries.append(.{
            .red = try reader.readInt(u8, .big),
            .green = try reader.readInt(u8, .big),
            .blue = try reader.readInt(u8, .big),
        });
    }

    return palette;
}

const SignificantBits = struct {};

const ReadSignificantBitsChunkOptions = struct {
    pixel_format: PixelFormat,
};

fn readSignificantBitsChunk(reader: anytype, options: ReadSignificantBitsChunkOptions) !SignificantBits {
    // TODO: use sBIT / SignificantBits
    try reader.skipBytes(options.pixel_format.getComponents(), .{});

    return .{};
}

const ImageReconstructor = struct {
    const Self = @This();

    image: ImageUnmanaged,

    scanline_index: usize,
    filtered_bytes: usize,
    filter: ?Filter = null,

    fn init(image: ImageUnmanaged) ImageReconstructor {
        return .{
            .image = image,
            .scanline_index = 0,
            .filtered_bytes = 0,
        };
    }

    fn writeFullScanline(self: *Self, filtered_scanline: []const u8) !void {
        const scanline_size = (self.image.width * self.image.pixel_format.getBitsPerPixel() + 7) / 8;
        const pixel_size = (self.image.pixel_format.getBitsPerPixel() + 7) / 8;

        const filter = self.filter orelse {
            return error.NoActiveFilter;
        };

        const reconstructed_scanline = self.image.data[(self.scanline_index * scanline_size)..((self.scanline_index + 1) * scanline_size)];

        if (self.scanline_index == 0) {
            try reconstructFirstScanline(
                filter,
                pixel_size,
                filtered_scanline,
                reconstructed_scanline,
            );
            // std.log.debug("{}: reconstructed", .{self.scanline_index});
        } else {
            const previous_reconstructed_scanline = self.image.data[((self.scanline_index - 1) * scanline_size)..((self.scanline_index) * scanline_size)];

            try reconstructScanline(
                filter,
                pixel_size,
                filtered_scanline,
                previous_reconstructed_scanline,
                reconstructed_scanline,
            );
            // std.log.debug("{}: reconstructed", .{self.scanline_index});
        }

        self.filter = null;
        self.scanline_index += 1;
    }

    fn writePartialScanline(self: *Self, partial_scanline: []const u8) !void {
        const scanline_size = (self.image.width * self.image.pixel_format.getBitsPerPixel() + 7) / 8;

        const start = self.filtered_bytes + (self.scanline_index * scanline_size);
        const end = start + partial_scanline.len;

        @memcpy(self.image.data[start..end], partial_scanline);

        self.filtered_bytes += partial_scanline.len;

        if (self.filtered_bytes == scanline_size) {
            try self.writeFullScanline(self.image.data[(self.scanline_index * scanline_size)..((self.scanline_index + 1) * scanline_size)]);

            self.filtered_bytes = 0;
        }
    }

    pub fn reconstruct(self: *Self, buffer: []const u8) !void {
        // std.log.debug("ImageReconstructor.writeAll(): buffer.len={}", .{buffer.len});

        if (buffer.len == 0) {
            return;
        }

        const scanline_size = (self.image.width * self.image.pixel_format.getBitsPerPixel() + 7) / 8;

        var offset: usize = 0;

        if (self.filtered_bytes != 0) {
            if (self.filtered_bytes + buffer.len < scanline_size) {
                const leftover = buffer[offset..];
                try self.writePartialScanline(leftover);
                offset += leftover.len;
            } else {
                const leftover = buffer[0..(scanline_size - self.filtered_bytes)];

                try self.writePartialScanline(leftover);

                if (self.filtered_bytes != 0) {
                    return error.WTF;
                }

                offset += leftover.len;
            }
        }

        while (offset < buffer.len) {
            if (self.filter == null) {
                self.filter = try Filter.fromRaw(buffer[offset]);
                offset += 1;
            }
            if ((buffer.len - offset) < scanline_size) {
                const leftover = buffer[offset..];
                try self.writePartialScanline(leftover);
                offset += leftover.len;
            } else {
                try self.writeFullScanline(buffer[offset..(offset + scanline_size)]);
                offset += scanline_size;
            }
        }
    }
};

fn reconstructFirstScanline(filter: Filter, pixel_size: usize, in: []const u8, out: []u8) !void {
    switch (filter) {
        // Recon(x) = Filt(x)
        .none => {
            for (0..in.len) |i| {
                out[i] = in[i];
            }
        },
        // Recon(x) = Filt(x) + Recon(a)
        .sub => {
            for (0..pixel_size) |i| {
                out[i] = in[i];
            }
            for (pixel_size..in.len) |i| {
                out[i] = in[i] +% out[i - pixel_size];
            }
        },
        // Recon(x) = Filt(x) + Recon(b)
        .up => {
            for (0..in.len) |i| {
                out[i] = in[i];
            }
        },
        // Recon(x) = Filt(x) + floor((Recon(a) + Recon(b)) / 2)
        .average => {
            for (0..pixel_size) |i| {
                out[i] = in[i];
            }
            for (pixel_size..in.len) |i| {
                out[i] = in[i] +% (out[i - pixel_size] >> 1);
            }
        },
        // Recon(x) = Filt(x) + PaethPredictor(Recon(a), Recon(b), Recon(c))
        .paeth => {
            for (0..pixel_size) |i| {
                out[i] = in[i];
            }
            for (pixel_size..in.len) |i| {
                out[i] = in[i] +% out[i - pixel_size];
            }
        },
    }
}

fn reconstructScanline(filter: Filter, pixel_size: usize, in: []const u8, previous_scanline: []const u8, out: []u8) !void {
    switch (filter) {
        // Recon(x) = Filt(x)
        .none => {
            for (0..in.len) |i| {
                out[i] = in[i];
            }
        },
        // Recon(x) = Filt(x) + Recon(a)
        .sub => {
            for (0..pixel_size) |i| {
                out[i] = in[i];
            }
            for (pixel_size..in.len) |i| {
                out[i] = in[i] +% out[i - pixel_size];
            }
        },
        // Recon(x) = Filt(x) + Recon(b)
        .up => {
            for (0..in.len) |i| {
                out[i] = in[i] +% previous_scanline[i];
            }
        },
        // Recon(x) = Filt(x) + floor((Recon(a) + Recon(b)) / 2)
        .average => {
            for (0..pixel_size) |i| {
                out[i] = in[i];
            }
            for (pixel_size..in.len) |i| {
                const a = out[i - pixel_size];
                const b = previous_scanline[i];

                const z: u32 = a + b;

                out[i] +%= @truncate(z / 2);
            }
        },
        // Recon(x) = Filt(x) + PaethPredictor(Recon(a), Recon(b), Recon(c))
        .paeth => {
            for (0..pixel_size) |i| {
                out[i] = in[i];
            }
            for (pixel_size..in.len) |i| {
                const a = out[i - pixel_size];
                const b = previous_scanline[i];
                const c = previous_scanline[i - pixel_size];

                var pa: i32 = @as(i32, @intCast(b)) - c;
                var pb: i32 = @as(i32, @intCast(a)) - c;
                var pc: i32 = pa + pb;

                if (pa < 0) pa = -pa;
                if (pb < 0) pb = -pb;
                if (pc < 0) pc = -pc;

                out[i] +%= if (pa <= pb and pa <= pc) a else if (pb <= pc) b else c;
            }
        },
    }
}

const Filter = enum {
    none,
    sub,
    up,
    average,
    paeth,

    pub fn fromRaw(v: u8) !Filter {
        return switch (v) {
            0 => .none,
            1 => .sub,
            2 => .up,
            3 => .average,
            4 => .paeth,
            else => error.UnsupportedFilter,
        };
    }
};

const ImageGamma = u32; // The value is encoded as a four-byte PNG unsigned integer, representing gamma times 100000.

fn readImageGammaChunk(reader: anytype) !ImageGamma {
    return try reader.readInt(ImageGamma, .big);
}

const StandardRgbColourSpace = enum {
    perceptual,
    relative_colorimetric,
    saturation,
    absolute_colorimetric,

    fn fromRaw(r: u8) !StandardRgbColourSpace {
        return switch (r) {
            0 => .perceptual,
            1 => .relative_colorimetric,
            2 => .saturation,
            3 => .absolute_colorimetric,
            else => return error.UnsupportedStandardRgbColourSpace,
        };
    }
};

fn readStandardRgbColourSpaceChunk(reader: anytype) !StandardRgbColourSpace {
    return try StandardRgbColourSpace.fromRaw(try reader.readByte());
}

const PhysicalPixelDimensions = struct {
    const Unit = enum {
        unknown,
        metre,

        fn fromRaw(r: u8) !Unit {
            return switch (r) {
                0 => .unknown,
                1 => .metre,
                else => return error.UnsupportedUnit,
            };
        }
    };

    pixel_per_unit_x: u32,
    pixel_per_unit_y: u32,
    unit: Unit,
};

fn readPhysicalPixelDimensionsChunk(reader: anytype) !PhysicalPixelDimensions {
    return .{
        .pixel_per_unit_x = try reader.readInt(u32, .big),
        .pixel_per_unit_y = try reader.readInt(u32, .big),
        .unit = try PhysicalPixelDimensions.Unit.fromRaw(try reader.readInt(u8, .big)),
    };
}

const Metadata = ImageHeader;

pub fn readMetadataFromBytes(bytes: []const u8) !Metadata {
    if (bytes.len == 0) {
        return error.Empty;
    }
    if (bytes.len < 33) {
        return error.TooSmall;
    }

    const stream = std.io.fixedBufferStream(bytes);

    return readMetadataFromReader(stream.reader());
}

pub fn readMetadataFromFile(file: std.fs.File) !Metadata {
    const end = try file.getEndPos();
    try file.seekTo(0);

    if (end == 0) {
        return error.Empty;
    }
    if (end < 33) {
        return error.TooSmall;
    }

    return readMetadataFromReader(file.reader());
}

fn readMetadataFromReader(reader: anytype) !Metadata {
    const s = try reader.readBoundedBytes(signature.len);

    if (!std.mem.eql(u8, s.slice(), &signature)) {
        return error.InvalidSignature;
    }

    return try readImageHeaderChunk(reader);
}

const ChunkType = union(enum) {
    unknown: ChunkTypeRaw,

    IHDR,
    IEND,
    pHYs,
    sRGB,
    gAMA,
    IDAT,
    sBIT,
    PLTE,

    pub fn toRaw(self: ChunkType) *const ChunkTypeRaw {
        return switch (self) {
            .IHDR => "IHDR",
            .IEND => "IEND",
            .pHYs => "pHYs",
            .sRGB => "sRGB",
            .gAMA => "gAMA",
            .IDAT => "IDAT",
            .sBIT => "sBIT",
            .PLTE => "PLTE",
            .unknown => |u| &u,
        };
    }

    pub fn fromRaw(raw: *const ChunkTypeRaw) !ChunkType {
        const i = std.mem.readInt(u32, raw, .big);

        return switch (i) {
            std.mem.readInt(u32, "IHDR", .big) => .IHDR,
            std.mem.readInt(u32, "IEND", .big) => .IEND,
            std.mem.readInt(u32, "pHYs", .big) => .pHYs,
            std.mem.readInt(u32, "sRGB", .big) => .sRGB,
            std.mem.readInt(u32, "gAMA", .big) => .gAMA,
            std.mem.readInt(u32, "IDAT", .big) => .IDAT,
            std.mem.readInt(u32, "sBIT", .big) => .sBIT,
            std.mem.readInt(u32, "PLTE", .big) => .PLTE,
            else => .{ .unknown = raw.* },
        };
    }
};

const ChunkHeader = struct {
    type: ChunkType,
    length: u32,
};

const ChunkTypeRaw = [4]u8;

fn readChunkHeader(reader: anytype) !ChunkHeader {
    const length = try reader.readInt(u32, .big);
    var type_raw: ChunkTypeRaw = .{
        try reader.readByte(),
        try reader.readByte(),
        try reader.readByte(),
        try reader.readByte(),
    };

    const t = try ChunkType.fromRaw(&type_raw);

    return .{
        .type = t,
        .length = length,
    };
}

const ImageHeader = struct {
    width: u32,
    height: u32,
    pixel_format: PixelFormat,
    interlace_method: InterlaceMethod,
};

fn readImageHeaderChunk(reader: anytype) !ImageHeader {
    const head = try readChunkHeader(reader);

    if (head.type != .IHDR) {
        return error.InvalidFormat;
    }
    if (head.length != 13) {
        return error.InvalidFormat;
    }

    const width = try reader.readInt(u32, .big);
    const height = try reader.readInt(u32, .big);
    const bit_depth = try reader.readInt(u8, .big);
    const colour_type = try reader.readInt(u8, .big);
    const compression_method = try reader.readInt(u8, .big);
    const filter_method = try reader.readInt(u8, .big);
    const interlace_method_raw = try reader.readInt(u8, .big);

    const crc = try reader.readInt(u32, .big);
    _ = crc; // TODO

    if (width == 0) {
        return error.InvalidWidth;
    }
    if (height == 0) {
        return error.InvalidWidth;
    }

    if (compression_method != 0) {
        return error.InvalidCompressionMethod;
    }

    if (filter_method != 0) {
        return error.InvalidFilterMethod;
    }

    const pixel_format = try PixelFormat.fromRaw(colour_type, bit_depth);
    const interlace_method = try InterlaceMethod.fromRaw(interlace_method_raw);

    return .{
        .width = width,
        .height = height,
        .pixel_format = pixel_format,
        .interlace_method = interlace_method,
    };
}

const InterlaceMethod = enum {
    none,
    adam7,

    fn fromRaw(raw: u8) !InterlaceMethod {
        return switch (raw) {
            0 => .none,
            1 => .adam7,
            else => error.InvalidInterlaceMethod,
        };
    }
};

const ColorType = enum {
    greyscale,
    truecolour,
    indexed_colour,
    greyscale_with_alpha,
    truecolour_with_alpha,

    fn fromRaw(raw: u8) !ColorType {
        return switch (raw) {
            0 => .greyscale,
            2 => .truecolour,
            3 => .indexed_colour,
            4 => .greyscale_with_alpha,
            6 => .truecolour_with_alpha,
            else => error.InvalidColorType,
        };
    }
};

const PixelFormat = enum {
    greyscale_1,
    greyscale_2,
    greyscale_4,
    greyscale_8,
    greyscale_16,
    truecolour_8,
    truecolour_16,
    indexed_colour_1,
    indexed_colour_2,
    indexed_colour_4,
    indexed_colour_8,
    greyscale_with_alpha_8,
    greyscale_with_alpha_16,
    truecolour_with_alpha_8,
    truecolour_with_alpha_16,

    // NOTE: used for filter
    pub fn getPixelSize(self: PixelFormat) usize {
        return (self.getBitsPerPixel() + 7) / 8;
    }

    pub fn getComponents(self: PixelFormat) u8 {
        return switch (self) {
            .greyscale_1 => 1,
            .greyscale_2 => 1,
            .greyscale_4 => 1,
            .greyscale_8 => 1,
            .greyscale_16 => 1,
            .truecolour_8 => 3,
            .truecolour_16 => 3,
            .indexed_colour_1 => 3,
            .indexed_colour_2 => 3,
            .indexed_colour_4 => 3,
            .indexed_colour_8 => 3,
            .greyscale_with_alpha_8 => 2,
            .greyscale_with_alpha_16 => 2,
            .truecolour_with_alpha_8 => 4,
            .truecolour_with_alpha_16 => 4,
        };
    }

    pub fn getBitsPerPixel(self: PixelFormat) usize {
        return switch (self) {
            .greyscale_1 => 1,
            .greyscale_2 => 2,
            .greyscale_4 => 4,
            .greyscale_8 => 8,
            .greyscale_16 => 16,
            .truecolour_8 => 3 * 8,
            .truecolour_16 => 3 * 16,
            .indexed_colour_1 => 1,
            .indexed_colour_2 => 2,
            .indexed_colour_4 => 4,
            .indexed_colour_8 => 8,
            .greyscale_with_alpha_8 => 2 * 8,
            .greyscale_with_alpha_16 => 2 * 16,
            .truecolour_with_alpha_8 => 4 * 8,
            .truecolour_with_alpha_16 => 4 * 16,
        };
    }

    pub fn fromRaw(color_type: u8, bit_depth: u8) !PixelFormat {
        const c = try ColorType.fromRaw(color_type);
        return switch (c) {
            .greyscale => switch (bit_depth) {
                1 => .greyscale_1,
                2 => .greyscale_2,
                4 => .greyscale_4,
                8 => .greyscale_8,
                16 => .greyscale_16,
                else => error.InvalidPixelFormat,
            },
            .truecolour => switch (bit_depth) {
                8 => .truecolour_8,
                16 => .truecolour_16,
                else => error.InvalidPixelFormat,
            },
            .indexed_colour => switch (bit_depth) {
                1 => .indexed_colour_1,
                2 => .indexed_colour_2,
                4 => .indexed_colour_4,
                8 => .indexed_colour_8,
                else => error.InvalidPixelFormat,
            },
            .greyscale_with_alpha => switch (bit_depth) {
                8 => .greyscale_with_alpha_8,
                16 => .greyscale_with_alpha_16,
                else => error.InvalidPixelFormat,
            },
            .truecolour_with_alpha => switch (bit_depth) {
                8 => .truecolour_with_alpha_8,
                16 => .truecolour_with_alpha_16,
                else => error.InvalidPixelFormat,
            },
        };
    }
};
