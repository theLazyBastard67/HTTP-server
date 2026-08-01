const std = @import("std");
const builtins = @import("builtin");
const formatting = @import("formatting.zig");
const parser = @import("httpParser.zig");

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [4096]u8 = undefined;
    var stdin_buffer: [4096]u8 = undefined;

    var stdout_inst = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    var stdout_printer = &stdout_inst.interface;

    var stdin_inst = std.Io.File.stdin().reader(init.io, &stdin_buffer);
    var stdin_reader = &stdin_inst.interface;

    try stdout_printer.print("A simple TCP server written in Zig {d}.{d}.{d}.\n\n", .{ builtins.zig_version.major, builtins.zig_version.minor, builtins.zig_version.patch });
    try stdout_printer.print("Enter the server port: ", .{});
    try stdout_inst.flush();

    const raw_port_number: ?[]u8 = try stdin_reader.takeDelimiterExclusive('\n');
    stdin_reader.toss(1);
    var port_number: u16 = undefined;

    if (raw_port_number) |checked_port_number| {
        port_number = try std.fmt.parseInt(u16, std.mem.trim(u8, checked_port_number, " "), 10);
    }

    try stdout_printer.print("Enter the address: ", .{});
    try stdout_inst.flush();

    const address: ?[]u8 = try stdin_reader.takeDelimiterExclusive('\n');
    stdin_reader.toss(1);

    if (address) |checked_address| {
        if (std.mem.eql(u8, "localhost", checked_address)) {
            try server(init.io, stdout_printer, port_number, "127.0.0.1");
        } else if (checked_address.len == 0) {
            try stdout_printer.print("{s}No address read from stdin, defaulting to localhost.{s}\n", .{ formatting.Color.bold_bright_yellow, formatting.Color.reset });
            try stdout_inst.flush();
            try server(init.io, stdout_printer, port_number, "127.0.0.1");
        } else try server(init.io, stdout_printer, port_number, checked_address);
    }
}

fn handleAcceptedConnections(server_stream: std.Io.net.Stream, io: std.Io, stdout_writer_interface: *std.Io.Writer) !void {
    defer server_stream.close(io);

    var server_read_buffer: [4096]u8 = undefined;
    var server_write_buffer: [4096]u8 = undefined;

    var stream_writer_inst = server_stream.writer(io, &server_write_buffer);
    const server_writer = &stream_writer_inst.interface;

    var stream_reader_inst = server_stream.reader(io, &server_read_buffer);
    const server_reader = &stream_reader_inst.interface;

    var parseResult: parser.httpRequestParsedStruct = .{};
    var responseHandler: ResponseHandler = .{};

    while (true) {
        var read_data_slice = server_reader.buffered();

        while (std.mem.containsAtLeast(u8, read_data_slice, 1, "\r\n\r\n")) {
            parseResult = .{};
            const request_body_start = std.mem.find(u8, read_data_slice, "\r\n\r\n").? + 4;

            parseResult.parseHttpRequestHeader(read_data_slice[0 .. request_body_start - 4]) catch |err| {
                try stdout_writer_interface.print("{s}\n{any}\n\nMalformed request, closing connection.\n{s}", .{ formatting.Color.bold_bright_red, err, formatting.Color
                    .reset });
                try stdout_writer_interface.flush();

                responseHandler.init(400, "Bad Request", "text/plain", "close", "");

                return;
            };

            if (std.mem.eql(u8, parseResult.method, "POST")) {
                const body_recieved = read_data_slice.len - request_body_start;

                if (body_recieved < parseResult.content_length) {
                    server_reader.fill(request_body_start + parseResult.content_length) catch return;
                    read_data_slice = server_reader.buffered();
                }
                parseResult.request_body = read_data_slice[request_body_start .. request_body_start + parseResult.content_length];
            }

            responseHandler.respond(parseResult, io, server_writer) catch |err|
                {
                    try stdout_writer_interface.print("{s}\n{any}\n{s}", .{ formatting.Color.bold_bright_red, err, formatting.Color
                        .reset });
                    try stdout_writer_interface.flush();
                };
            if (std.mem.eql(u8, parseResult.connection, "close")) return;
            // const request_body_end = request_body_start + parseResult.content_length;

            server_reader.toss(request_body_start + parseResult.content_length);
            read_data_slice = server_reader.buffered();
        }

        server_reader.fillMore() catch return;
    }
}

fn server(io: std.Io, stdout_writer_interface: *std.Io.Writer, server_port: u16, server_address: []const u8) !void {
    const IpAddress = std.Io.net.IpAddress;
    const server_address_parsed = try IpAddress.parse(server_address, server_port);

    var server_inst = try IpAddress.listen(&server_address_parsed, io, .{});
    defer server_inst.deinit(io);

    try stdout_writer_interface.print("{s}\n\nThe server started listening on {s}:{d}.{s}\n\n", .{ formatting.Color.bold_bright_green, server_address, server_port, formatting.Color.reset });
    try stdout_writer_interface.flush();

    while (true) {
        const server_stream = try server_inst.accept(io);
        const thread = try std.Thread.spawn(.{}, handleAcceptedConnections, .{ server_stream, io, stdout_writer_interface });
        thread.detach();
    }
}

const ResponseHandler = struct {
    status_code: u16 = 0,
    reason_phrase: []const u8 = "",
    content_type: []const u8 = "",
    connection: []const u8 = "",
    body: []const u8 = "",

    pub fn init(s: *ResponseHandler, status_code: u16, reason_phrase: []const u8, content_type: []const u8, connection: []const u8, body: []const u8) void {
        s.status_code = status_code;
        s.reason_phrase = reason_phrase;
        s.content_type = content_type;
        s.connection = connection;
        s.body = body;
    }

    pub fn serializeAndPrint(s: *ResponseHandler, server_writer: *std.Io.Writer, fileLength: u64) !void {
        try server_writer.print("HTTP/1.1 {d} {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nConnection: {s}\r\n\r\n{s}", .{ s.status_code, s.reason_phrase, s.content_type, fileLength, s.connection, s.body });
        try server_writer.flush();
    }

    pub fn respond(s: *ResponseHandler, parsedStruct: parser.httpRequestParsedStruct, io: std.Io, server_writer: *std.Io.Writer) !void {
        if (std.mem.eql(u8, parsedStruct.method, "GET") or std.mem.eql(u8, parsedStruct.method, "POST")) {
            const responseFile = std.Io.Dir.cwd().openFile(io, parsedStruct.filePath[1..], .{}) catch |err| {
                std.debug.print("File not found for: {s}", .{parsedStruct.filePath});
                s.status_code = 404;
                s.reason_phrase = "Not Found";
                s.content_type = "image/jpg";
                s.connection = s.connection;

                try s.serializeAndPrint(server_writer, 13);
                return err;
            };
            defer responseFile.close(io);

            const fileBuffer = try std.heap.smp_allocator.alloc(u8, try responseFile.length(io));
            defer std.heap.smp_allocator.free(fileBuffer);

            var file_reader_inst = responseFile.reader(io, fileBuffer);
            const file_reader = &file_reader_inst.interface;

            s.status_code = 200;
            s.reason_phrase = "OK";
            s.content_type = "image/jpg";
            s.connection = s.connection;

            try s.serializeAndPrint(server_writer, try responseFile.length(io));

            _ = try file_reader.streamRemaining(server_writer);
            try server_writer.flush();
        } else return error.InvalidMethod;
    }
};
