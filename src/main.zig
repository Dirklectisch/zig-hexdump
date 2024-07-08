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

    const max_line_length = 16;
    var total_bytes_on_line: u8 = 0;
    var total_bytes_printed: u64 = 0x0000000;
    var bytes_on_line: [max_line_length]u8 = undefined;
    var bytes_on_last_line: [max_line_length]u8 = undefined;
    var endOfStream = false;

    while (true) {

        for (0..max_line_length) |i| {
            const byte: u8 = reader.readByte() catch {
                endOfStream = true;
                break;
            };

            bytes_on_line[i] = byte;
            total_bytes_on_line += 1;
        }

        const startOfFile = total_bytes_printed > 0;
        if (startOfFile) {
            const sameAsLastLine = std.mem.eql(u8, bytes_on_line[0..], bytes_on_last_line[0..]);
            if(sameAsLastLine) {
                try writer.print("*\n", .{});
                total_bytes_printed += total_bytes_on_line;
                total_bytes_on_line = 0;
                continue;
            }
        }

        try writer.print("{X:0>7} ", .{total_bytes_printed});

        for (0..total_bytes_on_line) |i| {
            try writer.print("{X:0>2} ", .{bytes_on_line[i]});
        }

        if(endOfStream) {
            const padding_length = (max_line_length - total_bytes_on_line) * 3;
            for (0..padding_length) |_| {
                try writer.print(" ", .{});
            }
        }


        if(options.printASCII == true) {
            var replacement_buffer: [max_line_length]u8 = undefined;
            _ = std.mem.replace(u8, &bytes_on_line, "\n", ".", &replacement_buffer);
            try writer.print("|{s}|", .{replacement_buffer[0..total_bytes_on_line]});
        }

        try writer.print("\n", .{});

        if(endOfStream) {
            break;
        }

        @memcpy(bytes_on_last_line[0..], bytes_on_line[0..]);

        total_bytes_printed += total_bytes_on_line;
        total_bytes_on_line = 0;
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
