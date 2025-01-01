pub const FmtOptions = struct {
    quote_style: QuoteStyle = .double,
    comment_style: CommentStyle = .hash,
    pub const QuoteStyle = enum(u3) {
        single,
        double,
        none,
    };
    pub const CommentStyle = enum(u3) {
        semi,
        hash,
    };
};
