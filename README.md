# Snake written in x86-64 with NASM

<p align="center">
  <img src="https://github.com/user-attachments/assets/1e847582-f417-430d-b8bd-3dc17b13bbde" />
</p>

It's the hit game snake! Written completely from scratch in assembly only using the Windows operating system APIs.

## Why does the code suck?

I've never built an entire application in assembly before. In addition, x86-64 isn't very human friendly in comparison to simpler architectures.

### So why build it in x86-64?

To become more familiar with the architecture so I am better at reverse engineering 64-bit applications.

## How to build

Make sure you have
- [Netwide assembler](https://nasm.us/)
- Any 64-bit compatible linker (like [gcc](https://gcc.gnu.org/))

Then run this in command prompt
```sh
nasm -f win64 snake.asm && gcc snake.obj -o snake.exe -luser32 -lkernel32 -lgdi32 -Wl,-subsystem,windows && snake.exe
```
