const std = @import("std");
const Layout = @import("layout.zig").Layout;
const ShapeUtils = @import("shape.zig");

pub fn TensorView(comptime T: type, comptime rank: usize) type {
    return struct {
        const Self = @This();
        pub const Rank = rank;

        layout: Layout(rank),
        data_view: []T,

        pub fn fromSliceConst(slice: []const T, layout: Layout(Rank)) error{LengthMismatch}!Self {
            if (slice.len != try layout.elementCount()) {
                return error.LengthMismatch;
            }
            return .{
                .layout = layout,
                .data_view = slice,
            };
        }

        pub fn fromSlice(slice: []T, layout: Layout(Rank)) error{LengthMismatch}!Self {
            if (slice.len != try layout.elementCount()) {
                return error.LengthMismatch;
            }
            return .{
                .layout = layout,
                .data_view = slice,
            };
        }

        pub fn fromArray(arr: anytype) error{Overflow}!Self {
            const PtrType = @TypeOf(arr);
            const ptr_info = switch (@typeInfo(PtrType)) {
                .pointer => |p| p,
                else => @compileError("Expected pointer type"),
            };
            if (ptr_info.size != .one) {
                @compileError("Expected pointer to an array, got slice");
            }
            if (ptr_info.attrs.@"const") {
                @compileError("Cannot create a mutable view from a const array");
            }

            const ArrayType = ptr_info.child;
            comptime {
                if (ShapeUtils.arrayRank(ArrayType) != Rank) {
                    @compileError("Array rank does not match TensorView");
                }

                if (ShapeUtils.arrayElementType(ArrayType) != T) {
                    @compileError("Array element type does not match TensorView");
                }
            }

            const shape = comptime ShapeUtils.arrayShape(ArrayType);
            const layout = try Layout(Rank).initContiguous(shape);
            const len = try layout.elementCountConst();

            const ptr: [*]T = @ptrCast(arr); // we need to cast from array back to pointer

            return .{
                .layout = layout,
                .data_view = ptr[0..len],
            };
        }
    };
}

test "TensorView.fromArray" {
    var arr = [2][3]f32{
        .{ 1, 2, 3 },
        .{ 4, 5, 6 },
    };

    const view = try TensorView(f32, 2).fromArray(&arr);

    try std.testing.expectEqualSlices(
        usize,
        &.{ 2, 3 },
        &view.layout.shape,
    );

    try std.testing.expectEqualSlices(
        isize,
        &.{ 3, 1 },
        &view.layout.strides,
    );

    try std.testing.expectEqualSlices(
        f32,
        &.{ 1, 2, 3, 4, 5, 6 },
        view.data_view,
    );

    view.data_view[4] = 42;

    try std.testing.expectEqual(42.0, arr[1][1]);
}
