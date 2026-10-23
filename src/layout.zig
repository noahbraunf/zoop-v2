const std = @import("std");
const ShapeUtils = @import("shape.zig");

pub fn contiguousStrides(comptime rank: usize, shape: [rank]usize) error{Overflow}![rank]isize {
    if (rank == 0) return [0]isize{};
    var strides: [rank]isize = undefined;
    strides[rank - 1] = 1;
    var i = rank - 1;
    while (i > 0) : (i -= 1) {
        if (shape[i] <= std.math.maxInt(isize)) {
            const signed_shape: isize = @intCast(shape[i]);
            strides[i - 1] = try std.math.mul(isize, strides[i], signed_shape);
        } else {
            return error.Overflow;
        }
    }
    return strides;
}

test "contiguous rank 3 strides" {
    const shape = [3]usize{ 2, 3, 4 };
    const strides = contiguousStrides(3, shape);
    try std.testing.expectEqual([3]isize{ 12, 4, 1 }, strides);
}

test "contiguous rank 1 strides" {
    const shape = [1]usize{5};
    const strides = contiguousStrides(1, shape);
    try std.testing.expectEqual([1]isize{1}, strides);
}

test "contiguous rank 0 strides" {
    const strides = contiguousStrides(0, [0]usize{});
    try std.testing.expectEqual([0]isize{}, strides);
}

test "overflow example" {
    const shape = [3]usize{ 3, std.math.maxInt(isize), 4 };
    const strides = contiguousStrides(3, shape);
    try std.testing.expectError(error.Overflow, strides);
}

pub fn Layout(comptime rank: usize) type {
    return struct {
        pub const Rank = rank;
        const Self = @This();
        shape: [rank]usize,
        strides: [rank]isize,
        offset: isize = 0,

        pub fn initContiguous(shape: [Rank]usize) error{Overflow}!Self {
            return .{
                .shape = shape,
                .strides = try contiguousStrides(Rank, shape),
            };
        }

        pub fn elementCount(self: *Self) error{Overflow}!usize {
            return ShapeUtils.elementCount(self.shape);
        }

        pub fn transpose(self: *Self, axisA: usize, axisB: usize) error{IndexOutOfBounds}!void {
            if (axisA >= self.Rank or axisB >= self.Rank) {
                return error.IndexOutOfBounds;
            }
            std.mem.swap(usize, &self.shape[axisA], &self.shape[axisB]);
            std.mem.swap(isize, &self.strides[axisA], &self.strides[axisB]);
        }
    };
}
