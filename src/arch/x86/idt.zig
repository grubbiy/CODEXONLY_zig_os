const std = @import("std");

pub const Entry = packed struct {
    offset_low: u16,
    selector: u16,
    zero: u8,
    type_attr: u8,
    offset_high: u16,
};

const Ptr = packed struct {
    limit: u16,
    base: u32,
};

var idt: [256]Entry = undefined;
var idt_ptr: Ptr = undefined;

pub fn setGate(index: u8, handler: usize, selector: u16, type_attr: u8) void {
    idt[index] = .{
        .offset_low = @truncate(handler & 0xFFFF),
        .selector = selector,
        .zero = 0,
        .type_attr = type_attr,
        .offset_high = @truncate((handler >> 16) & 0xFFFF),
    };
}

pub fn load() void {
    idt_ptr = .{
        .limit = @as(u16, @intCast(@sizeOf(@TypeOf(idt)) - 1)),
        .base = @as(u32, @intCast(@intFromPtr(&idt))),
    };
    asm volatile ("lidt (%[ptr])"
        :
        : [ptr] "r" (&idt_ptr),
        : .{ .memory = true });
}

pub fn init() void {
    idt = std.mem.zeroes(@TypeOf(idt));
    load();
}
