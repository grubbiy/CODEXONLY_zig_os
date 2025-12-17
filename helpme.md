# Zig 0.15.2 Kernel Development Guide

This repository contains a tiny freestanding **x86 (32-bit) Multiboot v1** kernel written in **Zig 0.15.2**. It prints to VGA text mode and COM1 serial, and exposes a small interactive shell over the serial port.

## Quick start (try it in QEMU)
Prerequisites: **Zig 0.15.2** and `qemu-system-i386`.

```bash
zig version          # should print 0.15.2
zig build run        # boots headless; your terminal is the serial console
```

You should see boot logs and a prompt:

```text
Type `help` for commands.
>
```

Try:
- `help` (list commands)
- `mem` / `mmap` (allocator + Multiboot info)
- `exit` (quits QEMU via `isa-debug-exit`; QEMU will exit with a non-zero status such as `33`—this is expected)

## Using the kernel shell
The prompt accepts input from **COM1 serial** (your terminal when using `-serial stdio`) and from the **PS/2 keyboard** when a VGA window is enabled.

Commands:
- `help`: list available commands.
- `clear`: clear the VGA text screen.
- `ticks`: print PIT tick counter.
- `mem`: print Multiboot memory info (if present) and `pmm` free pages.
- `mmap`: dump the Multiboot memory map to serial output.
- `alloc` / `free`: allocate one physical page and free the most recent one.
- `kmalloc`: allocate 64 bytes from the heap and print the returned pointer.
- `reboot`: attempt a CPU reset via the keyboard controller.
- `exit`: exit QEMU via `isa-debug-exit`.

### Note for WSL users
If the repo lives on a Windows filesystem mount like `/mnt/c/...`, Zig may fail to update `.zig-cache` (rename `AccessDenied`). Either move the repo to the Linux filesystem (recommended) or build with explicit cache dirs, for example:

`zig build --cache-dir /tmp/zig-cache --global-cache-dir /tmp/zig-global-cache`

## Environment setup
1. Download Zig 0.15.2 from the official release page and ensure `zig` is on your PATH.
2. Install QEMU (tested with `qemu-system-i386`). On Debian/Ubuntu, `sudo apt-get install qemu-system-x86`.
3. Verify tools: `zig version` should print `0.15.2` and `qemu-system-i386 --version` should succeed.

## What the kernel does today
- Provides a **Multiboot v1 header** and boot stack in `src/boot.zig` (no external `.s` files).
- Initializes **VGA text mode** + **COM1 serial** output and prints early boot status.
- Enables **SSE/SSE2** early (Zig may emit SSE instructions even for simple copies).
- Sets up **GDT + IDT**, remaps the **PIC**, and enables **IRQs**.
- Enables the **PIT timer** and **PS/2 keyboard** IRQs.
- Builds a **physical page allocator** (from the Multiboot memory map) and a simple **bump heap**.
- Exposes a tiny **console** (keyboard + serial input) with `help`, `clear`, `ticks`, `mem`, `mmap`, `alloc`, `free`, `kmalloc`, `reboot`, `exit`.

## Repository layout
- `build.zig` – Build script targeting **x86 freestanding** with a custom linker script and QEMU runner.
- `linker.ld` – Places sections at the 1 MiB physical address and aligns segments for the kernel image.
- `src/boot.zig` – Multiboot header + `_start` entry (stack + jump to `kmain`).
- `src/kernel.zig` – Kernel entry + init and the serial console loop.
- `src/arch/x86/*` – x86 low-level setup (GDT/IDT/interrupt stubs, port I/O).
- `src/drivers/*` – Serial/VGA/PIC/PIT/keyboard drivers.
- `src/memory/*` – Physical page allocator and a tiny heap.

## Build and run (details)
- Build only: `zig build` (outputs `zig-out/bin/kernel`).
- Run via build runner: `zig build run` (headless; COM1 is mapped to your terminal).
- Format: `zig fmt src build.zig`.

## Running the kernel manually
If you want to bypass the build runner:
1. Build the kernel: `zig build`.
2. Boot with QEMU directly (headless):

   `qemu-system-i386 -kernel zig-out/bin/kernel -serial stdio -no-reboot -no-shutdown -display none -device isa-debug-exit,iobase=0xf4,iosize=0x04`

3. You should see serial output (including the `>` prompt) in your terminal. Remove `-display none` to get a VGA window.

### Automated smoke run (headless)
You can feed commands into QEMU over COM1 and have the kernel exit QEMU via `isa-debug-exit`:

`(sleep 1; printf "help\rexit\r") | qemu-system-i386 -kernel zig-out/bin/kernel -serial stdio -no-reboot -no-shutdown -display none -device isa-debug-exit,iobase=0xf4,iosize=0x04`

Note: the `isa-debug-exit` device makes QEMU exit with a non-zero status (success is typically `33`).

## Extending the kernel
- Add new Zig modules under `src/` and import them from `src/kernel.zig` (or a new subsystem module).
- Add new console commands by extending `runCommand` in `src/kernel.zig` (then verify via `zig build run`).
- Add new IRQ handlers by implementing a handler and registering it in `src/kernel.zig` via `interrupts.register(...)`.
- Keep the freestanding target in mind: avoid stdlib features that assume an OS (files, threads, host allocators) until you provide your own implementations.
- Use serial logging for early diagnostics: `serial.write(serial.com1, "...")` is safe to call very early.

## Troubleshooting
- **Missing Zig or QEMU:** Install the required tools and re-run `zig build` / `zig build run`.
- **Zig version mismatch:** This repo targets Zig **0.15.2**; confirm with `zig version`.
- **No serial output:** Ensure QEMU is run with `-serial stdio` (the build script does this) and check your terminal for log lines.
- **Boot hangs immediately:** Verify Multiboot magic matches (`0x2BADB002`) and that you are using a Multiboot-capable loader (`qemu-system-i386 -kernel zig-out/bin/kernel`).
- **`zig build run` looks like it “failed” after `exit`:** QEMU returns a non-zero code with `isa-debug-exit` (e.g., `33`) even on success.

## Roadmap (suggested)
- Add paging (identity map + higher-half kernel) and a real heap allocator.
- Grow into scheduling, processes, and user mode once memory + interrupts are solid.
