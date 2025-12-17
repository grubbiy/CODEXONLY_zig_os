const io = @import("../arch/x86/io.zig");
const interrupts = @import("../arch/x86/interrupts.zig");

pub var ticks: u32 = 0;

pub fn init(hz: u32) void {
    const divisor: u16 = @intCast(1193182 / hz);
    io.outb(0x43, 0x36);
    io.outb(0x40, @truncate(divisor & 0xFF));
    io.outb(0x40, @truncate((divisor >> 8) & 0xFF));
}

pub fn irqHandler(_: *interrupts.InterruptFrame) void {
    ticks += 1;
}
