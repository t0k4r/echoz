const std = @import("std");
const RadixTree = @import("./radix.zig").RadixTree;
const http = std.http;
const Allocator = std.mem.Allocator;

pub const Context = struct {
    const Self = @This();
    response: ?*http.Server.Response = null,
    pub fn text() !void {}
    pub fn json() !void {}
};

pub const HandlerFunc = *const fn (ctx: Context) anyerror!void;
pub const MiddlewareFunc = *const fn (next: ?*Middleware, ctx: Context, h: HandlerFunc) anyerror!void;

const Middleware = struct {
    const Self = @This();
    func: MiddlewareFunc,
    next: ?*Middleware = null,
    fn init(func: MiddlewareFunc) Self {
        return Self{
            .func = func,
        };
    }
    fn exec(self: *Self, ctx: Context, handler: HandlerFunc) !void {
        try self.func(self.next, ctx, handler);
    }
};

const Handler = struct {
    const Self = @This();
    func: HandlerFunc,
    middleware: ?Middleware = null,
    fn init(func: HandlerFunc) Self {
        return Self{
            .func = func,
        };
    }
    fn use(self: *Self, middleware: *Middleware) void {
        var i: u32 = 0;
        if (self.middleware) |*m| {
            std.debug.print("self middlerware\n", .{});
            var now: *Middleware = m;
            while (now.next) |n| {
                now = n;
                i += 1;
            }
            now.next = middleware;
        } else {
            self.middleware = middleware.*;
        }
        std.debug.print("{}\n", .{i});
    }
    fn exec(self: *Self, ctx: Context) !void {
        return if (self.middleware) |*m| m.exec(ctx, self.func) else self.func(ctx);
    }
};

pub const Router = struct {
    const Self = @This();
    tree: RadixTree(std.AutoHashMap(http.Method, Handler)),
    allocator: Allocator,
    pub fn init(allocator: Allocator) Self {
        return Self{
            .tree = RadixTree(std.AutoHashMap(http.Method, Handler)).init(allocator),
            .allocator = allocator,
        };
    }
    pub fn deinit(self: *Self) void {
        self.tree.deinitception();
    }

    fn add_handler(self: *Self, method: http.Method, path: []const u8, handler: HandlerFunc) !void {
        if (self.tree.searchPtr(path)) |i| {
            try i.put(method, Handler.init(handler));
        } else {
            var i = std.AutoHashMap(http.Method, Handler).init(self.allocator);
            var h = Handler.init(handler);
            var m1: *Middleware = try self.allocator.create(Middleware);
            m1.* = Middleware.init(tes2);
            h.use(m1);
            var m2: *Middleware = try self.allocator.create(Middleware);
            m2.* = Middleware.init(tes2);
            h.use(m2);
            var m3: *Middleware = try self.allocator.create(Middleware);
            m3.* = Middleware.init(tes2);
            h.use(m3);
            try i.put(method, h);
            try self.tree.insert(path, i);
        }
    }
    pub fn GET(self: *Self, path: []const u8, handler: HandlerFunc) !void {
        try self.add_handler(http.Method.GET, path, handler);
    }
    pub fn handle(self: *Self, resp: *http.Server.Response) !void {
        if (self.tree.search(resp.request.target)) |h| {
            if (h.getPtr(resp.request.method)) |handler| {
                var ctx = Context{ .response = resp };
                try handler.exec(ctx);
            }
        }
    }
};

test "Router" {
    const testing = std.testing;
    const alloc = std.heap.page_allocator;
    const talloc = testing.allocator;
    _ = talloc;

    var s = http.Server.init(alloc, .{});
    defer s.deinit();

    var r = Router.init(alloc);
    defer r.deinit();
    try r.GET("/tes", tes);

    try s.listen(try std.net.Address.parseIp("127.0.0.1", 2137));
    var re = try s.accept(.{ .allocator = alloc });
    defer re.deinit();
    try re.wait();
    try re.do();
    try r.handle(&re);
}

fn tes(ctx: Context) !void {
    _ = ctx;
    std.debug.print("tes2\n", .{});
}

fn tes2(next: ?*Middleware, ctx: Context, h: HandlerFunc) !void {
    std.debug.print("tes1\n", .{});
    if (next) |n| try n.exec(ctx, h) else try h(ctx);
    std.debug.print("tes3\n", .{});
}
