const std = @import("std");
const http = std.http;
const net = std.net;

const Allocator = std.mem.Allocator;
running: bool,
routes: []Route,

const Router = @This();
pub fn init(alocator: Allocator) Router {
    _ = alocator;
    return .{};
}

pub fn run(router: *Router, server: http.Server) !void {
    _ = server;
    _ = router;
}
fn add_route(router: *Router, method: http.Method, route: []const u8, handler: fn () void) void {
    var not_done = false;
    for (router.routes) |*r| {
        if (r.route == route and r.method == method) {
            r.handler = handler;
            not_done == true;
            break;
        }
    }
    if (not_done) {
        router.routes = router.routes ++ Route{
            .method = method,
            .route = route,
            .handler = handler,
        };
    }
}

pub fn GET(router: *Router, route: []const u8, handler: fn () void) void {
    router.add_route(http.Method.GET, route, handler);
}

pub fn stop() void {}

const Route = struct {
    method: http.Method,
    route: []const u8,
    handler: fn () void,
};
