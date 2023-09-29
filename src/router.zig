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
        fn exec(self: *Self, ctx: *Router(T).Context, handler: Router(T).HandlerFunc) !void {
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
        fn exec(self: *Self, ctx: *Router(T).Context) !void {
            if (self.middleware) |*m| try m.exec(ctx, self.func) else try self.func(ctx);
        }
    };
}

fn Ctx(comptime T: type) type {
    return struct {
        const Self = @This();
        allocator: Allocator,
        shared: *T,
        res: *http.Server.Response,
        tree: *Tree(std.AutoHashMap(http.Method, Handler(T))),
        params: ?std.ArrayList([]const u8),
        fn init(allocator: Allocator, res: *http.Server.Response, shared: *T, tree: *Tree(std.AutoHashMap(http.Method, Handler(T)))) !*Self {
            var ctx = try allocator.create(Self);
            ctx.* = Self{
                .allocator = allocator,
                .res = res,
                .shared = shared,
                .tree = tree,
                .params = null,
            };
            return ctx;
        }
        fn deinit(self: *Self) void {
            if (self.params) |p| p.deinit();
            self.allocator.destroy(self);
        }
        pub fn param(self: *Self, key: []const u8) !?[]const u8 {
            if (self.params == null) self.params = try self.tree.search_route(self.res.request.target);

            if (self.params) |p| {
                var iter = std.mem.split(u8, self.res.request.target, "/");
                _ = iter.next();
                for (p.items) |path| {
                    var now = iter.next() orelse break;
                    if (std.mem.eql(u8, key, path)) {
                        return now;
                    }
                }
            }
            return null;
        }

        pub fn no_content(self: *Self, status: http.Status) !void {
            self.res.status = status;
            try self.res.do();
        }

        pub fn plain(self: *Self, status: http.Status, text: []const u8) !void {
            try self.res.headers.append("Content-Type", "text/plain");
            self.res.status = status;
            self.res.transfer_encoding = .{ .content_length = text.len };
            try self.res.do();
            _ = try self.res.write(text);
        }
        pub fn json(self: *Self, status: http.Status, data: anytype) !void {
            var string = std.ArrayList(u8).init(self.allocator);
            defer string.deinit();
            try std.json.stringify(data, .{}, string.writer());
            try self.res.headers.append("Content-Type", "application/json");
            self.res.status = status;
            self.res.transfer_encoding = .{ .content_length = string.items.len };
            try self.res.do();
            _ = try self.res.write(string.items);
        }
    };
}

pub fn Group(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        path: []const u8,
        tree: *Tree(std.AutoHashMap(http.Method, Handler(T))),
        middleware: ?Middleware(T) = null,
        paths: std.ArrayList([]const u8),
        fn init(allocator: Allocator, path: []const u8, tree: *Tree(std.AutoHashMap(http.Method, Handler(T))), middleware: ?Middleware(T)) Self {
            return Self{
                .allocator = allocator,
                .path = path,
                .tree = tree,
                .middleware = middleware,
                .paths = std.ArrayList([]const u8).init(allocator),
            };
        }
        fn deinit(self: *Self) void {
            for (self.paths.items) |p| {
                self.allocator.free(p);
            }
            self.paths.deinit();
        }

        pub fn use(self: *Self, middleware: Router(T).MiddlewareFunc) !void {
            if (self.middleware) |*m| {
                try m.add(middleware);
            } else {
                self.middleware = Middleware(T).init(self.allocator, middleware);
            }
        }
        pub fn add_handler(self: *Self, method: http.Method, path: []const u8, handler: Router(T).HandlerFunc) !void {
            var full = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.path, path });
            try self.paths.append(full);
            if (self.tree.searchPtr(full)) |m| {
                var h = Handler(T).init(handler);
                h.middleware = self.middleware;
                try m.put(method, h);
            } else {
                var m = std.AutoHashMap(http.Method, Handler(T)).init(self.allocator);
                var h = Handler(T).init(handler);
                h.middleware = self.middleware;
                try m.put(method, h);
                try self.tree.insert(full, m);
            }
        }
    };
}

pub fn Router(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const Context = Ctx(T);
        pub const HandlerFunc = *const fn (ctx: *Context) anyerror!void;
        pub const MiddlewareFunc = *const fn (next: ?*Middleware(T), ctx: *Context, handler: HandlerFunc) anyerror!void;

        allocator: Allocator,
        shared: T,
        tree: Tree(std.AutoHashMap(http.Method, Handler(T))),
        middleware: ?Middleware(T) = null,
        groups: std.ArrayList(Group(T)),

        pub fn init(allocator: Allocator, shared: T) Self {
            return Self{
                .allocator = allocator,
                .shared = shared,
                .tree = Tree(std.AutoHashMap(http.Method, Handler(T))).init(allocator),
                .groups = std.ArrayList(Group(T)).init(allocator),
            };
        }
        pub fn deinit(self: *Self) void {
            self.tree.deinit_all();
            if (self.middleware) |*m| m.deinit();
            for (self.groups.items) |*g| g.deinit();
            self.groups.deinit();
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
                if (h.getPtr(res.request.method)) |func| {
                    var ctx = try Context.init(self.allocator, res, &self.shared, &self.tree);
                    defer ctx.deinit();
                    try func.exec(ctx);
                }
            }
        }

        pub fn group(self: *Self, path: []const u8) !*Group(T) {
            var i = self.groups.items.len;
            try self.groups.append(Group(T).init(self.allocator, path, &self.tree, self.middleware));
            return &self.groups.items[i];
        }
    };
}

fn mid(next: ?*Middleware(u32), ctx: *Router(u32).Context, handler: Router(u32).HandlerFunc) !void {
    std.debug.print("mid1\n", .{});
    if (next) |n| try n.exec(ctx, handler) else try handler(ctx);
    std.debug.print("mid2\n", .{});
}
