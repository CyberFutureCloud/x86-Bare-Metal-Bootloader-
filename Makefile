all: boot.img

boot.img: boot.asm
	nasm -f bin -o boot.img boot.asm

run: boot.img
	qemu-system-x86_64 -drive format=raw,file=boot.img

clean:
	rm -f boot.img
