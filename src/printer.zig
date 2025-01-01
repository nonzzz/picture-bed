const std = @import("std");
const ast = @import("./ast.zig");
const Parse = @import("./parse.zig").Parse;
const FmtOptions = @import("./fmt_options.zig").FmtOptions;

const AST = ast.AST;
const Node = ast.Node;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ArrayListUnmanaged = std.ArrayListUnmanaged;

fn line_less_than(_: @TypeOf(.{}), a: *Node, b: *Node) bool {
    if (a.loc.line == b.loc.line) {
        return a.loc.start < b.loc.start;
    }
    return a.loc.line < b.loc.line;
}

// Note: I have no time to implement a pretty printer. so this impl is opinionated.
pub const Printer = struct {
    const Self = @This();
    allocator: Allocator,
    sb: StringBuilder,
    fmt_options: FmtOptions,
    pub fn init(allocator: Allocator, options: FmtOptions) Self {
        return Self{
            .allocator = allocator,
            .sb = StringBuilder.init(allocator),
            .fmt_options = options,
        };
    }
    pub fn deinit(self: *Self) void {
        self.sb.deinit();
    }
    pub fn stringify(self: *Self, input: AST) anyerror!void {
        // var combined_nodes: ArrayListUnmanaged(*Node) = .{};

        // defer {
        //     for (combined_nodes.items) |n| {
        //         n.deinit(self.allocator);
        //     }
        //     combined_nodes.deinit(self.allocator);
        // }

        // var cloned_nodes = try input.nodes.clone(self.allocator);

        // defer {
        //     for (cloned_nodes.items) |cloned_node| {
        //         cloned_node.deinit(self.allocator);
        //     }
        //     cloned_nodes.deinit(self.allocator);
        // }
        // const cloned_comments = try input.comments.clone(self.allocator);
        // _ = cloned_comments; // autofix
        // try combined_nodes.appendSlice(self.allocator, cloned_nodes.items);
        // try combined_nodes.appendSlice(self.allocator, cloned_comments.items);

        // std.mem.sort(*Node, combined_nodes.items, .{}, line_less_than);
        for (input.nodes.items) |node| {
            try self.print_node(node);
        }

        try self.print('\n');
    }
    inline fn print_paris(self: *Self, node: *Node) anyerror!void {
        const p: *Node.Pairs = @fieldParentPtr("base", node);
        try self.print(p.decl.value);
        try self.print(' ');
        try self.print('=');
        try self.print(' ');
        const quote = switch (self.fmt_options.quote_style) {
            .single => "'",
            .double => "\"",
            .none => "",
        };
        if (p.flag == .none) {
            try self.print(quote);
            try self.print(p.init.value);
            try self.print(quote);
        } else {
            try self.print(quote);
            try self.print(p.init.value[1..(p.init.value.len - 1)]);
            try self.print(quote);
        }
    }
    inline fn print_section(self: *Self, node: *Node) anyerror!void {
        const p: *Node.Section = @fieldParentPtr("base", node);
        try self.print('[');
        try self.print(p.name.value);
        try self.print(']');
        for (p.children.items) |child| {
            try self.print_node(child);
        }
    }

    fn print_node(self: *Self, node: *Node) anyerror!void {
        if (node.loc.line >= 1) {
            try self.print('\n');
        }
        switch (node.kind) {
            .pairs => try self.print_paris(node),
            .section => try self.print_section(node),
            .comment => {
                const ch = switch (self.fmt_options.comment_style) {
                    .semi => ";",
                    .hash => "#",
                };
                const p: *Node.Comment = @fieldParentPtr("base", node);
                try self.print(ch);
                try self.print(p.text);
            },
            else => unreachable,
        }
    }
    inline fn print(self: *Self, data: anytype) anyerror!void {
        try self.sb.write(data);
    }
};

const StringBuilder = struct {
    const Self = @This();
    s: ArrayList(u8),
    allocator: Allocator,
    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .s = ArrayList(u8).init(allocator),
        };
    }
    pub fn deinit(self: *Self) void {
        self.s.deinit();
    }

    pub fn write_str(self: *Self, str: []const u8) !void {
        for (str) |b| {
            try self.s.append(b);
        }
    }
    pub fn write_byte(self: *Self, byte: comptime_int) !void {
        try self.s.append(byte);
    }
    pub fn write(self: *Self, data: anytype) !void {
        const T = @TypeOf(data);
        switch (@typeInfo(T)) {
            .Int, .ComptimeInt => try self.write_byte(data),
            .Pointer => |ptr| switch (ptr.size) {
                .One, .Slice => try self.write_str(data),
                else => @compileError("Unsupported pointer type"),
            },
            else => @compileError("Unsupported type"),
        }
    }
};

test "StringBuilder" {
    var sb = StringBuilder.init(std.testing.allocator);
    defer sb.deinit();
    try sb.write(48);
    try sb.write(48);
    try sb.write("000");
    try std.testing.expect(std.mem.eql(u8, sb.s.items, "00000"));
}

fn TestPrinter(fixture_name: []const u8, allocator: Allocator) !void {
    const cwd = try std.process.getCwdAlloc(allocator);
    const path = try std.fs.path.join(allocator, &[_][]const u8{ cwd, "/ini/", fixture_name });
    const content = try std.fs.cwd().readFileAlloc(allocator, path, std.math.maxInt(usize));
    defer {
        allocator.free(cwd);
        allocator.free(path);
        allocator.free(content);
    }
    var parse = Parse.init(allocator);
    defer parse.deinit();
    try parse.parse(content);
    var printer = Printer.init(allocator, .{});
    defer printer.deinit();
    try printer.stringify(parse.ast);
    // std.debug.print("{s}", .{printer.sb.s.items});
}

test "Printer" {
    try TestPrinter("base.ini", std.testing.allocator);
    try TestPrinter("section.ini", std.testing.allocator);
    try TestPrinter("comment.ini", std.testing.allocator);
}
