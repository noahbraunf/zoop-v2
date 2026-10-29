const std = @import("std");
const ShapeUtils = @import("shape.zig");
const Utils = @import("utils.zig");

/// Representation of the underlying layout of a `Tensor` or `TensorView`.
///
/// Since both `Tensor` and `TensorView` are represented "under the hood" by
/// a contiguous array(slice) (i.e. []T), we need to be able to easily convert
/// between the layout and the underlying array. This makes it easier, especially
/// for arrays with wildly different layouts and striding. It also is useful because
/// it detaches the way the data is traversed from the way the data is stored.
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
                .strides = try Utils.contiguousStrides(Rank, shape),
            };
        }

        /// Calculate the offset to index into a bit of memory which is accessible from the given `Layout`
        ///
        /// Parameters:
        /// - `self: *Self`:
        /// - `indices: [Rank]usize`: index corresponding to element in array
        ///
        /// Returns (`error{ IndexOutOfBounds, Overflow }!isize`): [TODO:return]
        ///
        /// Errors (`error{ IndexOutOfBounds, Overflow }`): [TODO:throw]
        /// - `error.IndexOutOfBounds`: [TODO:throw]
        /// - `error.Overflow`: [TODO:throw]
        pub fn physicalOffset(self: *Self, indices: [Rank]usize) error{ IndexOutOfBounds, Overflow }!isize {
            var pOffset: isize = 0;
            for (indices, 0..) |index, i| {
                if (index >= self.shape[i]) {
                    return error.IndexOutOfBounds;
                }

                if (index >= std.math.maxInt(usize)) {
                    return error.Overflow;
                }

                pOffset += try std.math.mul(isize, self.strides[i], @intCast(index));
            }

            return std.math.add(isize, self.offset, pOffset);
        }

        pub fn elementCount(self: *Self) error{Overflow}!usize {
            return ShapeUtils.elementCount(self.shape);
        }

        pub fn transpose(self: *Self, axisA: usize, axisB: usize) error{IndexOutOfBounds}!void {
            if (axisA >= Rank or axisB >= Rank) {
                return error.IndexOutOfBounds;
            }
            std.mem.swap(usize, &self.shape[axisA], &self.shape[axisB]);
            std.mem.swap(isize, &self.strides[axisA], &self.strides[axisB]);
        }

        // TODO: Correctly implement `permute` such that it swaps indices correctly
        pub fn permute(self: *Self, indices: [Rank]usize) !void {
            const tempShape = self.shape;
            const tempStrides = self.strides;
            for (indices, 0..) |index, i| {
                if (index >= Rank) {
                    return error.IndexOutOfBounds;
                }
                self.shape[i] = tempShape[index];
                self.strides[i] = tempStrides[index];
            }
        }

        pub fn reverseAxis(self: *Self, axis: usize) error{ IndexOutOfBounds, Overflow }!void {
            comptime if (Rank > std.math.maxInt(isize)) {
                return error.Overflow;
            };

            if (axis >= Rank) {
                return error.IndexOutOfBounds;
            }

            self.offset = try std.math.add(isize, self.offset, try std.math.mul(isize, @intCast(Rank - 1), self.strides[axis]));
            self.strides[axis] = -self.strides[axis];
        }
    };
}

test "reverse axis" {
    var layout = try Layout(3).initContiguous([3]usize{ 2, 3, 4 });
    const physicalOffset = try layout.physicalOffset([3]usize{ 1, 1, 1 });
    try layout.reverseAxis(0);
    try std.testing.expectEqualSlices(usize, &[3]usize{ 2, 3, 4 }, &layout.shape);
    try std.testing.expectEqualSlices(isize, &[3]isize{ -12, 4, 1 }, &layout.strides);
    try std.testing.expectEqual(physicalOffset, try layout.physicalOffset([3]usize{ 1, 1, 1 }));
    try layout.reverseAxis(1);
    try std.testing.expectEqualSlices(isize, &[3]isize{ -12, -4, 1 }, &layout.strides);
    try std.testing.expectEqual(physicalOffset, try layout.physicalOffset([3]usize{ 1, 1, 1 }));
    try layout.reverseAxis(2);
    try std.testing.expectEqualSlices(isize, &[3]isize{ -12, -4, -1 }, &layout.strides);
    try std.testing.expectEqual(physicalOffset, try layout.physicalOffset([3]usize{ 1, 1, 1 }));
}

test "double reverse is involution" {
    var layout = try Layout(3).initContiguous([3]usize{ 2, 3, 4 });
    try layout.reverseAxis(0);
    try layout.reverseAxis(0);
    try std.testing.expectEqualSlices(usize, &[3]usize{ 2, 3, 4 }, &layout.shape);
    try std.testing.expectEqualSlices(isize, &[3]isize{ 12, 4, 1 }, &layout.strides);
}

test "double transpose is involution" {
    var layout = try Layout(3).initContiguous([3]usize{ 2, 3, 4 });
    try layout.transpose(0, 1);
    try layout.transpose(0, 1);
    try std.testing.expectEqualSlices(usize, &[3]usize{ 2, 3, 4 }, &layout.shape);
    try std.testing.expectEqualSlices(isize, &[3]isize{ 12, 4, 1 }, &layout.strides);
}
test "transpose layout" {
    var layout = try Layout(2).initContiguous([2]usize{ 2, 3 });
    try layout.transpose(0, 1);
    try std.testing.expectEqualSlices(usize, &[2]usize{ 3, 2 }, &layout.shape);
    try std.testing.expectEqualSlices(isize, &[2]isize{ 1, 3 }, &layout.strides);
}

test "double permutation is involution" {
    var layout = try Layout(3).initContiguous([3]usize{ 2, 3, 4 });
    try layout.permute([3]usize{ 2, 0, 1 });
    try layout.permute([3]usize{ 1, 2, 0 });
    try std.testing.expectEqualSlices(usize, &[3]usize{ 2, 3, 4 }, &layout.shape);
    try std.testing.expectEqualSlices(isize, &[3]isize{ 12, 4, 1 }, &layout.strides);
}

test "permute layout" {
    var layout = try Layout(3).initContiguous([3]usize{ 2, 3, 4 });
    const physicalOffset = try layout.physicalOffset([3]usize{ 1, 2, 3 });
    try layout.permute([3]usize{ 2, 0, 1 });
    try std.testing.expectEqualSlices(usize, &[3]usize{ 4, 2, 3 }, &layout.shape);
    try std.testing.expectEqualSlices(isize, &[3]isize{ 1, 12, 4 }, &layout.strides);
    try std.testing.expectEqual(physicalOffset, try layout.physicalOffset([3]usize{ 3, 1, 2 }));
}
