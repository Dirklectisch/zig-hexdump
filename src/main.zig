const std = @import("std");

const Options = struct {
    path: ?[]const u8,
};

var options: Options = undefined;

pub fn parseArgs() void {
    options = Options{
        .path = null,
    };

    for (std.os.argv, 0..) |arg, idx| {
        if (idx == 1) {
            options.path = std.mem.span(arg);
        }
    }
}

pub fn hexdump(reader: anytype) !void {
    var stdout = std.io.getStdOut();
    var buffer = std.io.bufferedWriter(stdout.writer());
    var writer = buffer.writer();

    var byte = reader.readByte();
    var bytes_on_line: u8 = 0;
    var total_bytes_printed: u64 = 0x0000000;

    while (byte != error.EndOfStream) : (byte = reader.readByte()) {
        if (bytes_on_line == 0) {
            try writer.print("{X:0>7} ", .{total_bytes_printed});
        }

        try writer.print("{X:0>2} ", .{try byte});
        bytes_on_line += 1;
        total_bytes_printed += 1;

        if (bytes_on_line == 16) {
            try writer.print("\n", .{});
            bytes_on_line = 0;
        }
    }

    try writer.print("\n", .{});
    try buffer.flush();
}

pub fn main() u8 {
    parseArgs();

    if (options.path != null) {
        const path: []const u8 = options.path orelse "";

        const file = std.fs.cwd().openFile(path, .{ .mode = .read_only }) catch |err| {
            std.log.err("{!}: Opening file at path {s} failed", .{ err, path });
            return 1;
        };
        defer file.close();

        var buffer = std.io.bufferedReader(file.reader());

        hexdump(buffer.reader()) catch |err| {
            std.log.err("{!}: Printing output failed", .{err});
            return 1;
        };
    } else {
        var stdin = std.io.getStdIn();
        hexdump(stdin.reader()) catch |err| {
            std.log.err("{!}: Printing output failed", .{err});
            return 1;
        };
    }

    return 0;
}
