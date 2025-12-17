const io = @import("../arch/x86/io.zig");

const pic1_cmd: u16 = 0x20;
const pic1_data: u16 = 0x21;
const pic2_cmd: u16 = 0xA0;
const pic2_data: u16 = 0xA1;

const icw1_init: u8 = 0x10;
const icw1_icw4: u8 = 0x01;
const icw4_8086: u8 = 0x01;

pub fn remap(offset1: u8, offset2: u8) void {
    const a1 = io.inb(pic1_data);
    const a2 = io.inb(pic2_data);

    io.outb(pic1_cmd, icw1_init | icw1_icw4);
    io.ioWait();
    io.outb(pic2_cmd, icw1_init | icw1_icw4);
    io.ioWait();

    io.outb(pic1_data, offset1);
    io.ioWait();
    io.outb(pic2_data, offset2);
    io.ioWait();

    io.outb(pic1_data, 4);
    io.ioWait();
    io.outb(pic2_data, 2);
    io.ioWait();

    io.outb(pic1_data, icw4_8086);
    io.ioWait();
    io.outb(pic2_data, icw4_8086);
    io.ioWait();

    io.outb(pic1_data, a1);
    io.outb(pic2_data, a2);
}

pub fn sendEoi(irq: u8) void {
    if (irq >= 8) io.outb(pic2_cmd, 0x20);
    io.outb(pic1_cmd, 0x20);
}

pub fn setMask(irq: u8) void {
    const port: u16 = if (irq < 8) pic1_data else pic2_data;
    const bit: u3 = @truncate(irq & 7);
    const value = io.inb(port) | (@as(u8, 1) << bit);
    io.outb(port, value);
}

pub fn clearMask(irq: u8) void {
    const port: u16 = if (irq < 8) pic1_data else pic2_data;
    const bit: u3 = @truncate(irq & 7);
    const value = io.inb(port) & ~(@as(u8, 1) << bit);
    io.outb(port, value);
}
