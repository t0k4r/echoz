const std = @import("std");
const Allocator = std.mem.Allocator;
const http = std.http;
const net = std.net;

const Router = @import("./router.zig").Router;
const Group = @import("./router.zig").Group;

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

        fn group(self: *Self, path: []const u8) !*Group(T) {
            return self.router.group(path);
        }

        fn GET(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(.GET, path, handler);
        }
        fn HEAD(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(.HEAD, path, handler);
        }
        fn POST(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(.POST, path, handler);
        }
        fn PUT(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(.PUT, path, handler);
        }
        fn DELETE(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(.DELETE, path, handler);
        }
        fn CONNECT(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(.CONNECT, path, handler);
        }
        fn OPTIONS(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(.OPTIONS, path, handler);
        }
        fn TRACE(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(.TRACE, path, handler);
        }
        fn PATCH(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(.PATCH, path, handler);
        }
        fn listen_and_server(self: *Self, address: net.Address) !void {
            try self.server.listen(address);
            var i: usize = 0;
            while (true) {
                var res = try self.server.accept(.{ .allocator = self.allocator });
                defer res.deinit();
                try res.wait();
                try self.router.handle(&res);
                i += 1;
                if (i == 5) {
                    break;
                }
            }
        }
    };
}

const testing = std.testing;
test "Echoz" {
    const allocator = testing.allocator;
    var e = Echo(u32).init(allocator, 2137);
    defer e.deinit();
    var g = try e.group("/xd");
    try g.add_handler(.GET, "/plain", hplain);

    try e.GET("/plain", hplain);
    try e.GET("/json", hjson);
    try e.GET("/no", hno_content);
    try e.GET("/param/:ok", hparam);
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
    return if (param) |p| ctx.json(.ok, .{ .param = p }) else ctx.no_content(.ok);
}
