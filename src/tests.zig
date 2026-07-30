// const main = @import("main.zig");
const parser = @import("httpParser.zig");
const std = @import("std");

test "parse POST request" {
    const request =
        "POST /login HTTP/1.1\r\n" ++
        "Host: localhost\r\n" ++
        "Content-Length: 5\r\n\r\n";

    var result: parser.httpRequestParsedStruct = .{};
    try result.parseHttpRequestHeader(@constCast(request));

    try std.testing.expectEqualStrings("POST", result.method);
    try std.testing.expectEqualStrings("/login", result.filePath);
    try std.testing.expectEqual(@as(usize, 5), result.content_length);
}

test "parse POST with zero content length" {
    const request =
        "POST / HTTP/1.1\r\n" ++
        "Host: localhost\r\n" ++
        "Content-Length: 0\r\n\r\n";

    var result: parser.httpRequestParsedStruct = .{};
    try result.parseHttpRequestHeader(@constCast(request));

    try std.testing.expectEqual(@as(usize, 0), result.content_length);
}

test "ignore unknown headers" {
    const request =
        "GET / HTTP/1.1\r\n" ++
        "Host: localhost\r\n" ++
        "X-Test: abc\r\n\r\n";

    var result: parser.httpRequestParsedStruct = .{};
    try result.parseHttpRequestHeader(@constCast(request));

    try std.testing.expectEqualStrings("localhost", result.host);
}

test "trim whitespace around header name and value" {
    const request =
        "GET / HTTP/1.1\r\n" ++
        "Host    :    localhost    \r\n\r\n";

    var result: parser.httpRequestParsedStruct = .{};
    try result.parseHttpRequestHeader(@constCast(request));

    try std.testing.expectEqualStrings("localhost", result.host);
}

test "parse multiple known headers" {
    const request =
        "GET / HTTP/1.1\r\n" ++
        "Host: localhost\r\n" ++
        "Content-Length: 123\r\n\r\n";

    var result: parser.httpRequestParsedStruct = .{};
    try result.parseHttpRequestHeader(@constCast(request));

    try std.testing.expectEqualStrings("localhost", result.host);
    try std.testing.expectEqual(@as(usize, 123), result.content_length);
}

test "empty request returns InvalidRequest" {
    var request: [0]u8 = .{};
    var result: parser.httpRequestParsedStruct = .{};

    try std.testing.expectError(
        error.InvalidRequest,
        result.parseHttpRequestHeader(&request),
    );
}

test "missing HTTP version returns InvalidRequest" {
    const request =
        "GET /\r\n" ++
        "Host: localhost\r\n\r\n";

    var result: parser.httpRequestParsedStruct = .{};

    try std.testing.expectError(
        error.InvalidRequest,
        result.parseHttpRequestHeader(@constCast(request)),
    );
}

test "missing path returns InvalidRequest" {
    const request =
        "GET  HTTP/1.1\r\n" ++
        "Host: localhost\r\n\r\n";

    var result: parser.httpRequestParsedStruct = .{};

    try std.testing.expectError(
        error.InvalidRequest,
        result.parseHttpRequestHeader(@constCast(request)),
    );
}

test "header without colon returns InvalidRequest" {
    const request =
        "GET / HTTP/1.1\r\n" ++
        "Host localhost\r\n\r\n";

    var result: parser.httpRequestParsedStruct = .{};

    try std.testing.expectError(
        error.InvalidRequest,
        result.parseHttpRequestHeader(@constCast(request)),
    );
}

test "invalid content length returns error" {
    const request =
        "POST / HTTP/1.1\r\n" ++
        "Host: localhost\r\n" ++
        "Content-Length: abc\r\n\r\n";

    var result: parser.httpRequestParsedStruct = .{};

    try std.testing.expectError(
        error.InvalidCharacter,
        result.parseHttpRequestHeader(@constCast(request)),
    );
}

test "request with no Host header is accepted" {
    const request =
        "GET / HTTP/1.1\r\n\r\n";

    var result: parser.httpRequestParsedStruct = .{};
    try result.parseHttpRequestHeader(@constCast(request));

    try std.testing.expectEqualStrings("GET", result.method);
    try std.testing.expectEqualStrings("/", result.filePath);
    try std.testing.expectEqualStrings("", result.host);
}

test "duplicate Host header uses last value" {
    const request =
        "GET / HTTP/1.1\r\n" ++
        "Host: localhost\r\n" ++
        "Host: example.com\r\n\r\n";

    var result: parser.httpRequestParsedStruct = .{};
    try result.parseHttpRequestHeader(@constCast(request));

    try std.testing.expectEqualStrings("example.com", result.host);
}
test "parse basic GET request" {
    const request =
        "GET / HTTP/1.1\r\n" ++
        "Host: localhost\r\n\r\n";

    var result: parser.httpRequestParsedStruct = .{};
    try result.parseHttpRequestHeader(@constCast(request));

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

    var result: parser.httpRequestParsedStruct = .{};
    try result.parseHttpRequestHeader(@constCast(request));

    try std.testing.expectEqualStrings("GET", result.method);
    try std.testing.expectEqualStrings("/a/b/c/index.html", result.filePath);
}

test "parse GET with query string" {
    const request =
        "GET /search?q=zig HTTP/1.1\r\n" ++
        "Host: localhost\r\n\r\n";

    var result: parser.httpRequestParsedStruct = .{};
    try result.parseHttpRequestHeader(@constCast(request));

    try std.testing.expectEqualStrings("/search?q=zig", result.filePath);
}
