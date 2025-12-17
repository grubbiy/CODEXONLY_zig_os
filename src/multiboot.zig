pub const InfoFlags = struct {
    pub const memory: u32 = 1 << 0;
    pub const boot_device: u32 = 1 << 1;
    pub const cmdline: u32 = 1 << 2;
    pub const modules: u32 = 1 << 3;
    pub const aout_sym: u32 = 1 << 4;
    pub const elf_shdr: u32 = 1 << 5;
    pub const mmap: u32 = 1 << 6;
    pub const drives: u32 = 1 << 7;
    pub const config_table: u32 = 1 << 8;
    pub const boot_loader_name: u32 = 1 << 9;
    pub const apm_table: u32 = 1 << 10;
    pub const vbe: u32 = 1 << 11;
    pub const framebuffer: u32 = 1 << 12;
};

pub const Info = extern struct {
    flags: u32,
    mem_lower: u32,
    mem_upper: u32,

    boot_device: u32,
    cmdline: u32,

    mods_count: u32,
    mods_addr: u32,

    syms: [4]u32,

    mmap_length: u32,
    mmap_addr: u32,
};

pub const MemoryMapType = enum(u32) {
    available = 1,
    reserved = 2,
    acpi_reclaimable = 3,
    nvs = 4,
    badram = 5,
    _,
};

pub const MemoryMapEntry = extern struct {
    size: u32,
    addr_low: u32,
    addr_high: u32,
    len_low: u32,
    len_high: u32,
    kind: MemoryMapType,

    pub fn addr(self: *const MemoryMapEntry) u64 {
        return (@as(u64, self.addr_high) << 32) | @as(u64, self.addr_low);
    }

    pub fn len(self: *const MemoryMapEntry) u64 {
        return (@as(u64, self.len_high) << 32) | @as(u64, self.len_low);
    }
};
