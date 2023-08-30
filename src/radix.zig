const std = @import("std");
const Allocator = std.mem.Allocator;

const Node = struct {
    const Self = @This();
    children: std.ArrayList(Node),
    key: []const u8,
    index: ?usize,
    fn init(allocator: Allocator, key: []const u8, index: ?usize) Self {
        return Self{
            .children = std.ArrayList(Node).init(allocator),
            .key = key,
            .index = index,
        };
    }
    fn deinit(self: Self) void {
        for (self.children.items) |child| {
            child.deinit();
        }
        self.children.deinit();
    }
};

pub fn RadixTree(comptime T: type) type {
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
        pub fn deinitception(self: *Self) void {
            self.root.deinit();
            for (self.values.items) |*item| {
                item.deinit();
            }
            self.values.deinit();
        }
        pub fn insert(self: *Self, keys: []const u8, value: T) !void {
            var keys_iter = std.mem.split(u8, keys, "/");
            var now = &self.root;
            while (keys_iter.next()) |key| {
                var last = keys_iter.peek() == null;
                for (now.children.items) |*item| {
                    if (std.mem.eql(u8, item.key, key) or
                        std.mem.eql(u8, item.key, "*") or
                        (if (item.key.len != 0) item.key[0] == ':' else false))
                    {
                        if (last) {
                            if (item.index) |i| {
                                self.values.items[i] = value;
                            } else {
                                item.index = self.values.items.len;
                                try self.values.append(value);
                            }
                        } else {
                            now = item;
                        }
                        break;
                    }
                } else {
                    if (last) {
                        try now.children.append(Node.init(
                            self.allocator,
                            key,
                            self.values.items.len,
                        ));
                        try self.values.append(value);
                    } else {
                        try now.children.append(Node.init(
                            self.allocator,
                            key,
                            null,
                        ));
                    }
                    now = &now.children.items[now.children.items.len - 1];
                }
            }
        }
        fn search_index(self: *Self, keys: []const u8) ?usize {
            var keys_clean = std.mem.split(u8, keys, "?");
            var keys_iter = std.mem.split(u8, keys_clean.first(), "/");
            var now = &self.root;
            while (keys_iter.next()) |key| {
                var last = keys_iter.peek() == null;
                for (now.children.items) |*item| {
                    if (std.mem.eql(u8, item.key, key) or
                        std.mem.eql(u8, item.key, "*") or
                        (if (item.key.len != 0) item.key[0] == ':' else false))
                    {
                        if (last) {
                            return if (item.index) |i| i else null;
                        } else {
                            now = item;
                        }
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

    try testing.expect(t.searchPtr("/xd/lol/kek").?.* == 34);
    try testing.expect(t.search("/") == 42);
    try testing.expect(t.search("/x/sperma/dyn?xd=2137") == 66);
    try testing.expect(t.search("/x/sperma") == null);

    try t.insert("/x/:oppo", 69);
    try testing.expect(t.search("/x/sperma") == 69);
}
