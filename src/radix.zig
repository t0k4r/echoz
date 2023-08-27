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
        fn deinitception(self: *Self) void {
            for (self.children.items) |child| {
                child.deinit();
            }
            self.children.deinit();
            if (self.value) |*v| {
                v.deinit();
            }
        }
    };
}

pub fn RadixTree(comptime T: type) type {
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
        pub fn deinitception(self: *Self) void {
            self.root.deinitception();
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

test "RadixTree" {
    const testing = std.testing;
    const allocator = testing.allocator;
    var t = RadixTree(u32).init(allocator);
    defer t.deinit();

    try t.insert("/xd/lol/kek", 34);
    try t.insert("/", 42);
    try t.insert("/x/:oppo/dyn", 66);

    try testing.expect(t.search("/xd/lol/kek") == 34);
    try testing.expect(t.search("/") == 42);
    try testing.expect(t.search("/x/sperma/dyn?xd=2137") == 66);
    try testing.expect(t.search("/x/sperma") == null);

    try t.insert("/x/:oppo", 69);
    try testing.expect(t.search("/x/sperma") == 69);
}
