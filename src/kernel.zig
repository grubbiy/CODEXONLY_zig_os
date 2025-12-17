const std = @import("std");

const vga_width = 80;
const vga_height = 25;
const vga_buffer = @intToPtr([*]volatile u16, 0xb8000);

const Color = enum(u8) {
    Black = 0,
    Blue = 1,
    Green = 2,
    Cyan = 3,
    Red = 4,
    Magenta = 5,
    Brown = 6,
    LightGrey = 7,
    DarkGrey = 8,
    LightBlue = 9,
    LightGreen = 10,
    LightCyan = 11,
    LightRed = 12,
    LightMagenta = 13,
    Yellow = 14,
    White = 15,
};

fn vgaEntry(char: u8, fg: Color, bg: Color) u16 {
    return @as(u16, char) | (@as(u16, @intFromEnum(fg)) << 8) | (@as(u16, @intFromEnum(bg)) << 12);
}

fn vgaClear(fg: Color, bg: Color) void {
    const value = vgaEntry(' ' as u8, fg, bg);
    var i: usize = 0;
    while (i < vga_width * vga_height) : (i += 1) {
        vga_buffer[i] = value;
    }
}

fn vgaWriteAt(x: usize, y: usize, char: u8, fg: Color, bg: Color) void {
    if (x >= vga_width or y >= vga_height) return;
    const idx = y * vga_width + x;
    vga_buffer[idx] = vgaEntry(char, fg, bg);
}

fn vgaWriteStringAt(x: usize, y: usize, text: []const u8, fg: Color, bg: Color) void {
    var i: usize = 0;
    var cx = x;
    while (i < text.len and cx < vga_width) : (i += 1, cx += 1) {
        vgaWriteAt(cx, y, text[i], fg, bg);
    }
}

fn outb(port: u16, value: u8) void {
    asm volatile ("outb %[value], %[port]" :: [value] "a" (value), [port] "Nd" (port));
}

fn inb(port: u16) u8 {
    var value: u8 = undefined;
    asm volatile ("inb %[port], %[value]" : [value] "=a" (value) : [port] "Nd" (port));
    return value;
}

fn serialInit(base: u16) void {
    outb(base + 1, 0x00); // disable interrupts
    outb(base + 3, 0x80); // enable DLAB
    outb(base + 0, 0x03); // divisor low byte (38400 baud)
    outb(base + 1, 0x00); // divisor high byte
    outb(base + 3, 0x03); // 8 bits, no parity, one stop bit
    outb(base + 2, 0xC7); // enable FIFO
    outb(base + 4, 0x0B); // IRQs enabled, RTS/DSR set
}

fn serialCanTransmit(base: u16) bool {
    return (inb(base + 5) & 0x20) != 0;
}

fn serialWriteByte(base: u16, byte: u8) void {
    while (!serialCanTransmit(base)) {}
    outb(base, byte);
}

fn serialWrite(base: u16, text: []const u8) void {
    for (text) |ch| serialWriteByte(base, ch);
}

fn hang() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}

const MULTIBOOT_MAGIC = 0x2BADB002;

pub export fn kmain(magic: u32, info_ptr: u32) callconv(.C) void {
    vgaClear(.LightGrey, .Black);
    vgaWriteStringAt(0, 0, "Zig kernel booting...", .LightGreen, .Black);

    serialInit(0x3F8);
    serialWrite(0x3F8, "[serial] Zig kernel starting\r\n");

    if (magic != MULTIBOOT_MAGIC) {
        serialWrite(0x3F8, "[serial] invalid multiboot magic!\r\n");
        vgaWriteStringAt(0, 2, "Bad multiboot magic.", .LightRed, .Black);
        hang();
    }

    vgaWriteStringAt(0, 2, "Multiboot magic OK", .White, .Black);

    const info_addr = info_ptr;
    serialWrite(0x3F8, "[serial] multiboot info at 0x");
    var buf: [10]u8 = undefined;
    const len = std.fmt.formatIntBuf(&buf, info_addr, 16, .lower, .{});
    serialWrite(0x3F8, buf[0..len]);
    serialWrite(0x3F8, "\r\n");

    vgaWriteStringAt(0, 4, "Serial logging on COM1", .LightCyan, .Black);
    vgaWriteStringAt(0, 5, "Basic VGA text output ready", .LightCyan, .Black);
    vgaWriteStringAt(0, 7, "System halted.", .Yellow, .Black);

    hang();
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    vgaClear(.Red, .Black);
    vgaWriteStringAt(0, 0, "Kernel panic", .White, .Black);
    vgaWriteStringAt(0, 1, msg, .White, .Black);
    serialWrite(0x3F8, "[panic] ");
    serialWrite(0x3F8, msg);
    serialWrite(0x3F8, "\r\n");
    hang();
}
