const std = @import("std");

const print = std.debug.print;
const Allocator = std.mem.Allocator;

fn TireNode(comptime K: type, comptime V: type) type {
    return struct {
        children: std.ArrayList(TireNode(K, V)),
        key: K,
        value: ?V,
    };
}

pub fn Tire(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();
        allocator: Allocator,
        root: TireNode(K, V),
        eq_fn: *const fn (K, K) bool,
        pub fn init(allocator: Allocator, eq_fn: *const fn (K, K) bool) Self {
            return Self{
                .allocator = allocator,
                .root = TireNode(K, V){
                    .children = std.ArrayList(TireNode(K, V)).init(allocator),
                    .value = null,
                    .key = undefined,
                },
                .eq_fn = eq_fn,
            };
        }
        pub fn insert(self: *Self, keys: []K, value: V) !void {
            var last = keys.len - 1;
            var now = &self.root;
            for (keys, 0..) |key, i| {
                for (now.children.items) |*item| {
                    if (self.eq_fn(key, item.key)) {
                        if (i == last) {
                            item.value = value;
                        } else {
                            now = item;
                        }
                        break;
                    }
                } else {
                    try now.children.append(TireNode(K, V){
                        .children = std.ArrayList(TireNode(K, V)).init(self.allocator),
                        .value = if (i == last) value else null,
                        .key = key,
                    });
                    now = &now.children.items[now.children.items.len - 1];
                }
            }
        }
        pub fn search(self: *Self, keys: []K) ?V {
            _ = keys;
            _ = self;
            return null;
        }
    };
}

// const TrieNode = struct {
//     children: []TrieNode,
//     value: []const u8,
// };

// const Trie = @This();
// root: []TrieNode,key

// pub fn init() Trie {
//     // std.ArrayList(comptime T: type)
//     return .{ .root = []TrieNode{} };
// }

// pub fn insert(self: *Trie, value: []const u8) void {
//     _ = value;
//     if (self.root.len == 0) {

//     } else {}
// }
