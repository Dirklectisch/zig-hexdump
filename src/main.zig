const std = @import("std");

const Options = struct {
    path: ?[]const u8,
    printASCII: bool,
};

var options: Options = undefined;

pub fn parseArgs() void {
    options = Options{
        .path = null,
        .printASCII = false,
    };

    for (std.os.argv, 0..) |arg, idx| {
        const argAsSlice = std.mem.span(arg);

        if (std.mem.eql(u8, argAsSlice, "-C")) {
            options.printASCII = true;
        } else if (idx == 1) {
            options.path = argAsSlice;
        }
    }
}

pub fn hexdump(reader: anytype) !void {
    var stdout = std.io.getStdOut();
    var buffer = std.io.bufferedWriter(stdout.writer());
    var writer = buffer.writer();

    var byte = reader.readByte();
    var total_bytes_on_line: u8 = 0;
    var bytes_on_line: [16]u8 = undefined;
    var total_bytes_printed: u64 = 0x0000000;

    while (byte != error.EndOfStream) : (byte = reader.readByte()) {
        if (total_bytes_on_line == 0) {
            try writer.print("{X:0>7} ", .{total_bytes_printed});
        }

        const current_byte: u8 = try byte;
        try writer.print("{X:0>2} ", .{current_byte});
        bytes_on_line[total_bytes_on_line] = current_byte;
        total_bytes_on_line += 1;
        total_bytes_printed += 1;

        // TODO: Fix showing ASCII on shorter lines
        if (total_bytes_on_line == 16) {
            if(options.printASCII == true) {
                // TODO: escape newlines
                try writer.print("|{s}|", .{bytes_on_line});
            }

            try writer.print("\n", .{});
            total_bytes_on_line = 0;
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
