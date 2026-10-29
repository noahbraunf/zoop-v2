const std = @import("std");
const ShapeUtils = @import("shape.zig");
const Utils = @import("utils.zig");

// pub const TensorOptions = struct {
//     layout: enum { RowMajor, ColumnMajor }
// };

pub fn Tensor(comptime T: type, comptime rank: usize) type {
    return struct {
        pub const Rank = rank;
        pub const ElementType = T;

        const Self = @This();

        data: []T,
        shape: [Rank]usize,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, shape: [Rank]usize) error{ Overflow, OutOfMemory }!Self {
            const data = try allocator.alloc(T, ShapeUtils.elementCount(shape));
            return .{
                .data = data,
                .shape = shape,
                .allocator = allocator,
            };
        }

        pub fn initFilled(allocator: std.mem.Allocator, shape: [Rank]usize, value: T) error{ Overflow, OutOfMemory }!Self {
            const elementCount = try ShapeUtils.elementCount(shape);
            const data = try allocator.alloc(T, elementCount);
            @memset(&data, value);
            return .{
                .data = data,
                .shape = shape,
                .allocator = allocator,
            };
        }

        pub fn initZeroes(allocator: std.mem.Allocator, shape: [Rank]usize) error{ Overflow, OutOfMemory }!Self {
            return initFilled(allocator, shape, std.mem.zeroes(T));
        }
        pub fn initOnes(allocator: std.mem.Allocator, shape: [Rank]usize) error{ Overflow, OutOfMemory }!Self {
            Utils.requireNumeric(T);
            return initFilled(allocator, shape, @as(T, 1));
        }

        pub fn clone(self: *Self) error{OutOfMemory}!Self {
            const newData = try self.allocator.alloc(T, self.shape.len);
            @memcpy(&newData, &self.data);
            return .{
                .data = newData,
                .shape = self.shape,
                .allocator = self.allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.data);
            self.shape = undefined;
            self.allocator = undefined;
            self.* = undefined;
        }

        pub fn numElements(self: *Self) usize {
            return ShapeUtils.elementCount(self.shape);
        }
    };
}
