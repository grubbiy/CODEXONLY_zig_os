const io = @import("../arch/x86/io.zig");

pub const ExitCode = enum(u32) {
    success = 0x10,
    failure = 0x11,
};

pub fn exit(code: ExitCode) noreturn {
    @setRuntimeSafety(false);
    io.outl(0xF4, @intFromEnum(code));
    io.halt();
}
