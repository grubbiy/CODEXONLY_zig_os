const io = @import("../arch/x86/io.zig");

pub const com1: u16 = 0x3F8;

pub fn init(base: u16) void {
    io.outb(base + 1, 0x00); // disable interrupts
    io.outb(base + 3, 0x80); // enable DLAB
    io.outb(base + 0, 0x03); // divisor low byte (38400 baud)
    io.outb(base + 1, 0x00); // divisor high byte
    io.outb(base + 3, 0x03); // 8 bits, no parity, one stop bit
    io.outb(base + 2, 0xC7); // enable FIFO
    io.outb(base + 4, 0x0B); // IRQs enabled, RTS/DSR set
}

fn canTransmit(base: u16) bool {
    return (io.inb(base + 5) & 0x20) != 0;
}

pub fn writeByte(base: u16, byte: u8) void {
    while (!canTransmit(base)) {}
    io.outb(base, byte);
}

pub fn write(base: u16, text: []const u8) void {
    for (text) |ch| writeByte(base, ch);
}

fn canReceive(base: u16) bool {
    return (io.inb(base + 5) & 0x01) != 0;
}

pub fn readByteNonBlocking(base: u16) ?u8 {
    if (!canReceive(base)) return null;
    return io.inb(base);
}

fn nibbleToHex(n: u4) u8 {
    return switch (n) {
        0...9 => '0' + @as(u8, n),
        10...15 => 'a' + @as(u8, n - 10),
    };
}

pub fn writeHex(base: u16, value: anytype) void {
    const T = @TypeOf(value);
    const info = @typeInfo(T);
    if (info != .int or info.int.signedness != .unsigned) {
        @compileError("serial.writeHex only supports unsigned integers");
    }

    if (info.int.bits > 64) {
        @compileError("serial.writeHex only supports <= 64-bit integers");
    }

    const digits: usize = (info.int.bits + 3) / 4;
    const v: u64 = @as(u64, value);
    var started = false;
    var i: usize = 0;
    while (i < digits) : (i += 1) {
        const shift: usize = (digits - 1 - i) * 4;
        const nibble: u4 = @truncate((v >> @as(u6, @intCast(shift))) & 0xF);
        if (!started and nibble == 0 and i + 1 < digits) continue;
        started = true;
        writeByte(base, nibbleToHex(nibble));
    }
}

pub fn writeDec(base: u16, value: anytype) void {
    const T = @TypeOf(value);
    const info = @typeInfo(T);
    if (info != .int or info.int.signedness != .unsigned) {
        @compileError("serial.writeDec only supports unsigned integers");
    }

    if (info.int.bits > 32) {
        @compileError("serial.writeDec only supports <= 32-bit integers");
    }

    var v: u32 = @as(u32, value);
    if (v == 0) {
        writeByte(base, '0');
        return;
    }

    var buf: [10]u8 = undefined;
    var len: usize = 0;
    while (v != 0) : (v /= 10) {
        const digit: u8 = @truncate(v % 10);
        buf[len] = '0' + digit;
        len += 1;
    }

    while (len != 0) {
        len -= 1;
        writeByte(base, buf[len]);
    }
}
