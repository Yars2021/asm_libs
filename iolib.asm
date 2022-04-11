%define O_RDONLY 0x0
%define O_WRONLY 0x1
%define O_RDWR 0x2
%define O_CREAT	0100
%define O_APPEND 02000
%define F_read 0
%define F_write 1
%define F_open 2
%define F_close 3
%define F_create 85
%define ENDL 0xA

section .text

global create_file
global open_write
global open_read
global fprint_string
global fread_string
global fprint_char
global fprint_newline
global fprint_uint
global fprint_int
global fprintln_string
global fprintln_char
global fprintln_uint
global fprintln_int
global print_string
global read_string
global print_char
global print_newline
global print_uint
global print_int
global println_string
global println_char
global println_uint
global println_int

; inputs: rdi - string pointer
; return values: rax - string length without 0
string_length:
    mov rax, 0

    .strlen_loop:
        cmp BYTE [rdi + rax], 0
        je .strlen_finish
        inc rax
        jmp .strlen_loop

    .strlen_finish:
        ret

create_file:
	ret

open_write:
	ret

open_read:
	ret

; inputs: rdi - file descriptor, rsi - string pointer
; return values: none
fprint_string:
    push rdi
    push rsi
    push rcx
    push rdx
    push rax
    mov rcx, rdi
    mov rdi, rsi
	call string_length
	mov rdx, rax			; string length in bytes
	mov rax, 1				; system call number
	mov rdi, rcx 			; descriptor (1 for stdout)
	syscall
    pop rax
    pop rdx
    pop rcx
    pop rsi
    pop rdi
    ret

fread_string:
    ret

; inputs: rdi - file descriptor, rsi - char code
; return values: none
fprint_char:
    push rdi
    push rsi
    push rcx
    push rdx
    push rax
    push rsi
    mov rsi, rsp
    mov rdx, 1
    mov rax, 1
    syscall
    pop rsi
    pop rax
    pop rdx
    pop rcx
    pop rsi
    pop rdi
    ret

; inputs: rdi - file descriptor
; return values: none
fprint_newline:
    mov rsi, ENDL
    jmp fprint_char

; inputs: rdi - file descriptor, rsi - the 8-byte number
; return values: none
fprint_uint:
    push rdi
    push rsi
    push rcx
    push rdx
    push rax
    push rsi
    mov rax, rsi
    mov rcx, 10
    mov rbp, rsp
    push 0

    .fprint_uint_loop:
        mov rdx, 0
        div rcx
        add edx, '0'
        dec rsp
        mov [rsp], dl
        cmp rax, 0
        jne .fprint_uint_loop

    mov rsi, rsp
    call fprint_string
    mov rsp, rbp
    pop rsi
    pop rax
    pop rdx
    pop rcx
    pop rsi
    pop rdi
    ret

; inputs: rdi - file descriptor, rsi - the 8-byte number
; return values: none
fprint_int:
    cmp rsi, 0
    jnl .fprint_positive

    neg rsi
    push rsi
    mov rsi, '-'
    call fprint_char
    pop rsi

    .fprint_positive:
        jmp fprint_uint

; inputs: rdi - file descriptor, rsi - string pointer
; return values: none
fprintln_string:
    call fprint_string
    call fprint_newline
    ret

; inputs: rdi - file descriptor, rsi - char code
; return values: none
fprintln_char:
    call fprint_char
    call fprint_newline
    ret

; inputs: rdi - file descriptor, rsi - the 8-byte number
; return values: none
fprintln_uint:
    call fprint_uint
    call fprint_newline
    ret

; inputs: rdi - file descriptor, rsi - the 8-byte number
; return values: none
fprintln_int:
    call fprint_int
    call fprint_newline
    ret

; inputs: rdi - string pointer
; return values: none
print_string:
    mov rsi, rdi
    mov rdi, 1
    jmp fprint_string

read_string:
	ret

; inputs: rdi - char code
; return values: none
print_char:
    mov rsi, rdi
    mov rdi, 1
    jmp fprint_char

; inputs: none
; return values: none
print_newline:
    mov rdi, ENDL
    jmp print_char

; inputs: rdi - the 8-byte number
; return values: none
print_uint:
    mov rsi, rdi
    mov rdi, 1
    jmp fprint_uint

; inputs: rdi - the 8-byte number
; return values: none
print_int:
    mov rsi, rdi
    mov rdi, 1
    jmp fprint_int

; inputs: rdi - string pointer
; return values: none
println_string:
    mov rsi, rdi
    mov rdi, 1
    jmp fprintln_string

; inputs: rdi - char code
; return values: none
println_char:
    mov rsi, rdi
    mov rdi, 1
    jmp fprintln_char

; inputs: rdi - the 8-byte number
; return values: none
println_uint:
    mov rsi, rdi
    mov rdi, 1
    jmp fprintln_uint

; inputs: rdi - the 8-byte number
; return values: none
println_int:
    mov rsi, rdi
    mov rdi, 1
    jmp fprintln_int