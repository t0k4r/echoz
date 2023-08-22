const std = @import("std");
const http = std.http;
const Allocator = std.mem.Allocator;

const Trie = @import("./trie.zig").Tire;

const Route = struct {
    route: []const u8,
    method: http.Method,

    pub fn eq(a: Route, b: Route) bool {
        _ = b;
        _ = a;
        return false;
    }
};

const Handler = *const fn (*http.Server.Response) bool;

pub fn Router() type {
    return struct {
        const Self = @This();
        routes: Trie(Route, Handler),
        pub fn init(allocator: Allocator) Self {
            _ = allocator;
            return Self{ .routes = Trie(Route, Handler) };
        }
        pub fn deinit(self: Self) void {
            self.routes.deinit();
        }
        fn add_route(self: Self, method: http.Method, route: []const u8, handler: Handler) !void {
            _ = self;
            _ = handler;
            _ = route;
            _ = method;
        }
    };
}

fn Handle2() type {
    return struct {
        method: http.Method,
        dispatch: ?*const fn () anyerror!void,
        handler: *const fn () anyerror!void,
    };
}
