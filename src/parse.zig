const std = @import("std");
const lex = @import("./lex.zig");
const ast = @import("./ast.zig");

const Token = lex.Token;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const AST = ast.AST;
const Loc = ast.Loc;
const Node = ast.Node;

pub const ParseError = error{
    InvalidPairs, // like missing init
    InvalidSection,
    UnexpectedToken,
} || Allocator.Error;

pub const Parse = struct {
    allocator: Allocator,
    ast: AST,
    tokens: []Token,
    source: []const u8,
    pos: usize,
    const Self = @This();
    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .tokens = undefined,
            .ast = .{},
            .source = undefined,
            .pos = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.tokens);
        for (self.ast.nodes.items) |node| {
            node.deinit(self.allocator);
        }
        for (self.ast.comments.items) |node| {
            node.deinit(self.allocator);
        }
        self.ast.nodes.deinit(self.allocator);
        self.ast.comments.deinit(self.allocator);
    }

    pub fn parse(self: *Self, buffer: []const u8) !void {
        var tokens = try lex.Tokenizer(buffer, self.allocator);
        defer tokens.deinit();
        self.tokens = try tokens.toOwnedSlice();
        self.source = buffer;
        loop: while (true) {
            switch (self.current().kind) {
                .end_of_file => {
                    break :loop;
                },
                .string => {
                    const pairs = try self.consume_key_value_pairs();
                    try self.ast.nodes.append(self.allocator, pairs);
                },
                .comment => {
                    const comment = try self.consume_comment();
                    try self.ast.comments.append(self.allocator, comment);
                },
                .open_bracket => {
                    const section = try self.consume_section();
                    try self.ast.nodes.append(self.allocator, section);
                },
                else => self.advance(),
            }
        }
    }

    fn consume_key_value_pairs(self: *Self) ParseError!*Node {
        const node = try self.allocator.create(Node.Pairs);
        errdefer self.allocator.destroy(node);
        node.* = .{};

        node.decl = self.consume_identifer();

        loop: while (true) {
            switch (self.current().kind) {
                .end_of_file => {
                    break :loop;
                },
                .comment => {
                    break :loop;
                },
                .open_bracket => {
                    break :loop;
                },
                .equal => {
                    _ = self.eat(.whitespace);
                    _ = self.eat(.string);
                    node.flag = self.current().flag;
                    node.init = self.consume_identifer();

                    node.base.loc = Loc.create(node.decl.base.loc.line, node.decl.base.loc.start, node.init.base.loc.end);
                    break :loop;
                },
                .whitespace => self.advance(),
                .break_line => {
                    self.advance();
                    break :loop;
                },
                else => {
                    return error.UnexpectedToken;
                },
            }
        }
        return &node.base;
    }

    fn consume_comment(self: *Self) !*Node {
        const node = try self.allocator.create(Node.Comment);
        errdefer self.allocator.destroy(node);
        node.* = .{};
        node.flag = self.current().flag;

        const comment_token = self.current();
        const comment_raw = self.decode_text();

        node.base.loc = Loc.create(comment_token.line_number, comment_token.start, comment_token.end);
        node.text = comment_raw;

        self.advance();

        return &node.base;
    }

    fn consume_section(self: *Self) ParseError!*Node {
        const start_token = self.current();

        _ = self.eat(.whitespace);

        self.advance();

        const node = try self.allocator.create(Node.Section);

        errdefer self.allocator.destroy(node);

        errdefer {
            for (node.children.items) |child| {
                child.deinit(self.allocator);
            }
            node.children.deinit(self.allocator);
        }

        node.* = .{};
        node.name = self.consume_identifer();
        if (self.current().kind == .whitespace) {
            self.advance();
        }
        self.advance();
        if (self.peek().kind == .close_bracket) {
            return error.InvalidSection;
        }
        loop: while (true) {
            switch (self.current().kind) {
                .break_line => {
                    self.advance();
                },
                .whitespace => self.advance(),
                .string => {
                    const pairs = try self.consume_key_value_pairs();
                    try node.children.append(self.allocator, pairs);
                },
                .comment => {
                    const comment = try self.consume_comment();
                    try self.ast.comments.append(self.allocator, comment);
                },
                .open_bracket => {
                    break :loop;
                },
                .end_of_file => {
                    break :loop;
                },
                else => {
                    return error.UnexpectedToken;
                },
            }
        }
        node.base.loc = Loc.create(start_token.line_number, start_token.start, self.current().end);
        return &node.base;
    }

    inline fn consume_identifer(self: *Self) Node.Identifer {
        const start_token = self.current();
        while (true) {
            switch (self.peek().kind) {
                .break_line => break,
                .end_of_file => break,
                .comment => break,
                .open_bracket => break,
                .equal => break,
                .close_bracket => break,
                .whitespace => {
                    self.advance();
                    if (self.peek().kind == .equal or self.peek().kind == .close_bracket) {
                        self.pos -= 1;
                        break;
                    }
                },
                else => {
                    if (start_token.kind == .string and (start_token.flag == .single_quote or start_token.flag == .double_quote)) {
                        break;
                    }
                    self.advance();
                },
            }
        }
        const end_token = self.current();
        const node = Node.Identifer{
            .base = .{
                .kind = .identifer,
                .loc = Loc.create(start_token.line_number, start_token.start, end_token.end),
            },
            .value = self.source[start_token.start..end_token.end],
        };
        self.advance();
        return node;
    }

    inline fn advance(self: *Self) void {
        if (self.pos >= self.tokens.len) {
            return;
        }
        self.pos += 1;
    }
    inline fn current(self: *Self) Token {
        if (self.pos >= self.tokens.len) {
            return Token.init();
        }
        return self.tokens[self.pos];
    }
    inline fn peek(self: *Self) Token {
        if (self.pos >= self.tokens.len - 1) {
            return Token.init();
        }
        return self.tokens[self.pos + 1];
    }
    inline fn eat(self: *Self, kind: Token.Kind) bool {
        if (self.peek().kind == kind) {
            self.advance();
            return true;
        }
        return false;
    }
    inline fn decode_text(self: *Self) []const u8 {
        const token = self.current();
        return self.source[token.start..token.end];
    }
};

fn TestParse(fixture_name: []const u8, allocator: Allocator, expects: []const Node.NodeKind, comments: []const Node.NodeKind) !void {
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

    if (expects.len > 0) {
        std.debug.assert(parse.ast.nodes.items.len >= expects.len);
        for (expects, 0..) |expect, idx| {
            try std.testing.expectEqual(expect, parse.ast.nodes.items[idx].kind);
        }
    }
    if (comments.len > 0) {
        std.debug.assert(parse.ast.comments.items.len >= comments.len);
        for (comments, 0..) |expect, idx| {
            try std.testing.expectEqual(expect, parse.ast.comments.items[idx].kind);
        }
    }
}

test "Parse" {
    try TestParse("base.ini", std.testing.allocator, &[_]Node.NodeKind{ .pairs, .pairs, .pairs }, &[_]Node.NodeKind{});
    try TestParse("comment.ini", std.testing.allocator, &[_]Node.NodeKind{.pairs}, &[_]Node.NodeKind{
        .comment,
        .comment,
    });
    try TestParse("section.ini", std.testing.allocator, &[_]Node.NodeKind{.section}, &[_]Node.NodeKind{});
}
