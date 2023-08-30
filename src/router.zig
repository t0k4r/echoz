const std = @import("std");
const RadixTree = @import("./radix.zig").RadixTree;
const http = std.http;
const Allocator = std.mem.Allocator;

pub const Context = struct {
    const Self = @This();
    response: *http.Server.Response,
    pub fn text() !void {}
    pub fn json() !void {}
};

pub const HandlerFunc = *const fn (Context) anyerror!void;
pub const MiddlewareFunc = *const fn (HandlerFunc) HandlerFunc;

pub const Router = struct {
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

    fn add_handler(self: *Self, method: http.Method, path: []const u8, handler: HandlerFunc) !void {
        if (self.tree.searchPtr(path)) |i| {
            try i.put(method, handler);
        } else {
            var i = std.AutoHashMap(http.Method, HandlerFunc).init(self.allocator);
            try i.put(method, handler);
            try self.tree.insert(path, i);
        }
    }
    pub fn GET(self: *Self, path: []const u8, handler: HandlerFunc, middleware: ?MiddlewareFunc) !void {
        try self.add_handler(http.Method.GET, path, if (middleware) |m| m(handler) else handler);
    }
    pub fn handle(self: *Self, resp: *http.Server.Response) !void {
        if (self.tree.search(resp.request.target)) |h| {
            if (h.get(resp.request.method)) |handler| {
                var ctx = Context{ .response = resp };
                try handler(ctx);
            }
        }
    }
};

test "Router" {
    const testing = std.testing;
    const alloc = std.heap.page_allocator;
    _ = alloc;
    const talloc = testing.allocator;

    var s = http.Server.init(talloc, .{});
    defer s.deinit();

    var r = Router.init(talloc);
    defer r.deinit();
    try r.GET("/tes", tes, tes2);

    try s.listen(try std.net.Address.parseIp("127.0.0.1", 2137));
    var re = try s.accept(.{ .allocator = talloc });
    defer re.deinit();
    try re.wait();
    try r.handle(&re);
}

fn tes(c: Context) !void {
    _ = c;
    std.debug.print("tes", .{});
}

fn tes2(h: HandlerFunc) HandlerFunc {
    const func = struct {
        fn call(c: Context) HandlerFunc {
            _ = c;
            std.debug.print("tes2", .{});
            // h(c);
        }
    };
    _ = func;
    return h;
}

fn tes3(h: HandlerFunc) !void {
    _ = h;
}
