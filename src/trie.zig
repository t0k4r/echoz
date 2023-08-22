const std = @import("std");
const Allocator = std.mem.Allocator;

fn Node(comptime T: type) type {
    return struct {
        const Self = @This();
        children: std.ArrayList(Node(T)),
        key: []const u8,
        value: ?T,
        fn init(allocator: Allocator, key: []const u8, value: ?T) Self {
            return Self{
                .children = std.ArrayList(Node(T)).init(allocator),
                .key = key,
                .value = value,
            };
        }
        fn deinit(self: Self) void {
            for (self.children.items) |child| {
                child.deinit();
            }
            self.children.deinit();
        }
    };
}

pub fn Trie(comptime T: type) type {
    return struct {
        const Self = @This();
        allocator: Allocator,
        root: Node(T),
        pub fn init(allocator: Allocator) Self {
            return Self{
                .allocator = allocator,
                .root = Node(T).init(allocator, "", null),
            };
        }
        pub fn deinit(self: *Self) void {
            self.root.deinit();
        }
        pub fn insert(self: *Self, keys: []const u8, value: T) !void {
            var keys_iter = std.mem.split(u8, keys, "/");
            var now = &self.root;
            while (keys_iter.next()) |key| {
                var last = keys_iter.peek() == null;
                for (now.children.items) |*item| {
                    if (std.mem.eql(u8, item.key, key) or
                        (if (item.key.len != 0) item.key[0] == ':' else false))
                    {
                        if (last) item.value = value else now = item;
                        break;
                    }
                } else {
                    try now.children.append(Node(T).init(
                        self.allocator,
                        key,
                        if (last) value else null,
                    ));
                    now = &now.children.items[now.children.items.len - 1];
                }
            }
        }
        pub fn search(self: *Self, keys: []const u8) ?T {
            var keys_clean = std.mem.split(u8, keys, "?");
            var keys_iter = std.mem.split(u8, keys_clean.first(), "/");
            var now = &self.root;
            while (keys_iter.next()) |key| {
                var last = keys_iter.peek() == null;
                for (now.children.items) |*item| {
                    if (std.mem.eql(u8, item.key, key) or
                        (if (item.key.len != 0) item.key[0] == ':' else false))
                    {
                        if (last) return item.value else now = item;
                        break;
                    }
                } else {
                    return null;
                }
            }
            return null;
        }
    };
}

test "NewTrie" {
    const testing = std.testing;
    const allocator = testing.allocator;
    var t = Trie(u32).init(allocator);
    defer t.deinit();

    try t.insert("/xd/lol/kek", 34);
    try t.insert("/", 42);
    try t.insert("/x/:oppo/dyn", 66);

    try testing.expect(t.search("/xd/lol/kek") == 34);
    try testing.expect(t.search("/") == 42);
    try testing.expect(t.search("/x/sperma/dyn?xd=2137") == 66);
    try testing.expect(t.search("/x/sperma") == null);
}

pub fn TireOld(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();
        allocator: Allocator,
        root: Node(K, V),
        eq_fn: *const fn (K, K) bool,
        pub fn init(allocator: Allocator, eq_fn: *const fn (K, K) bool) Self {
            return Self{
                .allocator = allocator,
                .root = Node(K, V).init(
                    allocator,
                    undefined,
                    null,
                ),
                .eq_fn = eq_fn,
            };
        }
        pub fn deinit(self: *Self) void {
            self.root.deinit();
        }
        pub fn insert(self: *Self, keys: []K, value: V) !void {
            var last = keys.len - 1;
            var now = &self.root;
            for (keys, 0..) |key, i| {
                for (now.children.items) |*item| {
                    if (self.eq_fn(key, item.key)) {
                        if (i == last) item.value = value else now = item;
                        break;
                    }
                } else {
                    try now.children.append(Node(K, V).init(
                        self.allocator,
                        key,
                        if (i == last) value else null,
                    ));
                    now = &now.children.items[now.children.items.len - 1];
                }
            }
        }
        pub fn search(self: *Self, keys: []K) ?V {
            var last = keys.len - 1;
            var now = &self.root;
            for (keys, 0..) |key, i| {
                for (now.children.items) |*item| {
                    if (self.eq_fn(key, item.key)) {
                        if (i == last) return item.value else now = item;
                        break;
                    }
                } else {
                    return null;
                }
            } else {
                return null;
            }
        }
    };
}

test "Trie" {
    // const testing = std.testing;
    // const allocator = testing.allocator;

    // var t = TireOld([]const u8, u32).init(allocator, test_eq);
    // defer t.deinit();

    // var k1 = try test_to_keys(allocator, "/");
    // defer k1.deinit();
    // try t.insert(k1.items, 34);

    // var k2 = try test_to_keys(allocator, "/hello");
    // defer k2.deinit();
    // try t.insert(k2.items, 42);

    // var k3 = try test_to_keys(allocator, "/hello/world");
    // defer k3.deinit();
    // try t.insert(k3.items, 69);

    // var k4 = try test_to_keys(allocator, "/world");
    // defer k4.deinit();

    // var k5 = try test_to_keys(allocator, "/hello/xd/world/");
    // defer k5.deinit();

    // var k6 = try test_to_keys(allocator, "/hello/world/xd");
    // defer k6.deinit();

    // try testing.expect(t.search(k1.items) == 34);
    // try testing.expect(t.search(k2.items) == 42);
    // try testing.expect(t.search(k3.items) == 69);

    // try testing.expect(t.search(k4.items) == null);
    // try testing.expect(t.search(k5.items) == null);
    // try testing.expect(t.search(k6.items) == null);
}
fn test_eq(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}
fn test_to_keys(allocator: Allocator, str: []const u8) !std.ArrayList([]const u8) {
    var keys = std.ArrayList([]const u8).init(allocator);
    var split = std.mem.split(u8, str, "/");
    while (split.next()) |x|
        try keys.append(x);
    return keys;
}
