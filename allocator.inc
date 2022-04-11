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

extern max_size
extern mmap
extern alloc_region
extern new_block
extern block_get_next
extern block_get_cap
extern block_is_empty
extern block_set_next
extern block_set_cap
extern block_set_empty
extern capacity_from_size
extern size_from_capacity
extern block_after
extern heap_init
extern block_splittable
extern split_big_block
extern block_continuous
extern mergeable
extern merge_with_next
extern find_block
extern try_alloc
extern expand_heap
extern allocate
extern malloc
extern free
extern print_heap
extern get_heap_addr