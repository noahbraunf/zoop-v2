//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;

// pub const Tensor = @import("tensor.zig").Tensor;
// pub const TensorView = @import("tensor_view.zig").TensorView;

test {
    // _ = @import("tensor.zig");
    // _ = @import("tensor_view.zig");
    _ = @import("shape.zig");
}
