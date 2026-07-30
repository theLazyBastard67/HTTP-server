const std = @import("std");
const builtins = @import("builtin");
const formatting = @import("formatting.zig");

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
            try stdout_printer.print("{s}No address read from stdin, defaulting to localhost.{s}\n", .{ formatting.Color.bold_bright_yellow, formatting.Color.reset });
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

    var parseResult: httpRequestParsedStruct = undefined;

    while (true) {
        var read_data_slice = server_reader.buffered();

        while (std.mem.containsAtLeast(u8, read_data_slice, 1, "\r\n\r\n")) {
            const request_body_start = std.mem.find(u8, read_data_slice, "\r\n\r\n").? + 4;

            parseResult = parseHttpRequestHeader(read_data_slice[0 .. request_body_start - 4]) catch |err| {
                try stdout_writer_interface.print("{s}\n{any}\n{s}", .{ formatting.Color.bold_bright_red, err, formatting.Color
                    .reset });
                try stdout_writer_interface.flush();
                break;
            };

            if (std.mem.eql(u8, parseResult.method, "POST")) {
                const body_recieved = read_data_slice.len - request_body_start;

                if (body_recieved < parseResult.content_length) {
                    server_reader.fill(request_body_start + parseResult.content_length) catch break;
                    read_data_slice = server_reader.buffered();
                }
                parseResult.request_body = read_data_slice[request_body_start .. request_body_start + parseResult.content_length];
            }

            std.debug.print("{s} \n", .{parseResult.method});
            std.debug.print("{s} \n", .{parseResult.filePath});
            std.debug.print("{s} \n", .{parseResult.httpVersion});
            std.debug.print("{s} \n", .{parseResult.host});
            std.debug.print("{s} \n", .{parseResult.request_body});

            try server_writer.print("{s}", .{read_data_slice});
            try server_writer.flush();

            // const request_body_end = request_body_start + parseResult.content_length;

            server_reader.toss(request_body_start + parseResult.content_length);
            read_data_slice = server_reader.buffered();
        }

        server_reader.fillMore() catch break;
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

// Tests.

test "parse basic GET request" {
    const request =
        "GET / HTTP/1.1\r\n" ++
        "Host: localhost\r\n\r\n";

    const result = try parseHttpRequestHeader(@constCast(request));

    try std.testing.expectEqualStrings("GET", result.method);
    try std.testing.expectEqualStrings("/", result.filePath);
    try std.testing.expectEqualStrings("HTTP/1.1", result.httpVersion);
    try std.testing.expectEqualStrings("localhost", result.host);
    try std.testing.expectEqual(@as(usize, 0), result.content_length);
}

test "parse GET with nested path" {
    const request =
        "GET /a/b/c/index.html HTTP/1.1\r\n" ++
        "Host: localhost\r\n\r\n";

    const result = try parseHttpRequestHeader(@constCast(request));

    try std.testing.expectEqualStrings("GET", result.method);
    try std.testing.expectEqualStrings("/a/b/c/index.html", result.filePath);
}

test "parse GET with query string" {
    const request =
        "GET /search?q=zig HTTP/1.1\r\n" ++
        "Host: localhost\r\n\r\n";

    const result = try parseHttpRequestHeader(@constCast(request));

    try std.testing.expectEqualStrings("/search?q=zig", result.filePath);
}

test "parse POST request" {
    const request =
        "POST /login HTTP/1.1\r\n" ++
        "Host: localhost\r\n" ++
        "Content-Length: 5\r\n\r\n";

    const result = try parseHttpRequestHeader(@constCast(request));

    try std.testing.expectEqualStrings("POST", result.method);
    try std.testing.expectEqualStrings("/login", result.filePath);
    try std.testing.expectEqual(@as(usize, 5), result.content_length);
}

test "parse POST with zero content length" {
    const request =
        "POST / HTTP/1.1\r\n" ++
        "Host: localhost\r\n" ++
        "Content-Length: 0\r\n\r\n";

    const result = try parseHttpRequestHeader(@constCast(request));

    try std.testing.expectEqual(@as(usize, 0), result.content_length);
}

test "ignore unknown headers" {
    const request =
        "GET / HTTP/1.1\r\n" ++
        "Host: localhost\r\n" ++
        "X-Test: abc\r\n\r\n";

    const result = try parseHttpRequestHeader(@constCast(request));

    try std.testing.expectEqualStrings("localhost", result.host);
}

test "trim whitespace around header name and value" {
    const request =
        "GET / HTTP/1.1\r\n" ++
        "Host    :    localhost    \r\n\r\n";

    const result = try parseHttpRequestHeader(@constCast(request));

    try std.testing.expectEqualStrings("localhost", result.host);
}

test "parse multiple known headers" {
    const request =
        "GET / HTTP/1.1\r\n" ++
        "Host: localhost\r\n" ++
        "Content-Length: 123\r\n\r\n";

    const result = try parseHttpRequestHeader(@constCast(request));

    try std.testing.expectEqualStrings("localhost", result.host);
    try std.testing.expectEqual(@as(usize, 123), result.content_length);
}

test "empty request returns InvalidRequest" {
    var request: [0]u8 = .{};

    try std.testing.expectError(
        error.InvalidRequest,
        parseHttpRequestHeader(&request),
    );
}

test "missing HTTP version returns InvalidRequest" {
    const request =
        "GET /\r\n" ++
        "Host: localhost\r\n\r\n";

    try std.testing.expectError(
        error.InvalidRequest,
        parseHttpRequestHeader(@constCast(request)),
    );
}

test "missing path returns InvalidRequest" {
    const request =
        "GET  HTTP/1.1\r\n" ++
        "Host: localhost\r\n\r\n";

    try std.testing.expectError(
        error.InvalidRequest,
        parseHttpRequestHeader(@constCast(request)),
    );
}

test "header without colon returns InvalidRequest" {
    const request =
        "GET / HTTP/1.1\r\n" ++
        "Host localhost\r\n\r\n";

    try std.testing.expectError(
        error.InvalidRequest,
        parseHttpRequestHeader(@constCast(request)),
    );
}

test "invalid content length returns error" {
    const request =
        "POST / HTTP/1.1\r\n" ++
        "Host: localhost\r\n" ++
        "Content-Length: abc\r\n\r\n";

    try std.testing.expectError(
        error.InvalidCharacter,
        parseHttpRequestHeader(@constCast(request)),
    );
}

test "request with no Host header is accepted" {
    const request =
        "GET / HTTP/1.1\r\n\r\n";

    const result = try parseHttpRequestHeader(@constCast(request));

    try std.testing.expectEqualStrings("GET", result.method);
    try std.testing.expectEqualStrings("/", result.filePath);
    try std.testing.expectEqualStrings("", result.host);
}

test "duplicate Host header uses last value" {
    const request =
        "GET / HTTP/1.1\r\n" ++
        "Host: localhost\r\n" ++
        "Host: example.com\r\n\r\n";

    const result = try parseHttpRequestHeader(@constCast(request));

    // Current parser overwrites previous values.
    try std.testing.expectEqualStrings("example.com", result.host);
}
