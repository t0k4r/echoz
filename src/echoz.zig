const std = @import("std");
const testing = std.testing;
const http = std.http;
const net = std.net;

const print = std.debug.print;
const Allocator = std.mem.Allocator;

test "RadixTree" {
    _ = @import("./radix.zig");
}

test "xd" {
    _ = xd()();
}

fn xd() *const fn () bool {
    return v;
}

fn v() bool {
    return true;
}

test "clojure" {
    const c = 3;
    const func = struct {
        pub fn call() bool {
            return c != 2137;
        }
    };
    const z = func.call;

    try testing.expect(z());
}

test "Router" {
    _ = @import("./router.zig");
}
