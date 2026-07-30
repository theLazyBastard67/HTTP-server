const std = @import("std");

pub const httpRequestParsedStruct = struct {
    method: []const u8 = "",
    filePath: []const u8 = "",
    httpVersion: []const u8 = "",
    host: []const u8 = "",
    userAgent: []const u8 = "",
    accept: []const u8 = "",
    connection: []const u8 = "",
    content_length: usize = 0,
    request_body: []const u8 = "",

    pub fn parseHttpRequestHeader(s: *httpRequestParsedStruct, inputBuffer: []u8) !void {
        const trim = std.mem.trim;

        var colon: usize = undefined;
        var fieldName: []const u8 = undefined;
        var fieldValue: []const u8 = undefined;

        var tokenizer = std.mem.tokenizeAny(u8, inputBuffer, "\r\n");

        if (tokenizer.next()) |request_line| {
            var tokenizeRequestLine = std.mem.tokenizeScalar(u8, request_line, ' ');

            s.method = tokenizeRequestLine.next() orelse return error.InvalidRequest;
            s.filePath = tokenizeRequestLine.next() orelse return error.InvalidRequest;
            s.httpVersion = tokenizeRequestLine.next() orelse return error.InvalidRequest;
        } else return error.InvalidRequest;

        while (tokenizer.next()) |next_header_token| {
            const trimmedTokenValue = trim(u8, next_header_token, " ");

            colon = std.mem.find(u8, trimmedTokenValue, ":") orelse return error.InvalidRequest;

            fieldName = trim(u8, trimmedTokenValue[0..colon], " ");
            fieldValue = trim(u8, trimmedTokenValue[colon + 1 .. trimmedTokenValue.len], " ");

            if (std.mem.eql(u8, fieldName, "Host")) {
                s.host = fieldValue;
            }
            if (std.mem.eql(u8, fieldName, "Content-Length")) {
                s.content_length = try std.fmt.parseInt(usize, fieldValue, 10);
            }
        }
    }
};
