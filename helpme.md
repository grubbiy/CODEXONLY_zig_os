# Zig 0.15.2 Kernel Development Guide

This document explains how to build, run, and extend the small Multiboot-compatible kernel written in Zig 0.15.2 that lives in this repository.

## Quick start
- **Prerequisites:** Zig 0.15.2 and `qemu-system-i386`.
- **Build:** `zig build` produces `zig-out/bin/kernel` (an ELF kernel that includes the multiboot header).
- **Run in QEMU:** `zig build run` boots the kernel headless with serial redirected to your terminal; you should get an interactive `>` prompt over serial.
- **Format:** `zig fmt src build.zig` keeps Zig sources consistent.

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

## Running the kernel manually
If you want to bypass the build runner:
1. Build the kernel: `zig build -p zig-out`.
2. Boot with QEMU directly: `qemu-system-i386 -kernel zig-out/bin/kernel -serial stdio -no-reboot -no-shutdown -display none -device isa-debug-exit,iobase=0xf4,iosize=0x04`.
3. You should see serial output (including the `>` prompt) in your terminal; remove `-display none` if you want a VGA window.

### Automated smoke run (headless)
You can feed commands into QEMU over COM1 and have the kernel exit QEMU via `isa-debug-exit`:

`(sleep 1; printf "help\rexit\r") | qemu-system-i386 -kernel zig-out/bin/kernel -serial stdio -display none -device isa-debug-exit,iobase=0xf4,iosize=0x04`

Note: the `isa-debug-exit` device makes QEMU exit with a non-zero status (success is typically `33`).

## Extending the kernel
- Add new Zig modules under `src/` and import them from `src/kernel.zig` or future subsystem files.
- Keep the freestanding target in mind: avoid standard library features that assume an OS (files, threading, heap allocators) until you provide your own implementations.
- Use serial logging for early diagnostics—`serialWrite` is safe to call during boot before other systems are ready.

## Troubleshooting
- **Missing Zig or QEMU:** Install the required tools and re-run `zig build` / `zig build run`.
- **No serial output:** Ensure QEMU is run with `-serial stdio` (the build script does this) and check your terminal for log lines.
- **Boot hangs immediately:** Verify Multiboot magic matches (`0x2BADB002`) and that you are using a Multiboot-capable loader (`qemu-system-i386 -kernel zig-out/bin/kernel`).

## Roadmap (suggested)
- Add paging (identity map + higher-half kernel) and a real heap allocator.
- Grow into scheduling, processes, and user mode once memory + interrupts are solid.
