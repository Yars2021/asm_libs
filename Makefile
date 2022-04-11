TARGET	= main
LINKER	= ld

ASM_EXT	= ".asm"
OBJ_EXT	= ".o"

all: main.o
	ld -o ${TARGET} "main.o" "vector.o" "allocator.o" "iolib.o"

main.o:
	nasm -g "main${ASM_EXT}" -felf64 -o "main${OBJ_EXT}"
	nasm -g "vector${ASM_EXT}" -felf64 -o "vector${OBJ_EXT}"
	nasm -g "allocator${ASM_EXT}" -felf64 -o "allocator${OBJ_EXT}"
	nasm -g "iolib${ASM_EXT}" -felf64 -o "iolib${OBJ_EXT}"

clean:
	rm -f ./*.o ./${TARGET}

