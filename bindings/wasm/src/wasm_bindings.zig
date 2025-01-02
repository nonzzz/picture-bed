const std = @import("std");
const ini = @import("zig-ini");

const wasm_alloc = std.heap.wasm_allocator;

export fn format(
    input_ptr: [*]u8,
    input_len: usize,
    opts_ptr: [*]u8,
    opts_len: usize,
) i32 {
    const input = input_ptr[0..input_len];
    const opts_str = opts_ptr[0..opts_len];
    var opts = std.json.parseFromSlice(
        ini.FmtOptions,
        wasm_alloc,
        opts_str,
        .{},
    ) catch return -2;
    defer opts.deinit();
    var parser = ini.Parse.init(wasm_alloc);
    var printer = ini.Printer.init(wasm_alloc, .{
        .comment_style = opts.value.comment_style,
        .quote_style = opts.value.quote_style,
    });
    defer {
        parser.deinit();
        printer.deinit();
    }
    // todo
    parser.parse(input) catch return -1;
    printer.stringify(parser.ast) catch return -1;

    std.mem.copyBackwards(u8, input_ptr[0..printer.sb.s.items.len], printer.sb.s.items);
    return @as(i32, @intCast(printer.sb.s.items.len));
}
