%include "allocator.inc"
%include "iolib.inc"

%define MIN_VECTOR_SIZE 512
%define BYTE_VECTOR 0           ; 00000000
%define WORD_VECTOR 1           ; 00000001
%define DWORD_VECTOR 2          ; 00000010
%define QWORD_VECTOR 3          ; 00000011
%define EXPANDED_VECTOR 4       ; 00000100
%define INDEX_OK 0
%define INDEX_ERROR 1
%define VECTOR_HEADER_SIZE 13

global items_to_bytes
global bytes_to_items
global actual_vector_size
global vector_get_data
global vector_get_length
global vector_get_type
global vector_get_expanded
global vector_set_data
global vector_set_length
global vector_set_type
global vector_set_expanded
global create_vector
global expand
global reallocate
global get_mem_address
global get_item_no_realloc
global set_item_no_realloc
global delete_vector
global print_vector_header
global print_vector_numbers

section .data

INFO_ADDRESS_LABEL: db 'Header address: ', 0
INFO_DATA_LINK_LABEL: db 'Data pointer: ', 0
INFO_LENGTH_LABEL: db 'Length (in items): ', 0
INFO_TYPE_LABEL: db 'Item type: ', 0
INFO_EXPANDED_LABEL: db 'Expanded: ', 0

section .text

; inputs: rdi - the index, rsi - vector type
; return values: rax - byte index of the item
items_to_bytes:
    mov rax, rdi
    mov rcx, 0

    .shift_loop:
        cmp rcx, rsi
        je .items_to_bytes_finish
        shl rax, 1
        inc rcx
        jmp .shift_loop

    .items_to_bytes_finish:
        ret

; inputs: rdi - the size, rsi - vector type
; return values: rax - the item index
bytes_to_items:
    mov rax, rdi
    mov rcx, 0

    .shift_loop:
        cmp rcx, rsi
        je .items_to_bytes_finish
        shr rax, 1
        inc rcx
        jmp .shift_loop

    .items_to_bytes_finish:
        ret


; inputs: rdi - vector size in items, rsi - vector type
; return values: rax - the number of bytes to contain the data
actual_vector_size:
    push rdi
    push rsi
    call items_to_bytes
    mov rdi, rax
    shr rax, 2
    add rdi, rax                ; 125%
    mov rsi, MIN_VECTOR_SIZE
    call max_size
    pop rsi
    pop rdi
    ret

; VECTOR HEADER
; ---------------------------------
; QWORD - data pointer
; DWORD - length
; BYTE - type and flags (2 lower bits - type, the next bit - expansion flag)

; inputs: rdi - vector pointer
; return values: rax - data pointer
vector_get_data:
    mov QWORD rax, [rdi]
    ret

; inputs: rdi - vector pointer
; return values: rax - length
vector_get_length:
    mov DWORD eax, [rdi + 8]
    ret

; inputs: rdi - vector pointer
; return values: rax - type
vector_get_type:
    mov BYTE al, [rdi + 12]
    and rax, 3                   ; rax and 00000011
    ret

; inputs: rdi - vector pointer
; return values: rax - 1 if the vector is expanded to it's limit
vector_get_expanded:
    mov BYTE al, [rdi + 12]
    and rax, 4                   ; rax and 00000100
    shr rax, 2
    ret

; inputs: rdi - vector pointer, rsi - new data pointer
; return values: none
vector_set_data:
    mov QWORD [rdi], rsi
    ret

; inputs: rdi - vector pointer, rsi - new length
; return values: none
vector_set_length:
    mov DWORD [rdi + 8], esi
    ret

; inputs: rdi - vector pointer, rsi - new type
; return values: none
vector_set_type:
    or BYTE [rdi + 12], sil
    ret

; inputs: rdi - vector pointer, rsi - expanded flag value
; return values: none
vector_set_expanded:
    push rsi
    shl sil, 2
    or BYTE [rdi + 12], sil
    pop rsi
    ret

; inputs: rdi - initial size (in items), rsi - vector type
; return values: rax - vector pointer
create_vector:
    call actual_vector_size
    push rdi
    push rsi
    push rdi
    push rsi
    call actual_vector_size
    mov rdx, rax
    push rdx
    call get_heap_addr
    pop rdx
    cmp rax, NULL
    jne .heap_ready

    mov rdi, rdx
    push rdx
    call heap_init
    pop rdx

    .heap_ready:
        mov rdi, rdx
        call malloc

    mov rbx, rax                        ; rbx holds the data pointer
    mov rdi, VECTOR_HEADER_SIZE
    call malloc                         ; rax holds the header pointer
    pop rsi                             ; rsi holds vector type
    pop rdi                             ; rdi holds it's length

    push rdi
    push rsi

    mov rdi, rax
    mov rsi, rbx
    call vector_set_data                ; setting vector data pointer

    pop rsi
    call vector_set_type                ; setting vector type

    pop rsi
    call vector_set_length              ; setting vector length

    pop rsi                             ; recovering the arguments
    pop rdi
    ret

; inputs: rdi - vector pointer
; return values: 1 if the expansion happened
expand:
    call vector_get_expanded
    cmp rax, 1
    je .unable_to_expand

    push rsi
    mov rsi, 1
    call vector_set_expanded

    call vector_get_type
    mov rbx, rax                         ; saving vector type

    push rdi
    call vector_get_data
    mov rdi, rax
    sub rdi, BLOCK_HEADER_SIZE
    call block_get_cap                  ; getting the memory block capacity to take it all

    mov rdi, rax
    mov rsi, rbx
    call bytes_to_items                 ; getting the number of items the block can fit
    pop rdi

    mov rsi, rax
    call vector_set_length
    pop rsi

    mov rax, 1
    jmp .expand_finish

    .unable_to_expand:
        mov rax, 0

    .expand_finish:
        ret

; inputs: rdi - vector pointer, rsi - new size
; return values: none
reallocate:
    push rbx
    push rdi
    call vector_get_type

    mov rdi, rsi
    mov rsi, rax
    call actual_vector_size

    mov rdi, rax
    call malloc

    mov rbx, rax            ; rbx now holds the address of the new area

    ; ToDo
    pop rdi
    pop rbx
    ret

; Tries to get the item's actual address in memory with expanding the vector
; inputs: rdi - vector pointer, rsi - index
; return values: rax - index exitcode, rdx - memory address of the item
get_mem_address:
    cmp rsi, 0
    jl .index_error

    .try_fit:
        call vector_get_length
        cmp rsi, rax
        jnl .expand_vector

        push rdi
        push rsi

        call vector_get_data

        mov rdx, rax                       ; saving the vector data pointer

        call vector_get_type

        mov rdi, rsi
        mov rsi, rax
        call items_to_bytes                 ; calculating the item offset

        add rdx, rax                        ; adding the item offset to the vector data pointer

        pop rsi
        pop rdi

        mov rax, INDEX_OK
        jmp .get_mem_address_finish

    .expand_vector:
        call expand
        cmp rax, 1
        je .try_fit

    .index_error:
        mov rax, INDEX_ERROR
        mov rdx, 0

    .get_mem_address_finish:
        ret

; inputs: rdi - vector pointer, rsi - index
; return values: rax - index exitcode, rdx - item value
get_item_no_realloc:
    call get_mem_address
    cmp rax, INDEX_ERROR
    je .get_item_nr_finish

    push rbx
    mov rbx, rdx
    mov rdx, 0

    call vector_get_type
    cmp rax, BYTE_VECTOR
    jg .not_byte

    mov BYTE dl, [rbx]
    jmp .get_item_nr_exitcode

    .not_byte:
        cmp rax, WORD_VECTOR
        jg .not_word

        mov WORD dx, [rbx]
        jmp .get_item_nr_exitcode

    .not_word:
        cmp rax, DWORD_VECTOR
        jg .not_dword

        mov DWORD edx, [rbx]
        jmp .get_item_nr_exitcode

    .not_dword:
        mov QWORD rdx, [rbx]
        jmp .get_item_nr_exitcode

    .get_item_nr_exitcode:
        mov rax, INDEX_OK

    .get_item_nr_finish:
        pop rbx
        ret

; inputs: rdi - vector pointer, rsi - index, rdx - new item value
; return values: rax - index exitcode
set_item_no_realloc:
    push rdx
    push rbx
    mov rbx, rdx
    call get_mem_address
    cmp rax, INDEX_ERROR
    je .set_item_nr_finish

    call vector_get_type
    cmp rax, BYTE_VECTOR
    jg .not_byte

    mov BYTE [rdx], bl
    jmp .set_item_nr_exitcode

    .not_byte:
        cmp rax, WORD_VECTOR
        jg .not_word

        mov WORD [rdx], bx
        jmp .set_item_nr_exitcode

    .not_word:
        cmp rax, DWORD_VECTOR
        jg .not_dword

        mov DWORD [rdx], ebx
        jmp .set_item_nr_exitcode

    .not_dword:
        mov QWORD [rdx], rbx
        jmp .set_item_nr_exitcode

    .set_item_nr_exitcode:
        mov rax, INDEX_OK

    .set_item_nr_finish:
        pop rbx
        pop rdx
        ret

; inputs: rdi - vector pointer
; return values: none
delete_vector:
    push rsi
    mov rsi, 0
    ;call vector_set_type
    ;call vector_set_length
    ;push rax

    ;call vector_get_data
    ;push rdi
    ;mov rdi, rax
    ;call free
    ;pop rdi

    ;mov rsi, 0
    ;call vector_set_data

    ;call free

    ;pop rax
    pop rsi
    ret

; inputs: rdi - vector pointer
; return values: none
print_vector_header:
    push rdi
    mov rdi, INFO_ADDRESS_LABEL
    call print_string
    pop rdi

    push rdi
    call print_int
    call print_newline
    pop rdi

    push rdi
    mov rdi, INFO_DATA_LINK_LABEL
    call print_string
    pop rdi

    push rdi
    call vector_get_data
    mov rdi, rax
    call print_int
    call print_newline
    pop rdi

    push rdi
    mov rdi, INFO_LENGTH_LABEL
    call print_string
    pop rdi

    push rdi
    call vector_get_length
    mov rdi, rax
    call print_int
    call print_newline
    pop rdi

    push rdi
    mov rdi, INFO_TYPE_LABEL
    call print_string
    pop rdi

    push rdi
    call vector_get_type
    mov rdi, rax
    call print_int
    call print_newline
    pop rdi

    push rdi
    mov rdi, INFO_EXPANDED_LABEL
    call print_string
    pop rdi

    push rdi
    call vector_get_expanded
    mov rdi, rax
    call print_int
    call print_newline
    pop rdi

    ret

; inputs: rdi - vector pointer
; return values: none
print_vector_numbers:
    call vector_get_length
    mov rcx, rax

    mov rsi, 0

    .print_vector_loop:
        cmp rsi, rcx
        jnl .print_vector_finish

        push rcx
        call get_item_no_realloc
        pop rcx

        push rdi
        push rsi

        push rcx
        mov rdi, rdx
        call print_int
        mov rdi, 32
        call print_char
        pop rcx

        pop rsi
        pop rdi

        inc rsi
        jmp .print_vector_loop

    .print_vector_finish:
        call print_newline
        ret