function TableConcat(t1,t2)
    for i=1,#t2 do
        t1[#t1+1] = t2[i]
    end
    return t1
end
function SortDirectory(dir)
	folders_table = {}
	files_table = {}
	for i,file in pairs(dir) do
		if file.directory then
			table.insert(folders_table,file)
		else
			table.insert(files_table,file)
		end
	end
	table.sort(files_table, function (a, b) return (a.name:lower() < b.name:lower() ) end)
	table.sort(folders_table, function (a, b) return (a.name:lower() < b.name:lower() ) end)
	return_table = TableConcat(folders_table,files_table)
	return return_table
end
--shamefully copied from ORGANIZ3D--


--adds something to the bottom screen--
function logg(str)
	table.insert(logger,str)
	updatescreen()
	Screen.clear(BOTTOM_SCREEN)
end


--prints everything--
function updatescreen()
	--SmileBASIC files--
	Screen.fillRect(0,174,(index-scroll)*15,(index-scroll)*15+10,Color.new(40+(1-selected)*40,40+(1-selected)*40,40+(1-selected)*40),TOP_SCREEN)
	for l, file in pairs(files) do
		if ((l-scroll)*15<240) and ((l-scroll)*15>-1) then
			Screen.debugPrint(0,(l-scroll)*15,file.name,white,TOP_SCREEN)
		end
	end
	--SD card files--
	Screen.fillRect(175,399,(sdindex-sdscroll)*15,(sdindex-sdscroll)*15+10,Color.new(40+(selected)*40,40+(selected)*40,40+(selected)*40),TOP_SCREEN)
	for l, file in pairs(sdfiles) do
		if ((l-sdscroll)*15<240) and ((l-sdscroll)*15>-1) then
			if (string.len(file.name)>23) then
				Screen.debugPrint(175,(l-sdscroll)*15,string.sub(file.name,1,20) .. "...",white,TOP_SCREEN)
			else
				Screen.debugPrint(175,(l-sdscroll)*15,file.name,white,TOP_SCREEN)
			end
		end
	end
	--Bottom screen log--
	for l, logg in pairs(logger) do
		if (l>#logger-16) then
			Screen.debugPrint(0,(15-(#logger-l))*15,logg,white,BOTTOM_SCREEN)
		end
	end
	oldpad=pad
	
	Screen.flip()
	Screen.waitVblankStart()
	Screen.refresh()
end


--copy functions--
function SBtoSD(SBdir,SDdir)
	logg("Source: "..SBdir)
	logg("Destination: "..SDdir)
	readfile = io.open(SBdir,FREAD,archive)
	--open SB file for reading--
	if System.doesFileExist(SDdir) then
		System.deleteFile(SDdir)
		logg("Deleted old "..SDdir)
	end
	--check if SD file exist, delete if true so it doesn't interfere--
	writefile = io.open(SDdir,FCREATE)
	--open SD file for creating and writing--
	filesize = io.size(readfile)
	--get size of file to write--
	i = 0
	while (i+(MAX_RAM_ALLOCATION/2) < filesize) do
		io.write(writefile,i,io.read(readfile,i,MAX_RAM_ALLOCATION/2),(MAX_RAM_ALLOCATION/2))
		i = i + (MAX_RAM_ALLOCATION/2)
	end
	--write SD file from SB file--
	--the 3DS only has so much ram, so it does this in segments--
	if (i < filesize) then
		io.write(writefile,i,io.read(readfile,i,filesize-i),(filesize-i))
	end
	--finish--
	io.close(readfile)
	io.close(writefile)
	--close files--
	logg("Done.")
end
function SDtoSB(SDdir,SBdir)
	logg("Source: "..SDdir)
	logg("Destination: "..SBdir)
	readfile = io.open(SDdir,FREAD)
	--open SD file for reading--
	filesize = io.size(readfile)
	--get size of file to write--
	i=0
	while (string.sub(SBdir,string.len(SBdir)-i,string.len(SBdir)-i)~="/") do
		i=i+1
	end
	if (string.sub(SBdir,string.len(SBdir)-i+1,string.len(SBdir)-i+1)~="B") and (string.sub(SBdir,string.len(SBdir)-i+1,string.len(SBdir)-i+1)~="T") then
		logg("Adding T to filename")
		SBdir=string.sub(SBdir,1,string.len(SBdir)-i).."T"..string.sub(SBdir,string.len(SBdir)-i+1,string.len(SBdir))
	end
	writefile = io.open(SBdir,FCREATE,archive,filesize)
	--open SB file for creating and writing--
	i = 0
	while (i+(MAX_RAM_ALLOCATION/2) < filesize) do
		io.write(writefile,i,io.read(readfile,i,MAX_RAM_ALLOCATION/2),(MAX_RAM_ALLOCATION/2))
		i = i + (MAX_RAM_ALLOCATION/2)
	end
	--write SB file from SD file--
	--the 3DS only has so much ram, so it does this in segments--
	if (i < filesize) then
		io.write(writefile,i,io.read(readfile,i,filesize-i),(filesize-i))
	end
	--finish--
	io.close(readfile)
	io.close(writefile,true)
	--close files--
	logg("Done.")
end


--sandwich copy functions--
function SBtoSDsand(SBdir,SDdir)
	logg("Source: "..SBdir)
	readfile = io.open(SBdir,FREAD,archive)
	logg("Destination: "..SDdir)
	--open SB file for reading--
	if System.doesFileExist(SDdir) then
		System.deleteFile(SDdir)
		logg("Deleted old "..SDdir)
	end
	--check if SD file exist, delete if true so it doesn't interfere--
	writefile = io.open(SDdir,FCREATE)
	--open SD file for creating and writing--
	filesize = io.size(readfile)
	--get size of file to write--
	i = 0
	while (i+(MAX_RAM_ALLOCATION/2) < filesize-100) do
		io.write(writefile,i,io.read(readfile,i+80,MAX_RAM_ALLOCATION/2),(MAX_RAM_ALLOCATION/2))
		i = i + (MAX_RAM_ALLOCATION/2)
	end
	--write SD file from SB file--
	--the 3DS only has so much ram, so it does this in segments--
	if (i < filesize-100) then
		io.write(writefile,i,io.read(readfile,i+80,filesize-100-i),(filesize-100-i))
	end
	--finish--
	io.close(readfile)
	io.close(writefile)
	--close files--
	logg("Done.")
end
function SDtoSBsand(SDdir,SBdir)
	logg("Source: "..SDdir)
	logg("Destination: "..SBdir)
	readfile = io.open(SDdir,FREAD)
	--open SD file for reading--
	filesize = io.size(readfile)
	--get size of file to write--
	i=0
	while (string.sub(SBdir,string.len(SBdir)-i,string.len(SBdir)-i)~="/") do
		i=i+1
	end
	if (string.sub(SBdir,string.len(SBdir)-i+1,string.len(SBdir)-i+1)=="B") then
		if (io.read(readfile,8,12)==hextostring("03 00 02 00 00 02 00 00 00 02 00 00")) then
			logg("Using the GRP file header")
			s=hextostring("01 00 01 00 00 00 02 00")..numbertostring(filesize,4)..hextostring("DF 07 0A 0F 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00")
		else
			logg("Using the DAT file header")
			s=hextostring("01 00 01 00 00 00 00 00")..numbertostring(filesize,4)..hextostring("DF 07 0A 0F 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00")
		end
	else
		if (string.sub(SBdir,string.len(SBdir)-i+1,string.len(SBdir)-i+1)~="T") then
			logg("Adding T to filename")
			SBdir=string.sub(SBdir,1,string.len(SBdir)-i).."T"..string.sub(SBdir,string.len(SBdir)-i+1,string.len(SBdir))
		end
		logg("Using the TXT file header")
		s=hextostring("01 00 00 00 00 00 01 00")..numbertostring(filesize,4)..hextostring("DF 07 0A 0F 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00")
	end
	writefile = io.open(SBdir,FCREATE,archive,filesize+100)
	--open SB file for creating and writing--
	io.write(writefile,0,s,80)
	io.write(writefile,filesize+80,"SB FILE MANAGER FOOT",20)
	--inject custom header and footer--
	i = 0
	while (i+(MAX_RAM_ALLOCATION/2) < filesize) do
		io.write(writefile,i+80,io.read(readfile,i,MAX_RAM_ALLOCATION/2),(MAX_RAM_ALLOCATION/2))
		i = i + (MAX_RAM_ALLOCATION/2)
	end
	--write SB file from SD file--
	--the 3DS only has so much ram, so it does this in segments--
	if (i < filesize) then
		io.write(writefile,i+80,io.read(readfile,i,filesize-i),(filesize-i))
	end
	--finish--
	io.close(readfile)
	io.close(writefile,true)
	--close files--
	logg("Done.")
end


--used in header injection--
function hextostring(s)
	stri=""
	hex={}
	hex["0"]=0
	hex["1"]=1
	hex["2"]=2
	hex["3"]=3
	hex["4"]=4
	hex["5"]=5
	hex["6"]=6
	hex["7"]=7
	hex["8"]=8
	hex["9"]=9
	hex["A"]=10
	hex["B"]=11
	hex["C"]=12
	hex["D"]=13
	hex["E"]=14
	hex["F"]=15
	for i=0,(string.len(s)-2)/3 do
		stri=stri..string.char(hex[string.sub(s,i*3+1,i*3+1)]*16+hex[string.sub(s,i*3+2,i*3+2)])
	end
	return stri
end


--used in parsing header--
function stringtonumber(stri)
	number=0
	for i=1,string.len(stri) do
		number=number+(256^(i-1))*string.byte(stri,i)
	end
	return number
end


--used in header injection for using the correct size--
function numbertostring(num,length)
	stri=""
	while num>0 do
		stri=stri..string.char(math.fmod(num,256))
		num=(num-math.fmod(num,256))/256
	end
	while string.len(stri)<length do
		stri=stri..string.char(0)
	end
	if string.len(stri)>length then --just in case :D
		stri=string.sub(stri,1,length)
	end
	return stri
end

--parses the header--
function logheader()
	valid=1
	if (selected==0) and not (files[index].directory) then
		readfile = io.open("/"..folders[indexbkup].name.."/"..files[index].name,FREAD,archive)
	elseif (selected==1) and not (sdfiles[sdindex].directory) then
		readfile = io.open(System.currentDirectory()..sdfiles[sdindex].name,FREAD)
	else
		valid=0
	end
	if (valid==1) then
		n=stringtonumber(io.read(readfile,2,1))
		if (n==0) then
			logg("Type: TXT")
		elseif (n==1) then
			logg("Type: DAT")
		else
			logg("Type "..n)
		end
		logg("Author: "..io.read(readfile,38,18))
		s=tostring(stringtonumber(io.read(readfile,60,4)))
		logg("Blacklist ID: "..string.sub(s,1,string.len(s)-2))
		s=tostring(stringtonumber(io.read(readfile,8,4)))
		logg("Size: "..string.sub(s,1,string.len(s)-2))
		s1=tostring(stringtonumber(io.read(readfile,12,2)))
		s1=string.sub(s1,1,string.len(s1)-2)
		s2=tostring(stringtonumber(io.read(readfile,14,1)))
		s2=string.sub(s2,1,string.len(s2)-2)
		s3=tostring(stringtonumber(io.read(readfile,15,1)))
		s3=string.sub(s3,1,string.len(s3)-2)
		s4=tostring(stringtonumber(io.read(readfile,16,1)))
		s4=string.sub(s4,1,string.len(s4)-2)
		s5=tostring(stringtonumber(io.read(readfile,17,1)))
		s5=string.sub(s5,1,string.len(s5)-2)
		s6=tostring(stringtonumber(io.read(readfile,18,1)))
		s6=string.sub(s6,1,string.len(s6)-2)
		logg("Last edited: "..s1.."/"..s2.."/"..s3.." "..s4..":"..s5..":"..s6)
		if (n==1) then
			n=stringtonumber(io.read(readfile,88,1))
			if (n==3) then
				logg("Data type: color")
			elseif (n==4) then
				logg("Data type: int")
			elseif (n==5) then
				logg("Data type: real")
			else
				logg("Data type "..n)
			end
			dim=stringtonumber(io.read(readfile,90,1))
			s=""
			for i=1,dim do
				t=tostring(stringtonumber(io.read(readfile,88+4*i,4)))
				s=s..string.sub(t,1,string.len(t)-2)
				if i~=dim then
					s=s.."x"
				else
					if dim==1 then
						s=s.."-item"
					end
					s=s.." array"
				end
			end
			logg(s)
		end
	end
end

--variable declaration--
--messy--
white = Color.new(255,255,255)
archive = 0x16de --American SmileBASIC--

folders = SortDirectory(System.listExtdataDir("/",archive)) --get SB folder list--
files = folders --table for SB file browser--
scroll = 1 --scroll variable for SB file browser--
index = 1 --cursor variable for SB file browser--
indexbkup = 1 --stores cursor on folders so that it can tell which folder you're in and where to put the cursor when you back out of a folder--

System.currentDirectory("/") --set directory to root--
dir="/" --string operations--
sdfiles = SortDirectory(System.listDirectory("/")) --table for SD file browser--
sdscroll = 1 --scroll variable for SD file browser--
sdindex = 1 --cursor variable for SD file browser--

selected = 0 --which file browser is being used--
logger = {} --table for logs on bottom screen - debug stuff and messages--
MAX_RAM_ALLOCATION = 10485760 --used for copying--

Screen.waitVblankStart()
Screen.refresh()

logg("Controls:")
logg("D-pad: Move cursor")
logg("L/R: Switch between file browsers")
logg("A: Navigate into a folder/list header")
logg("B: Navigate out of a folder")
logg("Y: Copy a file or folder")
logg("X: Copy the code of a file or folder")
if (System.checkBuild()==1) then
	logg("Start: Exit")
	logg("Select: Launch SmileBASIC")
else
	logg("L+R+B+Down: Exit")
end

while true do
	Screen.clear(TOP_SCREEN)
	Screen.clear(BOTTOM_SCREEN)
	pad = Controls.read()
	if Controls.check(Controls.read(),KEY_HOME) or Controls.check(Controls.read(),KEY_POWER) then
		System.showHomeMenu()
	end
	if (Controls.check(pad,KEY_START)) and (System.checkBuild()==1) then
		System.exit()
	end
	if (Controls.check(pad,KEY_SELECT)) and (System.checkBuild()==1) then
		System.launchCIA(archive*0x100,SDMC)
	end
	
	--SmileBASIC file viewer controls--
	if selected == 0 then
		--move up and down--
		if (Controls.check(pad,KEY_DUP)) and not (Controls.check(oldpad,KEY_DUP)) then
			if (index>1) then
				index = index - 1
			end
		elseif (Controls.check(pad,KEY_DDOWN)) and not (Controls.check(oldpad,KEY_DDOWN)) then
			if (index<#files) then
				index = index + 1
			end
		end
		if (Controls.check(pad,KEY_DLEFT)) and not (Controls.check(oldpad,KEY_DLEFT)) then
			index = index - 15
			if (index<1) then
				index = 1
			end
		elseif (Controls.check(pad,KEY_DRIGHT)) and not (Controls.check(oldpad,KEY_DRIGHT)) then
			index = index + 15
			if (index>#files) then
				index = #files
			end
		end
		--switch to SD--
		if (Controls.check(pad,KEY_R)) and not (Controls.check(oldpad,KEY_R)) then
			selected = 1
		end
		--go inside a folder/log header--
		if (Controls.check(pad,KEY_A)) and not (Controls.check(oldpad,KEY_A)) then
			if (files[index].directory) then
				files = SortDirectory(System.listExtdataDir("/"..files[index].name.."/",archive))
				indexbkup=index
				index=1
			else
				logheader()
			end
		end
		--exit a folder--
		if (Controls.check(pad,KEY_B)) and not (Controls.check(oldpad,KEY_B)) then
			if (files ~= folders) then
				files = folders
				index=indexbkup
			end
		end
		--adjust scroll--
		while ((index-scroll)*15+15>235) and (scroll<#files-15) do
			scroll = scroll+1
		end
		while ((index-scroll)*15<5) and (scroll>1) do
			scroll = scroll-1
		end
	--SD card file viewer controls--
	else
		--move up and down--
		if (Controls.check(pad,KEY_DUP)) and not (Controls.check(oldpad,KEY_DUP)) then
			if (sdindex>1) then
				sdindex = sdindex - 1
			end
		elseif (Controls.check(pad,KEY_DDOWN)) and not (Controls.check(oldpad,KEY_DDOWN)) then
			if (sdindex<#sdfiles) then
				sdindex = sdindex + 1
			end
		end
		if (Controls.check(pad,KEY_DLEFT)) and not (Controls.check(oldpad,KEY_DLEFT)) then
			sdindex = sdindex - 15
			if (sdindex<1) then
				sdindex = 1
			end
		elseif (Controls.check(pad,KEY_DRIGHT)) and not (Controls.check(oldpad,KEY_DRIGHT)) then
			sdindex = sdindex + 15
			if (sdindex>#sdfiles) then
				sdindex = #sdfiles
			end
		end
		--switch to SB--
		if (Controls.check(pad,KEY_L)) and not (Controls.check(oldpad,KEY_L)) then
			selected = 0
		end
		--go inside a folder/log header--
		if (Controls.check(pad,KEY_A)) and not (Controls.check(oldpad,KEY_A)) then
			if (sdfiles[sdindex].directory) then
				dir=dir..sdfiles[sdindex].name.."/"
				System.currentDirectory(dir)
				sdfiles = SortDirectory(System.listDirectory(dir))
				sdindex=1
			else
				logheader()
			end
		end
		--back out of a folder--
		if (Controls.check(pad,KEY_B)) and not (Controls.check(oldpad,KEY_B)) then
			if (dir ~= "/") then
				dir=string.sub(dir,1,string.len(dir)-1)
				while string.sub(dir,string.len(dir),string.len(dir))~="/" do
					dir=string.sub(dir,1,string.len(dir)-1)
				end
				System.currentDirectory(dir)
				sdfiles = SortDirectory(System.listDirectory(dir))
				sdindex=1
			end
		end
		--adjust scroll--
		while ((sdindex-sdscroll)*15+15>235) and (sdscroll<#sdfiles-15) do
			sdscroll = sdscroll+1
		end
		while ((sdindex-sdscroll)*15<5) and (sdscroll>1) do
			sdscroll = sdscroll-1
		end
	end
	--copy--
	if (Controls.check(pad,KEY_Y)) and not (Controls.check(oldpad,KEY_Y)) then
		logg("Copying...")
		if (selected==0) then
			if (files[index].directory) then
				System.createDirectory(System.currentDirectory()..files[index].name)
				insidefolder=SortDirectory(System.listExtdataDir("/"..files[index].name.."/",archive))
				for l,file in pairs(insidefolder) do
					SBtoSD("/"..files[index].name.."/"..file.name,System.currentDirectory()..files[index].name.."/"..file.name)
				end
			else
				SBtoSD("/"..folders[indexbkup].name.."/"..files[index].name,System.currentDirectory()..files[index].name)
			end
			sdfiles = SortDirectory(System.listDirectory(System.currentDirectory()))
		elseif (selected==1) and not (files[index].directory and not sdfiles[sdindex].directory) then
			if (sdfiles[sdindex].directory) then
				System.createExtdataDir("/"..sdfiles[sdindex].name,archive)
				insidefolder=SortDirectory(System.listDirectory(System.currentDirectory()..sdfiles[sdindex].name.."/"))
				for l,file in pairs(insidefolder) do
					SDtoSB(System.currentDirectory()..sdfiles[sdindex].name.."/"..file.name,"/"..sdfiles[sdindex].name.."/"..file.name)
				end
			else
				SDtoSB(System.currentDirectory()..sdfiles[sdindex].name,"/"..folders[indexbkup].name.."/"..sdfiles[sdindex].name)
			end
			if (files[index].directory) then
				files = SortDirectory(System.listExtdataDir("/",archive))
			else
				files = SortDirectory(System.listExtdataDir("/"..folders[indexbkup].name.."/",archive))
			end
		else
			logg("Could not copy.")
		end
	end
	--sandwich copying
	if (Controls.check(pad,KEY_X)) and not (Controls.check(oldpad,KEY_X)) then
		logg("Copying code only...")
		if (selected==0) then
			if (files[index].directory) then
				System.createDirectory(System.currentDirectory()..files[index].name)
				insidefolder=SortDirectory(System.listExtdataDir("/"..files[index].name.."/",archive))
				for l,file in pairs(insidefolder) do
					SBtoSDsand("/"..files[index].name.."/"..file.name,System.currentDirectory()..files[index].name.."/"..file.name)
				end
			else
				SBtoSDsand("/"..folders[indexbkup].name.."/"..files[index].name,System.currentDirectory()..files[index].name)
			end
			sdfiles = SortDirectory(System.listDirectory(System.currentDirectory()))
		elseif (selected==1) and not (files[index].directory and not sdfiles[sdindex].directory) then
			if (sdfiles[sdindex].directory) then
				System.createExtdataDir("/"..sdfiles[sdindex].name,archive)
				insidefolder=SortDirectory(System.listDirectory(System.currentDirectory()..sdfiles[sdindex].name.."/"))
				for l,file in pairs(insidefolder) do
					SDtoSBsand(System.currentDirectory()..sdfiles[sdindex].name.."/"..file.name,"/"..sdfiles[sdindex].name.."/"..file.name)
				end
			else
				SDtoSBsand(System.currentDirectory()..sdfiles[sdindex].name,"/"..folders[indexbkup].name.."/"..sdfiles[sdindex].name)
			end
			if (files[index].directory) then
				files = SortDirectory(System.listExtdataDir("/",archive))
			else
				files = SortDirectory(System.listExtdataDir("/"..folders[indexbkup].name.."/",archive))
			end
		else
			logg("Could not copy.")
		end
	end
	
	updatescreen()
end
