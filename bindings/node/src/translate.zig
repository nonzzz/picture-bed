const std = @import("std");
const c = @import("c.zig");

const TranslationError = error{
    ExceptionThrown,
};

pub fn throw(env: c.npai_env, comptime message: [:0]const u8) TranslationError {
    const result = c.napi_throw_error(env, null, @as([*c]const u8, @ptrCast(message)));
    switch (result) {
        c.napi_ok, c.napi_pending_exception => {},
        else => unreachable,
    }

    return TranslationError.ExceptionThrown;
}
