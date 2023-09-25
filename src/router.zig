const std = @import("std");
const Allocator = std.mem.Allocator;
const http = std.http;

const Tree = @import("./tree.zig").Tree;
test "Tree" {
    _ = @import("./tree.zig");
}

fn Middleware(comptime T: type) type {
    return struct {
        const Self = @This();
        allocator: Allocator,
        func: Router(T).MiddlewareFunc,
        next: ?*Middleware(T) = null,
        fn init(allocator: Allocator, func: Router(T).MiddlewareFunc) Self {
            return Self{
                .allocator = allocator,
                .func = func,
            };
        }
        fn deinit(self: *Self) void {
            if (self.next) |n| {
                n.deinit();
                self.allocator.destroy(n);
            }
        }
        fn add(self: *Self, middleware: Router(T).MiddlewareFunc) !void {
            var now = self;
            while (now.next) |n| {
                now = n;
            }
            var m = try self.allocator.create(Middleware(T));
            m.* = Middleware(T).init(self.allocator, middleware);
            now.next = m;
        }
        fn exec(self: *Self, ctx: Router(T).Context, handler: Router(T).HandlerFunc) !void {
            try self.func(self.next, ctx, handler);
        }
    };
}

fn Handler(comptime T: type) type {
    return struct {
        const Self = @This();
        func: Router(T).HandlerFunc,
        middleware: ?Middleware(T) = null,
        fn init(func: Router(T).HandlerFunc) Self {
            return Self{
                .func = func,
            };
        }
        fn exec(self: *Self, ctx: Router(T).Context) !void {
            if (self.middleware) |*m| try m.exec(ctx, self.func) else try self.func(ctx);
        }
    };
}

pub fn Router(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const Context = struct {
            const Ctx = @This();
            shared: *T,
            res: *http.Server.Response,
            fn init(res: *http.Server.Response, shared: *T) Ctx {
                return Ctx{
                    .res = res,
                    .shared = shared,
                };
            }
            fn text(self: *Ctx) !void {
                _ = self;
            }
            fn json(self: *Ctx) !void {
                _ = self;
            }
        };
        pub const HandlerFunc = *const fn (ctx: Context) anyerror!void;
        pub const MiddlewareFunc = *const fn (next: ?*Middleware(T), ctx: Context, handler: HandlerFunc) anyerror!void;

        allocator: Allocator,
        shared: T,
        tree: Tree(std.AutoHashMap(http.Method, Handler(T))),
        middleware: ?Middleware(T) = null,
        pub fn init(allocator: Allocator, shared: T) Self {
            return Self{
                .allocator = allocator,
                .shared = shared,
                .tree = Tree(std.AutoHashMap(http.Method, Handler(T))).init(allocator),
            };
        }
        pub fn deinit(self: *Self) void {
            self.tree.deinit_all();
            if (self.middleware) |*m| m.deinit();
        }
        pub fn use(self: *Self, middleware: MiddlewareFunc) !void {
            if (self.middleware) |*m| {
                try m.add(middleware);
            } else {
                self.middleware = Middleware(T).init(self.allocator, middleware);
            }
        }

        pub fn add_handler(self: *Self, method: http.Method, path: []const u8, handler: HandlerFunc) !void {
            if (self.tree.searchPtr(path)) |m| {
                var h = Handler(T).init(handler);
                h.middleware = self.middleware;
                try m.put(method, h);
            } else {
                var m = std.AutoHashMap(http.Method, Handler(T)).init(self.allocator);
                var h = Handler(T).init(handler);
                h.middleware = self.middleware;
                try m.put(method, h);
                try self.tree.insert(path, m);
            }
        }

        pub fn handle(self: *Self, res: *http.Server.Response) !void {
            if (self.tree.search(res.request.target)) |h| {
                if (h.getPtr(http.Method.GET)) |func| {
                    try func.exec(Context.init(res, &self.shared));
                }
            }
        }
    };
}

const testing = std.testing;
test "Router" {
    // const allocator = testing.allocator;

    // var r = Router(u32).init(allocator, 32);
    // defer r.deinit();
    // try r.use(mid);

    // try r.add_handler(http.Method.GET, "/xd/ok", xd);

    // var ser = http.Server.init(allocator, .{});
    // defer ser.deinit();

    // try ser.listen(try std.net.Address.parseIp("127.0.0.1", 2137));

    // var res = try ser.accept(.{ .allocator = allocator });
    // try res.wait();
    // try r.handle(&res);
    // res.deinit();
}

fn xd(ctx: Router(u32).Context) !void {
    _ = ctx;
    std.debug.print("{}\n", .{2137});
}

fn mid(next: ?*Middleware(u32), ctx: Router(u32).Context, handler: Router(u32).HandlerFunc) !void {
    std.debug.print("mid1\n", .{});
    if (next) |n| try n.exec(ctx, handler) else try handler(ctx);
    std.debug.print("mid2\n", .{});
}
