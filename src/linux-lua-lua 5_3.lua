
return function(cb, ...)
	--made for luafox runtime--
	local lfastr = require("lfastr")
	local serpent = require("serpent")
	local copas = require("copas")
	local lfs = require("lfs")
	copas.addthread(function(...)
		_G.newProc = function(cb, ...)
				return copas.addthread(cb, ...)
		end
		_G.aStep = function()
			copas.sleep(0)
		end
		_G.sleep = function(ms)
			copas.sleep(ms / 1000)
		end
		_G.Promise = {}
		_G.Promise.__index = _G.Promise
		
		function _G.Promise.new(executor)
		    local self = setmetatable({
		        _state = "pending", -- "pending", "fulfilled", or "rejected"
		        _value = nil,
		        _then_queue = {},
		        _catch_queue = {}
		    }, _G.Promise)
		
		    local function resolve(value)
		        if self._state ~= "pending" then return end
		        self._state = "fulfilled"
		        self._value = value
		        
		        copas.addthread(function()
		            for _, cb in ipairs(self._then_queue) do
		                pcall(cb, self._value)
										copas.sleep(0)
		            end
		            return false
		        end)
		    end
		
		    local function reject(reason)
		        if self._state ~= "pending" then return end
		        self._state = "rejected"
		        self._value = reason
		        
		        GLib.idle_add(GLib.PRIORITY_DEFAULT, function()
		            for _, cb in ipairs(self._catch_queue) do
		                pcall(cb, self._value)
		            end
		            return false
		        end)
		    end
		
		    local ok, err = pcall(executor, resolve, reject)
		    if not ok then
		        reject(err)
		    end
		
		    return self
		end
		
		-- Replaces .then() with .after()
		function _G.Promise:after(on_fulfilled)
		    if self._state == "fulfilled" then
		        GLib.idle_add(GLib.PRIORITY_DEFAULT, function() on_fulfilled(self._value); return false end)
		    elseif self._state == "pending" then
		        table.insert(self._then_queue, on_fulfilled)
		    end
		    return self -- Allows chaining more methods
		end
		
		function _G.Promise:catch(on_rejected)
		    if self._state == "rejected" then
		  		copas.addthread(function() on_rejected(self._value); return false end)
		    elseif self._state == "pending" then
		        table.insert(self._catch_queue, on_rejected)
		    end
		    return self
		end
		--global async promise bassed functions--
		_G.aFor = function(callback, itr)
				return Promise.new(function(resolve, reject)
					local tb = {""}
					local tb2 = {true}
					repeat
							aStep()
							tb = {pcall(itr)}
							aStep()
							if not tb[1] then
								reject("error on iterator: " .. tb[2])
							end
							aStep()
							tb2 = {pcall(callback, table.unpack(tb, 2, #tb))}
							if not tb2[1] then
								reject("error on callback: " .. tb2[2])
								aStep()
							end
					until tb[2] == nil or (not tb[1] or not tb2[1])
					aStep()
					resolve(table.unpack(tb2, 2, #tb2))
				end)
		end
		function _G.aWhile(callback, boolcb, ...)
			local tb2 = {...}
			return Promise.new(function(resolve)
				local tb = {}
				local go = boolcb()
				while Go do
					aStep()
					tb = {pcall(callback, table.unpack(tb2, 1, #tb2))}
					if not tb[1] then
							reject("error on callback: " .. tb[2])
					end
				end
				resolve(table.unpack(tb, 2, #tb))
			end)
		end
		-- global adjustmemts--
		_G.clear = function()
			os.execute('clear')
		end
		_G._PLATFORM = {"linux", "lua", _VERSION}
		function _G.dostring(str)
		  return load(str, '=DoString_Chunk', 'bt')
		end
		--table adjustments--
		table.stringify = function(tb)
		  return serpent.line(tb, {comment=false})
		end
		function table.parse(str)
		  return load("return " .. str, '=Table_Parser', 't')()
		end
		--filesystem--
		do
		  local fs = {}
		  fs.paths = {
		AppData = os.getenv('HOME') .. '/.config/',
		User = os.getenv("HOME") .. '/',
		lfrtBin = os.getenv('HOME') .. '/.config/lfrt/prg/',
		lfrtLib = os.getenv('HOME') .. '/.config/lfrt/lib/',
		lfrt = os.getenv('HOME') .. '/.config/lfrt/'
		}
		  fs.exists = function(path)
		    if lfs.touch(path) then
		      return true
		    else
		      return false
		    end
		  end
		  fs.create = function(path, data)
		    local a = ''
		    for i, v in ipairs(path:split('/')) do
					aStep()
		      a = a .. v .. '/'
		      b, c = lfs.touch(a)
					aStep()
		      if not b then
		        if data ~= nil and i >= #path:split('/') then
		          local f0 = io.open(path, 'wb')
		          f0:write(data)
		          f0:flush()
		          f0:close()
		        else
		          lfs.mkdir(a)
		        end
		      end
		    end
		  end
		  fs.list = function(path, isFull, recurse)
		    local out = {}
		    local function cycle(s, p)
		      for f in lfs.dir(s .. p) do
						aStep()
		       if f ~= '.' and f ~= '..' then
		        if fs.attributes(s .. p .. '/' ..  f).mode == 'file' then
		          if isFull then
		            table.insert(out, s .. p .. '/' .. f)
		          else
		            table.insert(out, p .. '/' .. f) 
		          end
		        	else
		          	cycle(s, p .. '/' .. f)
		          	if isFull then
		            	table.insert(out, s .. p .. '/' .. f)
		          	else
		            	table.insert(out, p .. '/' .. f)
		          	end
		        	end
						end
		      end
		    end
		    if recurse then
		    	cycle(path, '')
		    else
		    	for f in lfs.dir(path) do
						aStep()
		        if f ~= '.' and f ~= '..' then
		    			if isFull then
		    				table.insert(out, path .. '/' .. f)
		    			else
		    				table.insert(out, f) 
		    			end
						end
		    	end
		    end
		    return out
		  end
			fs.open = function(...)
				log("filesystem.open is deprecated avoid using. now use filesystem.[readPart, writePart, readAll, writeAll]")
				return io.open(...)
			end
		  fs.attributes = lfs.attributes
		  fs.remove = function(path)
		    if lfs.attributes(path).mode == 'directory' then
		      local function cycle(s, p)
						aStep()
		        for f in lfs.dir(s .. p) do
		          if f ~= '.' and f ~= '..' then
		            if lfs.attributes(s .. p .. '/' .. f).mode == 'file' then
		              os.remove(s .. p .. '/' .. f)
		            elseif lfs.attributes(s .. p .. '/' .. f).mode == 'directory' then
		              cycle(s, p .. '/' .. f)
		              lfs.rmdir(s .. p .. '/' ..  f)
		            end
		          end
		        end
		      end
		      cycle(path, "")
					lfs.rmdir(path)
		    else
		      os.remove(path)
		    end
		  end
		  fs.pwd = function(val)
		    if val then
		      lfs.chdir(val)
		    end
				return lfs.currentdir()
		  end
			function fs.readAll(path)
				assert(fs.exists(path), "File Not Found: " .. path)
				local f = io.open(path, 'rb')
				local dat = ""
				repeat
					local buff = f:read(1024)
					aStep()
					dat = dat .. (buff or "")
				until not buff
				f:flush()
				f:close()
				return dat
			end
			function fs.writeAll(path, data)
				local f = io.open(path, 'wb')
				f:write(data)
				f:flush()
				f:close()
			end
		  function fs.readPart(path)
				local f = io.open(path, 'rb')
				return function(size, close)
					if close then
						f:flush()
						f:close()
					else
						aStep()
						return f:read(size)
					end
				end
			end
			function fs.writePart(path)
				local f = io.open(path, 'wb')
				return function(data, close)
					if close then
						f:flush()
						f:close()
					else
						aStep()
						return f:write(data)
					end
				end
			end
			_G.fs = fs
		end
		do
		local f = io.open('./log.txt', 'w+')
		_G.log = function(...)
			local a = ''
			for k, v in ipairs({...}) do
				a = a .. tostring(v) .. '\t'
				aStep()
			end
			f:write(a .. '\n')
			f:flush()
		end
		local ok, r = pcall(...)
		if not ok then
			log("error:", tostring(r))
		end
		end
	end, cb, ...)
	copas.seterrorhandler(function(err)
		log("[luafox-platform-core] an error occoured: ", err)
	end)
	copas.loop()
end