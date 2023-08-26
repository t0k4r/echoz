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
