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

    const max_line_length = 16;
    var total_bytes_on_line: u8 = 0;
    var total_bytes_printed: u64 = 0x0000000;
    var bytes_on_line: [max_line_length]u8 = undefined;

    while (true) : (byte = reader.readByte()) {

        const endOfLine = total_bytes_on_line == max_line_length;
        const endOfStream = byte == error.EndOfStream;
        if(endOfStream) {
            const padding_length = (max_line_length - total_bytes_on_line) * 3;
            for (0..padding_length) |_| {
                try writer.print(" ", .{});
            }
        }

        if(endOfStream or endOfLine) {
            if(options.printASCII == true) {
                var replacement_buffer: [max_line_length]u8 = undefined;
                _ = std.mem.replace(u8, &bytes_on_line, "\n", ".", &replacement_buffer);
                try writer.print("|{s}|", .{replacement_buffer[0..total_bytes_on_line]});
            }

            try writer.print("\n", .{});
            total_bytes_on_line = 0;
        }

        if(endOfStream) {
            break;
        }

        const startOfLine = total_bytes_on_line == 0;
        if (startOfLine) {
            try writer.print("{X:0>7} ", .{total_bytes_printed});
        }

        const current_byte: u8 = try byte;
        try writer.print("{X:0>2} ", .{current_byte});
        bytes_on_line[total_bytes_on_line] = current_byte;
        total_bytes_on_line += 1;
        total_bytes_printed += 1;
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
