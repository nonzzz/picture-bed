const std = @import("std");
const ini = @import("zig-ini");

const wasm_alloc = std.heap.wasm_allocator;

export fn format(s: [*]u8, len: usize, cap: usize) i32 {
    _ = cap; // autofix
    const input = s[0..len];
    var parser = ini.Parse.init(wasm_alloc);
    var printer = ini.Printer.init(wasm_alloc, .{});
    defer {
        parser.deinit();
        printer.deinit();
    }
    // todo
    parser.parse(input) catch return -1;
    printer.stringify(parser.ast) catch return -1;

    std.mem.copyBackwards(u8, s[0..printer.sb.s.items.len], printer.sb.s.items);
    return @as(i32, @intCast(printer.sb.s.items.len));
}
