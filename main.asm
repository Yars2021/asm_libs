%include "vector.inc"
%include "iolib.inc"

section .text

global _start

_start:
    mov rdi, 10
    mov rsi, BYTE_VECTOR
    call create_vector

    mov rdi, rax
    mov r9, rdi

    push rdi
    call print_vector_header
    call print_newline
    pop rdi

    mov rcx, 0

    .loop:
        cmp rcx, 10

        push rcx

        jnl .loop_break
        mov rsi, rcx
        mov rdx, rcx
        call set_item_no_realloc

        pop rcx

        inc rcx
        jmp .loop


    mov rdi, r9

    call println_int

    mov rdi, r9

    push rdi

    .loop_break:
        call print_vector_numbers

    pop rdi

    call println_int

    call delete_vector

    mov rax, 60
    mov rdi, 0
    syscall