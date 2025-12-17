# Repository Guidelines

This repo builds a small freestanding **x86 Multiboot v1** kernel using **Zig 0.15.2**.

## Project Structure & Module Organization
- `src/kernel.zig`: kernel entry (`kmain`) and high-level init/console loop.
- `src/boot.zig`: Multiboot header + `_start` (stack setup, jumps into `kmain`).
- `src/arch/x86/`: low-level x86 code (GDT/IDT, interrupts, port I/O, CPU helpers).
- `src/drivers/`: device drivers (VGA text, COM1 serial, PIC/PIT, keyboard, QEMU exit).
- `src/memory/`: physical page allocator + simple heap.
- `linker.ld`: kernel memory layout (loaded at 1 MiB).
- `helpme.md`: longer development guide; update it when workflow or usage changes.
- Generated (do not commit): `.zig-cache/`, `zig-out/` (already in `.gitignore`).

## Build, Test, and Development Commands
- `zig build`: build the kernel to `zig-out/bin/kernel`.
- `zig build run`: boot in QEMU (`qemu-system-i386`) with serial on stdio (headless).
- `zig build -Doptimize=ReleaseSmall`: smaller binary; use `Debug` while developing.
- `zig fmt src build.zig`: format Zig sources (run before opening a PR).

## Coding Style & Naming Conventions
- Use `zig fmt` as the source of truth for formatting/indentation.
- Keep code freestanding: avoid OS-backed stdlib features (files, threads, host allocators).
- Naming: `lowerCamelCase` for functions/vars, `UpperCamelCase` for types; use
  ABI-defined constants (e.g., Multiboot magic) exactly as specified.
- Prefer early diagnostics via both VGA and serial (`src/drivers/vga.zig`, `src/drivers/serial.zig`).

## Testing Guidelines
- No unit test suite yet; do a smoke boot: `zig build run`, then try `help`, `mem`, `exit`.
- If you add features with new “how to verify” steps, document them in `helpme.md`.

## Commit & Pull Request Guidelines
- Commit subjects in history are short, imperative sentences (e.g., “Add initial Zig multiboot kernel”).
- PRs should include: what changed, how to run (`zig build run`), and expected serial/VGA output (or new console commands). Keep changes focused.
