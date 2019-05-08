3dstool -cvtf romfs romfs.bin --romfs-dir romfs
makerom -f cci -o sbfm.3ds -rsf gw_workaround.rsf -target d -exefslogo -elf sbfm.elf -icon icon.bin -banner banner.bin -romfs romfs.bin
makerom -f cia -o sbfm.cia -elf sbfm.elf -rsf cia_workaround.rsf -icon icon.bin -banner banner.bin -exefslogo -target t -romfs romfs.bin