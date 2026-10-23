const std = @import("std");

pub fn elementCount(shape: []const usize) ?usize {
    var prod: usize = 1;
    for (shape) |dim| {
        prod = std.math.mul(usize, prod, dim) catch return null;
    }
    return prod;
}

// fn assertArray(comptime T: type) void {
//     switch (@typeInfo(T)) {
//         .array => {},
//         else => @compileError("expected array type, got " ++ @typeName(T)),
//     }
// }

pub fn arrayRank(comptime T: type) usize {
    comptime switch (@typeInfo(T)) {
        .array => |arr| {
            var ChildType = @typeInfo(arr.child);
            var rank = 1;

            while (ChildType == .array) {
                rank += 1;

                ChildType = @typeInfo(ChildType.array.child);
            }

            return rank;
        },
        else => {
            return 0; // we assume everything else is a rank-0 element
        },
    };
}

pub fn arrayElementType(comptime T: type) type {
    comptime switch (@typeInfo(T)) {
        .array => |arr| {
            var ChildType = arr.child;
            var ChildTypeInfo = @typeInfo(arr.child);

            while (ChildTypeInfo == .array) {
                ChildType = ChildTypeInfo.array.child;
                ChildTypeInfo = @typeInfo(ChildTypeInfo.array.child);
            }

            return ChildType;
        },
        else => {
            return T;
        },
    };
}

pub fn arrayShape(comptime T: type) [arrayRank(T)]usize {
    comptime switch (@typeInfo(T)) {
        .array => |arr| {
            const rank = arrayRank(T);
            var shape: [rank]usize = undefined;
            var arrayInfo = arr;
            for (0..rank) |i| {
                shape[i] = arrayInfo.len;
                if (i != rank - 1) {
                    arrayInfo = @typeInfo(arrayInfo.child).array;
                }
            }
            return shape;
        },
        else => {
            return [0]usize{};
        },
    };
}

test "Array shape extraction" {
    try std.testing.expectEqual(comptime arrayShape(f32), [0]usize{});
    try std.testing.expectEqual(comptime arrayShape([4]f32), [1]usize{4});
    try std.testing.expectEqual(comptime arrayShape([4][2]f32), [2]usize{ 4, 2 });
    try std.testing.expectEqual(comptime arrayShape([4][0][2]f32), [3]usize{ 4, 0, 2 });
}

test "Array rank extraction" {
    try std.testing.expectEqual(comptime arrayRank(f32), 0);
    try std.testing.expectEqual(comptime arrayRank([4]f32), 1);
    try std.testing.expectEqual(comptime arrayRank([2][2]f32), 2);
    try std.testing.expectEqual(comptime arrayRank([2][2][3]f32), 3);
    try std.testing.expectEqual(comptime arrayRank(*[2][2][3]f32), 0);
}

test "Matrix element count" {
    try std.testing.expectEqual(@as(?usize, 12), elementCount(&[_]usize{ 3, 4 }));
    try std.testing.expectEqual(@as(?usize, 24), elementCount(&[_]usize{ 2, 3, 4 }));
    try std.testing.expectEqual(@as(?usize, 7), elementCount(&[_]usize{7}));
    try std.testing.expectEqual(@as(?usize, 1), elementCount(&[_]usize{}));
    try std.testing.expectEqual(@as(?usize, 0), elementCount(&[_]usize{ 1, 2, 3, 0 }));
    try std.testing.expectEqual(@as(?usize, null), elementCount(&[_]usize{ std.math.maxInt(usize), 2, 3 }));
}
