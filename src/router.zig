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

pub const HandlerFunc = *const fn (Context) anyerror!void;
pub const MiddlewareFunc = *const fn (Context, ?HandlerFunc) anyerror!void;

// const Handler = struct {
//     middleware: ?*Middleware = null,
//     handler: HandlerFunc,
//     const Self = @This();
//     fn init(handler: HandlerFunc) Self {
//         return Self{
//             .handler = handler,
//         };
//     }
//     fn exec(self: *Self, ctx: *Context) !void {
//         std.debug.print("exe\n", .{});
//         if (self.middleware) |m| {
//             std.debug.print("mid\n", .{});
//             try m.on_request(ctx, self.handler);
//         } else {
//             std.debug.print("han\n", .{});
//             try self.handler(ctx);
//         }
//     }
//     fn use(self: *Self, middleware: Middleware) void {
//         if (self.middleware) |m| {
//             var now = m;
//             var i: i32 = 0;
//             while (now.next) |o| {
//                 now = o;
//                 i += 1;
//             }
//             std.debug.print("{}", .{i});
//             now.next = @constCast(&middleware);
//         } else {
//             self.middleware = @constCast(&middleware);
//         }
//     }
// };
const Middleware = struct {
    const Self = @This();
    func: MiddlewareFunc,
    fn init(func: MiddlewareFunc) Self {
        return Self{
            .func = func,
        };
    }
    fn exec(self: *Self, ctx: Context, handler: HandlerFunc) !void {
        return self.func(ctx, handler);
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
    fn use(self: *Self, middleware: Middleware) void {
        self.middleware = middleware;
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
            h.use(Middleware.init(tes2));
            // h.use(Middleware.init(tes2, 0));
            // h.use(Middleware.init(tes2, 1));
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
    _ = alloc;
    const talloc = testing.allocator;

    var s = http.Server.init(talloc, .{});
    defer s.deinit();

    var r = Router.init(talloc);
    defer r.deinit();
    try r.GET("/tes", tes);

    try s.listen(try std.net.Address.parseIp("127.0.0.1", 2137));
    var re = try s.accept(.{ .allocator = talloc });
    defer re.deinit();
    try re.wait();
    try re.do();
    try r.handle(&re);
}

fn tes(c: Context) !void {
    _ = c;
    std.debug.print("tes2\n", .{});
}

fn tes2(ctx: Context, next: ?HandlerFunc) !void {
    std.debug.print("tes1\n", .{});
    if (next) |n| try n(ctx);
    std.debug.print("tes3\n", .{});
}

// const Middleware = struct {
//     const Self = @This();
//     next: ?*Middleware = null,
//     middleware: MiddlewareFunc,
//     id: u32 = 0,
//     fn init(middleware: MiddlewareFunc, id: u32) Self {
//         _ = id;
//         // if (id != 0 or id != 1) {
//         //     @compileError("WTFFFF");
//         // }
//         return Self{
//             .middleware = middleware,
//             .id = 1,
//         };
//     }
//     // fn add_other(self: *Self, other: *const Self) void {
//     //     var now = self;
//     //     while (now.other) |o| {
//     //         now = o;
//     //     }
//     //     now.other = @constCast(other);
//     // }
//     fn on_request(self: *Self, ctx: *Context, handler: HandlerFunc) !void {
//         std.debug.print("ID: {d}\n", .{self.id});
//         std.debug.print("nextnull: {}\n", .{self.next == null});

//         if (self.next) |next| {
//             _ = next;
//             std.debug.print("next\n", .{});
//             // var b = next.next;
//             // _ = b;
//             if (self.next == null) std.debug.print("nextnull\n", .{});
//             // const c = @constCast(&Context{});
//             // try next.on_request(c, handler);
//             // try next.middleware(c, null);
//         } else {
//             std.debug.print("last\n", .{});
//             try self.middleware(ctx, handler);
//         }
//     }
// };
