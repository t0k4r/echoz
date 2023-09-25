const std = @import("std");
const Allocator = std.mem.Allocator;
const http = std.http;
const net = std.net;

const Router = @import("./router.zig").Router;

pub fn Echo(comptime T: type) type {
    return struct {
        const Self = @This();
        const HandlerFunc = Router(T).HandlerFunc;
        const MiddlewareFunc = Router(T).MiddlewareFunc;
        const Context = Router(T).Context;

        allocator: Allocator,
        router: Router(T),
        server: http.Server,
        fn init(allocator: Allocator, shared: T) Self {
            return Self{
                .allocator = allocator,
                .router = Router(T).init(allocator, shared),
                .server = http.Server.init(allocator, .{
                    .reuse_address = true,
                    .reuse_port = true,
                }),
            };
        }
        fn deinit(self: *Self) void {
            self.router.deinit();
            self.server.deinit();
        }

        fn use(self: *Self, middleware: MiddlewareFunc) !void {
            try self.router.use(middleware);
        }

        fn GET(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(http.Method.GET, path, handler);
        }
        fn HEAD(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(http.Method.HEAD, path, handler);
        }
        fn POST(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(http.Method.POST, path, handler);
        }
        fn PUT(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(http.Method.PUT, path, handler);
        }
        fn DELETE(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(http.Method.DELETE, path, handler);
        }
        fn CONNECT(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(http.Method.CONNECT, path, handler);
        }
        fn OPTIONS(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(http.Method.OPTIONS, path, handler);
        }
        fn TRACE(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(http.Method.TRACE, path, handler);
        }
        fn PATCH(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(http.Method.PATCH, path, handler);
        }
        fn listen_and_server(self: *Self, address: net.Address) !void {
            try self.server.listen(address);
            while (true) {
                var res = try self.server.accept(.{ .allocator = self.allocator });
                defer res.deinit();
                try res.wait();
                try self.router.handle(&res);
            }
        }
    };
}

const testing = std.testing;
test "Echoz" {
    const allocator = testing.allocator;
    var e = Echo(u32).init(allocator, 2137);
    defer e.deinit();
    try e.GET("/plain", hplain);
    try e.GET("/json", hjson);
    try e.GET("/no", hno_content);
    try e.GET("/param/:ok/xd", hparam);
    try e.listen_and_server(try net.Address.parseIp("127.0.0.1", 2137));
}

fn hplain(ctx: *Echo(u32).Context) !void {
    return ctx.plain(.ok, "Hello, World\n");
}

fn hjson(ctx: *Echo(u32).Context) !void {
    return ctx.json(.ok, .{ .hello = "world" });
}
fn hno_content(ctx: *Echo(u32).Context) !void {
    return ctx.no_content(.ok);
}

fn hparam(ctx: *Echo(u32).Context) !void {
    var param = try ctx.param(":ok");
    return if (param) |p| ctx.plain(.ok, p) else std.mem.Allocator.Error.OutOfMemory;
}
