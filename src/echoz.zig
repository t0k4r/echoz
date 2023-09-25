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
                .server = http.Server.init(allocator, .{}),
            };
        }
        fn deinit(self: *Self) void {
            self.router.deinit();
            self.server.deinit();
        }

        fn GET(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(http.Method.GET, path, handler);
        }
        fn POST(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(http.Method.POST, path, handler);
        }
        fn listen_and_server(self: *Self, address: net.Address) !void {
            try self.server.listen(address);
            while (true) {
                var res = try self.server.accept(.{ .allocator = self.allocator });
                try res.wait();
                try self.router.handle(&res);
                try res.finish();
                _ = res.reset();
                res.deinit();
                break;
            }
        }
    };
}

const testing = std.testing;
test "Echoz" {
    const allocator = testing.allocator;
    var e = Echo(u32).init(allocator, 2137);
    defer e.deinit();
    try e.GET("/ok", ok);
    try e.listen_and_server(try net.Address.parseIp("127.0.0.1", 2137));
}

fn ok(ctx: Echo(u32).Context) !void {
    try ctx.res.do();
    try ctx.res.headers.append("Content-Type", "text/plain");
    ctx.res.transfer_encoding = .{ .content_length = "ok".len };
    _ = try ctx.res.write("ok");
    // std.debug.print("{}\n", .{ctx.shared.*});
}
