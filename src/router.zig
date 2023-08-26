const std = @import("std");
const http = std.http;
const Allocator = std.mem.Allocator;

fn Context(comptime T: type) type {
    return struct {
        const Self = @This();
        shared: T,
        request: null,
        response: null,
        pub fn text() void {}
        pub fn json() void {}
    };
}

const MiddlewareFunc = fn () bool!anyerror;
const HandlerFunc = fn (Context(null)) void!anyerror;

pub fn Router(comptime T: type) type {
    _ = T;
    return struct {
        const Self = @This();
    };
}
