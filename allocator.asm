%include "iolib.inc"
; define all the flags and const values
%define NULL 0x0
%define PROT_READ 0x1
%define PROT_WRITE 0x2
%define MAP_FIXED 0x1 
%define MAP_FIXED_NOREPLACE 0x100000
%define MAP_PRIVATE 0x2 
%define MAP_SHARED 0x4 
%define MAP_ANONYMOUS 0x20
%define REGION_MIN_SIZE 0x1000	; 4096 in decimal
%define MAP_FAILED -1 
%define REGION_INVALID -1
%define HEAP_START 0x0
%define BLOCK_HEADER_SIZE 13
%define BLOCK_MIN_CAPACITY 24
%define BSR_FOUND_GOOD_BLOCK 0x0
%define BSR_NOT_FOUND 0x1

section .data

HEAP_ADDR: dq 0
INFO_CURRENT_LABEL: db 'Block address: ', 0
INFO_NEXT_LABEL: db 'Next pointer: ', 0
INFO_CAP_LABEL: db 'Capacity (bytes): ', 0
INFO_EMPTY_LABEL: db 'Is free: ', 0
INFO_SEPARATOR: db '---------------------------', 0

section .text

global max_size
global mmap
global alloc_region
global new_block
global block_get_next
global block_get_cap
global block_is_empty
global block_set_next
global block_set_cap
global block_set_empty
global capacity_from_size
global size_from_capacity
global block_after
global heap_init
global block_splittable
global split_big_block
global block_continuous
global mergeable
global merge_with_next
global find_block
global try_alloc
global expand_heap
global allocate
global malloc
global free
global print_heap
global get_heap_addr

; inputs: rdi, rsi - integer numbers
; return values: rax - max(rdi, rsi)
max_size:
	cmp rdi, rsi
	jl .second_max
	mov rax, rdi
	jmp .finish_max

	.second_max:
		mov rax, rsi

	.finish_max:
		ret

; inputs: rdi - mmap destination (put in 0 to let the OS choose), rsi - the size needed, rdx - additional flags
; return values: rax - address
mmap:
    push rsi
	mov r8, -1				; file descriptor, -1 for anonymous allocation
	mov r9, 0				; offset
	mov r10, rdx			; additional flags moved to r10
	or r10, MAP_PRIVATE		; adding the PRIVATE flag to the additional flags
	or r10, MAP_ANONYMOUS	; adding the ANONYMOUS flag to the additional flags
	mov rax, 9				; syscall number (9 calls mmap)
	mov rdx, PROT_READ		; adding the READ flag
	or rdx, PROT_WRITE		; adding the WRITE flag
	mov rsi, 4096			; page size
	syscall
	pop rsi
	ret

; inputs: rdi - destination address (put in 0 to let the OS choose), rsi - the size needed
; return values: rax - the address of the region or MAP_FAILED
alloc_region:
	push rdi
	mov rdi, REGION_MIN_SIZE
	call max_size
	mov rsi, rax			        ; rsi now holds the actual region size
	add rsi, BLOCK_HEADER_SIZE
	pop rdi
	mov rdx, MAP_FIXED_NOREPLACE
	call mmap				        ; rax holds the region address now
	cmp rax, MAP_FAILED
	jne .init_region

	.without_noreplace:
		mov rdx, 0
		call mmap
		cmp rax, MAP_FAILED
		je .finish_alloc_region
		
	.init_region:
		mov rdi, rax
		sub rsi, BLOCK_HEADER_SIZE
		call new_block
		mov rsi, NULL
		call block_set_next ; it will help to stop the search loop
		
	.finish_alloc_region:
		ret

; BLOCK STRUCTURE
; ---------------------------------
; QWORD - link to the next one
; DWORD - capacity in bytes
; BYTE - is_empty

; inputs: rdi - address, rsi - block capacity
; return values: none
new_block:
	mov QWORD [rdi], 0
	mov DWORD [rdi + 8], esi
	mov BYTE [rdi + 12], 1
	ret

; inputs: rdi - block address
; return values: rax - pointer to the next block
block_get_next:
	mov QWORD rax, [rdi]
	ret

; inputs: rdi - block address
; return values: rax - capacity of the current block (in bytes)
block_get_cap:
	mov DWORD eax, [rdi + 8]
	ret

; inputs: rdi - block address
; return values: rax - 1 if the block is free and 0 if it is not
block_is_empty:
	mov BYTE al, [rdi + 12]
	ret

; inputs: rdi - block address, rsi - pointer to the next block
; return values: none
block_set_next:
	mov QWORD [rdi], rsi
	ret

; inputs: rdi - block address, rsi - the capacity
; return values: none
block_set_cap:
	mov DWORD [rdi + 8], esi
	ret

; inputs: rdi - block address, rsi - 1 means the block is free
; return values: none
block_set_empty:
	mov BYTE [rdi + 12], sil
	ret

; inputs: rdi - block size
; return values: rax - block capacity
capacity_from_size:
	mov rax, rdi
	sub rax, BLOCK_HEADER_SIZE
	ret

; inputs: rdi - block capacity
; return values: rax - block size
size_from_capacity:
	mov rax, rdi
	add rax, BLOCK_HEADER_SIZE
	ret

; inputs: rdi - block address
; return values: rax - pointer to the block after this one
block_after:
	call block_get_cap
	add rax, BLOCK_HEADER_SIZE
	add rax, rdi
	ret

; inputs: rdi - block address, rsi - query size
; return values: rax - 1 if the block can contain query
block_is_big_enough:
    push rdx
    call block_get_cap
    mov rdx, rax
    mov rax, 0
    cmp rdx, rsi
    jl .block_size_check_finish

    .block_is_big_enough:
        mov rax, 1

    .block_size_check_finish:
        pop rdx
        ret

; inputs: rdi - initial size of the heap
; return values: rax - address of the heap
heap_init:
	mov rsi, rdi
	mov rdi, HEAP_START
	call alloc_region
	cmp rax, MAP_FAILED
	je .heap_init_finish

	.save_heap_address:
	    mov [HEAP_ADDR], rax

	.heap_init_finish:
	    ret

; inputs: rdi - block pointer, rsi - query size
; return values: rax - 1 if the block is splittable
block_splittable:
    push rsi
    push rdx
	call block_is_empty
	mov rdx, rax
	add rsi, BLOCK_MIN_CAPACITY
	add rsi, BLOCK_HEADER_SIZE
	call block_get_cap
	cmp rsi, rax
	jg .block_is_not_splittable
	
	.block_is_splittable:
		mov rax, 1
		jmp .block_splittable_finish
		
	.block_is_not_splittable:
		mov rax, 0

	.block_splittable_finish:
		and rax, rdx
		pop rdx
		pop rsi
		ret

; inputs: rdi - block pointer, rsi - query size
; return values: rax - 1 if the splitting was executed successfully
split_big_block:
	call block_splittable
	cmp rax, 0
	je .split_finish
	
	.split_block:
		push rdi
		mov rdi, BLOCK_MIN_CAPACITY
		call max_size
		mov r8, rax					; r8 now holds the actual query size
        pop rdi

		mov rax, rdi
		add rax, BLOCK_HEADER_SIZE
		add rax, r8
	    mov r9, rax                 ; r9 now holds the new block pointer

        call block_get_cap
        sub rax, r8
        mov r10, rax
        sub r10, BLOCK_HEADER_SIZE  ; r10 now holds the new block capacity

        push rdi
        mov rdi, r9
        mov rsi, r10
		call new_block              ; creating the new block
		pop rdi

        push rdi
		call block_get_next
        mov rdi, r9
        mov rsi, rax
        call block_set_next         ; new header is filled
        pop rdi

        mov rsi, r8
        call block_set_cap          ; old block caapacity updated

        mov rsi, r9
        call block_set_next         ; old block next pointer updated

		mov rax, 1                  ; returning true
		
	.split_finish:
		ret

; inputs: rdi - first block pointer, rsi - second block pointer
; return values: rax - 1 if the the blocks are next to each other
block_continuous:
    push rdi
    call block_after
    mov rdi, rax
    mov rax, 0
    cmp rdi, rsi
    jne .block_is_not_cont

    .block_is_cont:
        mov rax, 1

    .block_is_not_cont:
        pop rdi
        ret

; inputs: rdi - first block pointer, rsi - second block pointer
; return values: rax - 1 if the blocks can be merged
mergeable:
    push rdx
    call block_is_empty
    mov rdx, rax

    push rdi
    mov rdi, rsi
    call block_is_empty
    pop rdi

    and rdx, rax
    call block_continuous
    and rax, rdx
    pop rdx
    ret

; inputs: rdi - block pointer
; return values: rax - 1 if the merge is executed successfully
merge_with_next:
    push rsi
    call block_get_next
    mov rdx, rax                    ; rdx is rdi->next
    cmp rax, NULL                   ; finish if there is no next block
    je .merge_finish
    mov rsi, rdx
    call mergeable
    cmp rax, 0                      ; check if the blocks can be merged
    je .merge_finish

    .merge_blocks:
        push rdi
        mov rdi, rdx
        call block_get_next
        mov rsi, rax                ; rsi now holds rdx->next
        pop rdi

        call block_set_next         ; rdi->next = rdx->next

        push rdi
        mov rdi, rdx
        call block_get_cap
        mov rdi, rax
        call size_from_capacity
        mov rsi, rax                ; rsi now holds the size of rdx block
        pop rdi

        call block_get_cap
        add rsi, rax
        call block_set_cap          ; updating the rdi capaity

        mov rax, 1

    .merge_finish:
        pop rsi
        ret

; inputs: rdi - block pointer to start the search from, rsi - query size
; return values: rax - block pointer, rdx - BSR exitcode
find_block:
    push rdi
    push rsi
    .search_loop:
        .merge_loop:
            call merge_with_next
            cmp rax, 1
            je .merge_loop

        call block_is_big_enough
        mov rdx, rax
        call block_is_empty
        and rdx, rax                    ; rdx holds 1 if the block is good
        cmp rdx, 1
        jne .search_loop_continue       ; if the block is not good the loop continues

        .return_good_block:
            mov rax, rdi
            mov rdx, BSR_FOUND_GOOD_BLOCK
            jmp .search_finish

        .search_loop_continue:
            call block_get_next
            cmp rax, NULL
            jne .search_iteration_loop  ; if the next block exists switch to it

        .return_reached_end:
            mov rax, rdi
            mov rdx, BSR_NOT_FOUND
            jmp .search_finish

        .search_iteration_loop:
            call block_get_next
            mov rdi, rax                ; switching to the next block
            jmp .search_loop

    .search_finish:
        pop rsi
        pop rdi
        ret

; Tries to allocate a block without expanding the heap
; inputs: rdi - beginning block, rsi - query size
; return values: rax - block pointer, rdx - BSR exitcode
try_alloc:
    call find_block
    cmp rdx, BSR_NOT_FOUND
    je .try_alloc_finish

    .split_good_block:
        push rdi
        push rax
        mov rdi, rax
        call split_big_block        ; splitting the found block
        pop rax

        push rsi
        mov rdi, rax
        mov rsi, 0
        call block_set_empty        ; marking it as not empty
        pop rsi
        pop rdi

    .try_alloc_finish:
        ret

; inputs: rdi - last block pointer, rsi - query size
; return values: none
expand_heap:
    push rdi
    mov rdi, 0
    call alloc_region
    pop rdi
    mov rsi, rax
    call block_set_next
    ret

; inputs: rdi - heap pointer, rsi - query size
; return values: rax - address of a good block
allocate:
    call try_alloc
    cmp rdx, BSR_FOUND_GOOD_BLOCK
    je .allocate_finish

    .try_expanding:
        push rsi
        push rdi
        mov rdi, rax
        call expand_heap
        pop rdi
        pop rsi

        call try_alloc
        cmp rdx, BSR_FOUND_GOOD_BLOCK
        je .allocate_finish

        mov rax, NULL               ; unable to allocate

    .allocate_finish:
        ret

; inputs: rdi - query size
; return values: rax - address
malloc:
    mov rsi, rdi
    call get_heap_addr
    mov rdi, rax
    call allocate
    cmp rax, NULL
    je .malloc_finish

    .malloc_return_address:
        add rax, BLOCK_HEADER_SIZE

    .malloc_finish:
	    ret

; inputs: rdi - address
; return values: none
free:
    cmp rdi, NULL
    je .free_finish

    sub rdi, BLOCK_HEADER_SIZE
    mov sil, 1
    call block_set_empty

    .free_loop:
        call merge_with_next
        cmp rax, 1
        je .free_loop

    .free_finish:
	    ret

; inputs: none
; return values: none
print_heap:
    call get_heap_addr
    mov rdi, rax

    .block_loop:
        cmp rdi, NULL
        je .print_heap_finish

        push rdi
        mov rdi, INFO_CURRENT_LABEL
        call print_string
        pop rdi

        push rdi
        call print_int
        call print_newline
        pop rdi

        push rdi
        mov rdi, INFO_NEXT_LABEL
        call print_string
        pop rdi

        push rdi
        call block_get_next
        mov rdi, rax
        call print_int
        call print_newline
        pop rdi

        push rdi
        mov rdi, INFO_CAP_LABEL
        call print_string
        pop rdi

        push rdi
        call block_get_cap
        mov rdi, rax
        call print_int
        call print_newline
        pop rdi

        push rdi
        mov rdi, INFO_EMPTY_LABEL
        call print_string
        pop rdi

        push rdi
        call block_is_empty
        mov rdi, rax
        call print_int
        call print_newline
        mov rdi, INFO_SEPARATOR
        call print_string
        call print_newline
        pop rdi

        call block_get_next
        mov rdi, rax
        jmp .block_loop

    .print_heap_finish:
        ret

; inputs: none
; return values: rax - the value of the HEAP_ADDR variable
get_heap_addr:
    mov rax, [HEAP_ADDR]
    ret