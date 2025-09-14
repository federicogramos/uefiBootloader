

	#### para gpt
	#dd if=/dev/zero of=./img/gpt_with_pmbr.img count=$1 bs=1048576
	dd if=/dev/zero of=./img/gpt_with_pmbr.img count=256 bs=1048576


	loop_device=$(losetup --find)
	sudo losetup -P $loop_device ./img/gpt_with_pmbr.img

	sudo parted $loop_device mklabel gpt	# Create GPT partition table (parted writes a protective MBR)

	sudo parted $loop_device mkpart primary fat32 2048s 128MiB	# New 127M partition (efi system partition)
	sudo parted $loop_device set 1 esp on
	sudo parted $loop_device set 1 boot on

	sudo parted $loop_device mkpart primary fat32 128MiB 100%	# 2nd partition.


	sudo mkfs.fat -F 32 ${loop_device}p1	# Format.
	sudo mkfs.fat -F 32 ${loop_device}p2	# Format.

	##sudo mkfs.ext4 ${loop_device}p1

	sudo mkdir /mnt/efi
	sudo mount ${loop_device}p1 /mnt/efi
	sudo mkdir -p /mnt/efi/EFI/BOOT
	echo copy
	sudo cp ./out/BOOTX64.EFI /mnt/efi/EFI/BOOT/BOOTX64.EFI

	sudo umount /mnt/efi
	sudo rmdir /mnt/efi
	sudo losetup -d $loop_device
	unset loop_device
