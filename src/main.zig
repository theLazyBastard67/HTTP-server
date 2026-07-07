const std = @import("std");
const builtins = @import("builtin");

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [4000]u8 = undefined;

    var stdout_inst = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    var stdout_printer = &stdout_inst.interface;

    try stdout_printer.print("A simple TCP server written in Zig {d}.{d}.{d}.\n\n", .{ builtins.zig_version.major, builtins.zig_version.minor, builtins.zig_version.patch });
    try stdout_inst.flush();

    try server(init.io, stdout_printer);
}

fn handleAcceptedConnections(server_stream: std.Io.net.Stream, io: std.Io) !void {
    defer server_stream.close(io);

    while (true) {
        var server_read_buffer: [4000]u8 = undefined;
        var server_client_response_buffer: [1][]u8 = .{server_read_buffer[0..]};
        var server_write_buffer: [4000]u8 = undefined;

        var stream_reader_inst = server_stream.reader(io, &server_read_buffer);
        const server_reader = &stream_reader_inst.interface;
        const client_input_size = server_reader.readVec(&server_client_response_buffer) catch {
            break;
        };

        var stream_writer_inst = server_stream.writer(io, &server_write_buffer);
        const server_writer = &stream_writer_inst.interface;

        if (client_input_size > 0) {
            try server_writer.print("{s}", .{server_read_buffer[0..client_input_size]});
            try server_writer.flush();
        }
    }
}

fn server(io: std.Io, stdout_writer_interface: *std.Io.Writer) !void {
    const server_address = "127.0.0.1";
    const server_port = 8080;

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
