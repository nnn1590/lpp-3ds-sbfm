local ops = {}

function ops.uint32_lrot(a, bits)
   return ((a << bits) & 0xFFFFFFFF) | (a >> (32 - bits))
end

function ops.byte_xor(a, b)
   return a ~ b
end

function ops.uint32_xor_3(a, b, c)
   return a ~ b ~ c
end

function ops.uint32_xor_4(a, b, c, d)
   return a ~ b ~ c ~ d
end

function ops.uint32_ternary(a, b, c)
   -- c ~ (a & (b ~ c)) has less bitwise operations than (a & b) | (~a & c).
   return c ~ (a & (b ~ c))
end

function ops.uint32_majority(a, b, c)
   -- (a & (b | c)) | (b & c) has less bitwise operations than (a & b) | (a & c) | (b & c).
   return (a & (b | c)) | (b & c)
end


local common = {}

-- Merges four bytes into a uint32 number.
function common.bytes_to_uint32(a, b, c, d)
   if a==nil then a=0 end if b==nil then b=0 end if c==nil then c=0 end if d==nil then d=0 end
   return a * 0x1000000 + b * 0x10000 + c * 0x100 + d
end

-- Splits a uint32 number into four bytes.
function common.uint32_to_bytes(a)
   local a4 = a % 256
   a = (a - a4) / 256
   local a3 = a % 256
   a = (a - a3) / 256
   local a2 = a % 256
   local a1 = (a - a2) / 256
   return a1, a2, a3, a4
end


local sha1 = {
   -- Meta fields retained for compatibility.
   _VERSION     = "sha.lua 0.6.0",
   _URL         = "https://github.com/mpeterv/sha1",
   _DESCRIPTION = [[
SHA-1 secure hash and HMAC-SHA1 signature computation in Lua,
using bit and bit32 modules and Lua 5.3 operators when available
and falling back to a pure Lua implementation on Lua 5.1.
Based on code orignally by Jeffrey Friedl and modified by
Eike Decker and Enrique García Cota.]],
   _LICENSE = [[
MIT LICENSE

Copyright (c) 2013 Enrique García Cota, Eike Decker, Jeffrey Friedl
Copyright (c) 2018 Peter Melnichenko

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.]]
}

sha1.version = "0.6.0"

local uint32_lrot = ops.uint32_lrot
local byte_xor = ops.byte_xor
local uint32_xor_3 = ops.uint32_xor_3
local uint32_xor_4 = ops.uint32_xor_4
local uint32_ternary = ops.uint32_ternary
local uint32_majority = ops.uint32_majority

local bytes_to_uint32 = common.bytes_to_uint32
local uint32_to_bytes = common.uint32_to_bytes

local sbyte = string.byte
local schar = string.char
local sformat = string.format
local srep = string.rep

local function hex_to_binary(hex)
   return (hex:gsub("..", function(hexval)
      return schar(tonumber(hexval, 16))
   end))
end

-- Calculates SHA1 for a string, returns it encoded as 40 hexadecimal digits.
function sha1.sha1(str)
   -- Input preprocessing.
   -- First, append a `1` bit and seven `0` bits.
   local first_append = schar(0x80)

   -- Next, append some zero bytes to make the length of the final message a multiple of 64.
   -- Eight more bytes will be added next.
   local non_zero_message_bytes = #str + 1 + 8
   local second_append = srep(schar(0), -non_zero_message_bytes % 64)

   -- Finally, append the length of the original message in bits as a 64-bit number.
   -- Assume that it fits into the lower 32 bits.
   local third_append = schar(0, 0, 0, 0, uint32_to_bytes(#str * 8))

   str = str .. first_append .. second_append .. third_append
   assert(#str % 64 == 0)

   -- Initialize hash value.
   local h0 = 0x67452301
   local h1 = 0xEFCDAB89
   local h2 = 0x98BADCFE
   local h3 = 0x10325476
   local h4 = 0xC3D2E1F0

   local w = {}

   -- Process the input in successive 64-byte chunks.
   for chunk_start = 1, #str, 64 do
      -- Load the chunk into W[0..15] as uint32 numbers.
      local uint32_start = chunk_start
	  local i

      for i = 0, 15 do
         w[i] = bytes_to_uint32(sbyte(str, uint32_start, uint32_start + 3))
         uint32_start = uint32_start + 4
      end

      -- Extend the input vector.
      for i = 16, 79 do
         w[i] = uint32_lrot(uint32_xor_4(w[i - 3], w[i - 8], w[i - 14], w[i - 16]), 1)
      end

      -- Initialize hash value for this chunk.
      local a = h0
      local b = h1
      local c = h2
      local d = h3
      local e = h4

      -- Main loop.
      for i = 0, 79 do
         local f
         local k

         if i <= 19 then
            f = uint32_ternary(b, c, d)
            k = 0x5A827999
         elseif i <= 39 then
            f = uint32_xor_3(b, c, d)
            k = 0x6ED9EBA1
         elseif i <= 59 then
            f = uint32_majority(b, c, d)
            k = 0x8F1BBCDC
         else
            f = uint32_xor_3(b, c, d)
            k = 0xCA62C1D6
         end

         local temp = (uint32_lrot(a, 5) + f + e + k + w[i]) &0x0ffffffff --% 4294967296
         e = d
         d = c
         c = uint32_lrot(b, 30)
         b = a
         a = temp
      end

      -- Add this chunk's hash to result so far.
      h0 = (h0 + a) &0x0ffffffff --% 4294967296
      h1 = (h1 + b) &0x0ffffffff --% 4294967296
      h2 = (h2 + c) &0x0ffffffff --% 4294967296
      h3 = (h3 + d) &0x0ffffffff --% 4294967296
      h4 = (h4 + e) &0x0ffffffff --% 4294967296
   end

   return sformat("%08x%08x%08x%08x%08x", h0, h1, h2, h3, h4)
end

function sha1.binary(str)
   return hex_to_binary(sha1.sha1(str))
end

-- Precalculate replacement tables.
local xor_with_0x5c = {}
local xor_with_0x36 = {}

for i = 0, 0xff do
   xor_with_0x5c[schar(i)] = schar(byte_xor(0x5c, i))
   xor_with_0x36[schar(i)] = schar(byte_xor(0x36, i))
end

-- 512 bits.
local BLOCK_SIZE = 64

function sha1.hmac(key, text)
   if #key > BLOCK_SIZE then
      key = sha1.binary(key)
   end

   local key_xord_with_0x36 = key:gsub('.', xor_with_0x36) .. srep(schar(0x36), BLOCK_SIZE - #key)
   local key_xord_with_0x5c = key:gsub('.', xor_with_0x5c) .. srep(schar(0x5c), BLOCK_SIZE - #key)

   return sha1.sha1(key_xord_with_0x5c .. sha1.binary(key_xord_with_0x36 .. text))
end

function sha1.hmac_binary(key, text)
   return hex_to_binary(sha1.hmac(key, text))
end





--copied from ORGANIZ3D--
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
function DeleteDir(dir)
	todelfiles = System.listDirectory(dir)
	for z, todelfile in pairs(todelfiles) do
		if (todelfile.directory) then
			DeleteDir(dir.."/"..todelfile.name)
		else
			System.deleteFile(dir.."/"..todelfile.name)
		end
	end
	System.deleteDirectory(dir)
end
function DeleteExtDir(dir,arch)
	todelfiles = System.listExtdataDir(dir,arch)
	for z, todelfile in pairs(todelfiles) do
		if (todelfile.directory) then
			DeleteExtDir(dir.."/"..todelfile.name,arch)
		else
			System.deleteFile(dir.."/"..todelfile.name,arch)
		end
	end
	System.deleteDirectory(dir,arch)
end
--copied from ORGANIZ3D--


--adds something to the top screen log--
function logg(str,flag)
	table.insert(logger,str)
	if flag~=0 then advanceframe() end
end
function advanceframe()
	updatescreen()
	Screen.clear(TOP_SCREEN)
	Screen.clear(BOTTOM_SCREEN)
end
function clearlogg()
	for k,v in pairs(logger) do logger[k]=nil end
end
function syscontrols()
	oldpad = pad
	pad = Controls.read()
	px,py = Controls.readCirclePad()
	if px<-100 and not Controls.check(pad,KEY_DLEFT) then pad = pad + KEY_DLEFT end
	if px>100 and not Controls.check(pad,KEY_DRIGHT) then pad = pad + KEY_DRIGHT end
	if py<-100 and not Controls.check(pad,KEY_DDOWN) then pad = pad + KEY_DDOWN end
	if py>100 and not Controls.check(pad,KEY_DUP) then pad = pad + KEY_DUP end
	for l,i in pairs({0,1,4,5,6,7,8,9,10,11}) do
		if times[i]==nil then times[i]=0 end
		if Controls.check(pad,2^i) and Controls.check(oldpad,2^i) then
			times[i]=times[i]+1
			if times[i]-14>=0 and times[i]%2==0 then oldpad=oldpad-2^i end --brepeat--
		else times[i]=0 end
	end
	if Controls.check(pad,KEY_HOME) or Controls.check(pad,KEY_POWER) then
		System.showHomeMenu()
	end
	-- Exit if HomeMenu calls APP_EXITING
    if System.checkStatus() == APP_EXITING then
        System.exit()
    end
	if (Controls.check(pad,KEY_START)) and (System.checkBuild()==1) then
		System.exit()
	end
	if (Controls.check(pad,KEY_SELECT)) and (System.checkBuild()==1) then
		System.launchCIA(archive*0x100,SDMC)
	end
end

--uses a png of the smilebasic font, as drawing with the Font module is laggy
function print(x,y,text,color,screen)
	for i = 1, #text do
		c = string.byte(text,i)
		Graphics.drawPartialImage(x,y,(c%64)*8,math.floor(c/64)*8,8,8,font,color)
		x=x+8
	end
	
end

--better keyboard
function keyboardinput(prompt,text,newlines)
	enter = false
	shifton = 1
	pastkey = "blank"
	out={} --only used if newlines==true
	if newlines then
		out[1]=text
		outindex=1
	end
	repeat
		Screen.clear(TOP_SCREEN)
		Screen.clear(BOTTOM_SCREEN)
		--controls
		oldpad=pad
		syscontrols()
		if Controls.check(pad,KEY_A) and not Controls.check(oldpad,KEY_A) then enter=true end --A=Enter
		if Controls.check(pad,KEY_Y) and not Controls.check(oldpad,KEY_Y) then --Y=Backspace
			if newlines then
				if out[outindex]=="" then
					if outindex>1 then outindex=outindex-1 end
					text=out[outindex]
				else
					out[outindex]=string.sub(out[outindex],1,string.len(out[outindex])-1)
				end
			else
				text=string.sub(text,1,string.len(text)-1)
			end
		end
		if Controls.check(pad,KEY_L) or Controls.check(pad,KEY_R) then --L or R=Shift
			shifton=2
		end
		if (not Controls.check(pad,KEY_L) and Controls.check(oldpad,KEY_L) and not Controls.check(pad,KEY_R)) or (not Controls.check(pad,KEY_R) and Controls.check(oldpad,KEY_R) and not Controls.check(pad,KEY_L)) then --when L and R are released then shift returns to off
			shifton=1
		end
		tx,ty = Controls.readTouch()
		if tx==0 and ty==0 then
			keypressed = ""
			pastkey = ""
		else
			ty=math.floor(ty/48)+1
			tx=math.floor((tx-keyrowdata[ty])/24)+1
			if tx<1 then tx=1 end
			if tx>#keyboard[shifton][ty] then tx=#keyboard[shifton][ty] end
			keypressed=keyboard[shifton][ty][tx]
			if keypressed~=pastkey and pastkey=="" then
				if string.len(keypressed)==1 then
					if newlines then out[outindex]=out[outindex]..keypressed else text=text..keypressed end
					if not Controls.check(pad,KEY_L) and not Controls.check(pad,KEY_R) and shifton==2 then shifton=1 end
				else
					if keypressed=="Sh" then
						if not Controls.check(pad,KEY_L) and not Controls.check(pad,KEY_R) then shifton=3-shifton end
					end --toggle shift
					if keypressed=="Space" then
						if newlines then out[outindex]=out[outindex].." " else text=text.." " end --do the space thing
					end
					if keypressed=="<-" then
						if newlines then
							if out[outindex]=="" then
								if outindex>1 then outindex=outindex-1 end
								text=out[outindex]
							else
								out[outindex]=string.sub(out[outindex],1,string.len(out[outindex])-1)
							end
						else
							text=string.sub(text,1,string.len(text)-1)
						end
					end --delete the last character
					if keypressed=="Ent" then
						if newlines==false then
							enter=true 
						else
							outindex=outindex+1
							if out[outindex]==nil then out[outindex]="" end
						end
					end --enter was pressed
				end
			end
			pastkey = keypressed
		end
		Graphics.initBlend(BOTTOM_SCREEN)
		--drawing the keyboard
		y=1
		while y<=5 do
			x=1
			while x<=#keyboard[shifton][y] do
				if keypressed==keyboard[shifton][y][x] then col=green else col=white end
				if string.len(keyboard[shifton][y][x])>1 then ofs=0 else ofs=4 end
				print(ofs+keyrowdata[y]+24*(x-1),16+48*(y-1),keyboard[shifton][y][x],col,BOTTOM_SCREEN)
				x=x+1
			end
			y=y+1
		end
		Graphics.termBlend()
		Graphics.initBlend(TOP_SCREEN)
		print(0,92,prompt,white,TOP_SCREEN)
		if newlines then
			for i,t in pairs(out) do
				print(16,112+15*(i-1),t,white,TOP_SCREEN)
			end
		else
			print(16,112,text,white,TOP_SCREEN)
		end
		Graphics.termBlend()
		Screen.flip()
		Screen.waitVblankStart()
		Screen.refresh()
	until enter == true
	if newlines then
		text=""
		for i,t in pairs(out) do
			if i>1 then text=text..string.char(13)..string.char(10) end
			text=text..t
		end
	end
	return text
end

--numpad
function numpadinput(prompt,text)
	enter = false
	k={{{"0",1},{"0",0},{".",1}},{{"<-",1},{"Ent",0},{"Ent",1},{"Ent",0}}}
	pastkey = "blank"
	repeat
		Screen.clear(TOP_SCREEN)
		Screen.clear(BOTTOM_SCREEN)
		--controls
		syscontrols()
		if Controls.check(pad,KEY_A) and not Controls.check(oldpad,KEY_A) then enter=true end --A=Enter
		if Controls.check(pad,KEY_Y) and not Controls.check(oldpad,KEY_Y) then text=string.sub(text,1,string.len(text)-1) end --Y=Backspace - This is for SmileBASIC users after all
		tx,ty = Controls.readTouch()
		if tx==0 and ty==0 then
			numpressed = ""
			pastkey = ""
		else
			ty=math.floor(ty*4/240)
			tx=math.floor(tx*4/320)
			if ty<3 and tx<3 then numpressed=tostring(tx+ty*3+1) else
				if tx==3 then numpressed=k[2][ty+1][1] else numpressed=k[1][tx+1][1] end
			end
			if numpressed~=pastkey and pastkey=="" then
				if string.len(numpressed)==1 then
					text=text..numpressed
					if shifton==2 then shifton=1 end
				else
					if numpressed=="<-" then text=string.sub(text,1,string.len(text)-1) end --delete the last character
					if numpressed=="Ent" then enter=true end
				end
			end
			pastkey = numpressed
		end
		Graphics.initBlend(BOTTOM_SCREEN)
		--drawing the keyboard
		y=0
		while y<4 do
			x=0
			while x<4 do
				if y<3 and x<3 then key=tostring(x+y*3+1) else
					if x==3 then
						if k[2][y+1][2]==1 then key=k[2][y+1][1] else key="" end
					else
						if k[1][x+1][2]==1 then key=k[1][x+1][1] else key="" end
					end
				end
				if numpressed==key then col=green else col=white end
				print((320/4)*x+320/8,(240/4)*y+240/8,key,col,BOTTOM_SCREEN)
				x=x+1
			end
			y=y+1
		end
		Graphics.termBlend()
		Graphics.initBlend(TOP_SCREEN)
		print(0,92,prompt,white,TOP_SCREEN)
		print(16,112,text,white,TOP_SCREEN)
		Graphics.termBlend()
		Screen.flip()
		Screen.waitVblankStart()
		Screen.refresh()
	until enter == true
	return text
end

--waits for the user to confirm
function confirm()
	okay=false --default false
	repeat syscontrols() updatescreen() until (((Controls.check(pad,KEY_A)) and not (Controls.check(oldpad,KEY_A))) or ((Controls.check(pad,KEY_B)) and not (Controls.check(oldpad,KEY_B))))
	if (Controls.check(pad,KEY_A)) and not (Controls.check(oldpad,KEY_A)) then
		okay=true
	elseif (Controls.check(pad,KEY_B)) and not (Controls.check(oldpad,KEY_B)) then
		okay=false
	end
	oldpad=pad
	return okay
end

--prints everything--
function updatescreen()
	Graphics.initBlend(BOTTOM_SCREEN)
	--SmileBASIC files--
	Graphics.fillRect(0,128,math.floor((index-scroll)*8),math.floor((index-scroll)*8)+8,Color.new(40+(1-selected)*40,40+(1-selected)*40,40+(1-selected)*40))
	for l, file in pairs(files) do
		if ((l-scroll)*8<240) and ((l-scroll)*8>-8) then
			if (string.len(file.name)>16) then filename=string.sub(file.name,1,13).."..." else filename=file.name end
			if file.directory then col=white else col=green end
			print(0,math.floor((l-scroll)*8),filename,col,BOTTOM_SCREEN)
		end
	end
	--SD card files--
	Graphics.fillRect(128,320,math.floor((sdindex-sdscroll)*8),math.floor((sdindex-sdscroll)*8)+8,Color.new(40+(selected)*40,40+(selected)*40,40+(selected)*40))
	for l, file in pairs(sdfiles) do
		if ((l-sdscroll)*8<240) and ((l-sdscroll)*8>-8) then
			if (string.len(file.name)>24) then filename=string.sub(file.name,1,21).."..." else filename=file.name end
			if file.directory then col=white else col=green end
			print(128,math.floor((l-sdscroll)*8),filename,col,BOTTOM_SCREEN)
		end
	end
	Graphics.termBlend()
	Graphics.initBlend(TOP_SCREEN)
	--Top screen log--
	for l, logg in pairs(logger) do
		if (l>=#logger-30) then
			print(0,(29-(#logger-l))*8,string.sub(logg,1,50),white,TOP_SCREEN)
		end
	end
	Graphics.termBlend()
	Screen.flip()
	Screen.waitVblankStart()
	Screen.refresh()
end

function isdir(t,i)
	if #t==0 then
		ans=false
	else
		ans=t[i].directory
	end
	return ans
end

--copy functions--
function copy()
	clearlogg()
	logg("How do you want to copy this",0)
	logg("file/folder?",0)
	logg("B: Cancel",0)
	logg("Y: Copy full file, including header",0)
	logg(" and footer",0)
	logg("X: Copy only the code of a file.",0)
	if selected==1 then
		logg(" Only use this when you have a file",0)
		logg(" containing only the code for a",0)
		logg(" program",0)
	end
	if selected==1 then
		logg("A: Copy only the contents of a DAT.",0)
		logg(" Only use this when all of your",0)
		logg(" files are in the DAT format, but",0)
		logg(" without even a secondary DAT",0)
		logg(" header.",1)
	else
		logg("A: Copy only the contents of a DAT.",1)
	end
	repeat syscontrols() updatescreen() until ((Controls.check(pad,KEY_B) and not Controls.check(oldpad,KEY_B)) or (Controls.check(pad,KEY_Y) and not Controls.check(oldpad,KEY_Y)) or (Controls.check(pad,KEY_X) and not Controls.check(oldpad,KEY_X)) or (Controls.check(pad,KEY_A) and not Controls.check(oldpad,KEY_A)))
	clearlogg()
	counter=0
	if (Controls.check(pad,KEY_B)) and not (Controls.check(oldpad,KEY_B)) then
		logg("Copy aborted",1)
	elseif (Controls.check(pad,KEY_Y)) and not (Controls.check(oldpad,KEY_Y)) then
		logg("Copying...",1)
		if (selected==0) then
			if (isdir(files,index)) then
				System.createDirectory(System.currentDirectory()..files[index].name)
				insidefolder=SortDirectory(System.listExtdataDir("/"..files[index].name.."/",archive))
				for l,file in pairs(insidefolder) do
					SBtoSD("/"..files[index].name.."/"..file.name,System.currentDirectory()..files[index].name.."/"..file.name)
				end
			elseif not (#files==0) then
				SBtoSD("/"..folders[indexbkup].name.."/"..files[index].name,System.currentDirectory()..files[index].name)
			else
				logg("You can't copy anything from",0)
				logg("an empty folder.",1)
			end
			sdfiles = SortDirectory(System.listDirectory(System.currentDirectory()))
		elseif (selected==1) and not (isdir(files,index) and not isdir(sdfiles,sdindex)) then
			if (isdir(sdfiles,sdindex)) then
				System.createDirectory("/"..sdfiles[sdindex].name,archive)
				insidefolder=SortDirectory(System.listDirectory(System.currentDirectory()..sdfiles[sdindex].name.."/"))
				for l,file in pairs(insidefolder) do
					SDtoSB(System.currentDirectory()..sdfiles[sdindex].name.."/"..file.name,"/"..sdfiles[sdindex].name.."/"..file.name)
				end
			elseif not (#sdfiles==0) then
				SDtoSB(System.currentDirectory()..sdfiles[sdindex].name,"/"..folders[indexbkup].name.."/"..sdfiles[sdindex].name)
			else
				logg("You can't copy anything from",0)
				logg("an empty folder.",1)
			end
			if (isdir(files,index)) then
				files = SortDirectory(System.listExtdataDir("/",archive))
			else
				files = SortDirectory(System.listExtdataDir("/"..folders[indexbkup].name.."/",archive))
			end
		else
			logg("Could not copy.",0)
			logg("Go into a folder in the SB",0)
			logg("pane to copy the file.",1)
		end
	elseif (Controls.check(pad,KEY_X)) and not (Controls.check(oldpad,KEY_X)) then
		logg("Copying code only...",1)
		if (selected==0) then
			if (isdir(files,index)) then
				System.createDirectory(System.currentDirectory()..files[index].name)
				insidefolder=SortDirectory(System.listExtdataDir("/"..files[index].name.."/",archive))
				for l,file in pairs(insidefolder) do
					SBtoSDsand("/"..files[index].name.."/"..file.name,System.currentDirectory()..files[index].name.."/"..file.name)
				end
			elseif not (#files==0) then
				SBtoSDsand("/"..folders[indexbkup].name.."/"..files[index].name,System.currentDirectory()..files[index].name)
			else
				logg("You can't copy anything from",0)
				logg("an empty folder.",1)
			end
			sdfiles = SortDirectory(System.listDirectory(System.currentDirectory()))
		elseif (selected==1) and not (isdir(files,index) and not isdir(sdfiles,sdindex)) then
			if (isdir(sdfiles,sdindex)) then
				System.createDirectory("/"..sdfiles[sdindex].name,archive)
				insidefolder=SortDirectory(System.listDirectory(System.currentDirectory()..sdfiles[sdindex].name.."/"))
				for l,file in pairs(insidefolder) do
					SDtoSBsand(System.currentDirectory()..sdfiles[sdindex].name.."/"..file.name,"/"..sdfiles[sdindex].name.."/"..file.name)
				end
			elseif not (#sdfiles==0) then
				SDtoSBsand(System.currentDirectory()..sdfiles[sdindex].name,"/"..folders[indexbkup].name.."/"..sdfiles[sdindex].name)
			else
				logg("You can't copy anything from",0)
				logg("an empty folder.",1)
			end
			if (isdir(files,index)) then
				files = SortDirectory(System.listExtdataDir("/",archive))
			else
				files = SortDirectory(System.listExtdataDir("/"..folders[indexbkup].name.."/",archive))
			end
		else
			logg("Could not copy.",1)
		end
	elseif (Controls.check(pad,KEY_A)) and not (Controls.check(oldpad,KEY_A)) then
		logg("Copying DAT contents...",1)
		if (selected==0) then
			if (isdir(files,index)) then
				System.createDirectory(System.currentDirectory()..files[index].name)
				insidefolder=SortDirectory(System.listExtdataDir("/"..files[index].name.."/",archive))
				for l,file in pairs(insidefolder) do
					SBtoSDdat("/"..files[index].name.."/"..file.name,System.currentDirectory()..files[index].name.."/"..file.name)
				end
			elseif not (#files==0) then
				SBtoSDdat("/"..folders[indexbkup].name.."/"..files[index].name,System.currentDirectory()..files[index].name)
			else
				logg("You can't copy anything from",0)
				logg("an empty folder.",1)
			end
			sdfiles = SortDirectory(System.listDirectory(System.currentDirectory()))
		elseif (selected==1) and not (isdir(files,index) and not isdir(sdfiles,sdindex)) then
			if (isdir(sdfiles,sdindex)) then
				System.createDirectory("/"..sdfiles[sdindex].name,archive)
				insidefolder=SortDirectory(System.listDirectory(System.currentDirectory()..sdfiles[sdindex].name.."/"))
				for l,file in pairs(insidefolder) do
					SDtoSBdat(System.currentDirectory()..sdfiles[sdindex].name.."/"..file.name,"/"..sdfiles[sdindex].name.."/"..file.name)
				end
			elseif not (#sdfiles==0) then
				SDtoSBdat(System.currentDirectory()..sdfiles[sdindex].name,"/"..folders[indexbkup].name.."/"..sdfiles[sdindex].name)
			else
				logg("You can't copy anything from",0)
				logg("an empty folder.",1)
			end
			if (isdir(files,index)) then
				files = SortDirectory(System.listExtdataDir("/",archive))
			else
				files = SortDirectory(System.listExtdataDir("/"..folders[indexbkup].name.."/",archive))
			end
		else
			logg("Could not copy.",1)
		end
	end
	syscontrols()
end

function SBtoSD(SBdir,SDdir)
	logg("Source: "..SBdir,0)
	logg("Destination: "..SDdir,1)
	readfile = io.open(SBdir,FREAD,archive)
	--open SB file for reading--
	if System.doesFileExist(SDdir) then
		System.deleteFile(SDdir)
		logg("Deleted old "..SDdir,1)
	end
	--check if SD file exist, delete if true so it doesn't interfere--
	writefile = io.open(SDdir,FCREATE)
	--open SD file for creating and writing--
	filesize = io.size(readfile)
	--get size of file to write--
	local d=io.read(readfile,0,filesize)
	io.write(writefile,0,d,filesize)
	--finish--
	io.close(readfile)
	io.close(writefile)
	--close files--
	logg("Done.",1)
end
function SDtoSB(SDdir,SBdir)
	logg("Source: "..SDdir,0)
	logg("Destination: "..SBdir,1)
	readfile = io.open(SDdir,FREAD)
	--open SD file for reading--
	filesize = io.size(readfile)
	--get size of file to write--
	local i=0
	while (string.sub(SBdir,string.len(SBdir)-i,string.len(SBdir)-i)~="/") do
		i=i+1
	end
	if (string.sub(SBdir,string.len(SBdir)-i+1,string.len(SBdir)-i+1)~="B") and (string.sub(SBdir,string.len(SBdir)-i+1,string.len(SBdir)-i+1)~="T") then
		if io.read(readfile,2,1)==1 then
			logg("This looks like a DAT file",0)
			logg("Adding B to filename",1)
			SBdir=string.sub(SBdir,1,string.len(SBdir)-i).."B"..string.sub(SBdir,string.len(SBdir)-i+1,string.len(SBdir))
		else
			logg("This looks like a TXT file",0)
			logg("Adding T to filename",1)
			SBdir=string.sub(SBdir,1,string.len(SBdir)-i).."T"..string.sub(SBdir,string.len(SBdir)-i+1,string.len(SBdir))
		end
	end
	writefile = io.open(SBdir,FCREATE,archive,filesize)
	--open SB file for creating and writing--
	local d=io.read(readfile,0,filesize)
	io.write(writefile,0,d,filesize)
	--finish--
	io.close(readfile)
	io.close(writefile,true)
	--close files--
	logg("Done.",1)
end


--sandwich copy functions--
function SBtoSDsand(SBdir,SDdir)
	logg("Source: "..SBdir,0)
	readfile = io.open(SBdir,FREAD,archive)
	logg("Destination: "..SDdir,1)
	--open SB file for reading--
	if System.doesFileExist(SDdir) then
		System.deleteFile(SDdir)
		logg("Deleted old "..SDdir,1)
	end
	--check if SD file exist, delete if true so it doesn't interfere--
	writefile = io.open(SDdir,FCREATE)
	--open SD file for creating and writing--
	filesize = io.size(readfile)
	
	local d=io.read(readfile,80,filesize-100)
	io.write(writefile,0,d,filesize-100)
	--finish--
	io.close(readfile)
	io.close(writefile)
	--close files--
	logg("Done.",1)
end
function SDtoSBsand(SDdir,SBdir)
	logg("Source: "..SDdir,0)
	logg("Destination: "..SBdir,1)
	readfile = io.open(SDdir,FREAD)
	--open SD file for reading--
	filesize = io.size(readfile)
	--get size of file to write--
	local i=0
	while (string.sub(SBdir,string.len(SBdir)-i,string.len(SBdir)-i)~="/") do
		i=i+1
	end
	if (string.sub(SBdir,string.len(SBdir)-i+1,string.len(SBdir)-i+1)=="B") then
		if (io.read(readfile,8,12)==hextostring("03 00 02 00 00 02 00 00 00 02 00 00")) then
			logg("Using the GRP file header",1)
			s=hextostring("01 00 01 00 00 00 02 00")..numbertostring(filesize,4)..hextostring("DF 07 0A 0F 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00")
		else
			logg("Using the DAT file header",1)
			s=hextostring("01 00 01 00 00 00 00 00")..numbertostring(filesize,4)..hextostring("DF 07 0A 0F 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00")
		end
	elseif (string.sub(SBdir,string.len(SBdir)-i+1,string.len(SBdir)-i+1)=="T") then
		logg("Using the TXT file header",1)
		s=hextostring("01 00 00 00 00 00 01 00")..numbertostring(filesize,4)..hextostring("DF 07 0A 0F 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00")
	else
		logg("Is this a TXT, DAT, or GRP file?",0)
		logg("A: TXT",0)
		logg("B: DAT",0)
		logg("Y: GRP",1)
		repeat syscontrols() updatescreen() until (((Controls.check(pad,KEY_A)) and not (Controls.check(oldpad,KEY_A))) or ((Controls.check(pad,KEY_B)) and not (Controls.check(oldpad,KEY_B))) or ((Controls.check(pad,KEY_Y)) and not (Controls.check(oldpad,KEY_Y))))
		if (Controls.check(pad,KEY_A)) and not (Controls.check(oldpad,KEY_A)) then
			logg("Adding T to filename",0)
			SBdir=string.sub(SBdir,1,string.len(SBdir)-i).."T"..string.sub(SBdir,string.len(SBdir)-i+1,string.len(SBdir))
			logg("Using the TXT file header",1)
			s=hextostring("01 00 00 00 00 00 01 00")..numbertostring(filesize,4)..hextostring("DF 07 0A 0F 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00")
		elseif (Controls.check(pad,KEY_B)) and not (Controls.check(oldpad,KEY_B)) then
			logg("Adding B to filename",0)
			SBdir=string.sub(SBdir,1,string.len(SBdir)-i).."B"..string.sub(SBdir,string.len(SBdir)-i+1,string.len(SBdir))
			logg("Using the DAT file header",1)
			s=hextostring("01 00 01 00 00 00 00 00")..numbertostring(filesize,4)..hextostring("DF 07 0A 0F 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00")
		elseif (Controls.check(pad,KEY_X)) and not (Controls.check(oldpad,KEY_X)) then
			logg("Adding B to filename",0)
			SBdir=string.sub(SBdir,1,string.len(SBdir)-i).."B"..string.sub(SBdir,string.len(SBdir)-i+1,string.len(SBdir))
			logg("Using the GRP file header",1)
			s=hextostring("01 00 01 00 00 00 02 00")..numbertostring(filesize,4)..hextostring("DF 07 0A 0F 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00")
		end
	end
	writefile = io.open(SBdir,FCREATE,archive,filesize+100)
	--open SB file for creating and writing--
	io.write(writefile,0,s,80)
	local d=io.read(readfile,0,filesize)
	io.write(writefile,80,d,filesize)
	io.write(writefile,filesize+80,sha1.hmac_binary([[nqmby+e9S?{%U*-V]51n%^xZMk8>b{?x]&?(NmmV[,g85:%6Sqd"'U")/8u77UL2]],s..d),20)
	--finish--
	io.close(readfile)
	io.close(writefile,true)
	--close files--
	logg("Done.",1)
end


--DAT copy functions--
function SBtoSDdat(SBdir,SDdir)
	logg("Source: "..SBdir,0)
	readfile = io.open(SBdir,FREAD,archive)
	logg("Destination: "..SDdir,1)
	--open SB file for reading--
	if System.doesFileExist(SDdir) then
		System.deleteFile(SDdir)
		logg("Deleted old "..SDdir,1)
	end
	--check if SD file exist, delete if true so it doesn't interfere--
	writefile = io.open(SDdir,FCREATE)
	--open SD file for creating and writing--
	filesize = io.size(readfile)
	--get size of file to write--
	local d=io.read(readfile,108,filesize-128)
	io.write(writefile,0,d,filesize-128)
	--finish--
	io.close(readfile)
	io.close(writefile)
	--close files--
	logg("Done.",1)
end
function getdatheader(filesize)
	o=hextostring("50 43 42 4E 30 30 30 31")
	repeat
		n=keyboardinput("Type (col, int, or real):","",false)
	until (n=="col" or n=="int" or n=="real")
	if n=="col" then
		typ=1
		o=o..numbertostring(3,2)
	elseif n=="int" then
		typ=2
		o=o..numbertostring(4,2)
	elseif n=="real" then
		typ=3
		o=o..numbertostring(5,2)
	end
	repeat
		n=numpadinput("Number of dimensions (1, 2, 3, or 4):","")
	until ((not string.find(n,"%D")) and tonumber(n)<=4 and tonumber(n)>=1)
	o=o..numbertostring(tonumber(n),2)
	sizes={2,4,8}
	if n=="1" then 
		num=math.floor(filesize/sizes[typ])
	end
	nums={"1st","2nd","3rd","4th"}
	local i=1
	while i<=4 do
		if i<=tonumber(n) then
			if n~="1" then
				repeat
					num=numpadinput(nums[i].." dimension size:","")
				until ((not string.find(n,"%D")) and tonumber(num)>0)
				num=tonumber(num)
			end
		else
			num=0
		end
		o=o..numbertostring(num,4)
		i=i+1
	end
	return o
end
function SDtoSBdat(SDdir,SBdir)
	logg("Source: "..SDdir,0)
	logg("Destination: "..SBdir,1)
	readfile = io.open(SDdir,FREAD)
	--open SD file for reading--
	filesize = io.size(readfile)
	--get size of file to write--
	local i=0
	while (string.sub(SBdir,string.len(SBdir)-i,string.len(SBdir)-i)~="/") do
		i=i+1
	end
	if (string.sub(SBdir,string.len(SBdir)-i+1,string.len(SBdir)-i+1)~="B") then
		logg("Adding B to filename",0)
		SBdir=string.sub(SBdir,1,string.len(SBdir)-i).."B"..string.sub(SBdir,string.len(SBdir)-i+1,string.len(SBdir))
	end
	logg("Is this a DAT or GRP file?",0)
	logg("A: DAT",0)
	logg("B: GRP",1)
	okay=confirm()
	if okay then
		logg("Using the DAT file header",1)
		s=hextostring("01 00 01 00 00 00 00 00")..numbertostring(filesize,4)..hextostring("DF 07 0A 0F 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00")
		s=s..getdatheader(filesize)
	else
		logg("Using the GRP file header",1)
		s=hextostring("01 00 01 00 00 00 02 00")..numbertostring(filesize,4)..hextostring("DF 07 0A 0F 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00")
		logg("This is a 512x512 col array,",0)
		logg("correct?",0)
		logg("A: Yes",0)
		logg("B: No",1)
		okay=confirm()
		if okay then
			s=s..hextostring("50 43 42 4E 30 30 30 31 03 00 02 00 00 02 00 00 00 02 00 00 30 37 2B 00 CC 1C 2E 00") --generic GRP header
		else
			s=s..getdatheader(filesize)
		end
	end
	writefile = io.open(SBdir,FCREATE,archive,filesize+128)
	--open SB file for creating and writing--
	io.write(writefile,0,s,108)
	local d=io.read(readfile,0,filesize)
	io.write(writefile,108,d,filesize)
	io.write(writefile,filesize+108,sha1.hmac_binary([[nqmby+e9S?{%U*-V]51n%^xZMk8>b{?x]&?(NmmV[,g85:%6Sqd"'U")/8u77UL2]],s..d),20)
	io.close(readfile)
	io.close(writefile,true)
	--close files--
	logg("Done.",1)
end
--end copy functions

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
	local i
	for i=0,(string.len(s)-2)/3 do
		stri=stri..string.char(hex[string.sub(s,i*3+1,i*3+1)]*16+hex[string.sub(s,i*3+2,i*3+2)])
	end
	return stri
end

--used in parsing header--
function stringtonumber(stri)
	number=0
	local i
	for i=1,string.len(stri) do
		number=number+(256^(i-1))*string.byte(stri,i)
	end
	return number
end

--used in header injection for using the correct size--
function numbertostring(num,length)
	stri=""
	while num>0 do
		stri=stri..string.char(math.fmod(math.floor(num),256))
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
	counter=0
	clearlogg()
	valid=1
	if (selected==0) and not (isdir(files,index)) then
		readfile = io.open("/"..folders[indexbkup].name.."/"..files[index].name,FREAD,archive)
	elseif (selected==1) and not (isdir(sdfiles,sdindex)) then
		readfile = io.open(System.currentDirectory()..sdfiles[sdindex].name,FREAD)
	else
		valid=0
	end
	if (valid==1) then
		n=stringtonumber(io.read(readfile,2,1))
		if (n==0) then
			logg("Type: TXT",0)
		elseif (n==1) then
			logg("Type: DAT",0)
		else
			logg("Type "..n,0)
		end
		logg("Author: "..io.read(readfile,38,18),0)
		s=tostring(stringtonumber(io.read(readfile,60,4)))
		logg("Blacklist ID: "..string.sub(s,1,string.len(s)-2),0)
		s=tostring(stringtonumber(io.read(readfile,8,4)))
		logg("Size: "..string.sub(s,1,string.len(s)-2),0)
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
		logg("Last edited: "..s1.."/"..s2.."/"..s3.." "..s4..":"..s5..":"..s6,1)
		if (n==1) then
			n=stringtonumber(io.read(readfile,88,1))
			if (n==3) then
				logg("Data type: color",0)
			elseif (n==4) then
				logg("Data type: int",0)
			elseif (n==5) then
				logg("Data type: real",0)
			else
				logg("Data type "..n,0)
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
			logg(s,1)
		end
		io.close(readfile)
	end
end

--variable declaration--
if System.getRegion()==2 then
	archive=0x1a1c --European SB--
else if System.getRegion()==1 then
	archive=0x1172 --JP SB--
else
	archive=0x16de --US SB--
end
Graphics.init()
if System.checkBuild()==1 then
	font=Graphics.loadImage("romfs:/sbfont.png")
else
	font=Graphics.loadImage(System.currentDirectory().."sbfont.png")
end

white=Color.new(255,255,255)
green=Color.new(0,255,0)

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
counter = 60 --resets logg to controls when it reaches 120--
times={} --stores how long each button has been held down--

keyboard = {{ --array containing keyboard data
{"1","2","3","4","5","6","7","8","9","0","-","=","<-"},
{"q","w","e","r","t","y","u","i","o","p","[","]","\\"},
{"a","s","d","f","g","h","j","k","l",";","'","Ent"},
{"Sh","z","x","c","v","b","n","m",",",".","/"},
{"Space"}
},{
{"!","@","#","$","%","^","&","*","(",")","_","+","<-"},
{"Q","W","E","R","T","Y","U","I","O","P","{","}","|"},
{"A","S","D","F","G","H","J","K","L",":",'"',"Ent"},
{"Sh","Z","X","C","V","B","N","M","<",">","?"},
{"Space"}
}}
keyrowdata = {4,4,12,20,100} --offsets of the keyboard rows

Screen.disable3D()

Screen.waitVblankStart()
Screen.refresh()

while true do
	Screen.clear(TOP_SCREEN)
	Screen.clear(BOTTOM_SCREEN)
	syscontrols()
	
	if counter==60 then
		clearlogg()
		logg("SmileBASIC File Manager Version 1.7.0",0)
		logg("Controls:",0)
		logg("Circle pad/D-pad: Move cursor",0)
		logg("L/R: Switch between file browsers",0)
		logg("A: Navigate into a folder/list header",0)
		logg("B: Navigate out of a folder",0)
		logg("Y: Copy a file or folder",0)
		logg("X: Create/delete",0)
		if (System.checkBuild()==1) then
			logg("Start: Exit",0)
			logg("Select: Launch SmileBASIC",0)
		else
			logg("L+R+B+Down: Exit",0)
		end
	end
	if counter<=60 then counter=counter+1 end
	
	--touch scrolling--
	otx=tx
	oty=ty
	tx,ty = Controls.readTouch()
	if otx~=nil and otx~=0 and tx~=0 then
		if tx<128 then
			ta=0
			scroll=scroll-(ty-oty)/8
		else
			ta=1
			sdscroll=sdscroll-(ty-oty)/8
		end
		tvel=(ty-oty)
	end
	if (otx==nil or otx==0) and tx~=0 then
		if tx<128 then
			ta=0
			oldindex=index
			index=math.floor(ty/8+scroll)
			if index>#files then index=#files end
			if index<1 then index=1 end
			if oldindex==index and selected==0 then
				if not Controls.check(pad,KEY_A) then pad=pad+KEY_A end
				if Controls.check(oldpad,KEY_A) then oldpad=oldpad-KEY_A end
			end
			selected=0
		else
			ta=1
			oldsdindex=sdindex
			sdindex=math.floor(ty/8+sdscroll)
			if sdindex>#sdfiles then sdindex=#sdfiles end
			if sdindex<1 then sdindex=1 end
			if oldsdindex==sdindex and selected==1 then
				if not Controls.check(pad,KEY_A) then pad=pad+KEY_A end
				if Controls.check(oldpad,KEY_A) then oldpad=oldpad-KEY_A end
			end
			selected=1
		end
	end
	if tx==0 and tvel~=nil and tvel~=0 then
		tvel=tvel/1.1
		if ta==0 then scroll=scroll-tvel/8 else sdscroll=sdscroll-tvel/8 end
		if tvel<0.1 and tvel>-0.1 then tvel=0 end
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
			index = index - 30
			if (index<1) then
				index = 1
			end
		elseif (Controls.check(pad,KEY_DRIGHT)) and not (Controls.check(oldpad,KEY_DRIGHT)) then
			index = index + 30
			if (index>#files) then
				index = #files
				if (index==0) then index=1 end
			end
		end
		--switch to SD--
		if (Controls.check(pad,KEY_R)) and not (Controls.check(oldpad,KEY_R)) then
			selected = 1
		end
		--go inside a folder/log header--
		if (Controls.check(pad,KEY_A)) and not (Controls.check(oldpad,KEY_A)) then
			if #files>0 then
				if (isdir(files,index)) then
					files = SortDirectory(System.listExtdataDir("/"..files[index].name.."/",archive))
					indexbkup=index
					index=1
					scroll=0
				else
					logheader()
				end
			end
		end
		--exit a folder--
		if (Controls.check(pad,KEY_B)) and not (Controls.check(oldpad,KEY_B)) then
			if (files ~= folders) then
				files = folders
				index=indexbkup
			end
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
			sdindex = sdindex - 30
			if (sdindex<1) then
				sdindex = 1
			end
		elseif (Controls.check(pad,KEY_DRIGHT)) and not (Controls.check(oldpad,KEY_DRIGHT)) then
			sdindex = sdindex + 30
			if (sdindex>#sdfiles) then
				sdindex = #sdfiles
				if (sdindex==0) then sdindex=1 end
			end
		end
		--switch to SB--
		if (Controls.check(pad,KEY_L)) and not (Controls.check(oldpad,KEY_L)) then
			selected = 0
		end
		--go inside a folder/log header--
		if (Controls.check(pad,KEY_A)) and not (Controls.check(oldpad,KEY_A)) then
			if #sdfiles>0 then
				if (isdir(sdfiles,sdindex)) then
					dir=dir..sdfiles[sdindex].name.."/"
					System.currentDirectory(dir)
					sdfiles = SortDirectory(System.listDirectory(dir))
					if sdfiles==nil then sdfiles={} end
					sdindex=1
					sdscroll=0
				else
					logheader()
				end
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
				if sdfiles==nil then sdfiles={} end
				sdindex=1
			end
		end
	end
	if otx==nil or otx==0 or tx==0 or tx>=128 then
		--adjust scroll--
		if ((index-scroll)*8>240-16) and (scroll<#files-29) then
			target=index-(240-16)/8
			if target>#files-29 then target=#files-29 end
			if target<1 then target=1 end
			scroll=scroll+(target-scroll)/4
		end
		if (index-scroll<1) and (scroll>1) then
			target=index-1.12
			if target<1 then target=1 end
			scroll=scroll+(target-scroll)/4
		end
		if scroll<1 then scroll=scroll+(1-scroll)/4 elseif scroll>#files-29 then
			target=#files-29
			if target<1 then target=0.88 end
			scroll=scroll+(target-scroll)/4
		end
	end
	if otx==nil or otx==0 or tx<128 then
		--sd scroll
		if ((sdindex-sdscroll)*8>240-16) and (sdscroll<#sdfiles-29) then
			target=sdindex-(240-16)/8
			if target>#sdfiles-29 then target=#sdfiles-29 end
			if target<1 then target=1 end
			sdscroll=sdscroll+(target-sdscroll)/4
		end
		if (sdindex-sdscroll<1) and (sdscroll>1) then
			target=sdindex-1.12
			if target<1 then target=1 end
			sdscroll=sdscroll+(target-sdscroll)/4
		end
		if sdscroll<1 then sdscroll=sdscroll+(1-sdscroll)/4 elseif sdscroll>#sdfiles-29 then
			target=#sdfiles-29
			if target<1 then target=0.88 end
			sdscroll=sdscroll+(target-sdscroll)/4
		end
	end
	--copy--
	if (Controls.check(pad,KEY_Y)) and not (Controls.check(oldpad,KEY_Y)) then
		copy()
	end
	if (Controls.check(pad,KEY_X)) and not (Controls.check(oldpad,KEY_X)) then
		clearlogg()
		counter=0
		logg("A: Create folder",0)
		logg("X: Delete folder/file",0)
		logg("B: Cancel",1)
		repeat syscontrols() updatescreen() until (((Controls.check(pad,KEY_A)) and not (Controls.check(oldpad,KEY_A))) or ((Controls.check(pad,KEY_B)) and not (Controls.check(oldpad,KEY_B))) or ((Controls.check(pad,KEY_X)) and not (Controls.check(oldpad,KEY_X))))
		if Controls.check(pad,KEY_A) and not Controls.check(oldpad,KEY_A) then
			foldername=keyboardinput("Folder name:","",false);
			if selected==1 then
				System.createDirectory(System.currentDirectory()..foldername)
			else
				System.createDirectory("/"..foldername,archive)
			end
			sdfiles = SortDirectory(System.listDirectory(System.currentDirectory()))
			if (isdir(files,index)) then
				files = SortDirectory(System.listExtdataDir("/",archive))
			else
				files = SortDirectory(System.listExtdataDir("/"..folders[indexbkup].name.."/",archive))
			end
		elseif Controls.check(pad,KEY_X) and not Controls.check(oldpad,KEY_X) then
			if not (selected==0 and #files==0) and not (selected==1 and #sdfiles==0) then logg("Are you sure you want to delete",0) end
			filename=""
			directory=false
			if (selected==0) then
				if (isdir(files,index)) then
					filename="/"..files[index].name
					directory=true
				elseif not (#files==0) then
					filename="/"..folders[indexbkup].name.."/"..files[index].name
					directory=false
				else
					logg("You can't delete anything from",0)
					logg("an empty folder.",1)
				end
			elseif (selected==1) then
				if not (#sdfiles==0) then
					filename=System.currentDirectory()..sdfiles[sdindex].name
					directory=isdir(sdfiles,sdindex)
				else
					logg("You can't delete anything from",0)
					logg("an empty folder.",1)
				end
			end
			if filename~="" then
				logg(filename,0)
				logg("A: Yes",0)
				logg("B: No",1)
				okay=confirm()
				if okay then
					if selected==0 then
						if directory then DeleteExtDir(filename,archive) else System.deleteFile(filename,archive) end
					else
						if directory then DeleteDir(filename) else System.deleteFile(filename) end
					end
				end
				sdfiles = SortDirectory(System.listDirectory(System.currentDirectory()))
				if (isdir(files,index)) then
					files = SortDirectory(System.listExtdataDir("/",archive))
				else
					files = SortDirectory(System.listExtdataDir("/"..folders[indexbkup].name.."/",archive))
				end
				--adjust scroll--
				while ((sdindex-sdscroll)*15+15>235) and (sdscroll<#sdfiles-15) do
					sdscroll = sdscroll+1
				end
				while ((sdindex-sdscroll)*15<5) and (sdscroll>1) do
					sdscroll = sdscroll-1
				end
				while ((index-scroll)*15+15>235) and (scroll<#files-15) do
					scroll = scroll+1
				end
				while ((index-scroll)*15<5) and (scroll>1) do
					scroll = scroll-1
				end
			end
		end
	end
	
	updatescreen()
end
