const std = @import("std");
const RadixTree = @import("./radix.zig").RadixTree;
const http = std.http;
const Allocator = std.mem.Allocator;

fn Context(comptime T: type) type {
    return struct {
        const Self = @This();
        shared: T,
        request: http.Server.Request,
        response: http.Server.Response,
        pub fn text() !void {}
        pub fn json() !void {}
    };
}

pub fn Router(comptime T: type) type {
    const HandlerFunc = *const fn (Context(T)) anyerror!void;
    const MiddlewareFunc = *const fn (HandlerFunc) HandlerFunc;
    _ = MiddlewareFunc;

    return struct {
        const Self = @This();
        tree: RadixTree(std.AutoHashMap(http.Method, HandlerFunc)),
        allocator: Allocator,
        pub fn init(allocator: Allocator) Self {
            return Self{
                .tree = RadixTree(std.AutoHashMap(http.Method, HandlerFunc)).init(allocator),
                .allocator = allocator,
            };
        }
        pub fn deinit(self: *Self) void {
            self.tree.deinitception();
        }

        fn handle(self: *Self, method: http.Method, path: []const u8, handler: HandlerFunc) !void {
            if (self.tree.search(path)) |*i| {
                _ = i;
                // try i.put(method, handler);
                // try self.tree.insert(path, i);
            } else {
                var i = std.AutoHashMap(http.Method, HandlerFunc).init(self.allocator);
                try i.put(method, handler);
                try self.tree.insert(path, i);
            }
        }
        pub fn GET(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.handle(http.Method.GET, path, handler);
        }
    };
}

test "Router" {
    const testi = std.testing;
    _ = testi;
    const allocator = std.heap.page_allocator;

    var r = Router(u8).init(allocator);
    defer r.deinit();
    try r.GET("/tes", tes);
}

fn tes(c: Context(u8)) !void {
    _ = c;
    std.debug.print("tes", .{});
}
