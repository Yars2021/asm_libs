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

extern create_file
extern open_write
extern open_read
extern fprint_string
extern fread_string
extern fprint_char
extern fprint_newline
extern fprint_uint
extern fprint_int
extern fprintln_string
extern fprintln_char
extern fprintln_uint
extern fprintln_int
extern print_string
extern read_string
extern print_char
extern print_newline
extern print_uint
extern print_int
extern println_string
extern println_char
extern println_uint
extern println_int
