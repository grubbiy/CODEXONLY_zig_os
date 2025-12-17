# Agent Guidance

This repository builds a freestanding x86 Multiboot kernel with Zig 0.15.2.

## Working conventions
- Prefer Zig 0.15.2 for all code and formatting (`zig fmt`).
- Keep code freestanding: avoid OS-dependent stdlib features unless implemented locally.
- Maintain simple, synchronous logging via VGA text mode and COM1 serial.
- Update `helpme.md` whenever usage or workflow changes so users can follow along.

## Development workflow
- Build: `zig build`
- Run in QEMU: `zig build run` (uses `qemu-system-i386 -kernel`).
- Tests: none yet; if you add checks, document how to run them.

## Communication
- When summarizing changes, note any build or runtime limitations.
- If a command cannot be executed (e.g., Zig missing), state this explicitly in testing notes.
