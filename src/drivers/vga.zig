const width: usize = 80;
const height: usize = 25;
const buffer: [*]volatile u16 = @ptrFromInt(@as(usize, 0xb8000));

pub const Color = enum(u8) {
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

fn entry(ch: u8, fg: Color, bg: Color) u16 {
    return @as(u16, ch) | (@as(u16, @intFromEnum(fg)) << 8) | (@as(u16, @intFromEnum(bg)) << 12);
}

fn nibbleToHex(n: u4) u8 {
    return switch (n) {
        0...9 => '0' + @as(u8, n),
        10...15 => 'a' + @as(u8, n - 10),
    };
}

pub const Terminal = struct {
    row: usize = 0,
    col: usize = 0,
    fg: Color = .LightGrey,
    bg: Color = .Black,

    pub fn clear(self: *Terminal) void {
        const value = entry(' ', self.fg, self.bg);
        var i: usize = 0;
        while (i < width * height) : (i += 1) {
            buffer[i] = value;
        }
        self.row = 0;
        self.col = 0;
    }

    fn putAt(self: *Terminal, x: usize, y: usize, ch: u8) void {
        if (x >= width or y >= height) return;
        buffer[y * width + x] = entry(ch, self.fg, self.bg);
    }

    fn scroll(self: *Terminal) void {
        var y: usize = 1;
        while (y < height) : (y += 1) {
            var x: usize = 0;
            while (x < width) : (x += 1) {
                buffer[(y - 1) * width + x] = buffer[y * width + x];
            }
        }
        const value = entry(' ', self.fg, self.bg);
        var x: usize = 0;
        while (x < width) : (x += 1) {
            buffer[(height - 1) * width + x] = value;
        }
        self.row = height - 1;
        self.col = 0;
    }

    pub fn putChar(self: *Terminal, ch: u8) void {
        switch (ch) {
            '\n' => {
                self.col = 0;
                self.row += 1;
                if (self.row >= height) self.scroll();
            },
            '\r' => {
                self.col = 0;
            },
            else => {
                self.putAt(self.col, self.row, ch);
                self.col += 1;
                if (self.col >= width) {
                    self.col = 0;
                    self.row += 1;
                    if (self.row >= height) self.scroll();
                }
            },
        }
    }

    pub fn backspace(self: *Terminal) void {
        if (self.col == 0) {
            if (self.row == 0) return;
            self.row -= 1;
            self.col = width - 1;
        } else {
            self.col -= 1;
        }
        self.putAt(self.col, self.row, ' ');
    }

    pub fn write(self: *Terminal, text: []const u8) void {
        for (text) |ch| self.putChar(ch);
    }

    pub fn writeHex(self: *Terminal, value: anytype) void {
        const T = @TypeOf(value);
        const info = @typeInfo(T);
        if (info != .int or info.int.signedness != .unsigned) {
            @compileError("Terminal.writeHex only supports unsigned integers");
        }
        if (info.int.bits > 64) {
            @compileError("Terminal.writeHex only supports <= 64-bit integers");
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
            self.putChar(nibbleToHex(nibble));
        }
    }

    pub fn writeDec(self: *Terminal, value: anytype) void {
        const T = @TypeOf(value);
        const info = @typeInfo(T);
        if (info != .int or info.int.signedness != .unsigned) {
            @compileError("Terminal.writeDec only supports unsigned integers");
        }

        if (info.int.bits > 32) {
            @compileError("Terminal.writeDec only supports <= 32-bit integers");
        }

        var v: u32 = @as(u32, value);
        if (v == 0) {
            self.putChar('0');
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
            self.putChar(buf[len]);
        }
    }
};
