const std = @import("std");
const Allocator = std.mem.Allocator;

const Node = struct {
    const Self = @This();
    key: []const u8,
    value: ?usize,
    children: std.ArrayList(Node),
    fn init(allocator: Allocator, key: []const u8, value: ?usize) Self {
        return Self{
            .key = key,
            .value = value,
            .children = std.ArrayList(Node).init(allocator),
        };
    }

    fn deinit(self: Self) void {
        for (self.children.items) |child| {
            child.deinit();
        }
        self.children.deinit();
    }
};

pub fn Tree(comptime T: type) type {
    return struct {
        const Self = @This();
        allocator: Allocator,
        root: Node,
        values: std.ArrayList(T),
        pub fn init(allocator: Allocator) Self {
            return Self{
                .allocator = allocator,
                .root = Node.init(allocator, "", null),
                .values = std.ArrayList(T).init(allocator),
            };
        }
        pub fn deinit(self: *Self) void {
            self.root.deinit();
            self.values.deinit();
        }
        pub fn deinit_all(self: *Self) void {
            for (self.values.items) |*i| i.deinit();
            self.root.deinit();
            self.values.deinit();
        }
        pub fn insert(self: *Self, keys: []const u8, value: T) !void {
            var key_iter = std.mem.split(u8, keys, "/");
            var now = &self.root;
            while (key_iter.next()) |key| {
                var last = key_iter.peek() == null;
                for (now.children.items) |*item| {
                    if (std.mem.eql(u8, item.key, key)) {
                        if (last) {
                            if (item.value) |i| {
                                self.values.items[i] = value;
                            } else {
                                item.value = self.values.items.len;
                                if (key[0] == ':') try self.values.append(value) else try self.values.insert(0, value);
                            }
                        } else now = item;
                        break;
                    }
                } else {
                    if (last) {
                        try now.children.append(Node.init(self.allocator, key, self.values.items.len));
                        try self.values.append(value);
                    } else {
                        var i = now.children.items.len;
                        try now.children.append(Node.init(self.allocator, key, null));
                        now = &now.children.items[i];
                    }
                }
            }
        }
        fn search_index(self: *Self, keys: []const u8) ?usize {
            var key_iter = std.mem.split(u8, keys, "/");
            var now = &self.root;
            while (key_iter.next()) |key| {
                var last = key_iter.peek() == null;
                for (now.children.items) |*item| {
                    if (std.mem.eql(u8, item.key, key) or (if (item.key.len != 0) item.key[0] == ':' else false)) {
                        if (last) {
                            return item.value;
                        } else now = item;
                        break;
                    }
                } else {
                    return null;
                }
            }
            return null;
        }
        pub fn search(self: *Self, keys: []const u8) ?T {
            return if (self.search_index(keys)) |i| self.values.items[i] else null;
        }
        pub fn searchPtr(self: *Self, keys: []const u8) ?*T {
            return if (self.search_index(keys)) |i| &self.values.items[i] else null;
        }
        pub fn search_route(self: *Self, keys: []const u8) !?std.ArrayList([]const u8) {
            var route = std.ArrayList([]const u8).init(self.allocator);
            errdefer route.deinit();
            var key_iter = std.mem.split(u8, keys, "/");
            var now = &self.root;
            while (key_iter.next()) |key| {
                var last = key_iter.peek() == null;
                for (now.children.items) |*item| {
                    if (std.mem.eql(u8, item.key, key) or (if (item.key.len != 0) item.key[0] == ':' else false)) {
                        if (item.key.len != 0) try route.append(item.key);
                        if (last) {
                            return route;
                        } else now = item;
                        break;
                    }
                } else {
                    route.deinit();
                    return null;
                }
            }
            route.deinit();
            return null;
        }
    };
}

const testing = std.testing;
test "TreeTest" {
    const allocator = std.testing.allocator;
    var t = Tree(u32).init(allocator);
    defer t.deinit();
    try t.insert("/ok/ok", 21);
    try t.insert("/ok/:xd", 37);
    try testing.expect(21 == t.search("/ok/ok"));
    try testing.expect(37 == t.searchPtr("/ok/abc").?.*);
    try testing.expect(null == t.search("/oko/oko"));
    var ro = try t.search_route("/ok/xyz");
    if (ro) |r| {
        defer r.deinit();
        for (r.items, 0..) |value, i| {
            switch (i) {
                0 => try testing.expect(std.mem.eql(u8, "ok", value)),
                1 => try testing.expect(std.mem.eql(u8, ":xd", value)),
                else => unreachable,
            }
        }
    } else {
        unreachable;
    }
}
