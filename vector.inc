%define MIN_VECTOR_SIZE 512
%define BYTE_VECTOR 0
%define WORD_VECTOR 1
%define DWORD_VECTOR 2
%define QWORD_VECTOR 3
%define INDEX_ERROR -1
%define VECTOR_HEADER_SIZE 5

extern items_to_bytes
extern create_vector
extern items_to_bytes
extern actual_vector_size
extern vector_get_data
extern vector_get_length
extern vector_get_type
extern vector_get_expanded
extern vector_set_data
extern vector_set_length
extern vector_set_type
extern vector_set_expanded
extern create_vector
extern expand
extern reallocate
extern get_mem_address
extern get_item_no_realloc
extern set_item_no_realloc
extern delete_vector
extern print_vector_header
extern print_vector_numbers