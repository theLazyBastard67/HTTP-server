const std = @import("std");
const builtins = @import("builtin");

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [4000]u8 = undefined;
    var stdin_buffer: [4000]u8 = undefined;

    var stdout_inst = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    var stdout_printer = &stdout_inst.interface;

    var stdin_inst = std.Io.File.stdin().reader(init.io, &stdin_buffer);
    var stdin_reader = &stdin_inst.interface;

    try stdout_printer.print("A simple TCP server written in Zig {d}.{d}.{d}.\n\n", .{ builtins.zig_version.major, builtins.zig_version.minor, builtins.zig_version.patch });
    try stdout_printer.print("Enter the server port: ", .{});
    try stdout_inst.flush();

    const raw_port_number: ?[]u8 = try stdin_reader.takeDelimiterExclusive('\n');

    if (raw_port_number) |checked_port_number| {
        const port_number = try std.fmt.parseInt(u16, checked_port_number, 10);
        try server(init.io, stdout_printer, port_number);
    }
}

const httpRequestParsedStruct = struct { method: []const u8 = " ", filePath: []const u8 = " ", httpVersion: []const u8 = " ", host: []const u8 = " ", userAgent: []const u8 = " ", accept: []const u8 = " ", connection: []const u8 = " " };

pub fn parseHttpRequests(inputBuffer: []u8) !httpRequestParsedStruct {
    const trim = std.mem.trim;

    var tokenizer = std.mem.tokenizeAny(u8, inputBuffer, " \r\n");
    const parseResult: httpRequestParsedStruct = .{ .method = tokenizer.next() orelse return error.InvalidRequest, .filePath = tokenizer.next() orelse return error.InvalidRequest, .httpVersion = tokenizer.next() orelse return error.InvalidRequest, .host = trim(u8, tokenizer.next() orelse return error.InvalidRequest, "Host:") };
    return parseResult;
}

fn handleAcceptedConnections(server_stream: std.Io.net.Stream, io: std.Io) !void {
    defer server_stream.close(io);

    var server_read_buffer: [4000]u8 = undefined;
    var server_client_response_buffer: [1][]u8 = .{server_read_buffer[0..]};
    var server_write_buffer: [4000]u8 = undefined;

    var stream_writer_inst = server_stream.writer(io, &server_write_buffer);
    const server_writer = &stream_writer_inst.interface;

    var stream_reader_inst = server_stream.reader(io, &server_read_buffer);
    const server_reader = &stream_reader_inst.interface;

    while (true) {
        const client_input_size = server_reader.readVec(&server_client_response_buffer) catch {
            break;
        };

        if (client_input_size > 0) {
            std.debug.print("\n{any}\n", .{try parseHttpRequests(server_read_buffer[0..client_input_size])});
            try server_writer.print("{s}", .{server_read_buffer[0..client_input_size]});
            try server_writer.flush();
        }
    }
}

fn server(io: std.Io, stdout_writer_interface: *std.Io.Writer, server_port: u16) !void {
    const server_address = "127.0.0.1";

    const IpAddress = std.Io.net.IpAddress;
    const server_address_parsed = try IpAddress.parse(server_address, server_port);

    var server_inst = try IpAddress.listen(&server_address_parsed, io, .{});
    defer server_inst.deinit(io);

    try stdout_writer_interface.print("The server started listening on {s}:{d}. \n\n", .{ server_address, server_port });
    try stdout_writer_interface.flush();

    while (true) {
        const server_stream = try server_inst.accept(io);
        _ = try std.Thread.spawn(.{}, handleAcceptedConnections, .{ server_stream, io });
    }
}
