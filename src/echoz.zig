const std = @import("std");
const testing = std.testing;
const Router = @import("./Router.zig");

fn add(a: i32, b: i32) !i32 {
    return a + b;
}

test "basic add functionality" {
    try testing.expect(try add(3, 7) == 10);
}
