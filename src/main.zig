const std = @import("std");
const builtins = @import("builtin");

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
        port_number = try std.fmt.parseInt(u16, checked_port_number, 10);
    }

    try stdout_printer.print("Enter the address: ", .{});
    try stdout_inst.flush();

    const address: ?[]u8 = try stdin_reader.takeDelimiterExclusive('\n');
    stdin_reader.toss(1);
    if (address) |checked_address| {
        if (std.mem.eql(u8, "localhost", checked_address)) {
            try server(init.io, stdout_printer, port_number, "127.0.0.1");
        } else if (checked_address.len == 0) {
            try stdout_printer.print("No address read from stdin, defaulting to localhost. \n", .{});
            try stdout_inst.flush();
            try server(init.io, stdout_printer, port_number, "127.0.0.1");
        } else try server(init.io, stdout_printer, port_number, checked_address);
    }
}

const httpRequestParsedStruct = struct { method: []const u8 = "", filePath: []const u8 = "", httpVersion: []const u8 = "", host: []const u8 = "", userAgent: []const u8 = "", accept: []const u8 = "", connection: []const u8 = "", content_length: usize = 0, request_body: []const u8 = "" };

pub fn parseHttpRequestHeader(inputBuffer: []u8) !httpRequestParsedStruct {
    const trim = std.mem.trim;

    var colon: usize = undefined;
    var fieldName: []const u8 = undefined;
    var fieldValue: []const u8 = undefined;
    var parseResult: httpRequestParsedStruct = .{};

    var tokenizer = std.mem.tokenizeAny(u8, inputBuffer, "\r\n");

    if (tokenizer.next()) |request_line| {
        var tokenizeRequestLine = std.mem.tokenizeScalar(u8, request_line, ' ');

        parseResult.method = tokenizeRequestLine.next() orelse return error.InvalidRequest;
        parseResult.filePath = tokenizeRequestLine.next() orelse return error.InvalidRequest;
        parseResult.httpVersion = tokenizeRequestLine.next() orelse return error.InvalidRequest;
    } else return error.InvalidRequest;

    while (tokenizer.next()) |next_header_token| {
        const trimmedTokenValue = trim(u8, next_header_token, " ");
        std.debug.print("TOKEN: '{s}'\n", .{next_header_token});

        colon = std.mem.find(u8, trimmedTokenValue, ":") orelse return error.InvalidRequest;

        fieldName = trim(u8, trimmedTokenValue[0..colon], " ");
        fieldValue = trim(u8, trimmedTokenValue[colon + 1 .. trimmedTokenValue.len], " ");

        if (std.mem.eql(u8, fieldName, "Host")) {
            parseResult.host = fieldValue;
        }
        if (std.mem.eql(u8, fieldName, "Content-Length")) {
            parseResult.content_length = try std.fmt.parseInt(usize, fieldValue, 10);
        }
    }
    return parseResult;
}

fn handleAcceptedConnections(server_stream: std.Io.net.Stream, io: std.Io, stdout_writer_interface: *std.Io.Writer) !void {
    defer server_stream.close(io);

    var server_read_buffer: [4096]u8 = undefined;
    var server_write_buffer: [4096]u8 = undefined;

    var stream_writer_inst = server_stream.writer(io, &server_write_buffer);
    const server_writer = &stream_writer_inst.interface;

    var stream_reader_inst = server_stream.reader(io, &server_read_buffer);
    const server_reader = &stream_reader_inst.interface;
    var client_input_size: usize = 0;

    var parseResult: httpRequestParsedStruct = undefined;
    var server_client_response_buffer: [1][]u8 = .{server_read_buffer[client_input_size..]};

    while (true) {
        server_client_response_buffer = .{server_read_buffer[client_input_size..]};
        client_input_size += server_reader.readVec(&server_client_response_buffer) catch {
            break;
        };

        if (std.mem.containsAtLeast(u8, server_read_buffer[0..client_input_size], 1, "\r\n\r\n")) {
            const request_body_start = std.mem.find(u8, server_read_buffer[0..client_input_size], "\r\n\r\n").? + 4;
            parseResult = parseHttpRequestHeader(server_read_buffer[0 .. request_body_start - 4]) catch |err| {
                try stdout_writer_interface.print("\ndfhdhfhdf{any}\n", .{err});
                try stdout_writer_interface.flush();
                continue;
            };
            if (std.mem.eql(u8, parseResult.method, "POST")) {
                var body_recieved = client_input_size - request_body_start;
                while (body_recieved < parseResult.content_length) {
                    server_client_response_buffer = .{server_read_buffer[client_input_size..]};
                    const num_of_bytes_recieved = server_reader.readVec(&server_client_response_buffer) catch {
                        break;
                    };
                    body_recieved += num_of_bytes_recieved;
                    client_input_size += num_of_bytes_recieved;
                }
                parseResult.request_body = server_read_buffer[request_body_start .. request_body_start + parseResult.content_length];
            }
            std.debug.print("{s} \n", .{parseResult.method});
            std.debug.print("{s} \n", .{parseResult.filePath});
            std.debug.print("{s} \n", .{parseResult.httpVersion});
            std.debug.print("{s} \n", .{parseResult.host});
            std.debug.print("{s} \n", .{parseResult.request_body});

            try server_writer.print("{s}", .{server_read_buffer[0..client_input_size]});
            try server_writer.flush();

            const request_body_end = request_body_start + parseResult.content_length;

            if (request_body_end != client_input_size) {
                std.mem.copyForwards(u8, server_read_buffer[0..], server_read_buffer[request_body_end..client_input_size]);
            }

            client_input_size = client_input_size - request_body_end;
        }
    }
}

fn server(io: std.Io, stdout_writer_interface: *std.Io.Writer, server_port: u16, server_address: []const u8) !void {
    const IpAddress = std.Io.net.IpAddress;
    const server_address_parsed = try IpAddress.parse(server_address, server_port);

    var server_inst = try IpAddress.listen(&server_address_parsed, io, .{});
    defer server_inst.deinit(io);

    try stdout_writer_interface.print("\n\nThe server started listening on {s}:{d}. \n\n", .{ server_address, server_port });
    try stdout_writer_interface.flush();

    while (true) {
        const server_stream = try server_inst.accept(io);
        const thread = try std.Thread.spawn(.{}, handleAcceptedConnections, .{ server_stream, io, stdout_writer_interface });
        thread.detach();
    }
}
