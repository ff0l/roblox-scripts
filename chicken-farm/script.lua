local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
if not game:IsLoaded() then
	game.Loaded:Wait()
end
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	LocalPlayer = Players.LocalPlayer
end
local env = (typeof(getgenv) == "function" and getgenv()) or _G
if type(env) == "table" and type(env.CF_UNLOAD) == "function" then
	pcall(env.CF_UNLOAD)
end
local TARGET_PLACE = 137233438285284
local T = {
	bg = Color3.fromRGB(22, 22, 22),
	text = Color3.fromRGB(228, 228, 226),
	muted = Color3.fromRGB(142, 142, 140),
	dim = Color3.fromRGB(96, 96, 94),
	on = Color3.fromRGB(228, 228, 226),
	off = Color3.fromRGB(48, 48, 46),
	knobOn = Color3.fromRGB(22, 22, 22),
	knobOff = Color3.fromRGB(168, 168, 166),
	close = Color3.fromRGB(255, 95, 87),
}
local FONT = Enum.Font.BuilderSans
local FONT_MED = Enum.Font.BuilderSansMedium
local KEYWORDS = {
	"buy", "sell", "collect", "merge", "cash", "money", "coin", "egg",
	"upgrade", "process", "rebirth", "lucky", "nest", "chicken", "farm",
	"shop", "price", "auto", "tier", "hatch", "claim", "reward", "pad",
}
local Core = {
	running = true,
	connections = {},
}
function Core.track(connection)
	if connection then
		table.insert(Core.connections, connection)
	end
	return connection
end
function Core.disconnectAll()
	for _, connection in ipairs(Core.connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	Core.connections = {}
end
local function pickFn(...)
	for i = 1, select("#", ...) do
		local fn = select(i, ...)
		if typeof(fn) == "function" then
			return fn
		end
	end
	return nil
end
local hookMeta = pickFn(
	typeof(hookmetamethod) == "function" and hookmetamethod,
	type(env) == "table" and env.hookmetamethod
)
local getNamecall = pickFn(
	typeof(getnamecallmethod) == "function" and getnamecallmethod,
	type(env) == "table" and env.getnamecallmethod
)
local checkCaller = pickFn(
	typeof(checkcaller) == "function" and checkcaller,
	type(env) == "table" and env.checkcaller
)
local newClosure = pickFn(
	typeof(newcclosure) == "function" and newcclosure,
	type(env) == "table" and env.newcclosure
) or function(fn)
	return fn
end
local getConns = pickFn(
	typeof(getconnections) == "function" and getconnections,
	type(env) == "table" and env.getconnections
)
local writeFile = pickFn(
	typeof(writefile) == "function" and writefile,
	type(env) == "table" and env.writefile
)
local appendFile = pickFn(
	typeof(appendfile) == "function" and appendfile,
	type(env) == "table" and env.appendfile
)
local makeFolder = pickFn(
	typeof(makefolder) == "function" and makefolder,
	type(env) == "table" and env.makefolder
)
local setclipboard = pickFn(
	typeof(setclipboard) == "function" and setclipboard,
	typeof(toclipboard) == "function" and toclipboard,
	type(env) == "table" and env.setclipboard
)
local decompileFn = pickFn(
	typeof(decompile) == "function" and decompile,
	type(env) == "table" and env.decompile
)
local getScripts = pickFn(
	typeof(getscripts) == "function" and getscripts,
	type(env) == "table" and env.getscripts
)
local getBytecode = pickFn(
	typeof(getscriptbytecode) == "function" and getscriptbytecode,
	type(env) == "table" and env.getscriptbytecode
)
local Config = {
	interceptRemotes = true,
	interceptButtons = true,
	interceptWorld = true,
	autoCollect = false,
	autoDeposit = false,
	autoCash = false,
	autoBuy = false,
	autoMerge = false,
	autoUpgrade = false,
	autoLucky = false,
}
local function instancePath(inst)
	if typeof(inst) ~= "Instance" then
		return tostring(inst)
	end
	local ok, full = pcall(function()
		return inst:GetFullName()
	end)
	if ok and type(full) == "string" and full ~= "" then
		return full
	end
	return inst.Name
end
local function hasKeyword(text)
	if type(text) ~= "string" or text == "" then
		return false
	end
	local lower = string.lower(text)
	for _, word in ipairs(KEYWORDS) do
		if string.find(lower, word, 1, true) then
			return true
		end
	end
	return false
end
local function serialize(value, depth, seen)
	depth = depth or 0
	if depth > 4 then
		return "…"
	end
	local t = typeof(value)
	if t == "nil" then
		return "nil"
	elseif t == "boolean" or t == "number" then
		return tostring(value)
	elseif t == "string" then
		if #value > 160 then
			return string.format("%q", string.sub(value, 1, 160) .. "…")
		end
		return string.format("%q", value)
	elseif t == "Instance" then
		return "Inst(" .. instancePath(value) .. ")"
	elseif t == "EnumItem" then
		return tostring(value)
	elseif t == "Vector3" or t == "Vector2" or t == "UDim2" or t == "UDim" then
		return t .. "(" .. tostring(value) .. ")"
	elseif t == "CFrame" then
		return "CFrame(" .. tostring(value.Position) .. ")"
	elseif t == "Color3" then
		return string.format("Color3(%d,%d,%d)", value.R * 255, value.G * 255, value.B * 255)
	elseif t == "table" then
		seen = seen or {}
		if seen[value] then
			return "{cycle}"
		end
		seen[value] = true
		local parts = {}
		local count = 0
		for key, item in pairs(value) do
			count += 1
			if count > 12 then
				table.insert(parts, "…")
				break
			end
			table.insert(parts, serialize(key, depth + 1, seen) .. "=" .. serialize(item, depth + 1, seen))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	return t
end
local function serializeArgs(args)
	local parts = {}
	for i, value in ipairs(args) do
		parts[i] = serialize(value)
	end
	return table.concat(parts, ", ")
end
local Dump = {
	events = {},
	maxEvents = 250,
	count = 0,
	onEvent = nil,
	oldNamecall = nil,
	hooked = false,
	touchAt = {},
	guiHooked = {},
	fileBuf = "",
	fileDirty = false,
	lastFlush = 0,
}
function Dump.push(kind, text, extra)
	if not Core.running then
		return
	end
	Dump.count += 1
	local row = {
		n = Dump.count,
		t = os.clock(),
		kind = kind,
		text = text,
		extra = extra,
	}
	table.insert(Dump.events, row)
	if #Dump.events > Dump.maxEvents then
		table.remove(Dump.events, 1)
	end
	Dump.appendRow(row)
	return row
end
local function ensureFolder()
	if makeFolder then
		pcall(makeFolder, "cf")
	end
end
function Dump.appendRow(row)
	Dump.fileBuf ..= string.format("%d\t%.3f\t%s\t%s\n", row.n, row.t, row.kind, row.text)
	if #Dump.fileBuf > 180000 then
		Dump.fileBuf = string.sub(Dump.fileBuf, -90000)
	end
	Dump.fileDirty = true
end
function Dump.flush(force)
	if not writeFile or not Dump.fileDirty then
		return
	end
	local now = os.clock()
	if not force and Dump.lastFlush and now - Dump.lastFlush < 0.4 then
		return
	end
	ensureFolder()
	local ok = pcall(writeFile, "cf/events.txt", Dump.fileBuf)
	if ok then
		Dump.fileDirty = false
		Dump.lastFlush = now
	end
end
function Dump.writeJson(name, payload)
	if not writeFile then
		return false, "no writefile"
	end
	ensureFolder()
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(payload)
	end)
	if not ok then
		return false, "json failed"
	end
	local path = "cf/" .. name
	local wrote = pcall(writeFile, path, encoded)
	return wrote, wrote and path or "write failed"
end
function Dump.writeSnapshot(payload)
	local wrote, where = Dump.writeJson("dump.json", payload)
	if not wrote and type(payload) == "table" then
		payload.pads = {}
		wrote, where = Dump.writeJson("dump.json", payload)
	end
	return wrote, where
end
function Dump.writeLog()
	if not writeFile then
		return false
	end
	ensureFolder()
	local lines = {}
	for _, row in ipairs(Dump.events) do
		table.insert(lines, string.format("%d\t%s\t%s", row.n, row.kind, row.text))
	end
	return pcall(writeFile, "cf/log.txt", table.concat(lines, "\n"))
end
local function connectionInfo(signal)
	if not getConns then
		return nil
	end
	local ok, list = pcall(getConns, signal)
	if not ok or type(list) ~= "table" then
		return nil
	end
	local out = {}
	for i, conn in ipairs(list) do
		if i > 8 then
			break
		end
		local info = {
			enabled = conn.Enabled,
		}
		if type(conn.Function) == "function" then
			local okInfo, src = pcall(function()
				return debug.info(conn.Function, "sn")
			end)
			if okInfo then
				info.source = src
			end
		end
		table.insert(out, info)
	end
	return out
end
function Dump.scan()
	local started = os.clock()
	local payload = {
		placeId = game.PlaceId,
		placeName = game.Name,
		jobId = game.JobId,
		target = TARGET_PLACE,
		at = os.time(),
		remotes = {},
		bindables = {},
		buttons = {},
		prompts = {},
		clicks = {},
		pads = {},
		values = {},
		attributes = {},
	}
	local walked = 0
	local function consider(inst)
		walked += 1
		if walked % 400 == 0 then
			task.wait()
		end
		local className = inst.ClassName
		local path = instancePath(inst)
		local named = hasKeyword(inst.Name) or hasKeyword(path)
		if className == "RemoteEvent" or className == "RemoteFunction" or className == "UnreliableRemoteEvent" then
			table.insert(payload.remotes, {
				class = className,
				path = path,
			})
		elseif className == "BindableEvent" or className == "BindableFunction" then
			table.insert(payload.bindables, {
				class = className,
				path = path,
			})
		elseif inst:IsA("GuiButton") then
			local text = ""
			pcall(function()
				text = inst.Text
			end)
			local entry = {
				class = className,
				path = path,
				text = text,
				visible = inst.Visible,
			}
			local activated = connectionInfo(inst.Activated)
			if activated then
				entry.activated = activated
			end
			table.insert(payload.buttons, entry)
		elseif className == "ProximityPrompt" then
			table.insert(payload.prompts, {
				path = path,
				action = inst.ActionText,
				object = inst.ObjectText,
			})
		elseif className == "ClickDetector" then
			table.insert(payload.clicks, { path = path })
		elseif named and (inst:IsA("BasePart") or className == "Model" or className == "Folder") then
			table.insert(payload.pads, {
				class = className,
				path = path,
			})
		elseif named and (inst:IsA("ValueBase") or string.find(className, "Value", 1, true)) then
			local value
			pcall(function()
				value = inst.Value
			end)
			table.insert(payload.values, {
				class = className,
				path = path,
				value = serialize(value),
			})
		end
		local okAttr, attrs = pcall(function()
			return inst:GetAttributes()
		end)
		if okAttr and type(attrs) == "table" then
			for key, value in pairs(attrs) do
				if hasKeyword(key) or hasKeyword(inst.Name) then
					table.insert(payload.attributes, {
						path = path,
						key = key,
						value = serialize(value),
					})
				end
			end
		end
		return true
	end
	local function walkRoot(root, budget)
		if not root then
			return
		end
		consider(root)
		local n = 0
		for _, inst in ipairs(root:GetDescendants()) do
			n += 1
			if n > budget then
				break
			end
			consider(inst)
		end
	end
	walkRoot(LocalPlayer:FindFirstChild("PlayerGui"), 10000)
	walkRoot(StarterGui, 3000)
	walkRoot(ReplicatedStorage, 5000)
	walkRoot(ReplicatedFirst, 1500)
	walkRoot(LocalPlayer, 4000)
	walkRoot(Workspace, 8000)
	payload.walked = walked
	payload.ms = math.floor((os.clock() - started) * 1000)
	payload.counts = {
		remotes = #payload.remotes,
		bindables = #payload.bindables,
		buttons = #payload.buttons,
		prompts = #payload.prompts,
		clicks = #payload.clicks,
		pads = #payload.pads,
		values = #payload.values,
		attributes = #payload.attributes,
	}
	local summary = string.format(
		"scan %dms  remotes=%d  buttons=%d  pads=%d  values=%d  prompts=%d",
		payload.ms,
		payload.counts.remotes,
		payload.counts.buttons,
		payload.counts.pads,
		payload.counts.values,
		payload.counts.prompts
	)
	Dump.push("scan", summary, payload.counts)
	for i, remote in ipairs(payload.remotes) do
		if i > 80 then
			Dump.push("scan", string.format("… %d more remotes", #payload.remotes - 80))
			break
		end
		Dump.push("remote", remote.class .. "  " .. remote.path)
	end
	local wrote, where = Dump.writeSnapshot(payload)
	if wrote then
		Dump.push("file", "wrote " .. where)
	else
		Dump.push("file", "snapshot not written (" .. tostring(where) .. ")")
	end
	pcall(Dump.dumpGui)
	pcall(Dump.dumpEggs)
	pcall(Dump.dumpPlot)
	Dump.flush(true)
	if setclipboard then
		pcall(setclipboard, summary)
	end
	return payload
end
function Dump.dumpGui()
	local gui = LocalPlayer:FindFirstChild("PlayerGui")
	local rows = {}
	if gui then
		for _, inst in ipairs(gui:GetDescendants()) do
			if inst:IsA("GuiObject") then
				local text = ""
				pcall(function()
					text = inst.Text
				end)
				local enabled = true
				pcall(function()
					if inst:IsA("LayerCollector") then
						enabled = inst.Enabled
					elseif inst:IsA("GuiButton") then
						enabled = inst.Active
					end
				end)
				table.insert(rows, {
					class = inst.ClassName,
					path = instancePath(inst),
					name = inst.Name,
					text = text,
					visible = inst.Visible,
					enabled = enabled,
				})
				if #rows >= 900 then
					break
				end
			end
		end
	end
	local wrote, where = Dump.writeJson("gui.json", {
		at = os.time(),
		count = #rows,
		items = rows,
	})
	Dump.push("file", wrote and ("wrote " .. where) or ("gui.json failed"))
end
function Dump.dumpEggs()
	local folder = Workspace:FindFirstChild("Eggs")
	local rows = {}
	if folder then
		for _, egg in ipairs(folder:GetChildren()) do
			local kids = {}
			pcall(function()
				for _, child in ipairs(egg:GetChildren()) do
					table.insert(kids, child.ClassName .. ":" .. child.Name)
					if #kids >= 12 then
						break
					end
				end
			end)
			local attrs = {}
			pcall(function()
				for key, value in pairs(egg:GetAttributes()) do
					attrs[key] = serialize(value)
				end
			end)
			table.insert(rows, {
				name = egg.Name,
				class = egg.ClassName,
				attrs = attrs,
				kids = kids,
			})
		end
	end
	local wrote, where = Dump.writeJson("eggs.json", {
		at = os.time(),
		count = #rows,
		items = rows,
	})
	Dump.push("file", wrote and ("wrote " .. where .. " n=" .. #rows) or "eggs.json failed")
end
function Dump.dumpPlot()
	local plots = Workspace:FindFirstChild("Plots")
	local plot = plots and plots:FindFirstChild(LocalPlayer.Name)
	local buttons = plot and plot:FindFirstChild("Buttons")
	local rows = {}
	if buttons then
		for _, inst in ipairs(buttons:GetDescendants()) do
			local entry = {
				class = inst.ClassName,
				path = instancePath(inst),
				name = inst.Name,
			}
			pcall(function()
				local attrs = inst:GetAttributes()
				if attrs and next(attrs) then
					entry.attrs = {}
					for key, value in pairs(attrs) do
						entry.attrs[key] = serialize(value)
					end
				end
			end)
			table.insert(rows, entry)
		end
	end
	local wrote, where = Dump.writeJson("plot.json", {
		at = os.time(),
		plot = plot and plot.Name or "",
		count = #rows,
		items = rows,
	})
	Dump.push("file", wrote and ("wrote " .. where) or "plot.json failed")
end
function Dump.dumpScripts()
	if not decompileFn and not getBytecode then
		Dump.push("file", "no decompile / getscriptbytecode")
		return
	end
	if makeFolder then
		pcall(makeFolder, "cf/scripts")
	end
	local scripts = {}
	if getScripts then
		local ok, list = pcall(getScripts)
		if ok and type(list) == "table" then
			scripts = list
		end
	end
	if #scripts == 0 then
		for _, inst in ipairs(ReplicatedStorage:GetDescendants()) do
			if inst:IsA("LuaSourceContainer") then
				table.insert(scripts, inst)
			end
		end
	end
	local written = 0
	for _, script in ipairs(scripts) do
		local path = instancePath(script)
		local want = string.find(path, "Paper", 1, true)
			or string.find(path, "Farm", 1, true)
			or string.find(path, "Chicken", 1, true)
			or string.find(path, "Lucky", 1, true)
		if want then
			local src
			if decompileFn then
				pcall(function()
					src = decompileFn(script)
				end)
			end
			if (not src or src == "") and getBytecode then
				pcall(function()
					src = getBytecode(script)
				end)
			end
			if type(src) == "string" and src ~= "" and writeFile then
				local name = string.gsub(path, "[^%w%.%-]", "_")
				if #name > 80 then
					name = string.sub(name, 1, 80)
				end
				if pcall(writeFile, "cf/scripts/" .. name .. ".lua", src) then
					written += 1
				end
			end
			if written >= 20 then
				break
			end
		end
	end
	Dump.push("file", "scripts dumped=" .. written)
end
function Dump.dumpStats()
	local paper = ReplicatedStorage:FindFirstChild("Paper")
	local remotes = paper and paper:FindFirstChild("Remotes")
	local fn = remotes and remotes:FindFirstChild("__remotefunction")
	local rep = ReplicatedStorage:FindFirstChild("Replicator")
	local repFn = rep and rep:FindFirstChild("__replicatefunc")
	local data
	if repFn then
		pcall(function()
			data = repFn:InvokeServer("Data", LocalPlayer.Name .. "Stats")
		end)
	end
	if data == nil and fn then
		pcall(function()
			data = fn:InvokeServer("Data", LocalPlayer.Name .. "Stats")
		end)
	end
	if data == nil then
		Dump.push("file", "stats.json skipped (no data)")
		return
	end
	local wrote, where = Dump.writeJson("stats.json", {
		at = os.time(),
		player = LocalPlayer.Name,
		data = serialize(data),
	})
	Dump.push("file", wrote and ("wrote " .. where) or "stats.json failed")
end
function Dump.watchGui(gui)
	if not gui or Dump.guiHooked[gui] then
		return
	end
	Dump.guiHooked[gui] = true
	local function hookButton(button)
		if not button:IsA("GuiButton") then
			return
		end
		if button:GetAttribute("CFHooked") then
			return
		end
		pcall(function()
			button:SetAttribute("CFHooked", true)
		end)
		local function describe()
			local text = ""
			pcall(function()
				text = button.Text
			end)
			return string.format(
				"%s  name=%s  text=%s  vis=%s",
				instancePath(button),
				button.Name,
				tostring(text),
				tostring(button.Visible)
			)
		end
		local desc = describe()
		if hasKeyword(desc) then
			Dump.push("gui", desc)
		end
		local function onClick()
			if not Core.running or not Config.interceptButtons then
				return
			end
			Dump.push("button", describe())
		end
		Core.track(button.Activated:Connect(onClick))
		pcall(function()
			Core.track(button.MouseButton1Click:Connect(onClick))
		end)
	end
	for _, inst in ipairs(gui:GetDescendants()) do
		hookButton(inst)
	end
	Core.track(gui.DescendantAdded:Connect(hookButton))
end
function Dump.watchWorld()
	local function interesting(inst)
		return hasKeyword(inst.Name) or hasKeyword(instancePath(inst))
	end
	local function hookPrompt(prompt)
		if not prompt:IsA("ProximityPrompt") then
			return
		end
		Core.track(prompt.Triggered:Connect(function(player)
			if not Core.running or not Config.interceptWorld then
				return
			end
			Dump.push("prompt", instancePath(prompt) .. "  by=" .. (player and player.Name or "?"))
		end))
	end
	local function hookClick(detector)
		if not detector:IsA("ClickDetector") then
			return
		end
		Core.track(detector.MouseClick:Connect(function(player)
			if not Core.running or not Config.interceptWorld then
				return
			end
			Dump.push("click", instancePath(detector) .. "  by=" .. (player and player.Name or "?"))
		end))
	end
	local function hookTouch(part)
		if not part:IsA("BasePart") or not interesting(part) then
			return
		end
		Core.track(part.Touched:Connect(function(hit)
			if not Core.running or not Config.interceptWorld then
				return
			end
			local character = LocalPlayer.Character
			if not character or not hit:IsDescendantOf(character) then
				return
			end
			local now = os.clock()
			local last = Dump.touchAt[part]
			if last and now - last < 0.45 then
				return
			end
			Dump.touchAt[part] = now
			Dump.push("touch", instancePath(part))
		end))
	end
	local function consider(inst)
		hookPrompt(inst)
		hookClick(inst)
		hookTouch(inst)
	end
	for _, inst in ipairs(Workspace:GetDescendants()) do
		consider(inst)
	end
	Core.track(Workspace.DescendantAdded:Connect(consider))
end
function Dump.watchValues()
	local function hookValue(inst)
		if inst:IsA("ValueBase") and (hasKeyword(inst.Name) or hasKeyword(instancePath(inst))) then
			Core.track(inst:GetPropertyChangedSignal("Value"):Connect(function()
				if not Core.running then
					return
				end
				Dump.push("value", instancePath(inst) .. " = " .. serialize(inst.Value))
			end))
		end
		local okAttr, attrs = pcall(function()
			return inst:GetAttributes()
		end)
		if okAttr and type(attrs) == "table" then
			for key in pairs(attrs) do
				if hasKeyword(key) or hasKeyword(inst.Name) then
					Core.track(inst:GetAttributeChangedSignal(key):Connect(function()
						if not Core.running then
							return
						end
						Dump.push("attr", instancePath(inst) .. "." .. key .. " = " .. serialize(inst:GetAttribute(key)))
					end))
				end
			end
		end
	end
	local roots = { LocalPlayer, ReplicatedStorage }
	pcall(function()
		table.insert(roots, LocalPlayer:FindFirstChild("leaderstats"))
	end)
	for _, root in ipairs(roots) do
		if root then
			hookValue(root)
			for _, inst in ipairs(root:GetDescendants()) do
				hookValue(inst)
			end
			Core.track(root.DescendantAdded:Connect(hookValue))
		end
	end
end
function Dump.installHooks()
	if Dump.hooked then
		return Dump.hooked
	end
	if not hookMeta or not getNamecall then
		Dump.push("hook", "hookmetamethod / getnamecallmethod missing")
		return false
	end
	local old
	old = hookMeta(game, "__namecall", newClosure(function(self, ...)
		local args = { ... }
		pcall(function()
			local method = getNamecall()
			if method ~= "FireServer" and method ~= "InvokeServer"
				and method ~= "PromptProductPurchase" and method ~= "PromptGamePassPurchase"
				and method ~= "PromptPurchase"
			then
				return
			end
			if checkCaller and checkCaller() then
				return
			end
			if not Core.running or not Config.interceptRemotes then
				return
			end
			local remote = self
			task.defer(function()
				if not Core.running then
					return
				end
				local name = "?"
				pcall(function()
					name = instancePath(remote)
				end)
				Dump.push("net", method .. "  " .. name .. "  (" .. serializeArgs(args) .. ")")
			end)
		end)
		return old(self, table.unpack(args))
	end))
	Dump.oldNamecall = old
	Dump.hooked = true
	Dump.push("hook", "namecall intercept live")
	return true
end
function Dump.restoreHooks()
	if Dump.oldNamecall and hookMeta then
		pcall(hookMeta, game, "__namecall", Dump.oldNamecall)
	end
	Dump.oldNamecall = nil
	Dump.hooked = false
end
function Dump.start()
	Dump.installHooks()
	pcall(function()
		local gui = LocalPlayer:WaitForChild("PlayerGui", 8)
		if gui then
			Dump.watchGui(gui)
		end
	end)
	Dump.watchWorld()
	Dump.watchValues()
	Dump.push("boot", string.format(
		"place=%s  target=%s  match=%s",
		tostring(game.PlaceId),
		tostring(TARGET_PLACE),
		tostring(game.PlaceId == TARGET_PLACE)
	))
	Dump.flush(true)
end
local fireTouch = pickFn(
	typeof(firetouchinterest) == "function" and firetouchinterest,
	type(env) == "table" and env.firetouchinterest,
	syn and syn.firetouchinterest
)
local Farm = {
	seen = {},
	looping = false,
	eventRemote = nil,
	fnRemote = nil,
	busy = {},
	last = {},
	luckyUntil = 0,
	buying = false,
	luckyTarget = nil,
	luckyTried = {},
}
function Farm.fire(action, ...)
	if not Farm.eventRemote then
		return
	end
	local extra = { ... }
	pcall(function()
		Farm.eventRemote:FireServer(action, table.unpack(extra))
	end)
end
function Farm.gui(names)
	local inst = LocalPlayer:FindFirstChild("PlayerGui")
	if not inst then
		return nil
	end
	for _, name in ipairs(names) do
		inst = inst:FindFirstChild(name)
		if not inst then
			return nil
		end
	end
	return inst
end
function Farm.bindRemotes()
	local paper = ReplicatedStorage:FindFirstChild("Paper")
	local remotes = paper and paper:FindFirstChild("Remotes")
	if not remotes then
		return
	end
	Farm.eventRemote = remotes:FindFirstChild("__remoteevent")
	Farm.fnRemote = remotes:FindFirstChild("__remotefunction")
end
function Farm.root()
	local character = LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end
function Farm.fireTouched(part)
	local hrp = Farm.root()
	if not hrp or typeof(part) ~= "Instance" or not part:IsA("BasePart") then
		return
	end
	if getConns then
		local ok, list = pcall(getConns, part.Touched)
		if ok and type(list) == "table" then
			for _, conn in ipairs(list) do
				if conn.Enabled ~= false then
					if typeof(conn.Fire) == "function" then
						pcall(conn.Fire, conn, hrp)
					elseif typeof(conn.Function) == "function" then
						pcall(conn.Function, hrp)
					end
				end
			end
		end
	end
	if fireTouch then
		pcall(fireTouch, part, hrp, 0)
		pcall(fireTouch, part, hrp, 1)
	end
end
function Farm.due(key, interval)
	local now = os.clock()
	if Farm.last[key] and now - Farm.last[key] < interval then
		return false
	end
	Farm.last[key] = now
	return true
end
local LUCKY_TYPES = {
	Galaxy = true, Magma = true, Royal = true, Red = true, Angel = true,
	Gummy = true, Rainbow = true, Blue = true, Basic = true, Hacker = true,
	Ice = true, Tech = true, Nature = true, Imperial = true,
}
function Farm.looksLucky(egg)
	if typeof(egg) ~= "Instance" then
		return false
	end
	local ok, attrs = pcall(function()
		return egg:GetAttributes()
	end)
	if ok and type(attrs) == "table" then
		for key, value in pairs(attrs) do
			local blob = string.lower(tostring(key) .. " " .. tostring(value))
			if string.find(blob, "lucky", 1, true) then
				return true
			end
		end
	end
	if egg:FindFirstChild("LuckyBlock", true) or egg:FindFirstChild("Lucky", true) then
		return true
	end
	if LUCKY_TYPES[egg.Name] then
		return true
	end
	local hasMain = egg:FindFirstChild("Main") ~= nil
	local hasHitbox = egg:FindFirstChild("Hitbox") ~= nil
	local tier = nil
	pcall(function()
		tier = egg:GetAttribute("Tier")
	end)
	if tier == nil and hasMain then
		return true
	end
	if hasMain and not hasHitbox then
		return true
	end
	return false
end
function Farm.summary(egg)
	local parts = {}
	pcall(function()
		for _, child in ipairs(egg:GetChildren()) do
			table.insert(parts, child.ClassName .. ":" .. child.Name)
			if #parts >= 8 then
				break
			end
		end
	end)
	local tier = "?"
	pcall(function()
		tier = tostring(egg:GetAttribute("Tier"))
	end)
	return string.format("%s  tier=%s  kids=%s", egg.Name, tier, table.concat(parts, ","))
end
function Farm.ourGui(inst)
	return typeof(inst) == "Instance" and inst:FindFirstAncestor("CFMenu") ~= nil
end
function Farm.luckyLabel(inst)
	local name = string.lower((inst.Name or ""):gsub("%s+", ""))
	local text = ""
	pcall(function()
		text = string.lower((inst.Text or ""):gsub("%s+", ""))
	end)
	for _, word in ipairs({ "unlock", "open", "claim", "discard" }) do
		if name == word or text == word then
			return word
		end
	end
	if name == "buy" or text == "buy" then
		local path = ""
		pcall(function()
			path = string.lower(instancePath(inst))
		end)
		if string.find(path, "lucky", 1, true) or os.clock() < Farm.luckyUntil then
			return "buy"
		end
	end
	return nil
end
function Farm.fireButton(button)
	if typeof(button) ~= "Instance" or not button:IsA("GuiButton") then
		return
	end
	if not getConns then
		return
	end
	for _, signalName in ipairs({ "Activated", "MouseButton1Click", "MouseButton1Down" }) do
		local ok, signal = pcall(function()
			return button[signalName]
		end)
		if ok and signal then
			local okList, list = pcall(getConns, signal)
			if okList and type(list) == "table" then
				for _, conn in ipairs(list) do
					if conn.Enabled ~= false then
						if typeof(conn.Fire) == "function" then
							pcall(conn.Fire, conn)
						elseif typeof(conn.Function) == "function" then
							pcall(conn.Function)
						end
					end
				end
			end
		end
	end
end
function Farm.isShown(inst)
	local cur = inst
	while cur do
		if cur:IsA("LayerCollector") then
			if cur.Enabled == false then
				return false
			end
			break
		end
		if cur:IsA("GuiObject") and cur.Visible == false then
			return false
		end
		cur = cur.Parent
	end
	if inst:IsA("GuiObject") then
		local size = inst.AbsoluteSize
		if size.X < 8 or size.Y < 8 then
			return false
		end
	end
	return true
end
function Farm.luckyButtons()
	local found = {}
	local gui = LocalPlayer:FindFirstChild("PlayerGui")
	if not gui then
		return found
	end
	for _, inst in ipairs(gui:GetDescendants()) do
		if inst:IsA("GuiButton") and Farm.isShown(inst) and not Farm.ourGui(inst) then
			local kind = Farm.luckyLabel(inst)
			if kind then
				table.insert(found, { button = inst, kind = kind })
			end
		end
	end
	return found
end
function Farm.modal()
	local result = Farm.gui({ "Main", "LuckyblockAnim", "Result" })
	if result and Farm.isShown(result) then
		return "result"
	end
	local unlock = Farm.gui({ "Main", "Luckyblock" })
	if unlock and Farm.isShown(unlock) then
		return "unlock"
	end
	return nil
end
function Farm.clickNamed(frame, name)
	if not frame then
		return false
	end
	local buttons = frame:FindFirstChild("Buttons") or frame
	local button = buttons:FindFirstChild(name)
	if button and button:IsA("GuiButton") then
		Dump.push("farm", "click " .. name .. "  " .. instancePath(button))
		Farm.fireButton(button)
		return true
	end
	return false
end
function Farm.claimResult()
	local result = Farm.gui({ "Main", "LuckyblockAnim", "Result" })
	if not result or not Farm.isShown(result) then
		return false
	end
	if Farm.due("claim_result", 0.4) then
		Dump.push("farm", "claim opened chicken")
		local before = Farm.chickens()
		Farm.fire("Claim Opened Chicken")
		Farm.clickNamed(result, "Claim")
		task.spawn(function()
			task.wait(0.25)
			local stillUp = result.Parent and Farm.isShown(result)
			local gained = Farm.chickens() > before
			if (not stillUp or gained) then
				Farm.finishLucky()
			end
		end)
	end
	return true
end
function Farm.unlockLucky()
	if not (Farm.luckyTarget and Farm.luckyTarget.Parent) and os.clock() >= Farm.luckyUntil then
		return false
	end
	local frame = Farm.gui({ "Main", "Luckyblock" })
	if not frame or not Farm.isShown(frame) then
		return false
	end
	if Farm.due("unlock_lucky", 0.45) then
		Dump.push("farm", "unlock lucky block")
		Farm.invoke("Open Lucky Block")
		Farm.clickNamed(frame, "Unlock")
	end
	return true
end
function Farm.claimOffline()
	local frame = Farm.gui({ "Menus", "OfflineEarnings" })
	if not frame or not Farm.isShown(frame) then
		return false
	end
	if Farm.due("claim_offline", 1.2) then
		Dump.push("farm", "claim offline")
		Farm.clickNamed(frame:FindFirstChild("Frame") or frame, "Claim")
		Farm.invoke("Claim Offline Earnings")
		Farm.fire("Claim Offline Earnings")
	end
	return true
end
function Farm.handleModals()
	if Farm.claimResult() then
		return "result"
	end
	if Config.autoLucky and Farm.unlockLucky() then
		return "unlock"
	end
	Farm.claimOffline()
	return nil
end
function Farm.worldLucky()
	local folder = Workspace:FindFirstChild("Eggs")
	if not folder then
		return nil
	end
	for _, egg in ipairs(folder:GetChildren()) do
		if Farm.looksLucky(egg) then
			return egg
		end
	end
	return nil
end
function Farm.holdForLucky()
	if not Config.autoLucky then
		return false
	end
	if Farm.luckyTarget and Farm.luckyTarget.Parent then
		return true
	end
	if os.clock() < Farm.luckyUntil then
		return true
	end
	if Farm.modal() then
		return true
	end
	return Farm.worldLucky() ~= nil
end
function Farm.touchModel(model)
	if typeof(model) ~= "Instance" then
		return
	end
	local parts = model:GetDescendants()
	if model:IsA("BasePart") then
		table.insert(parts, model)
	end
	for _, inst in ipairs(parts) do
		if inst:IsA("BasePart") then
			Farm.fireTouched(inst)
		end
	end
end
function Farm.hideForced(egg)
	if typeof(egg) ~= "Instance" then
		return
	end
	pcall(function()
		local parts = egg:GetDescendants()
		table.insert(parts, egg)
		for _, inst in ipairs(parts) do
			if inst:IsA("BasePart") then
				inst.LocalTransparencyModifier = 1
				inst.Transparency = 1
				inst.CanCollide = false
				inst.CanTouch = false
				inst.CanQuery = false
			elseif inst:IsA("Decal") or inst:IsA("Texture") then
				inst.Transparency = 1
			elseif inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") or inst:IsA("Highlight") then
				inst.Enabled = false
			end
		end
		egg:Destroy()
	end)
end
function Farm.hide(egg)
	if typeof(egg) ~= "Instance" or Farm.looksLucky(egg) then
		return
	end
	Farm.hideForced(egg)
end
function Farm.finishLucky()
	local target = Farm.luckyTarget
	if typeof(target) == "Instance" and target.Parent then
		Dump.push("farm", "hide leftover lucky " .. target.Name)
		Farm.hideForced(target)
	end
	Farm.luckyTarget = nil
end
function Farm.chickens()
	local stats = LocalPlayer:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild("Chickens")
	if value then
		return tonumber(value.Value) or 0
	end
	return 0
end
function Farm.collect(egg)
	if not Core.running or typeof(egg) ~= "Instance" then
		return
	end
	if not egg:IsA("Model") then
		return
	end
	if Farm.looksLucky(egg) then
		if not Config.autoLucky then
			return
		end
	elseif not Config.autoCollect then
		return
	end
	local id = egg.Name
	if Farm.looksLucky(egg) then
		if Farm.modal() then
			return
		end
		local last = Farm.luckyTried[id]
		if last and os.clock() - last < 8 then
			return
		end
		if not Farm.due("lucky_world", 2.5) then
			return
		end
		Farm.luckyTried[id] = os.clock()
		Farm.luckyTarget = egg
		Farm.luckyUntil = os.clock() + 8
		Dump.push("farm", "lucky " .. Farm.summary(egg))
		Farm.touchModel(egg)
		Farm.invoke("Collect Lucky Block", id)
		return
	end
	if Farm.seen[id] then
		return
	end
	Farm.seen[id] = true
	Farm.touchModel(egg)
	if Farm.eventRemote then
		pcall(function()
			Farm.eventRemote:FireServer("Collect Egg", id)
		end)
	end
	Farm.hide(egg)
	task.delay(0.8, function()
		if egg.Parent then
			Farm.seen[id] = nil
		end
	end)
end
function Farm.collectAll()
	local folder = Workspace:FindFirstChild("Eggs")
	if not folder then
		return
	end
	local lucky = {}
	local eggs = {}
	for _, egg in ipairs(folder:GetChildren()) do
		if Farm.looksLucky(egg) then
			table.insert(lucky, egg)
		else
			table.insert(eggs, egg)
		end
	end
	if #lucky > 0 and not Farm.modal() then
		Farm.collect(lucky[1])
	end
	local n = 0
	for _, egg in ipairs(eggs) do
		if not Farm.seen[egg.Name] then
			Farm.collect(egg)
			n += 1
			if n >= 40 then
				break
			end
		end
	end
end
function Farm.invoke(action, ...)
	if not Farm.fnRemote then
		return
	end
	local extra = { ... }
	local key = action
	for i = 1, #extra do
		key = key .. "/" .. tostring(extra[i])
	end
	if Farm.busy[key] then
		return
	end
	Farm.busy[key] = true
	task.spawn(function()
		local finished = false
		task.delay(2.5, function()
			if not finished then
				Farm.busy[key] = nil
			end
		end)
		pcall(function()
			Farm.fnRemote:InvokeServer(action, table.unpack(extra))
		end)
		finished = true
		Farm.busy[key] = nil
	end)
end
function Farm.plot()
	local plots = Workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	return plots:FindFirstChild(LocalPlayer.Name)
end
function Farm.touchPad(names)
	local inst = Farm.plot()
	if not inst then
		return
	end
	for _, name in ipairs(names) do
		inst = inst:FindFirstChild(name)
		if not inst then
			return
		end
	end
	local button = inst:FindFirstChild("Button") or inst:FindFirstChild("Hitbox")
	if button then
		Farm.fireTouched(button)
	end
end
function Farm.tryBuy(amount)
	local before = Farm.chickens()
	Dump.push("farm", "try buy " .. amount)
	Farm.invoke("Buy Chickens", amount)
	Farm.touchPad({ "Buttons", "BuyChickens", "Buy" .. tostring(amount) })
	task.wait(0.12)
	return Farm.chickens() > before
end
function Farm.buyCycle()
	if Farm.buying then
		return false
	end
	Farm.buying = true
	local bought = false
	for _, amount in ipairs({ 100, 25, 5, 1 }) do
		if not Core.running then
			break
		end
		if Farm.tryBuy(amount) then
			Dump.push("farm", "bought " .. amount)
			bought = true
			break
		end
	end
	if bought and Config.autoMerge then
		Dump.push("farm", "merge after buy")
		Farm.invoke("Merge Chickens")
		Farm.touchPad({ "Buttons", "MergeChickens" })
	end
	Farm.buying = false
	return bought
end
function Farm.spend()
	if Farm.holdForLucky() then
		if Farm.due("lucky_hold", 3) then
			Dump.push("farm", "hold cash for lucky")
		end
		return
	end
	if Config.autoBuy and not Farm.buying and Farm.due("buy", 0.55) then
		task.spawn(Farm.buyCycle)
	elseif Config.autoMerge and not Config.autoBuy and Farm.due("merge", 0.5) then
		Dump.push("farm", "merge chickens")
		Farm.invoke("Merge Chickens")
		Farm.touchPad({ "Buttons", "MergeChickens" })
	end
	if Config.autoUpgrade then
		if Farm.due("upgrade_process", 0.8) then
			Farm.invoke("Upgrade Process Level")
			Farm.touchPad({ "Buttons", "UpgradeProcess" })
		elseif Farm.due("upgrade_tier", 1.0) then
			Farm.invoke("Upgrade Buy Tier Level")
			Farm.touchPad({ "Buttons", "UpgradeBuyTier" })
		end
	end
end
function Farm.start()
	if Farm.looping then
		return
	end
	Farm.looping = true
	Farm.bindRemotes()
	task.spawn(function()
		local folder = Workspace:FindFirstChild("Eggs") or Workspace:WaitForChild("Eggs", 15)
		if folder then
			Core.track(folder.ChildAdded:Connect(function(egg)
				task.defer(function()
					task.wait()
					Farm.collect(egg)
				end)
			end))
			Core.track(folder.ChildRemoved:Connect(function(egg)
				Farm.seen[egg.Name] = nil
				Farm.luckyTried[egg.Name] = nil
				if Farm.luckyTarget == egg then
					Farm.luckyTarget = nil
				end
			end))
			Farm.collectAll()
		end
	end)
	task.spawn(function()
		while Core.running do
			if not Farm.eventRemote or not Farm.fnRemote then
				Farm.bindRemotes()
			end
			Farm.handleModals()
			if (Config.autoCollect or Config.autoLucky) and Farm.due("collect", 0.12) then
				Farm.collectAll()
			end
			if Config.autoDeposit and Farm.due("deposit", 0.7) then
				Farm.invoke("Deposit Eggs")
				Farm.touchPad({ "Buttons", "DepositEggs" })
			end
			if Config.autoCash and Farm.due("cash", 0.7) then
				Farm.invoke("Collect Cash")
				Farm.touchPad({ "Buttons", "CollectMoney" })
			end
			if Config.autoCash and Farm.due("group", 20) then
				Farm.invoke("Claim Group Reward")
				Farm.touchPad({ "Buttons", "CollectGroupReward" })
			end
			Farm.spend()
			Dump.flush()
			task.wait(0.05)
		end
		Dump.flush()
	end)
end
local UI = {
	gui = nil,
	root = nil,
	open = true,
}
local function new(class, props)
	local inst = Instance.new(class)
	for key, value in pairs(props or {}) do
		inst[key] = value
	end
	return inst
end
local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 14)
	c.Parent = inst
	return c
end
local function pad(inst, top, side, bottom)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, top)
	p.PaddingBottom = UDim.new(0, bottom or top)
	p.PaddingLeft = UDim.new(0, side or top)
	p.PaddingRight = UDim.new(0, side or top)
	p.Parent = inst
	return p
end
function UI.setOpen(state)
	UI.open = state
	if UI.root then
		UI.root.Visible = state
	end
	if state then
		UserInputService.MouseIconEnabled = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end
function UI.toggle()
	UI.setOpen(not UI.open)
end
function UI.destroy()
	if UI.gui then
		UI.gui:Destroy()
	end
	UI.gui = nil
	UI.root = nil
end
local function toggleRow(parent, label, value, order, onChange)
	local row = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 28),
		LayoutOrder = order,
		Parent = parent,
	})
	new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -46, 1, 0),
		Font = FONT,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.text,
		Text = label,
		Parent = row,
	})
	local track = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(36, 20),
		BackgroundColor3 = value and T.on or T.off,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Parent = row,
	})
	corner(track, 10)
	local knob = new("Frame", {
		Size = UDim2.fromOffset(14, 14),
		Position = value and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7),
		BackgroundColor3 = value and T.knobOn or T.knobOff,
		BorderSizePixel = 0,
		Parent = track,
	})
	corner(knob, 7)
	local state = value
	track.Activated:Connect(function()
		state = not state
		track.BackgroundColor3 = state and T.on or T.off
		knob.Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
		knob.BackgroundColor3 = state and T.knobOn or T.knobOff
		onChange(state)
	end)
end
function UI.build(onUnload)
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("CFMenu")
	if existing then
		existing:Destroy()
	end
	local gui = new("ScreenGui", {
		Name = "CFMenu",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999999,
		AutoLocalize = false,
		Parent = playerGui,
	})
	UI.gui = gui
	local W, H = 280, 328
	local camera = Workspace.CurrentCamera
	local vp = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local x = math.floor((vp.X - W) * 0.5)
	local y = math.floor((vp.Y - H) * 0.42)
	local root = new("Frame", {
		Name = "Main",
		BackgroundColor3 = T.bg,
		Size = UDim2.fromOffset(W, H),
		Position = UDim2.fromOffset(x, y),
		BorderSizePixel = 0,
		Parent = gui,
	})
	UI.root = root
	corner(root, 16)
	local titleBar = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 52),
		Parent = root,
	})
	new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 16),
		Size = UDim2.new(1, -40, 0, 22),
		Font = FONT_MED,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.text,
		Text = "Chicken Farm",
		Parent = titleBar,
	})
	local close = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 20),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = T.close,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 20,
		Parent = root,
	})
	corner(close, 6)
	close.Activated:Connect(function()
		if onUnload then
			onUnload()
		end
	end)
	local dragging = false
	local dragStart
	local startPos
	Core.track(titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = root.Position
		end
	end))
	Core.track(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end))
	Core.track(UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart
			root.Position = UDim2.fromOffset(startPos.X.Offset + delta.X, startPos.Y.Offset + delta.Y)
		end
	end))
	local body = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 52),
		Size = UDim2.new(1, -40, 1, -68),
		Parent = root,
	})
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 8)
	list.Parent = body
	toggleRow(body, "Auto collect", Config.autoCollect, 1, function(on)
		Config.autoCollect = on
	end)
	toggleRow(body, "Auto deposit", Config.autoDeposit, 2, function(on)
		Config.autoDeposit = on
	end)
	toggleRow(body, "Auto cash", Config.autoCash, 3, function(on)
		Config.autoCash = on
	end)
	toggleRow(body, "Auto buy", Config.autoBuy, 4, function(on)
		Config.autoBuy = on
	end)
	toggleRow(body, "Auto merge", Config.autoMerge, 5, function(on)
		Config.autoMerge = on
	end)
	toggleRow(body, "Auto upgrade", Config.autoUpgrade, 6, function(on)
		Config.autoUpgrade = on
	end)
	toggleRow(body, "Auto lucky", Config.autoLucky, 7, function(on)
		Config.autoLucky = on
	end)
	Core.track(UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not Core.running then
			return
		end
		if input.KeyCode == Enum.KeyCode.Insert or input.KeyCode == Enum.KeyCode.RightShift then
			UI.toggle()
		end
	end))
	UI.setOpen(true)
end
local function unload()
	if not Core.running then
		return
	end
	Core.running = false
	Dump.onEvent = nil
	Dump.flush(true)
	Dump.restoreHooks()
	Core.disconnectAll()
	UI.destroy()
	if type(env) == "table" then
		env.CF_UNLOAD = nil
	end
end
if type(env) == "table" then
	env.CF_UNLOAD = unload
end
UI.build(unload)
Dump.start()
Farm.start()
task.defer(function()
	Dump.scan()
end)
