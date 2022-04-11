section .data

msg: db 'Hello, world!', 0xA, 0x0

section .text

global _start

strlen:
	mov rax, 0
	.strlen_loop:
		cmp BYTE [rdi + rax], 0x0
		je .strlen_finish
		inc rax
		jmp .strlen_loop
	.strlen_finish:
		ret

_start:
	mov rdi, msg
	call strlen
	mov rsi, rdi
	mov rdx, rax
	mov rax, 1
	mov rdi, 1
	syscall

	mov rax, 60
	mov rdi, 0
	syscall
