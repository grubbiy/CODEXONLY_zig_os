pub fn enableSSE() void {
    @setRuntimeSafety(false);

    var cr0: u32 = asm volatile ("mov %%cr0, %[out]"
        : [out] "=r" (-> u32),
    );
    cr0 &= ~(@as(u32, 1) << 2); // EM
    cr0 &= ~(@as(u32, 1) << 3); // TS
    cr0 |= @as(u32, 1) << 1; // MP
    cr0 |= @as(u32, 1) << 5; // NE
    asm volatile ("mov %[in], %%cr0"
        :
        : [in] "r" (cr0),
        : .{ .memory = true });

    var cr4: u32 = asm volatile ("mov %%cr4, %[out]"
        : [out] "=r" (-> u32),
    );
    cr4 |= (@as(u32, 1) << 9) | (@as(u32, 1) << 10); // OSFXSR | OSXMMEXCPT
    asm volatile ("mov %[in], %%cr4"
        :
        : [in] "r" (cr4),
        : .{ .memory = true });
}
