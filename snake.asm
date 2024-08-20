; Snake.asm
; x86-64 Windows
; Author: Connor Bren
; License: MIT
;
; Template: https://www.davidgrantham.com/nasm-basicwindow64/
; Big thanks to David Grantham for the quickstart into x64 nasm

FRUIT               EQU 2
SNAKE               EQU 1
NONE                EQU 0

TRUE                EQU 1
FALSE               EQU 0

FRUIT_SOUND_FREQ    EQU 523                   ; Middle C
FRUIT_SOUND_LEN     EQU 100

COLOR_WINDOW        EQU 5                     ; Constants
CS_BYTEALIGNWINDOW  EQU 2000h
CS_HREDRAW          EQU 2
CS_VREDRAW          EQU 1
CW_USEDEFAULT       EQU 80000000h
IDC_ARROW           EQU 7F00h
IDI_APPLICATION     EQU 7F00h
IMAGE_CURSOR        EQU 2
IMAGE_ICON          EQU 1
LR_SHARED           EQU 8000h
NULL                EQU 0
SW_SHOWNORMAL       EQU 1
WM_DESTROY          EQU 2
WM_PAINT            EQU 0xF
WS_EX_COMPOSITED    EQU 2000000h
WS_OVERLAPPEDWINDOW EQU 0CF0000h
PM_REMOVE           EQU 1
WM_KEYDOWN          EQU 0x0100

GRID_SIZE           EQU 20
CELL_SIZE           EQU 30

WindowWidth         EQU GRID_SIZE * CELL_SIZE
WindowHeight        EQU GRID_SIZE * CELL_SIZE

extern              CreateWindowExA           ; Import external symbols
extern              DefWindowProcA            ; Windows API functions, not decorated
extern              DispatchMessageA
extern              ExitProcess
extern              PeekMessageA
extern              GetModuleHandleA
extern              IsDialogMessageA
extern              LoadImageA
extern              PostQuitMessage
extern              RegisterClassExA
extern              ShowWindow
extern              TranslateMessage
extern              UpdateWindow
extern              RGB
extern              CreateSolidBrush
extern              FillRect
extern              DeleteObject
extern              EndPaint
extern              BeginPaint
extern              Sleep
extern              GetTickCount64
extern              InvalidateRect
extern              PlaySoundA

global              WinMain                   ; Export symbols. The entry point

section             .data                     ; Initialized data segment
  WindowName db "Snake", 0
  ClassName  db "GridWindowClass", 0

  FruitSound db "SystemStart", 0

  last_time dq 0

  xDirection db 1
  yDirection db 0

  speed dd 150

  hasTurnedThisTick db 0

section .bss ; Uninitialized data segment
  alignb    8
  hInstance resq 1

  length resd 1
  
  tiles resb GRID_SIZE * GRID_SIZE
  nodes resb GRID_SIZE * GRID_SIZE * 2

section .text ; Code segment
WinMain:
  sub rsp, 8 ; Align stack pointer to 16 bytes

  sub  rsp,                   32  ; 32 bytes of shadow space
  xor  ecx,                   ecx
  call GetModuleHandleA
  mov  qword [REL hInstance], rax
  add  rsp,                   32  ; Remove the 32 bytes

  call main

.Exit:
  xor  ecx, ecx
  call ExitProcess

main:
  push rbp          ; Set up a stack frame
  mov  rbp, rsp
  sub  rsp, 136 + 8 ; 136 bytes for local variables. 136 is not

  %define wc               rbp - 136 ; WNDCLASSEX structure, 80 bytes
  %define wc.cbSize        rbp - 136 ; 4 bytes. Start on an 8 byte boundary
  %define wc.style         rbp - 132 ; 4 bytes
  %define wc.lpfnWndProc   rbp - 128 ; 8 bytes
  %define wc.cbClsExtra    rbp - 120 ; 4 bytes
  %define wc.cbWndExtra    rbp - 116 ; 4 bytes
  %define wc.hInstance     rbp - 112 ; 8 bytes
  %define wc.hIcon         rbp - 104 ; 8 bytes
  %define wc.hCursor       rbp - 96  ; 8 bytes
  %define wc.hbrBackground rbp - 88  ; 8 bytes
  %define wc.lpszMenuName  rbp - 80  ; 8 bytes
  %define wc.lpszClassName rbp - 72  ; 8 bytes
  %define wc.hIconSm       rbp - 64  ; 8 bytes. End on an 8 byte boundary

  %define msg          rbp - 56 ; MSG structure, 48 bytes
  %define msg.hwnd     rbp - 56 ; 8 bytes. Start on an 8 byte boundary
  %define msg.message  rbp - 48 ; 4 bytes
  %define msg.Padding1 rbp - 44 ; 4 bytes. Natural alignment padding
  %define msg.wParam   rbp - 40 ; 8 bytes
  %define msg.lParam   rbp - 32 ; 8 bytes
  %define msg.time     rbp - 24 ; 4 bytes
  %define msg.py.x     rbp - 20 ; 4 bytes
  %define msg.pt.y     rbp - 16 ; 4 bytes
  %define msg.Padding2 rbp - 12 ; 4 bytes. Structure length padding

  %define hWnd rbp - 8 ; 8 bytes

  ; Set starting positions
  mov dword [rel length], 2

  lea rcx,              [rel tiles]
  mov eax,              17 * GRID_SIZE + 13
  mov byte [rcx + rax], FRUIT

  lea rcx,            [rel nodes]
  mov byte [rcx],     GRID_SIZE / 2 - 1
  mov byte [rcx + 1], GRID_SIZE / 2 - 1
  ; End set starting positions

  mov dword [wc.cbSize],      80                                           ; [rbp - 136]
  mov dword [wc.style],       CS_HREDRAW | CS_VREDRAW | CS_BYTEALIGNWINDOW ; [rbp - 132]
  lea rax,                    [REL WndProc]
  mov qword [wc.lpfnWndProc], rax                                          ; [rbp - 128]
  mov dword [wc.cbClsExtra],  NULL                                         ; [rbp - 120]
  mov dword [wc.cbWndExtra],  NULL                                         ; [rbp - 116]
  mov rax,                    qword [REL hInstance]                        ; Global
  mov qword [wc.hInstance],   rax                                          ; [rbp - 112]

  sub  rsp,                 32 + 16         ; Shadow space + 2 parameters
  xor  ecx,                 ecx
  mov  edx,                 IDI_APPLICATION
  mov  r8d,                 IMAGE_ICON
  xor  r9d,                 r9d
  mov  qword [rsp + 4 * 8], NULL
  mov  qword [rsp + 5 * 8], LR_SHARED
  call LoadImageA                           ; Large program icon
  mov  qword [wc.hIcon],    rax             ; [rbp - 104]
  add  rsp,                 48              ; Remove the 48 bytes

  sub  rsp,                 32 + 16      ; Shadow space + 2 parameters
  xor  ecx,                 ecx
  mov  edx,                 IDC_ARROW
  mov  r8d,                 IMAGE_CURSOR
  xor  r9d,                 r9d
  mov  qword [rsp + 4 * 8], NULL
  mov  qword [rsp + 5 * 8], LR_SHARED
  call LoadImageA                        ; Cursor
  mov  qword [wc.hCursor],  rax          ; [rbp - 96]
  add  rsp,                 48           ; Remove the 48 bytes

  mov qword [wc.hbrBackground], COLOR_WINDOW + 1 ; [rbp - 88]
  mov qword [wc.lpszMenuName],  NULL             ; [rbp - 80]
  lea rax,                      [REL ClassName]
  mov qword [wc.lpszClassName], rax              ; [rbp - 72]

  sub  rsp,                 32 + 16         ; Shadow space + 2 parameters
  xor  ecx,                 ecx
  mov  edx,                 IDI_APPLICATION
  mov  r8d,                 IMAGE_ICON
  xor  r9d,                 r9d
  mov  qword [rsp + 4 * 8], NULL
  mov  qword [rsp + 5 * 8], LR_SHARED
  call LoadImageA                           ; Small program icon
  mov  qword [wc.hIconSm],  rax             ; [rbp - 64]
  add  rsp,                 48              ; Remove the 48 bytes

  sub  rsp, 32          ; 32 bytes of shadow space
  lea  rcx, [wc]        ; [rbp - 136]
  call RegisterClassExA
  add  rsp, 32          ; Remove the 32 bytes

  sub  rsp,                  32 + 64               ; Shadow space + 8 parameters
  mov  ecx,                  WS_EX_COMPOSITED
  lea  rdx,                  [REL ClassName]       ; Global
  lea  r8,                   [REL WindowName]      ; Global
  mov  r9d,                  WS_OVERLAPPEDWINDOW
  mov  dword [rsp + 4 * 8],  CW_USEDEFAULT
  mov  dword [rsp + 5 * 8],  CW_USEDEFAULT
  mov  dword [rsp + 6 * 8],  WindowWidth
  mov  dword [rsp + 7 * 8],  WindowHeight
  mov  qword [rsp + 8 * 8],  NULL
  mov  qword [rsp + 9 * 8],  NULL
  mov  rax,                  qword [REL hInstance] ; Global
  mov  qword [rsp + 10 * 8], rax
  mov  qword [rsp + 11 * 8], NULL
  call CreateWindowExA
  mov  qword [hWnd],         rax                   ; [rbp - 8]
  add  rsp,                  96                    ; Remove the 96 bytes

  sub  rsp, 32            ; 32 bytes of shadow space
  mov  rcx, qword [hWnd]  ; [rbp - 8]
  mov  edx, SW_SHOWNORMAL
  call ShowWindow
  add  rsp, 32            ; Remove the 32 bytes

  sub  rsp, 32           ; 32 bytes of shadow space
  mov  rcx, qword [hWnd] ; [rbp - 8]
  call UpdateWindow
  add  rsp, 32           ; Remove the 32 bytes

  .MessageLoop:
    sub  rsp, 32
    call GetTickCount64 ; Get the time
    add  rsp, 32

    mov rcx, [rel last_time]
    sub rax, rcx
    cmp eax, dword [rel speed]
    jl  .continue_loop

    call GetTickCount64
    mov  [rel last_time], rax

    call Update

    ; Invalidate the window to trigger a repaint
    sub  rsp, 32           ; 32 bytes of shadow space
    mov  rcx, qword [hWnd] ; [rbp - 8], the window handle
    xor  rdx, rdx          ; lpRect = NULL (invalidate the entire client area)
    mov  r8d, 1            ; bErase = TRUE (erase the background)
    call InvalidateRect
    add  rsp, 32           ; Clean up the stack

  .continue_loop:
    sub  rsp,              32        ; 32 bytes of shadow space
    lea  rcx,              [msg]     ; [rbp - 56]
    xor  edx,              edx
    xor  r8d,              r8d
    xor  r9d,              r9d
    mov  dword [rsp + 32], PM_REMOVE
    call PeekMessageA
    add  rsp,              32        ; Remove the 32 bytes
    cmp  rax,              0
    je   .MessageLoop
    
    lea  rcx, [msg]
    call HandleInput

    sub  rsp, 32           ; 32 bytes of shadow space
    mov  rcx, qword [hWnd] ; [rbp - 8]
    lea  rdx, [msg]        ; [rbp - 56]
    call IsDialogMessageA  ; For keyboard strokes
    add  rsp, 32           ; Remove the 32 bytes
    cmp  rax, 0
    jne  .MessageLoop      ; Skip TranslateMessage and DispatchMessageA

    sub  rsp, 32          ; 32 bytes of shadow space
    lea  rcx, [msg]       ; [rbp - 56]
    call TranslateMessage
    add  rsp, 32          ; Remove the 32 bytes

    sub  rsp, 32          ; 32 bytes of shadow space
    lea  rcx, [msg]       ; [rbp - 56]
    call DispatchMessageA
    add  rsp, 32          ; Remove the 32 bytes
    jmp  .MessageLoop

  .Done:
  mov rsp, rbp ; Remove the stack frame
  pop rbp
  xor eax, eax
  ret

; HWND rcx
; UINT rdx
; WPARAM r8
; LPARAM r9
WndProc:
  push rbp
  mov  rbp, rsp
  sub  rsp, 32  ; Allocate shadow space

  cmp edx, WM_DESTROY
  je  .WMDESTROY
  cmp edx, WM_PAINT
  je  .WMPAINT

  .DefaultMessage:
    call DefWindowProcA
    jmp  .Exit

  .WMPAINT:
    sub  rsp,   120      ; Allocate space for HDC and PAINTSTRUCT
    lea  rdx,   [rsp+48] ; Address of PAINTSTRUCT
    call BeginPaint
    mov  [rsp], rax      ; Store HDC

    xor r12d, r12d ; r12d as row counter
    .row_loop:
      cmp r12d, GRID_SIZE
      jge .row_loop_end

      xor r13d, r13d ; r13d as column counter
      .col_loop:
        cmp r13d, GRID_SIZE
        jge .col_loop_end

        ; Calculate the offset into the tiles array
        mov  eax, GRID_SIZE
        imul eax, r12d
        add  eax, r13d
        
        ; Load the base address of tiles
        lea rcx, [rel tiles]
        
        ; Get the tile value
        movzx eax, byte [rcx + rax]
        
        ; Compare with SNAKE constant
        cmp al, SNAKE
        jne .not_snake

        ; Is a snake
          mov ecx, 0xc4c4ff ; Brown
          jmp .draw_pixel
        
        .not_fruit:
          mov ecx, 0x009933 ; Green
          jmp .draw_pixel
        
        .not_snake:
          cmp al, FRUIT
          jne .not_fruit
          
          mov ecx, 0x0000ff ; red

        .draw_pixel:

        sub  rsp, 40
        call CreateSolidBrush
        add  rsp, 40
        mov  r14, rax         ; Store brush in r14

        mov  ecx, r12d  ; row
        mov  edx, r13d  ; col
        mov  r8,  r14   ; brush
        mov  r9,  [rsp] ; hdc
        call DrawPixel

        mov  rcx, r14
        call DeleteObject

        .col_continue:
        inc r13d
        jmp .col_loop
      .col_loop_end:

      inc r12d
      jmp .row_loop
    .row_loop_end:

    mov  rcx, [rbp+16] ; hWnd
    lea  rdx, [rsp+48] ; Address of PAINTSTRUCT
    call EndPaint

    add rsp, 120
    xor eax, eax
    jmp .Exit

  .WMDESTROY:
    xor  ecx, ecx
    call PostQuitMessage
    xor  eax, eax

  .Exit:
    add rsp, 32 ; Free shadow space
    pop rbp
    ret

; ecx row
; edx column
; r8 brush
; r9 hdc
DrawPixel:
  push rbp
  mov  rbp, rsp

  push r12 ; Preserve r12
  push r13 ; Preserve r13

  mov r12d, ecx ; Store row in r12d
  mov r13d, edx ; Store column in r13d

  sub rsp, 16  ; Allocate space for RECT
  mov rdi, rsp ; rdi points to RECT

  ; Calculate and fill RECT structure
  mov  eax,   CELL_SIZE
  imul edx,   eax
  mov  [rdi], edx       ; left = col * CELL_SIZE

  imul ecx,     eax
  mov  [rdi+4], ecx ; top = row * CELL_SIZE

  lea  ecx,     [r13d+1]
  imul ecx,     eax
  mov  [rdi+8], ecx      ; right = (col+1) * CELL_SIZE

  lea  ecx,      [r12d+1]
  imul ecx,      eax
  mov  [rdi+12], ecx      ; bottom = (row+1) * CELL_SIZE

  mov  rcx, r9  ; hdc
  mov  rdx, rdi ; &RECT
  mov  r8,  r8  ; brush (already in r8)
  call FillRect

  add rsp, 16 ; Free RECT

  pop r13 ; Restore r13
  pop r12 ; Restore r12

  pop rbp
  ret

Update:
  push rbp
  mov  rbp, rsp

  push r11
  push r12
  push r13
  push r14
  push r15
  push rdi

  mov r12d, dword [rel length] ; Store length in r12d
  lea r14,  [rel nodes]        ; Get base address of nodes
  lea r15,  [rel tiles]        ; Get base address of tiles

  ; Store the current head position
  movzx r8d, byte [r14]     ; Head x
  movzx r9d, byte [r14 + 1] ; Head y

  ; Calculate new head position
  add r8b, byte [rel xDirection]
  add r9b, byte [rel yDirection]

  ; Bounds checking for new head position
  cmp r8b, GRID_SIZE
  jge .x_lesser_than_bounds
  cmp r8b, 0
  jl  .x_greater_than_bounds
  jmp .x_in_bounds

  .x_lesser_than_bounds:
    xor r8b, r8b     ; Wrap around to 0 if out of bounds
    jmp .x_in_bounds
  .x_greater_than_bounds:
    mov r8b, GRID_SIZE - 1
  .x_in_bounds:

  cmp r9b, GRID_SIZE
  jge .y_lesser_than_bounds
  cmp r9b, 0
  jl  .y_greater_than_bounds
  jmp .y_in_bounds

  .y_lesser_than_bounds:
    xor r9b, r9b     ; Wrap around to 0 if out of bounds
    jmp .y_in_bounds
  .y_greater_than_bounds:
    mov r9b, GRID_SIZE - 1
  .y_in_bounds:

  ; Calculate new head position in tiles
  mov  eax, r8d
  imul eax, GRID_SIZE
  add  eax, r9d

  ; Check if new head position is fruit
  mov bl, byte [r15 + rax]
  cmp bl, FRUIT
  je  .eat_fruit

  ; Check if new head position is snake (collision)
  cmp bl, SNAKE
  je  GameEnd

  ; Clear the tail tile if not growing
  mov   eax,              r12d
  dec   eax
  imul  eax,              2
  movzx edi,              byte [r14 + rax]     ; Tail x
  movzx esi,              byte [r14 + rax + 1] ; Tail y
  mov   eax,              edi
  imul  eax,              GRID_SIZE
  add   eax,              esi
  mov   byte [r15 + rax], NONE

  jmp .move_snake

  .eat_fruit:
    ; Increment length
    inc dword [rel length]
    inc r12d

    call PlaceNewFruit

    ; Speed up
    mov  eax,               dword [rel speed]
    imul eax,               97
    xor  edx,               edx
    mov  ecx,               100
    idiv ecx
    mov  dword [rel speed], eax

  .move_snake:
    ; Shift all segments
    mov r13d, r12d ; Start from the new length
    dec r13d       ; r13d = length - 1

  .shift_loop:
    cmp r13d, 0    ; Check if we reached the head
    jle .shift_end

    mov  eax,                  r13d
    imul eax,                  2
    sub  eax,                  2                    ; Go to previous segment
    mov  dl,                   byte [r14 + rax]     ; x of previous segment
    mov  r11b,                 byte [r14 + rax + 1] ; y of previous segment
    add  eax,                  2
    mov  byte [r14 + rax],     dl                   ; Store x in current segment
    mov  byte [r14 + rax + 1], r11b                 ; Store y in current segment

    dec r13d
    jmp .shift_loop

  .shift_end:
    ; Update head position in nodes array
    mov [r14],     r8b
    mov [r14 + 1], r9b

    ; Set new head position in tiles
    mov  eax,              r8d
    imul eax,              GRID_SIZE
    add  eax,              r9d
    mov  byte [r15 + rax], SNAKE
  
  mov byte [rel hasTurnedThisTick], FALSE

  pop rdi
  pop r15
  pop r14
  pop r13
  pop r12
  pop r11
  pop rbp
  ret

; rcx: pointer to MSG structure
HandleInput:
  push rbp
  mov  rbp, rsp

  ; Check if it's a keydown message
  cmp dword [rcx + 8],              WM_KEYDOWN ; message field
  jne .default_outcome
  cmp byte [rel hasTurnedThisTick], TRUE
  je  .default_outcome

  mov byte [rel hasTurnedThisTick], TRUE

  ; Check which key was pressed
  mov eax, [rcx + 16]  ; wParam field
  cmp eax, 'W'
  je  .handle_up
  cmp eax, 'A'
  je  .handle_left
  cmp eax, 'S'
  je  .handle_down
  cmp eax, 'D'
  je  .handle_right
  jmp .default_outcome

  .handle_up:
    cmp byte [rel xDirection], 1
    je  .default_outcome
    mov byte [rel yDirection], 0
    mov byte [rel xDirection], -1
    jmp .default_outcome

  .handle_left:
    cmp byte [rel yDirection], 1
    je  .default_outcome
    mov byte [rel xDirection], 0
    mov byte [rel yDirection], -1
    jmp .default_outcome

  .handle_down:
    cmp byte [rel xDirection], -1
    je  .default_outcome
    mov byte [rel yDirection], 0
    mov byte [rel xDirection], 1
    jmp .default_outcome

  .handle_right:
    cmp byte [rel yDirection], -1
    je  .default_outcome
    mov byte [rel xDirection], 0
    mov byte [rel yDirection], 1
    jmp .default_outcome

  .default_outcome:
    pop rbp
    ret

; I'm 100% there's a better way to do this
PlaceNewFruit:
  push rbp
  mov  rbp, rsp

  .try_spawn:
    ; Get random position
    xor    rdx, rdx
    rdrand rax
    mov    rcx, GRID_SIZE * GRID_SIZE
    div    rcx                        ; rax = rax / rcx

    ; Check if empty
    lea rcx,              [rel tiles]
    cmp byte [rcx + rdx], NONE
    jne .try_spawn

    mov byte [rcx, + rdx], FRUIT

  pop rbp
  ret

; Lol
GameEnd:
  int3
