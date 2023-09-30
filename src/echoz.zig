const std = @import("std");
const Allocator = std.mem.Allocator;
const http = std.http;
const net = std.net;

const rt = @import("./router.zig");

fn Group(comptime T: type) type {
    return struct {
        const Self = @This();
        const HandlerFunc = Echo(T).HandlerFunc;
        const MiddlewareFunc = Echo(T).MiddlewareFunc;
        group: *rt.Group(T),

        fn init(group: *rt.Group(T)) Self {
            return Self{
                .group = group,
            };
        }
        pub fn use(self: *Self, middleware: MiddlewareFunc) !void {
            try self.group.use(middleware);
        }
        pub fn GET(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.group.add_handler(.GET, path, handler);
        }
        pub fn HEAD(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.group.add_handler(.HEAD, path, handler);
        }
        pub fn POST(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.group.add_handler(.POST, path, handler);
        }
        pub fn PUT(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.group.add_handler(.PUT, path, handler);
        }
        pub fn DELETE(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.group.add_handler(.DELETE, path, handler);
        }
        pub fn CONNECT(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.group.add_handler(.CONNECT, path, handler);
        }
        pub fn OPTIONS(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.group.add_handler(.OPTIONS, path, handler);
        }
        pub fn TRACE(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.group.add_handler(.TRACE, path, handler);
        }
        pub fn PATCH(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.group.add_handler(.PATCH, path, handler);
        }
    };
}

pub fn Echo(comptime T: type) type {
    return struct {
        const Self = @This();
        const HandlerFunc = rt.Router(T).HandlerFunc;
        const MiddlewareFunc = rt.Router(T).MiddlewareFunc;
        const Context = rt.Router(T).Context;

        allocator: Allocator,
        router: rt.Router(T),
        server: http.Server,
        pub fn init(allocator: Allocator, shared: T) Self {
            return Self{
                .allocator = allocator,
                .router = rt.Router(T).init(allocator, shared),
                .server = http.Server.init(allocator, .{
                    .reuse_address = true,
                    .reuse_port = true,
                }),
            };
        }
        pub fn deinit(self: *Self) void {
            self.router.deinit();
            self.server.deinit();
        }

        pub fn use(self: *Self, middleware: MiddlewareFunc) !void {
            try self.router.use(middleware);
        }

        pub fn group(self: *Self, path: []const u8) !Group(T) {
            var g = try self.router.group(path);
            return Group(T).init(g);
        }

        pub fn GET(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(.GET, path, handler);
        }
        pub fn HEAD(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(.HEAD, path, handler);
        }
        pub fn POST(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(.POST, path, handler);
        }
        pub fn PUT(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(.PUT, path, handler);
        }
        pub fn DELETE(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(.DELETE, path, handler);
        }
        pub fn CONNECT(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(.CONNECT, path, handler);
        }
        pub fn OPTIONS(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(.OPTIONS, path, handler);
        }
        pub fn TRACE(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(.TRACE, path, handler);
        }
        pub fn PATCH(self: *Self, path: []const u8, handler: HandlerFunc) !void {
            try self.router.add_handler(.PATCH, path, handler);
        }
        pub fn listen_and_server(self: *Self, address: net.Address) !void {
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
    try e.use(mid);

    var g = try e.group("/xd");
    {
        try g.GET("/plain", hplain);
    }

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

fn mid(next: ?*rt.Middleware(u32), ctx: *rt.Router(u32).Context, handler: rt.Router(u32).HandlerFunc) !void {
    var t = std.time.microTimestamp();
    if (next) |n| try n.exec(ctx, handler) else try handler(ctx);
    std.debug.print("{}  {} μs\n", .{ ctx.res.status, std.time.microTimestamp() - t });
}
