const std = @import("std");

const ini = @import("zig-ini");

pub fn main() void {
    std.debug.print("{s}\n", .{"hello world"});
}
