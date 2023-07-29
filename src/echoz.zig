const std = @import("std");
const tr = @import("./Trie.zig");
const testing = std.testing;
const http = std.http;
const net = std.net;

const print = std.debug.print;
const Allocator = std.mem.Allocator;

test "Router" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    var r = Router().init(alloc);
    try r.add_route("/hello", world);
    // r.GET("/hello", handle);

    var server = http.Server.init(alloc, .{});
    _ = server;
    // try server.listen(try net.Address.parseIp("127.0.0.1", 2137));
    // var rer = try server.accept(.{ .allocator = alloc });
    // try r.handle(&rer);
}

test "Trie" {
    _ = @import("./Trie.zig");
}
// test "Trie" {
//     // _ = @import("./Trie.zig");
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     const alloc = gpa.allocator();

//     var t = tr.Tire([]const u8, i32).init(alloc, eqqq);
//     var keys = std.ArrayList([]const u8).init(alloc);
//     var split = std.mem.split(u8, "/o/k", "/");
//     while (split.next()) |x| {
//         try keys.append(x);
//     }
//     try t.insert(keys.items, 4269);
//     var v = t.search(keys.items);
//     print("\n\n\n{?}\n\n\n", .{v});
//     print("\n\n\n{?}\n\n\n", .{v});

//     print("\n\n\n{?}\n\n\n", .{v});
// }

fn eqqq(k1: []const u8, k2: []const u8) bool {
    return std.mem.eql(u8, k1, k2);
}

fn Router() type {
    return struct {
        const Self = @This();
        routes: std.ArrayList(Route),
        fn init(allocator: Allocator) Self {
            // const r = Route{ .route = "/hello", .handler = handler };
            // _ = r;
            return Self{ .routes = std.ArrayList(Route).init(allocator) };
        }
        fn add_route(self: *Self, route: []const u8, handler: *const fn () void) !void {
            for (self.routes.items) |*r| {
                if (std.mem.eql(u8, r.route, route)) {
                    r.handler = handler;
                    break;
                }
            } else {
                try self.routes.append(.{
                    .route = route,
                    .handler = handler,
                });
            }
        }
        fn handle(self: *Self, response: *http.Server.Response) !void {
            try response.wait();
            print("\n\n\n\n{s}\n\n", .{response.request.target});

            for (response.request.headers.list.items) |h| {
                print("\n\n{s}: {s}\n\n", .{ h.name, h.value });
            }
            response.status = http.Status.ok;
            try response.do();
            // _ = try response.write("ok");
            try response.finish();
            _ = self;
        }
    };
}

const Route = struct { route: []const u8, handler: *const fn () void };

fn world() void {
    print("\n\nworld\n\n", .{});
}
