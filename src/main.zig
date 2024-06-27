const std = @import("std");

pub fn hexdump(reader: anytype) !void {
    var stdout = std.io.getStdOut();
    var buffer = std.io.bufferedWriter(stdout.writer());
    var writer = buffer.writer();

    var byte = reader.readByte();
    var bytes_on_line: u8 = 0;

    while (byte != error.EndOfStream) : (byte = reader.readByte()) {
        try writer.print("{X:0>2} ", .{try byte});
        bytes_on_line += 1;

        if (bytes_on_line == 16) {
            try writer.print("\n", .{});
            bytes_on_line = 0;
        }
    }

    try buffer.flush();
}

const Arguments = struct {
    path: []const u8,
};

const ArgumentError = error{
    MissingPath,
};

pub fn parseArgs() ArgumentError!Arguments {
    var parsedArguments: Arguments = undefined;
    const length: usize = std.os.argv.len;
    if (length < 2) {
        return ArgumentError.MissingPath;
    }

    for (std.os.argv, 0..) |arg, idx| {
        if (idx == 1) {
            parsedArguments = Arguments{
                .path = std.mem.span(arg),
            };
        }
    }

    return parsedArguments;
}

pub fn main() u8 {
    const args: Arguments = parseArgs() catch |err| {
        std.log.err("{!}: Invalid command line arguments", .{err});
        return 1;
    };

    const file = std.fs.cwd().openFile(args.path, .{ .mode = .read_only }) catch |err| {
        std.log.err("{!}: Opening file at path {s} failed", .{ err, args.path });
        return 1;
    };
    defer file.close();

    var buffer = std.io.bufferedReader(file.reader());
    hexdump(buffer.reader()) catch |err| {
        std.log.err("{!}: Printing output failed", .{err});
        return 1;
    };

    return 0;
}
