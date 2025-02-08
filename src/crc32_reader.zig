const std = @import("std");
const io = std.io;
const testing = std.testing;

pub fn Crc32Reader(comptime ReaderType: anytype) type {
    return struct {
        child_reader: ReaderType,
        crc: *std.hash.Crc32,

        pub const Error = ReaderType.Error;
        pub const Reader = io.Reader(*@This(), Error, read);

        pub fn read(self: *@This(), buf: []u8) Error!usize {
            const amt = try self.child_reader.read(buf);

            self.crc.update(buf);

            return amt;
        }

        pub fn reader(self: *@This()) Reader {
            return .{ .context = self };
        }
    };
}

pub fn crc32Reader(reader: anytype, crc: *std.hash.Crc32) Crc32Reader(@TypeOf(reader)) {
    return .{
        .child_reader = reader,
        .crc = crc,
    };
}
