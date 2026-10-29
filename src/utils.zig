const std = @import("std");

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

pub fn requireNumeric(comptime T: type) void {
    comptime switch (@typeInfo(T)) {
        .int, .float, .comptime_int, .comptime_float => {},
        else => @compileError(
            "operation requires a numeric element type, got " ++ @typeName(T),
        ),
    };
}

test "requireNumeric accepts int" {
    requireNumeric(i32);
}
