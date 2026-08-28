local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
local env = (typeof(getgenv) == "function" and getgenv()) or _G
local function pickFn(...)
	for i = 1, select("#", ...) do
		local fn = select(i, ...)
		if typeof(fn) == "function" then
			return fn
		end
	end
	return nil
end
local mouseMoveRel = pickFn(
	typeof(mousemoverel) == "function" and mousemoverel,
	syn and syn.mousemoverel,
	fluxus and fluxus.mousemoverel
)
local mouseMoveAbs = pickFn(
	typeof(mousemoveabs) == "function" and mousemoveabs,
	syn and syn.mousemoveabs,
	fluxus and fluxus.mousemoveabs
)
local mouseSendInput = pickFn(
	typeof(sendinput) == "function" and sendinput,
	typeof(SendInput) == "function" and SendInput
)
local mouse1DownFn = pickFn(typeof(ismouse1pressed) == "function" and ismouse1pressed)
local mouse2DownFn = pickFn(typeof(ismouse2pressed) == "function" and ismouse2pressed)
local aimBindDown = false
local clearAllEsp = nil
local applyMisc = nil
local runAction = nil
local unload = nil
local Config = {
	aimbot = false,
	aimbotKey = Enum.KeyCode.E,
	aimbotMouse = nil,
	prediction = true,
	visibleOnly = true,
	drawFov = false,
	smoothness = 12,
	fov = 150,
	esp = true,
	espSkeleton = true,
	espNames = true,
	espHealth = true,
	espDistance = true,
	espVisCheck = false,
	espChams = false,
	chamFill = 8,
	chamOutline = 20,
	teamCheck = true,
	maxDistance = 500,
	watermark = true,
	antiAfk = false,
	uncappedFps = false,
	persist = false,
	fly = false,
	speed = false,
	noclip = false,
	flySpeed = 60,
}
local VIS_GREEN = Color3.fromRGB(64, 255, 120)
local VIS_RED = Color3.fromRGB(255, 64, 64)
local BOX_COLOR = Color3.fromRGB(255, 64, 64)
local CHAM_GREEN = Color3.fromRGB(0, 155, 28)
local CHAM_RED = Color3.fromRGB(168, 0, 0)
local MOUSE_BINDS = {
	Mouse1 = Enum.UserInputType.MouseButton1,
	Mouse2 = Enum.UserInputType.MouseButton2,
	Mouse3 = Enum.UserInputType.MouseButton3,
}
local connections = {}
local running = true
local ts = nil
local charByPlayer = {}
local teamByPlayer = {}
local playerByModel = {}
local localTeam = nil
local lastMapAt = 0
local entries = {}
local fovRing = nil
local aimRemainderX = 0
local aimRemainderY = 0
local lastAimPickAt = 0
local lastAimPick = nil
local boxedCount = 0
local mappedCount = 0
local drawOk = false
local drawErr = nil
local lastTickAt = 0
local lastWmAt = 0
local lastSetBoxErr = nil
local hlErr = nil
local tsWhy = "not loaded"
local stats = {
	models = 0,
	boxed = 0,
	behind = 0,
	failed = 0,
	mapped = 0,
	team = 0,
	localSkip = 0,
}
local TICK_HZ = 10
local FILE_CONFIG = "bb_config.json"
local FILE_SCRIPT = "bb.lua"
local persistQueued = false
local persistConn = nil
local persistSave = nil
local persistArm = nil
local persistStop = nil
local hideFov = nil
local chamFolder = nil
local chamWorld = nil
local visCache = {}
local rayMode = "none"
local rayIgnoreNames = ""
local rayIgnoreAt = 0
local rayIgnoreCached = {}
local combatModelsAt = 0
local combatModelsCached = {}
local combatModelsCount = -1
local aliveCache = {}
local lastFovKey = ""
local bootAt = 0
local antiAfkConn = nil
local watermarkGui = nil
local watermarkLabel = nil
local healthGui = nil
local wmFrames = 0
local wmElapsed = 0
local lastAction = ""
local hopping = false
local function bind(signal, fn)
	local ok, conn = pcall(function()
		return signal:Connect(fn)
	end)
	if ok and conn then
		table.insert(connections, conn)
	end
	return conn
end
local function removeDrawing(obj)
	if not obj then
		return
	end
	pcall(function()
		obj.Visible = false
		if obj.Remove then
			obj:Remove()
		end
	end)
end
local function applyBindName(name)
	if type(name) ~= "string" or name == "" then
		return
	end
	if MOUSE_BINDS[name] then
		Config.aimbotKey = nil
		Config.aimbotMouse = MOUSE_BINDS[name]
		return
	end
	local key = Enum.KeyCode[name]
	if key then
		Config.aimbotKey = key
		Config.aimbotMouse = nil
	end
end
local function currentBindName()
	if Config.aimbotMouse == Enum.UserInputType.MouseButton1 then
		return "Mouse1"
	end
	if Config.aimbotMouse == Enum.UserInputType.MouseButton2 then
		return "Mouse2"
	end
	if Config.aimbotMouse == Enum.UserInputType.MouseButton3 then
		return "Mouse3"
	end
	if Config.aimbotKey then
		return Config.aimbotKey.Name
	end
	return "E"
end
local function configTable()
	return {
		aimbot = Config.aimbot,
		bind = currentBindName(),
		prediction = Config.prediction,
		visibleOnly = Config.visibleOnly,
		drawFov = Config.drawFov,
		smoothness = Config.smoothness,
		fov = Config.fov,
		esp = Config.esp,
		espSkeleton = Config.espSkeleton,
		espNames = Config.espNames,
		espHealth = Config.espHealth,
		espDistance = Config.espDistance,
		espVisCheck = Config.espVisCheck,
		espChams = Config.espChams == true,
		chamFill = Config.chamFill,
		chamOutline = Config.chamOutline,
		teamCheck = Config.teamCheck,
		maxDistance = Config.maxDistance,
		watermark = Config.watermark,
		antiAfk = Config.antiAfk,
		uncappedFps = Config.uncappedFps,
		persist = false,
		fly = Config.fly == true,
		speed = Config.speed == true,
		noclip = Config.noclip == true,
		flySpeed = Config.flySpeed,
		unload = false,
	}
end
local function persistStub()
	return [[task.spawn(function()
	local env = (typeof(getgenv) == "function" and getgenv()) or _G
	if type(env) == "table" then
		if env.__BB_PERSIST_STARTED then
			return
		end
		env.__BB_PERSIST_STARTED = true
	end
	pcall(function()
		if not game:IsLoaded() then
			game.Loaded:Wait()
		end
	end)
	task.wait(0.2)
	local src
	if (type(src) ~= "string" or #src < 80) and typeof(readfile) == "function" and typeof(isfile) == "function" and isfile("bb.lua") then
		src = readfile("bb.lua")
	end
	if type(src) == "string" and #src > 80 then
		local fn = loadstring(src, "bb.lua")
		if type(fn) == "function" then
			task.spawn(fn)
		end
	end
end)]]
end
local function persistQueueFn()
	if typeof(queue_on_teleport) == "function" then
		return queue_on_teleport
	end
	if syn and typeof(syn.queue_on_teleport) == "function" then
		return syn.queue_on_teleport
	end
	if fluxus and typeof(fluxus.queue_on_teleport) == "function" then
		return fluxus.queue_on_teleport
	end
	return nil
end
persistSave = function()
	if type(writefile) ~= "function" then
		return
	end
	pcall(function()
		writefile(FILE_CONFIG, HttpService:JSONEncode(configTable()))
	end)
end
local function persistCacheScript()
	if type(writefile) ~= "function" then
		return
	end
	local src = httpRaw(HOST .. "/lv.lua?t=" .. tostring(os.clock()))
	if type(src) == "string" and #src > 80 then
		pcall(writefile, FILE_SCRIPT, src)
	end
end
persistArm = function()
	return
end
persistStop = function()
	if persistConn then
		pcall(function()
			persistConn:Disconnect()
		end)
		persistConn = nil
	end
end
local function loadSavedConfig()
	if type(readfile) ~= "function" or type(isfile) ~= "function" then
		return false
	end
	local ok, raw = pcall(function()
		if not isfile(FILE_CONFIG) then
			return nil
		end
		return readfile(FILE_CONFIG)
	end)
	if not ok or type(raw) ~= "string" or raw == "" then
		return false
	end
	local dok, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not dok or type(data) ~= "table" then
		return false
	end
	for _, key in ipairs({
		"aimbot", "prediction", "visibleOnly", "drawFov", "esp", "espSkeleton",
		"espNames", "espHealth", "espDistance", "espVisCheck", "espChams", "teamCheck",
		"watermark", "antiAfk", "uncappedFps", "persist",
		"fly", "speed", "noclip",
	}) do
		if type(data[key]) == "boolean" then
			Config[key] = data[key]
		end
	end
	if type(data.smoothness) == "number" then
		Config.smoothness = math.clamp(math.floor(data.smoothness + 0.5), 1, 50)
	end
	if type(data.fov) == "number" then
		Config.fov = math.clamp(math.floor(data.fov + 0.5), 20, 600)
	end
	if type(data.maxDistance) == "number" then
		Config.maxDistance = math.clamp(math.floor(data.maxDistance + 0.5), 50, 2000)
	end
	if type(data.chamFill) == "number" then
		Config.chamFill = math.clamp(math.floor(data.chamFill + 0.5), 0, 90)
	end
	if type(data.chamOutline) == "number" then
		Config.chamOutline = math.clamp(math.floor(data.chamOutline + 0.5), 0, 90)
	end
	if type(data.flySpeed) == "number" then
		Config.flySpeed = math.clamp(math.floor(data.flySpeed + 0.5), 20, 160)
	end
	if type(data.bind) == "string" then
		applyBindName(data.bind)
	end
	return true
end
local function loadTS()
	local module = ReplicatedStorage:FindFirstChild("TS")
	if not module then
		return nil
	end
	local function usable(value)
		return type(value) == "table"
			and type(value.Characters) == "table"
			and type(value.Characters.GetCharacter) == "function"
	end
	local ok, value = pcall(require, module)
	if ok and usable(value) then
		tsWhy = "require=table"
		return value
	end
	if type(getrenv) == "function" then
		local rok, rvalue = pcall(function()
			return getrenv().require(module)
		end)
		if rok and usable(rvalue) then
			tsWhy = "getrenv.require=table"
			return rvalue
		end
		if rok and type(rvalue) == "function" then
			local cok, cvalue = pcall(rvalue)
			if cok and usable(cvalue) then
				tsWhy = "getrenv.require()"
				return cvalue
			end
		end
	end
	if ok and type(value) == "function" then
		local cok, cvalue = pcall(value)
		if cok and usable(cvalue) then
			tsWhy = "require()"
			return cvalue
		end
	end
	tsWhy = "TS unusable"
	return nil
end
local function teamKey(team)
	if team == nil then
		return nil
	end
	if typeof(team) == "Instance" then
		return team.Name
	end
	return tostring(team)
end
local function isCombatModel(model)
	if typeof(model) ~= "Instance" then
		return false
	end
	if model.Name == "Proxy" then
		return false
	end
	local health = model:FindFirstChild("Health")
	local root = model:FindFirstChild("Root")
	local body = model:FindFirstChild("Body")
	return health ~= nil
		and health:IsA("ValueBase")
		and root ~= nil
		and root:IsA("BasePart")
		and body ~= nil
end
local function collectCombatModels()
	local folder = Workspace:FindFirstChild("Characters")
	if not folder then
		combatModelsCached = {}
		combatModelsCount = 0
		return combatModelsCached
	end
	local now = os.clock()
	local kids = folder:GetChildren()
	local count = #kids
	if now - combatModelsAt < 0.2 and count == combatModelsCount and #combatModelsCached > 0 then
		return combatModelsCached
	end
	local list = {}
	for _, child in ipairs(kids) do
		if isCombatModel(child) then
			table.insert(list, child)
		end
	end
	combatModelsAt = now
	combatModelsCached = list
	combatModelsCount = count
	return list
end
local function callGetCharacter(player)
	local getCharacter = ts and ts.Characters and ts.Characters.GetCharacter
	if type(getCharacter) ~= "function" then
		return nil
	end
	local ok, model = pcall(getCharacter, ts.Characters, player)
	if ok and isCombatModel(model) then
		return model
	end
	ok, model = pcall(getCharacter, player)
	if ok and isCombatModel(model) then
		return model
	end
	return nil
end
local function ownerFromModel(model)
	if playerByModel[model] then
		return playerByModel[model]
	end
	local chars = ts and ts.Characters
	if type(chars) ~= "table" then
		return nil
	end
	for _, name in ipairs({ "GetPlayerFromCharacter", "GetPlayer", "FromCharacter" }) do
		local fn = chars[name]
		if type(fn) == "function" then
			local ok, player = pcall(fn, chars, model)
			if ok and typeof(player) == "Instance" and player:IsA("Player") then
				return player
			end
			ok, player = pcall(fn, model)
			if ok and typeof(player) == "Instance" and player:IsA("Player") then
				return player
			end
		end
	end
	return nil
end
local function refreshMaps(force)
	local now = os.clock()
	if not force and now - lastMapAt < 0.75 then
		return
	end
	lastMapAt = now
	charByPlayer = {}
	teamByPlayer = {}
	playerByModel = {}
	localTeam = nil
	mappedCount = 0
	if not ts then
		return
	end
	local getTeam = ts.Teams and ts.Teams.GetPlayerTeam
	for _, player in ipairs(Players:GetPlayers()) do
		local model = callGetCharacter(player)
		if model then
			charByPlayer[player] = model
			playerByModel[model] = player
			mappedCount += 1
		end
		if type(getTeam) == "function" then
			local ok, team = pcall(getTeam, ts.Teams, player)
			if ok then
				teamByPlayer[player] = team
			end
		end
	end
	local folder = Workspace:FindFirstChild("Characters")
	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			if isCombatModel(child) and not playerByModel[child] then
				local owner = ownerFromModel(child)
				if owner and not charByPlayer[owner] then
					charByPlayer[owner] = child
					playerByModel[child] = owner
					mappedCount += 1
				end
			end
		end
	end
	localTeam = teamKey(teamByPlayer[LocalPlayer])
end
local function isTeammate(player)
	if not Config.teamCheck then
		return false
	end
	local theirs = teamKey(teamByPlayer[player])
	return localTeam ~= nil and theirs ~= nil and theirs == localTeam
end
local function getHead(model)
	if not model then
		return nil
	end
	local body = model:FindFirstChild("Body")
	local head = body and body:FindFirstChild("Head")
	if head and head:IsA("BasePart") and not string.find(string.lower(head.Name), "hitbox", 1, true) then
		return head
	end
	return nil
end
local function getRoot(model)
	local root = model and model:FindFirstChild("Root")
	return (root and root:IsA("BasePart")) and root or nil
end
local function getAimWorld(model, entry)
	local head = entry and entry.head
	if not (head and head.Parent) then
		head = getHead(model)
		if entry then
			entry.head = head
		end
	end
	local root = entry and entry.root
	if not (root and root.Parent) then
		root = getRoot(model)
		if entry then
			entry.root = root
		end
	end
	if head and head.Parent and head.Size.Y <= 2.8 and head.Size.Magnitude <= 7 then
		return head, head.Position + head.CFrame.UpVector * math.clamp(head.Size.Y * 0.22, 0.1, 0.4)
	end
	if root and root.Parent then
		return head or root, root.Position + Vector3.new(0, 1.4, 0)
	end
	if head and head.Parent then
		return head, head.Position
	end
	return nil, nil
end
local DEAD_WORDS = {
	dead = true,
	downed = true,
	down = true,
	died = true,
	ragdoll = true,
	corpse = true,
	knocked = true,
	eliminated = true,
	killed = true,
}
local function isDeadWord(value)
	return DEAD_WORDS[string.lower(tostring(value) or "")] == true
end
local function isModelAlive(model)
	if typeof(model) ~= "Instance" or model.Parent == nil then
		return false
	end
	local now = os.clock()
	local cached = aliveCache[model]
	local health = model:FindFirstChild("Health")
	if not health or not health:IsA("ValueBase") or health.Value <= 0.05 then
		aliveCache[model] = { alive = false, at = now, full = now }
		return false
	end
	if cached and cached.alive and now - cached.at < 0.12 then
		return true
	end
	if not isCombatModel(model) then
		aliveCache[model] = { alive = false, at = now, full = now }
		return false
	end
	local body = model:FindFirstChild("Body")
	local head = body and body:FindFirstChild("Head")
	local root = getRoot(model)
	if not body or not head or not head:IsA("BasePart") or not root then
		aliveCache[model] = { alive = false, at = now, full = now }
		return false
	end
	if head.Transparency >= 0.98 and root.Transparency >= 0.98 then
		aliveCache[model] = { alive = false, at = now, full = now }
		return false
	end
	local owner = playerByModel[model]
	if owner and owner.Parent ~= Players then
		aliveCache[model] = { alive = false, at = now, full = now }
		return false
	end
	if cached and cached.alive and cached.full and now - cached.full < 0.35 then
		aliveCache[model] = { alive = true, at = now, full = cached.full }
		return true
	end
	local function inspect(inst)
		if typeof(inst) ~= "Instance" then
			return false
		end
		local n = string.lower(inst.Name)
		if inst:IsA("BoolValue") then
			if inst.Value and (DEAD_WORDS[n] or n == "knocked") then
				return true
			end
			if n == "alive" and inst.Value == false then
				return true
			end
		elseif inst:IsA("StringValue") and isDeadWord(inst.Value) then
			return true
		elseif inst:IsA("NumberValue") and (n == "health" or n == "hp") and inst.Value <= 0.05 then
			return true
		end
		return false
	end
	local state = model:FindFirstChild("State")
	if state then
		for _, child in ipairs(state:GetChildren()) do
			if inspect(child) then
				aliveCache[model] = { alive = false, at = now, full = now }
				return false
			end
		end
	end
	local ok, attrs = pcall(function()
		return model:GetAttributes()
	end)
	if ok and type(attrs) == "table" then
		for key, value in pairs(attrs) do
			local n = string.lower(tostring(key))
			if typeof(value) == "boolean" then
				if value and DEAD_WORDS[n] then
					aliveCache[model] = { alive = false, at = now, full = now }
					return false
				end
				if n == "alive" and value == false then
					aliveCache[model] = { alive = false, at = now, full = now }
					return false
				end
			elseif isDeadWord(value) then
				aliveCache[model] = { alive = false, at = now, full = now }
				return false
			end
		end
	end
	aliveCache[model] = { alive = true, at = now, full = now }
	return true
end
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
pcall(function()
	rayParams.RespectCanCollide = true
end)
local function collectRayIgnore()
	local now = os.clock()
	if now - rayIgnoreAt < 0.3 and #rayIgnoreCached > 0 then
		return rayIgnoreCached
	end
	local list = {}
	local names = {}
	local function add(inst, label)
		if typeof(inst) == "Instance" then
			table.insert(list, inst)
			table.insert(names, label or inst.Name)
		end
	end
	add(Workspace:FindFirstChild("Characters"), "Characters")
	add(chamWorld or Workspace:FindFirstChild("__BB_CHAM_WORLD"), "ChamWorld")
	add(LocalPlayer and LocalPlayer.Character, "Proxy")
	add(charByPlayer[LocalPlayer], "LocalBody")
	local camera = Workspace.CurrentCamera
	if camera then
		add(camera, "Camera")
		for _, name in ipairs({ "ViewModel", "Viewmodel", "Arms", "FirstPerson" }) do
			add(camera:FindFirstChild(name), name)
		end
	end
	for _, name in ipairs({ "ViewModel", "Viewmodel", "Arms", "Effects", "Debris", "Bullets", "Projectiles" }) do
		add(Workspace:FindFirstChild(name), name)
	end
	rayIgnoreNames = table.concat(names, ",")
	rayIgnoreCached = list
	rayIgnoreAt = now
	return list
end
local function hitIsVolume(inst)
	if typeof(inst) ~= "Instance" then
		return false
	end
	local node = inst
	for _ = 1, 8 do
		if not node then
			break
		end
		local lower = string.lower(node.Name)
		if node.Name == "Characters" or node.Name == "Hitbox" or node.Name == "Proxy" then
			return true
		end
		if string.sub(node.Name, 1, 5) == "__BB_" then
			return true
		end
		if string.find(lower, "hitbox", 1, true) or string.find(lower, "hurtbox", 1, true) then
			return true
		end
		local parent = node.Parent
		if parent and parent.Name == "Characters" then
			return true
		end
		node = parent
	end
	if inst:IsA("BasePart") then
		local collide = inst.CanCollide
		local trans = inst.Transparency
		if collide == false and trans >= 0.9 then
			return true
		end
	end
	return false
end
local function castTo(origin, target)
	local delta = target - origin
	local dist = delta.Magnitude
	if dist < 0.35 then
		return {
			visible = true,
			reason = "near",
			dist = dist,
			hit = nil,
			hops = 0,
		}
	end
	local unit = delta.Unit
	local baseIgnore = collectRayIgnore()
	local ignores = {}
	for i, inst in ipairs(baseIgnore) do
		ignores[i] = inst
	end
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayMode = "exclude+collide"
	local traveled = 0
	local hops = 0
	local skipped = {}
	while hops < 8 and traveled < dist - 0.08 do
		rayParams.FilterDescendantsInstances = ignores
		local remain = dist - traveled - 0.06
		local start = origin + unit * traveled
		local ok, hit = pcall(function()
			return Workspace:Raycast(start, unit * remain, rayParams)
		end)
		if not ok or typeof(hit) ~= "RaycastResult" or not hit.Instance then
			return {
				visible = true,
				reason = #skipped > 0 and ("clear after " .. table.concat(skipped, ",")) or "clear",
				dist = dist,
				hit = nil,
				hops = hops,
			}
		end
		local inst = hit.Instance
		local hitDist = (hit.Position - origin).Magnitude
		if hitIsVolume(inst) then
			table.insert(ignores, inst)
			table.insert(skipped, inst.Name)
			traveled = hitDist + 0.04
			hops += 1
		else
			return {
				visible = false,
				reason = "blocked",
				dist = dist,
				hitDist = hitDist,
				hit = inst,
				hops = hops,
			}
		end
	end
	return {
		visible = false,
		reason = "hop-limit",
		dist = dist,
		hit = nil,
		hops = hops,
	}
end
local function probeVisibility(model, head, root, force)
	local now = os.clock()
	local cached = visCache[model]
	if not force and cached and now - cached.at < 0.08 then
		return cached
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return { body = false, head = false, at = now, lines = { "no camera" } }
	end
	local origin = camera.CFrame.Position
	local headClear, bodyClear = false, false
	local traces = {}
	if head then
		local mid = castTo(origin, head.Position)
		traces.head = mid
		if mid.visible then
			headClear = true
			bodyClear = true
		elseif force then
			local left = castTo(origin, head.Position + head.CFrame.RightVector * 0.22)
			local right = castTo(origin, head.Position - head.CFrame.RightVector * 0.22)
			traces.headL = left
			traces.headR = right
			if left.visible or right.visible then
				headClear = true
				bodyClear = true
			end
		end
	end
	if root and not bodyClear then
		local chest = castTo(origin, root.Position)
		traces.chest = chest
		if chest.visible then
			bodyClear = true
		end
	end
	local result = {
		body = bodyClear,
		head = headClear,
		at = now,
		origin = origin,
		traces = traces,
		mode = rayMode,
		ignore = rayIgnoreNames,
	}
	visCache[model] = result
	return result
end
local function isVisible(part, model)
	local vis = probeVisibility(model, part, nil)
	return vis.head or vis.body
end
local function predictedPos(part, root)
	if not Config.prediction or not part then
		return part and part.Position
	end
	local vel
	local source = root or part
	pcall(function()
		vel = source.AssemblyLinearVelocity
	end)
	if typeof(vel) ~= "Vector3" or vel.Magnitude < 2 then
		return part.Position
	end
	if vel.Magnitude > 36 then
		vel = vel.Unit * 36
	end
	local lead = vel * 0.035
	if lead.Magnitude > 2.4 then
		lead = lead.Unit * 2.4
	end
	return part.Position + lead
end
local function healthRatioOf(health)
	if not health or not health:IsA("ValueBase") then
		return nil
	end
	local maxObj = health:FindFirstChild("MaxHealth")
	local maxv = 150
	if maxObj and maxObj:IsA("ValueBase") and maxObj.Value > 0 then
		maxv = maxObj.Value
	end
	if typeof(health.Value) ~= "number" or maxv <= 0 then
		return nil
	end
	return math.clamp(health.Value / maxv, 0, 1)
end
local function healthBarColor(ratio)
	ratio = math.clamp(ratio, 0, 1)
	if ratio > 0.6 then
		return Color3.fromRGB(72, 220, 118)
	end
	if ratio > 0.3 then
		return Color3.fromRGB(245, 166, 55)
	end
	return Color3.fromRGB(235, 72, 72)
end
local function isAimbotHeld()
	if Config.aimbotMouse == Enum.UserInputType.MouseButton1 and mouse1DownFn then
		local ok, down = pcall(mouse1DownFn)
		if ok and down then
			return true
		end
	end
	if Config.aimbotMouse == Enum.UserInputType.MouseButton2 and mouse2DownFn then
		local ok, down = pcall(mouse2DownFn)
		if ok and down then
			return true
		end
	end
	if aimBindDown then
		return true
	end
	if Config.aimbotMouse then
		local ok, down = pcall(function()
			return UserInputService:IsMouseButtonPressed(Config.aimbotMouse)
		end)
		if ok and down then
			return true
		end
	end
	if Config.aimbotKey then
		local ok, down = pcall(function()
			return UserInputService:IsKeyDown(Config.aimbotKey)
		end)
		if ok and down then
			return true
		end
	end
	return false
end
local function hideWorld(entry)
	if not entry then
		return
	end
	if entry.hl then
		pcall(function()
			entry.hl.Enabled = false
		end)
	end
	if entry.adorn then
		pcall(function()
			entry.adorn.Visible = false
			entry.adorn.Transparency = 1
		end)
	end
	if type(entry.skelLines) == "table" then
		for _, item in ipairs(entry.skelLines) do
			if item.line then
				item.line.Visible = false
			end
		end
		entry.skelOff = true
	end
	if entry.bill then
		pcall(function()
			entry.bill.Enabled = false
		end)
	end
	if entry.nameLabel then
		entry.nameLabel.Visible = false
	end
	if entry.bar then
		pcall(function()
			entry.bar.Enabled = false
		end)
	end
	if entry.healthBg then
		entry.healthBg.Visible = false
	end
	entry.healthVisible = false
	entry.nameVisible = false
	entry.worldOn = false
	entry.espSig = nil
end
local function destroyWorld(entry)
	if not entry then
		return
	end
	for _, key in ipairs({ "hl", "adorn", "bill", "bar", "healthBg", "nameLabel", "chamVis", "chamHid", "chamClone" }) do
		local inst = entry[key]
		if inst then
			pcall(function()
				inst:Destroy()
			end)
			entry[key] = nil
		end
	end
	if type(entry.chamBoxes) == "table" then
		for _, item in ipairs(entry.chamBoxes) do
			for _, key in ipairs({ "adorn", "vis", "hid" }) do
				if item[key] then
					pcall(function()
						item[key]:Destroy()
					end)
				end
			end
		end
		entry.chamBoxes = nil
	end
	if type(entry.skelLines) == "table" then
		for _, item in ipairs(entry.skelLines) do
			pcall(function()
				item.line:Destroy()
			end)
		end
	end
	entry.skelLines = nil
	entry.skelBones = nil
	entry.billLabel = nil
	entry.barBg = nil
	entry.barFill = nil
	entry.healthFill = nil
	entry.healthVisible = false
	entry.nameVisible = false
	entry.chamAdornee = nil
	entry.chamKey = nil
	entry.chamMap = nil
	if type(entry.chamSkin) == "table" then
		for inst, orig in pairs(entry.chamSkin) do
			if instAlive(inst) and type(orig) == "table" then
				pcall(function()
					inst.Color = orig.Color
					inst.Material = orig.Material
				end)
			end
		end
		entry.chamSkin = nil
	end
	entry.worldOn = false
	entry.espSig = nil
end
local function instAlive(inst)
	if not inst then
		return false
	end
	local ok, parent = pcall(function()
		return inst.Parent
	end)
	return ok and parent ~= nil
end
local function parentWorld(inst)
	if typeof(gethui) == "function" then
		local pok, gui = pcall(gethui)
		if pok and gui then
			local ok = pcall(function()
				inst.Parent = gui
			end)
			if ok and inst.Parent then
				return "gethui"
			end
		end
	end
	local cok, core = pcall(function()
		return game:GetService("CoreGui")
	end)
	if cok and core then
		local ok = pcall(function()
			inst.Parent = core
		end)
		if ok and inst.Parent then
			return "coregui"
		end
	end
	return nil
end
local function isOurs(inst)
	if typeof(inst) ~= "Instance" then
		return false
	end
	local name = inst.Name
	return string.sub(name, 1, 5) == "__BB_"
end
local function sweepContainer(container)
	if typeof(container) ~= "Instance" then
		return
	end
	local ok, kids = pcall(function()
		return container:GetChildren()
	end)
	if not ok or type(kids) ~= "table" then
		return
	end
	for _, child in ipairs(kids) do
		if isOurs(child) then
			pcall(function()
				child:Destroy()
			end)
		end
	end
end
local function sweepOrphans()
	if typeof(gethui) == "function" then
		local ok, gui = pcall(gethui)
		if ok then
			sweepContainer(gui)
		end
	end
	pcall(function()
		sweepContainer(game:GetService("CoreGui"))
	end)
	local world = Workspace:FindFirstChild("__BB_CHAM_WORLD")
	if world then
		pcall(function()
			world:Destroy()
		end)
	end
	chamWorld = nil
	local camera = Workspace.CurrentCamera
	if camera then
		sweepContainer(camera)
	end
	if LocalPlayer and LocalPlayer.Character then
		sweepContainer(LocalPlayer.Character)
	end
	local folder = Workspace:FindFirstChild("Characters")
	if not folder then
		return
	end
	for _, model in ipairs(folder:GetChildren()) do
		sweepContainer(model)
		local body = model:FindFirstChild("Body")
		if body then
			sweepContainer(body)
		end
		local root = model:FindFirstChild("Root")
		if root then
			sweepContainer(root)
		end
		local weapon = model:FindFirstChild("ClassBaseWeapon") or model:FindFirstChild("PrimaryClassBaseWeapon")
		if weapon then
			sweepContainer(weapon)
		end
	end
end
local BONE_PAIRS = {
	{ "Head", "UpperTorso" },
	{ "Head", "Torso" },
	{ "UpperTorso", "LowerTorso" },
	{ "LowerTorso", "Root" },
	{ "UpperTorso", "Root" },
	{ "Torso", "Root" },
	{ "Head", "Root" },
	{ "UpperTorso", "LeftUpperArm" },
	{ "UpperTorso", "RightUpperArm" },
	{ "Torso", "Left Arm" },
	{ "Torso", "Right Arm" },
	{ "LeftUpperArm", "LeftLowerArm" },
	{ "LeftLowerArm", "LeftHand" },
	{ "RightUpperArm", "RightLowerArm" },
	{ "RightLowerArm", "RightHand" },
	{ "LowerTorso", "LeftUpperLeg" },
	{ "LowerTorso", "RightUpperLeg" },
	{ "Torso", "Left Leg" },
	{ "Torso", "Right Leg" },
	{ "LeftUpperLeg", "LeftLowerLeg" },
	{ "LeftLowerLeg", "LeftFoot" },
	{ "RightUpperLeg", "RightLowerLeg" },
	{ "RightLowerLeg", "RightFoot" },
}
local function collectBones(model)
	local bones = {}
	local body = model and model:FindFirstChild("Body")
	local function addPart(child)
		if not child or not child:IsA("BasePart") then
			return
		end
		local n = child.Name
		local ln = string.lower(n)
		if n == "Hitbox" or string.find(ln, "hitbox", 1, true) then
			return
		end
		bones[n] = bones[n] or child
	end
	if body then
		addPart(body)
		local ok, desc = pcall(function()
			return body:GetDescendants()
		end)
		if ok and type(desc) == "table" then
			for _, child in ipairs(desc) do
				addPart(child)
			end
		end
	end
	local head = getHead(model)
	local root = getRoot(model)
	if head then
		bones.Head = bones.Head or head
	end
	if root then
		bones.Root = bones.Root or root
	end
	bones.UpperTorso = bones.UpperTorso or bones.Torso or bones.Chest
	bones.Torso = bones.Torso or bones.UpperTorso
	bones.LowerTorso = bones.LowerTorso or bones.Waist or bones.Hips
	bones.LeftUpperArm = bones.LeftUpperArm or bones["Left Arm"] or bones.LeftArm
	bones.RightUpperArm = bones.RightUpperArm or bones["Right Arm"] or bones.RightArm
	bones.LeftUpperLeg = bones.LeftUpperLeg or bones["Left Leg"] or bones.LeftLeg
	bones.RightUpperLeg = bones.RightUpperLeg or bones["Right Leg"] or bones.RightLeg
	return bones
end
local function boneLod(a, b)
	if string.find(a, "Hand", 1, true) or string.find(b, "Hand", 1, true)
		or string.find(a, "Foot", 1, true) or string.find(b, "Foot", 1, true)
	then
		return 3
	end
	if string.find(a, "Lower", 1, true) or string.find(b, "Lower", 1, true)
		or string.find(a, "Arm", 1, true) or string.find(b, "Leg", 1, true)
	then
		return 2
	end
	return 1
end
local function destroySkeleton(entry)
	if not entry or type(entry.skelLines) ~= "table" then
		return
	end
	for _, item in ipairs(entry.skelLines) do
		pcall(function()
			item.line:Destroy()
		end)
	end
	entry.skelLines = nil
	entry.skelBones = nil
	entry.skelOff = true
	entry.skelPaint = nil
	entry.skelPos = nil
end
local function placeBone(line, root, fromPart, toPart)
	local a = fromPart.Position
	local b = toPart.Position
	local len = (b - a).Magnitude
	if len < 0.08 then
		if line.Visible then
			line.Visible = false
		end
		return
	end
	line.Length = len
	line.CFrame = root.CFrame:ToObjectSpace(CFrame.lookAt(a, b))
	if not line.Visible then
		line.Visible = true
	end
end
local function hideSkel(entry)
	if not entry or entry.skelOff or type(entry.skelLines) ~= "table" then
		if entry then
			entry.skelOff = true
		end
		return
	end
	entry.skelOff = true
	for _, item in ipairs(entry.skelLines) do
		if item.line then
			item.line.Visible = false
		end
	end
end
local function ensureSkeleton(entry, model, color)
	if Config.espSkeleton == false then
		destroySkeleton(entry)
		return
	end
	local bones = collectBones(model)
	local root = bones.Root
	if not root then
		destroySkeleton(entry)
		return
	end
	local body = model and model:FindFirstChild("Body")
	local haveTorso = bones.UpperTorso or bones.Torso
	if type(entry.skelLines) ~= "table" or #entry.skelLines == 0 then
		if type(entry.skelLines) == "table" then
			destroySkeleton(entry)
		end
		entry.skelLines = {}
		for _, pair in ipairs(BONE_PAIRS) do
			local skip = pair[1] == "Head" and pair[2] == "Root" and haveTorso
			local a = bones[pair[1]]
			local b = bones[pair[2]]
			if not skip and a and b and a ~= b then
				local ok, line = pcall(Instance.new, "LineHandleAdornment")
				if ok and line then
					line.Name = "__BB_BONE"
					line.Thickness = 0.2
					line.ZIndex = 8
					line.AlwaysOnTop = true
					line.Color3 = color
					line.Adornee = root
					local parented = pcall(function()
						line.Parent = root
					end)
					if not parented or not line.Parent then
						parented = pcall(function()
							line.Parent = body
						end)
					end
					if parented and line.Parent then
						table.insert(entry.skelLines, {
							line = line,
							a = pair[1],
							b = pair[2],
							lod = boneLod(pair[1], pair[2]),
						})
					else
						pcall(function()
							line:Destroy()
						end)
					end
				end
			end
		end
	end
	entry.skelBones = bones
	entry.skelColor = color
	entry.skelOff = false
end
local lastSkelAt = 0
local function updateSkeletons()
	if not Config.esp or Config.espSkeleton == false then
		for _, entry in pairs(entries) do
			if entry.skelLines then
				destroySkeleton(entry)
			end
		end
		return
	end
	local now = os.clock()
	if now - lastSkelAt < 0.05 then
		return
	end
	lastSkelAt = now
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local camPos = camera.CFrame.Position
	local vp = camera.ViewportSize
	for _, entry in pairs(entries) do
		if entry.shown and entry.root and entry.model and (type(entry.skelLines) ~= "table" or #entry.skelLines == 0) then
			ensureSkeleton(entry, entry.model, entry.skelColor or BOX_COLOR)
		end
		if not (entry.shown and type(entry.skelLines) == "table" and #entry.skelLines > 0 and entry.root) then
			if type(entry.skelLines) == "table" then
				hideSkel(entry)
			end
		else
			local root = entry.root
			local screen = camera:WorldToViewportPoint(root.Position)
			if screen.Z <= 0 or screen.X < -60 or screen.Y < -60 or screen.X > vp.X + 60 or screen.Y > vp.Y + 60 then
				hideSkel(entry)
			else
				local rootPos = root.Position
				local dist = (rootPos - camPos).Magnitude
				local lod = (dist > 150 and 1) or (dist > 80 and 2) or 3
				if not (lod == 1 and not entry.skelOff and entry.skelLod == 1 and entry.skelPos and (rootPos - entry.skelPos).Magnitude < 0.22) then
					pcall(function()
						entry.skelOff = false
						entry.skelPos = rootPos
						entry.skelLod = lod
						local bones = collectBones(entry.model)
						entry.skelBones = bones
						local color = entry.skelColor or BOX_COLOR
						if entry.skelPaint ~= color then
							entry.skelPaint = color
							for _, item in ipairs(entry.skelLines) do
								item.line.Color3 = color
							end
						end
						for _, item in ipairs(entry.skelLines) do
							if item.lod > lod then
								if item.line.Visible then
									item.line.Visible = false
								end
							else
								local a = bones[item.a]
								local b = bones[item.b]
								if a and b then
									placeBone(item.line, root, a, b)
								elseif item.line.Visible then
									item.line.Visible = false
								end
							end
						end
					end)
				end
			end
		end
	end
end
local function setWorldEsp(entry, model, color, name, ratio, dist)
	if entry.hl then
		pcall(function()
			entry.hl:Destroy()
		end)
		entry.hl = nil
	end
	local showName = Config.espNames ~= false
	local showHealth = Config.espHealth ~= false
	local showSkel = Config.espSkeleton ~= false
	if type(ratio) == "number" then
		entry.healthRatio = math.clamp(ratio, 0, 1)
	end
	local sig = table.concat({
		name or "",
		tostring(color),
		showSkel and "1" or "0",
		showName and "1" or "0",
		showHealth and "1" or "0",
	}, "|")
	if entry.worldOn and entry.espSig == sig then
		if showSkel then
			entry.skelColor = color
			if type(entry.skelLines) ~= "table" or #entry.skelLines == 0 then
				ensureSkeleton(entry, model, color)
			end
		end
		return
	end
	entry.espSig = sig
	local root = entry.root
	if entry.adorn then
		pcall(function()
			entry.adorn:Destroy()
		end)
		entry.adorn = nil
	end
	if showSkel then
		ensureSkeleton(entry, model, color)
	else
		destroySkeleton(entry)
	end
	entry.nameText = showName and name or ""
	if entry.bill then
		pcall(function()
			entry.bill:Destroy()
		end)
		entry.bill = nil
		entry.billLabel = nil
	end
	if not showName and entry.nameLabel then
		entry.nameLabel.Visible = false
		entry.nameVisible = false
	end
	if entry.bar then
		pcall(function()
			entry.bar:Destroy()
		end)
		entry.bar = nil
		entry.barBg = nil
		entry.barFill = nil
	end
	entry.worldOn = true
end
local HEALTH_BAR_W = 3
local HEALTH_BAR_GAP = 6
local function ensureHealthGui()
	if instAlive(healthGui) then
		return healthGui
	end
	if healthGui then
		pcall(function()
			healthGui:Destroy()
		end)
		healthGui = nil
	end
	local ok, gui = pcall(Instance.new, "ScreenGui")
	if not ok or not gui then
		return nil
	end
	gui.Name = "__BB_ESP"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100002
	gui.Enabled = true
	if parentWorld(gui) then
		healthGui = gui
		return gui
	end
	pcall(function()
		gui:Destroy()
	end)
	return nil
end
local function hideNameLabel(entry)
	if entry and entry.nameLabel then
		entry.nameLabel.Visible = false
	end
	if entry then
		entry.nameVisible = false
	end
end
local function ensureNameLabel(entry)
	if instAlive(entry.nameLabel) then
		return true
	end
	local gui = ensureHealthGui()
	if not gui then
		return false
	end
	if entry.nameLabel then
		pcall(function()
			entry.nameLabel:Destroy()
		end)
		entry.nameLabel = nil
	end
	local ok, lab = pcall(Instance.new, "TextLabel")
	if not ok or not lab then
		return false
	end
	lab.Name = "__BB_NM"
	lab.BackgroundTransparency = 1
	lab.AnchorPoint = Vector2.new(0.5, 1)
	lab.Size = UDim2.fromOffset(200, 16)
	lab.Font = Enum.Font.Gotham
	lab.TextSize = 13
	lab.TextColor3 = Color3.fromRGB(236, 236, 236)
	lab.TextStrokeColor3 = Color3.fromRGB(8, 8, 8)
	lab.TextStrokeTransparency = 0.2
	lab.TextXAlignment = Enum.TextXAlignment.Center
	lab.Visible = false
	lab.ZIndex = 4
	lab.Parent = gui
	entry.nameLabel = lab
	return true
end
local function layoutNameLabel(entry, camera)
	if Config.espNames == false or type(entry.nameText) ~= "string" or entry.nameText == "" then
		hideNameLabel(entry)
		return
	end
	local head = entry.head
	if not head or not ensureNameLabel(entry) then
		hideNameLabel(entry)
		return
	end
	local screen = camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.85, 0))
	if screen.Z <= 0 then
		hideNameLabel(entry)
		return
	end
	local vp = camera.ViewportSize
	local x = math.floor(screen.X + 0.5)
	local y = math.floor(screen.Y + 0.5)
	if x < -80 or y < -20 or x > vp.X + 80 or y > vp.Y + 20 then
		hideNameLabel(entry)
		return
	end
	if entry.nameLabel.Text ~= entry.nameText then
		entry.nameLabel.Text = entry.nameText
	end
	if entry.nmX ~= x or entry.nmY ~= y or not entry.nameVisible then
		entry.nameLabel.Position = UDim2.fromOffset(x, y)
		entry.nameLabel.Visible = true
		entry.nmX, entry.nmY = x, y
		entry.nameVisible = true
	end
end
local function muteGameNames(model)
	local body = model and model:FindFirstChild("Body")
	local head = body and body:FindFirstChild("Head")
	if not head then
		return
	end
	pcall(function()
		for _, inst in ipairs(head:GetChildren()) do
			if inst:IsA("BillboardGui") and not isOurs(inst) then
				inst.Enabled = false
			end
		end
		for _, inst in ipairs(body:GetChildren()) do
			if inst:IsA("BillboardGui") and not isOurs(inst) then
				inst.Enabled = false
			end
		end
	end)
end
local CHAM_PART_MAX = 32
local function isHitboxName(name)
	local ln = string.lower(tostring(name or ""))
	return name == "Hitbox" or string.find(ln, "hitbox", 1, true) ~= nil
end
local function chamParts(model)
	local list = {}
	local seen = {}
	local function add(inst)
		if typeof(inst) ~= "Instance" or not inst:IsA("BasePart") or seen[inst] or isHitboxName(inst.Name) then
			return
		end
		if inst.Size.Magnitude < 0.05 then
			return
		end
		seen[inst] = true
		table.insert(list, inst)
	end
	local body = model and model:FindFirstChild("Body")
	if typeof(body) == "Instance" then
		add(body)
		local ok, desc = pcall(function()
			return body:GetDescendants()
		end)
		if ok and type(desc) == "table" then
			for _, inst in ipairs(desc) do
				add(inst)
			end
		end
	end
	add(getHead(model))
	if #list == 0 then
		add(getRoot(model))
	end
	if #list > CHAM_PART_MAX then
		table.sort(list, function(a, b)
			return a.Size.Magnitude > b.Size.Magnitude
		end)
		while #list > CHAM_PART_MAX do
			table.remove(list)
		end
	end
	return list
end
local function chamBoxSize(part)
	return part.Size
end
local function makeChamBox(part, fallback)
	local ok, box = pcall(Instance.new, "BoxHandleAdornment")
	if not ok or not box then
		return nil
	end
	box.Name = "__BB_CHAM"
	box.Adornee = part
	box.AlwaysOnTop = true
	box.ZIndex = 8
	box.Color3 = CHAM_RED
	box.Transparency = 0.04
	box.Size = chamBoxSize(part)
	box.Visible = true
	local pok = pcall(function()
		box.Parent = part
	end)
	if not pok or box.Parent == nil then
		if fallback then
			pcall(function()
				box.Parent = fallback
			end)
		end
	end
	if box.Parent == nil then
		pcall(function()
			box:Destroy()
		end)
		return nil
	end
	return box
end
local function destroyChamItem(item)
	if not item then
		return
	end
	for _, key in ipairs({ "adorn", "vis", "hid" }) do
		if item[key] then
			pcall(function()
				item[key]:Destroy()
			end)
			item[key] = nil
		end
	end
end
local function destroyChams(entry)
	if not entry then
		return
	end
	if type(entry.chamBoxes) == "table" then
		for _, item in ipairs(entry.chamBoxes) do
			destroyChamItem(item)
		end
	end
	for _, key in ipairs({ "chamVis", "chamHid", "chamClone" }) do
		if entry[key] then
			pcall(function()
				entry[key]:Destroy()
			end)
			entry[key] = nil
		end
	end
	entry.chamBoxes = nil
	entry.chamAdornee = nil
	entry.chamKey = nil
	entry.chamMap = nil
	entry.chamSkin = nil
end
local function chamBoxesValid(entry)
	if type(entry.chamBoxes) ~= "table" or #entry.chamBoxes == 0 then
		return false
	end
	for _, item in ipairs(entry.chamBoxes) do
		if item.part and item.part.Parent and instAlive(item.adorn) then
			return true
		end
	end
	return false
end
local function ensureChams(entry, model)
	local parts = chamParts(model)
	if #parts == 0 then
		destroyChams(entry)
		return false
	end
	if chamBoxesValid(entry) then
		return true
	end
	destroyChams(entry)
	local root = getRoot(model)
	local boxes = {}
	for _, part in ipairs(parts) do
		local adorn = makeChamBox(part, root)
		if adorn then
			table.insert(boxes, { part = part, adorn = adorn, seen = nil })
		end
	end
	if #boxes == 0 then
		return false
	end
	entry.chamBoxes = boxes
	entry.chamKey = nil
	return true
end
local function chamPartVisible(origin, part)
	if not part or not part.Parent then
		return false
	end
	local result = castTo(origin, part.Position)
	return result.visible == true
end
local function updateChams(shown)
	if Config.espChams ~= true then
		for _, entry in pairs(entries) do
			destroyChams(entry)
		end
		return
	end
	local fill = math.clamp((Config.chamFill or 8) / 500, 0, 0.12)
	local camera = Workspace.CurrentCamera
	local origin = camera and camera.CFrame.Position
	local ranked = {}
	for _, item in ipairs(shown) do
		table.insert(ranked, item)
	end
	table.sort(ranked, function(a, b)
		return (a.dist or 1e9) < (b.dist or 1e9)
	end)
	local keep = {}
	for i = 1, #ranked do
		keep[ranked[i].entry] = ranked[i]
	end
	for _, entry in pairs(entries) do
		local item = keep[entry]
		if not item then
			destroyChams(entry)
		elseif ensureChams(entry, item.model) then
			for _, box in ipairs(entry.chamBoxes) do
				if box.adorn and box.part and box.part.Parent then
					local seen = origin and chamPartVisible(origin, box.part) or false
					box.adorn.Size = box.part.Size
					if box.seen ~= seen or entry.chamKey ~= fill then
						box.seen = seen
						box.adorn.Color3 = seen and CHAM_GREEN or CHAM_RED
						box.adorn.Transparency = fill
						box.adorn.Visible = true
						box.adorn.AlwaysOnTop = true
					end
				end
			end
			entry.chamKey = fill
		end
	end
end
local function hideHealthBar(entry)
	if not entry then
		return
	end
	if entry.healthBg then
		entry.healthBg.Visible = false
	end
	entry.healthVisible = false
end
local function destroyHealthBar(entry)
	if not entry then
		return
	end
	if entry.healthBg then
		pcall(function()
			entry.healthBg:Destroy()
		end)
	end
	entry.healthBg = nil
	entry.healthFill = nil
	entry.healthVisible = false
	entry.hbX, entry.hbY, entry.hbH, entry.hbFillH, entry.hbColor = nil, nil, nil, nil, nil
end
local function ensureHealthBar(entry)
	if instAlive(entry.healthBg) and instAlive(entry.healthFill) then
		return true
	end
	local now = os.clock()
	if entry.hbCreateAt and now - entry.hbCreateAt < 1 then
		return false
	end
	entry.hbCreateAt = now
	destroyHealthBar(entry)
	local gui = ensureHealthGui()
	if not gui then
		return false
	end
	local ok, bg = pcall(Instance.new, "Frame")
	if not ok or not bg then
		return false
	end
	bg.Name = "__BB_HP"
	bg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	bg.BackgroundTransparency = 0.35
	bg.BorderSizePixel = 0
	bg.Visible = false
	bg.ZIndex = 2
	bg.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(72, 220, 118)
	fill.BorderSizePixel = 0
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.fromScale(0, 1)
	fill.ZIndex = 3
	fill.Parent = bg
	entry.healthBg = bg
	entry.healthFill = fill
	return true
end
local function layoutHealthBar(entry, camera)
	if not ensureHealthBar(entry) then
		return
	end
	local head = entry.head
	local root = entry.root
	if not head or not root then
		hideHealthBar(entry)
		return
	end
	local top = camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.45, 0))
	local bottom = camera:WorldToViewportPoint(root.Position + Vector3.new(0, -3.25, 0))
	if top.Z <= 0 or bottom.Z <= 0 then
		hideHealthBar(entry)
		return
	end
	local y = math.floor(math.min(top.Y, bottom.Y) + 0.5)
	local h = math.clamp(math.floor(math.abs(bottom.Y - top.Y) + 0.5), 18, 200)
	local midX = (top.X + bottom.X) * 0.5
	local x = math.floor(midX - 14 - HEALTH_BAR_W + 0.5)
	local vp = camera.ViewportSize
	if x + HEALTH_BAR_W < -24 or y + h < -24 or x > vp.X + 24 or y > vp.Y + 24 then
		hideHealthBar(entry)
		return
	end
	local ratio = entry.healthRatio
	if type(ratio) ~= "number" then
		ratio = 1
	end
	ratio = math.clamp(ratio, 0, 1)
	local fillH = math.max(1, math.floor(h * ratio + 0.5))
	local color = healthBarColor(ratio)
	if entry.hbX ~= x or entry.hbY ~= y or entry.hbH ~= h or not entry.healthVisible then
		entry.healthBg.Size = UDim2.fromOffset(HEALTH_BAR_W, h)
		entry.healthBg.Position = UDim2.fromOffset(x, y)
		entry.healthBg.Visible = true
		entry.hbX, entry.hbY, entry.hbH = x, y, h
		entry.healthVisible = true
	end
	if entry.hbFillH ~= fillH then
		entry.healthFill.Size = UDim2.fromOffset(HEALTH_BAR_W, fillH)
		entry.hbFillH = fillH
	end
	if entry.hbColor ~= color then
		entry.healthFill.BackgroundColor3 = color
		entry.hbColor = color
	end
end
local lastHealthBarAt = 0
local function updateHealthBars()
	local now = os.clock()
	if now - lastHealthBarAt < 0.016 then
		return
	end
	lastHealthBarAt = now
	local wantHealth = Config.esp and Config.espHealth ~= false
	local wantNames = Config.esp and Config.espNames ~= false
	if not wantHealth and not wantNames then
		for _, entry in pairs(entries) do
			hideHealthBar(entry)
			hideNameLabel(entry)
		end
		if healthGui then
			healthGui.Enabled = false
		end
		return
	end
	local gui = ensureHealthGui()
	if not gui then
		return
	end
	gui.Enabled = true
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	for _, entry in pairs(entries) do
		pcall(function()
			if entry.shown then
				if entry.model and (not (entry.head and entry.head.Parent) or not (entry.root and entry.root.Parent)) then
					cacheParts(entry, entry.model)
				end
				if wantHealth and entry.head and entry.root then
					layoutHealthBar(entry, camera)
				else
					hideHealthBar(entry)
				end
				if wantNames and entry.head then
					layoutNameLabel(entry, camera)
				else
					hideNameLabel(entry)
				end
			else
				hideHealthBar(entry)
				hideNameLabel(entry)
			end
		end)
	end
end
local function hideEntry(entry)
	if not entry then
		return
	end
	if entry.shown then
		for i = 1, 4 do
			if entry.lines[i] then
				entry.lines[i].Visible = false
			end
		end
		if entry.label then
			entry.label.Visible = false
		end
	end
	hideWorld(entry)
	entry.shown = false
end
clearAllEsp = function()
	boxedCount = 0
	for _, entry in pairs(entries) do
		destroyWorld(entry)
		hideEntry(entry)
	end
end
local function destroyEntry(key)
	local entry = entries[key]
	if not entry then
		return
	end
	for i = 1, 4 do
		removeDrawing(entry.lines[i])
	end
	removeDrawing(entry.label)
	destroyWorld(entry)
	entries[key] = nil
end
local function ensureEntry(key)
	local entry = entries[key]
	if entry then
		return entry
	end
	entry = {
		lines = {},
		label = nil,
		head = nil,
		root = nil,
		model = nil,
		shown = false,
		lastBox = "",
	}
	entries[key] = entry
	return entry
end
local function cacheParts(entry, model)
	if entry.model == model and entry.head and entry.head.Parent then
		return true
	end
	if entry.model ~= model then
		destroySkeleton(entry)
		destroyChams(entry)
		entry.namesMuted = nil
	end
	entry.model = model
	entry.head = getHead(model)
	entry.root = getRoot(model)
	return entry.head ~= nil or entry.root ~= nil
end
local function localOrigin()
	local root = getRoot(charByPlayer[LocalPlayer])
	if root then
		return root.Position
	end
	local camera = Workspace.CurrentCamera
	return camera and camera.CFrame.Position
end
local function updateEsp()
	stats.models = 0
	stats.boxed = 0
	stats.behind = 0
	stats.failed = 0
	stats.mapped = mappedCount
	stats.team = 0
	stats.localSkip = 0
	if not Config.esp and Config.espChams ~= true then
		clearAllEsp()
		return
	end
	local origin = localOrigin()
	local seen = {}
	local shown = {}
	local visOn = Config.espVisCheck == true
	for _, model in ipairs(collectCombatModels()) do
		stats.models += 1
		seen[model] = true
		local owner = playerByModel[model]
		if owner == LocalPlayer then
			stats.localSkip += 1
			if entries[model] then
				hideEntry(entries[model])
			end
		elseif owner and isTeammate(owner) then
			stats.team += 1
			if entries[model] then
				hideEntry(entries[model])
			end
		else
			local health = model:FindFirstChild("Health")
			local alive = isModelAlive(model)
			local root = getRoot(model)
			local dist = origin and root and (root.Position - origin).Magnitude
			if not alive then
				if entries[model] then
					hideEntry(entries[model])
				end
				stats.failed += 1
			elseif dist and dist > Config.maxDistance then
				if entries[model] then
					hideEntry(entries[model])
				end
			else
				local entry = ensureEntry(model)
				if entry and cacheParts(entry, model) then
					local name = owner and (owner.DisplayName ~= "" and owner.DisplayName or owner.Name) or model.Name
					if Config.espDistance and dist then
						name = name .. " " .. tostring(math.floor(dist / 5 + 0.5) * 5) .. "m"
					end
					local color = BOX_COLOR
					if visOn then
						local vis = probeVisibility(model, entry.head, entry.root)
						entry.lastRay = vis
						color = vis.body and VIS_GREEN or VIS_RED
					end
					entry.skelColor = color
					local ratio = healthRatioOf(health)
					if ratio then
						entry.healthRatio = ratio
					end
					if Config.esp then
						setWorldEsp(entry, model, color, name, entry.healthRatio, dist)
						if not entry.namesMuted then
							muteGameNames(model)
							entry.namesMuted = true
						end
						entry.shown = true
						stats.boxed += 1
					else
						hideWorld(entry)
						entry.shown = true
					end
					table.insert(shown, { entry = entry, model = model, dist = dist, color = color })
				else
					stats.failed += 1
				end
			end
		end
	end
	boxedCount = stats.boxed
	for key in pairs(entries) do
		if not seen[key] then
			destroyEntry(key)
			visCache[key] = nil
			aliveCache[key] = nil
		end
	end
	updateChams(shown)
end
local fovGui = nil
hideFov = function()
	lastFovKey = ""
	if fovGui then
		pcall(function()
			fovGui.Enabled = false
		end)
	end
	if fovRing then
		pcall(function()
			fovRing.Visible = false
		end)
	end
end
local function updateFov()
	if not Config.drawFov or not Config.aimbot then
		hideFov()
		return
	end
	local size = math.clamp(Config.fov, 20, 600) * 2
	if not instAlive(fovGui) or not instAlive(fovRing) then
		if fovGui then
			pcall(function()
				fovGui:Destroy()
			end)
		end
		fovGui = nil
		fovRing = nil
		local ok, gui = pcall(Instance.new, "ScreenGui")
		if not ok or not gui then
			return
		end
		gui.Name = "__BB_FOV"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 100001
		gui.Enabled = true
		local rok, ring = pcall(Instance.new, "Frame")
		if rok and ring then
			ring.Name = "Ring"
			ring.AnchorPoint = Vector2.new(0.5, 0.5)
			ring.BackgroundTransparency = 1
			ring.BorderSizePixel = 0
			ring.Position = UDim2.fromScale(0.5, 0.5)
			ring.Size = UDim2.fromOffset(size, size)
			pcall(function()
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(1, 0)
				corner.Parent = ring
				local stroke = Instance.new("UIStroke")
				stroke.Thickness = 1
				stroke.Color = Color3.fromRGB(220, 220, 228)
				stroke.Transparency = 0.25
				stroke.Parent = ring
			end)
			ring.Parent = gui
			fovRing = ring
		end
		if parentWorld(gui) then
			fovGui = gui
		else
			pcall(function()
				gui:Destroy()
			end)
			return
		end
		lastFovKey = tostring(size)
	end
	if not fovGui.Enabled then
		fovGui.Enabled = true
	end
	if lastFovKey == tostring(size) then
		return
	end
	lastFovKey = tostring(size)
	pcall(function()
		fovRing.Visible = true
		fovRing.Position = UDim2.fromScale(0.5, 0.5)
		fovRing.Size = UDim2.fromOffset(size, size)
	end)
end
local function getClosestHead()
	local now = os.clock()
	if lastAimPickAt > 0 and now - lastAimPickAt < 0.016 then
		return lastAimPick
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		lastAimPick = nil
		return nil
	end
	lastAimPickAt = now
	local center = camera.ViewportSize * 0.5
	local origin = camera.CFrame.Position
	local best, bestDist = nil, Config.fov
	local visOnly = Config.visibleOnly == true
	local localModel = charByPlayer[LocalPlayer]
	for _, model in ipairs(collectCombatModels()) do
		if model ~= localModel then
			local player = playerByModel[model]
			if not (player and isTeammate(player)) then
				local entry = entries[model]
				if (entry and entry.shown) or isModelAlive(model) then
					local head, world = getAimWorld(model, entry)
					local root = (entry and entry.root) or getRoot(model)
					if head and world then
						local led = predictedPos(head, root)
						if typeof(led) == "Vector3" then
							world = world + (led - head.Position)
						end
						if typeof(world) == "Vector3" and (world - origin).Magnitude <= Config.maxDistance then
							if not visOnly or probeVisibility(model, head, root).head then
								local screen, onScreen = camera:WorldToViewportPoint(world)
								if onScreen and screen.Z > 0 then
									local dx, dy = screen.X - center.X, screen.Y - center.Y
									local dist = math.sqrt(dx * dx + dy * dy)
									if dist < bestDist then
										bestDist = dist
										best = { part = head, world = world }
									end
								end
							end
						end
					end
				end
			end
		end
	end
	lastAimPick = best
	return best
end
local function sendMouse(dx, dy, absX, absY)
	if mouseMoveRel and (dx ~= 0 or dy ~= 0) then
		local ok = pcall(mouseMoveRel, dx, dy)
		if ok then
			return true
		end
	end
	if mouseSendInput and (dx ~= 0 or dy ~= 0) then
		local ok = pcall(mouseSendInput, dx, dy)
		if ok then
			return true
		end
	end
	if mouseMoveAbs and absX and absY then
		local ok = pcall(mouseMoveAbs, absX, absY)
		if ok then
			return true
		end
	end
	return false
end
local function aimAt(target)
	if not target then
		return
	end
	if not (mouseSendInput or mouseMoveAbs or mouseMoveRel) then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local screen, onScreen = camera:WorldToViewportPoint(target.world)
	if not onScreen or screen.Z <= 0 then
		return
	end
	local mouse = UserInputService:GetMouseLocation()
	local deltaX, deltaY = screen.X - mouse.X, screen.Y - mouse.Y
	if math.sqrt(deltaX * deltaX + deltaY * deltaY) < 2 then
		return
	end
	local factor = math.clamp(1 / math.max(Config.smoothness, 0.01), 0.04, 1)
	aimRemainderX += deltaX * factor
	aimRemainderY += deltaY * factor
	local moveX = math.floor(aimRemainderX + 0.5)
	local moveY = math.floor(aimRemainderY + 0.5)
	if moveX == 0 and moveY == 0 then
		return
	end
	aimRemainderX -= moveX
	aimRemainderY -= moveY
	sendMouse(moveX, moveY, mouse.X + moveX, mouse.Y + moveY)
end
local flyBv = nil
local noclipParts = {}
local function getLocalBody()
	local mapped = charByPlayer[LocalPlayer]
	if mapped and mapped.Parent then
		return mapped
	end
	local model = callGetCharacter(LocalPlayer)
	if model then
		charByPlayer[LocalPlayer] = model
		playerByModel[model] = LocalPlayer
		return model
	end
	local folder = Workspace:FindFirstChild("Characters")
	if not folder then
		return nil
	end
	local ok, kids = pcall(function()
		return folder:GetChildren()
	end)
	if not ok or type(kids) ~= "table" then
		return nil
	end
	for _, child in ipairs(kids) do
		if isCombatModel(child) and ownerFromModel(child) == LocalPlayer then
			charByPlayer[LocalPlayer] = child
			playerByModel[child] = LocalPlayer
			return child
		end
	end
	return nil
end
local speedBv = nil
local function destroyFly()
	if flyBv then
		pcall(function()
			flyBv:Destroy()
		end)
		flyBv = nil
	end
end
local function destroySpeed()
	if speedBv then
		pcall(function()
			speedBv:Destroy()
		end)
		speedBv = nil
	end
end
local function keyDown(key)
	local ok, down = pcall(function()
		return UserInputService:IsKeyDown(key)
	end)
	return ok and down == true
end
local lastFlyAt = 0
local function updateFly()
	if not Config.fly then
		destroyFly()
		lastFlyAt = 0
		return
	end
	destroyFly()
	local root = getRoot(getLocalBody())
	if not root then
		return
	end
	local now = os.clock()
	local dt = lastFlyAt > 0 and math.clamp(now - lastFlyAt, 0, 0.05) or 0.016
	lastFlyAt = now
	local camera = Workspace.CurrentCamera
	local cf = camera and camera.CFrame or root.CFrame
	local move = Vector3.zero
	if keyDown(Enum.KeyCode.W) then
		move += cf.LookVector
	end
	if keyDown(Enum.KeyCode.S) then
		move -= cf.LookVector
	end
	if keyDown(Enum.KeyCode.A) then
		move -= cf.RightVector
	end
	if keyDown(Enum.KeyCode.D) then
		move += cf.RightVector
	end
	if keyDown(Enum.KeyCode.Space) then
		move += Vector3.yAxis
	end
	if keyDown(Enum.KeyCode.LeftControl) then
		move -= Vector3.yAxis
	end
	pcall(function()
		if move.Magnitude > 0.05 then
			move = move.Unit * math.clamp(Config.flySpeed or 60, 20, 160)
			root.AssemblyLinearVelocity = move
			root.CFrame = CFrame.new(root.Position + move * dt) * (root.CFrame - root.CFrame.Position)
		else
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end)
end
local function restoreNoclip()
	for part, collide in pairs(noclipParts) do
		pcall(function()
			if part.Parent then
				part.CanCollide = collide
			end
		end)
	end
	noclipParts = {}
end
local function updateNoclip()
	if not Config.noclip then
		if next(noclipParts) then
			restoreNoclip()
		end
		return
	end
	local body = getLocalBody()
	if not body then
		return
	end
	for part in pairs(noclipParts) do
		if not part.Parent then
			noclipParts[part] = nil
		end
	end
	local function consider(part)
		if typeof(part) ~= "Instance" or not part:IsA("BasePart") or part.Name == "Hitbox" then
			return
		end
		if noclipParts[part] == nil then
			noclipParts[part] = part.CanCollide
		end
		if part.CanCollide then
			part.CanCollide = false
		end
	end
	consider(getRoot(body))
	local model = body:FindFirstChild("Body")
	if model then
		local ok, kids = pcall(function()
			return model:GetChildren()
		end)
		if ok and type(kids) == "table" then
			for _, child in ipairs(kids) do
				consider(child)
			end
		end
	end
end
local function moveFlat()
	local camera = Workspace.CurrentCamera
	local cf = camera and camera.CFrame
	if not cf then
		return Vector3.zero
	end
	local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	local right = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
	if look.Magnitude < 0.05 then
		look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	end
	if look.Magnitude > 0.05 then
		look = look.Unit
	end
	if right.Magnitude > 0.05 then
		right = right.Unit
	end
	local move = Vector3.zero
	if keyDown(Enum.KeyCode.W) then
		move += look
	end
	if keyDown(Enum.KeyCode.S) then
		move -= look
	end
	if keyDown(Enum.KeyCode.A) then
		move -= right
	end
	if keyDown(Enum.KeyCode.D) then
		move += right
	end
	return move
end
local function updateSpeed()
	if not Config.speed or Config.fly then
		destroySpeed()
		return
	end
	local root = getRoot(getLocalBody())
	if not root then
		destroySpeed()
		return
	end
	destroySpeed()
	local move = moveFlat()
	local speed = math.clamp(Config.flySpeed or 60, 20, 160)
	if move.Magnitude > 0.05 then
		move = Vector3.new(move.X, 0, move.Z)
		if move.Magnitude > 0.05 then
			move = move.Unit * speed
			pcall(function()
				local current = root.AssemblyLinearVelocity
				root.AssemblyLinearVelocity = Vector3.new(move.X, current.Y, move.Z)
			end)
		end
	end
	local state = getLocalBody() and getLocalBody():FindFirstChild("State")
	for _, name in ipairs({ "SuperSprinting", "Sprinting" }) do
		local flag = state and state:FindFirstChild(name)
		if flag and flag:IsA("BoolValue") and flag.Value ~= true then
			pcall(function()
				flag.Value = true
			end)
		end
	end
end
local function updateExploits()
	pcall(updateFly)
	pcall(updateNoclip)
	pcall(updateSpeed)
end
local THROW_HINTS = {
	grenade = true,
	throwable = true,
	throwingknife = true,
	knife = true,
	molly = true,
	molotov = true,
	smoke = true,
	flash = true,
	flashbang = true,
	semtex = true,
	nade = true,
	c4 = true,
	claymore = true,
	tomahawk = true,
	throw = true,
}
local function looksThrown(name)
	local n = string.lower(tostring(name or ""))
	n = string.gsub(n, "%s+", "")
	if THROW_HINTS[n] then
		return true
	end
	return string.find(n, "grenade", 1, true) ~= nil or string.find(n, "throw", 1, true) ~= nil
end
local lastWeaponAt = 0
local lastWeaponKind = "none"
local function detectWeaponKind()
	local now = os.clock()
	if now - lastWeaponAt < 0.08 then
		return lastWeaponKind
	end
	lastWeaponAt = now
	local kind = "none"
	local model = getLocalBody()
	if not model then
		lastWeaponKind = "none"
		return lastWeaponKind
	end
	local display = model:FindFirstChild("ItemDisplay")
	if display then
		local ok, kids = pcall(function()
			return display:GetChildren()
		end)
		if ok and type(kids) == "table" then
			for _, child in ipairs(kids) do
				if looksThrown(child.Name) then
					lastWeaponKind = "throw"
					return lastWeaponKind
				end
				if child:FindFirstChild("AttachmentPayload") or child:FindFirstChild("PrimaryBodySkin") then
					kind = "gun"
				end
			end
		end
	end
	local ok, kids = pcall(function()
		return model:GetChildren()
	end)
	if ok and type(kids) == "table" then
		for _, child in ipairs(kids) do
			if looksThrown(child.Name) then
				lastWeaponKind = "throw"
				return lastWeaponKind
			end
			if child:FindFirstChild("AttachmentPayload") or child:FindFirstChild("PrimaryBodySkin") then
				kind = "gun"
			end
		end
	end
	lastWeaponKind = kind
	return lastWeaponKind
end
local function updateAimbot()
	if not Config.aimbot or not isAimbotHeld() then
		aimRemainderX, aimRemainderY = 0, 0
		return
	end
	aimAt(getClosestHead())
end
local function stopAntiAfk()
	if antiAfkConn then
		pcall(function()
			antiAfkConn:Disconnect()
		end)
		antiAfkConn = nil
	end
end
local function startAntiAfk()
	if antiAfkConn then
		return
	end
	antiAfkConn = LocalPlayer.Idled:Connect(function()
		pcall(function()
			local virtualUser = game:GetService("VirtualUser")
			virtualUser:CaptureController()
			virtualUser:ClickButton2(Vector2.new())
		end)
	end)
end
local function ensureWatermark()
	if instAlive(watermarkGui) and watermarkLabel then
		watermarkGui.Enabled = Config.watermark ~= false
		return
	end
	local ok, gui = pcall(Instance.new, "ScreenGui")
	if not ok or not gui then
		return
	end
	gui.Name = "__BB_WM"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100000
	gui.Enabled = Config.watermark ~= false
	pcall(function()
		local lab = Instance.new("TextLabel")
		lab.BackgroundTransparency = 1
		lab.Position = UDim2.fromOffset(12, 8)
		lab.Size = UDim2.fromOffset(220, 16)
		lab.Font = Enum.Font.GothamMedium
		lab.TextSize = 13
		lab.TextXAlignment = Enum.TextXAlignment.Left
		lab.TextColor3 = Color3.fromRGB(228, 228, 234)
		lab.TextStrokeTransparency = 0.6
		lab.Text = "Bad Business"
		lab.Parent = gui
		watermarkLabel = lab
	end)
	if parentWorld(gui) then
		watermarkGui = gui
	else
		pcall(function()
			gui:Destroy()
		end)
	end
end
local function updateWatermark(dt)
	if Config.watermark == false then
		if watermarkGui then
			watermarkGui.Enabled = false
		end
		return
	end
	ensureWatermark()
	if not watermarkLabel then
		return
	end
	wmFrames += 1
	wmElapsed += dt or 0
	if wmElapsed < 0.25 then
		return
	end
	local fps = math.floor(wmFrames / wmElapsed + 0.5)
	wmFrames = 0
	wmElapsed = 0
	watermarkLabel.Text = "Bad Business  " .. tostring(fps)
end
local function doHop()
	if hopping then
		return
	end
	hopping = true
	task.spawn(function()
		local ok, body = pcall(function()
			return game:HttpGet("https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Desc&limit=100")
		end)
		if ok and type(body) == "string" then
			local dok, data = pcall(function()
				return HttpService:JSONDecode(body)
			end)
			if dok and type(data) == "table" and type(data.data) == "table" then
				local candidates = {}
				for _, server in ipairs(data.data) do
					if server.id and server.id ~= game.JobId and type(server.playing) == "number" and server.playing < (server.maxPlayers or 0) then
						table.insert(candidates, server)
					end
				end
				if #candidates > 0 then
					local pick = candidates[math.random(1, #candidates)]
					pcall(function()
						TeleportService:TeleportToPlaceInstance(game.PlaceId, pick.id, LocalPlayer)
					end)
				end
			end
		end
		hopping = false
	end)
end
applyMisc = function()
	if Config.watermark ~= false then
		ensureWatermark()
	elseif watermarkGui then
		watermarkGui.Enabled = false
	end
	if Config.antiAfk then
		startAntiAfk()
	else
		stopAntiAfk()
	end
	if type(setfpscap) == "function" then
		pcall(setfpscap, Config.uncappedFps and 0 or 240)
	end
	if Config.persist ~= false then
		if persistArm then
			persistArm()
		end
	elseif persistStop then
		persistStop()
	end
end
runAction = function(action)
	if Config.persist ~= false and persistArm then
		persistArm()
	end
	if action == "rejoin" then
		pcall(function()
			TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
		end)
	elseif action == "hop" then
		doHop()
	end
end
local function tick()
	if not running then
		return
	end
	pcall(updateAimbot)
	local now = os.clock()
	local dt = lastWmAt > 0 and (now - lastWmAt) or 0
	lastWmAt = now
	pcall(updateWatermark, dt)
	pcall(updateFov)
	if now - lastTickAt >= (1 / TICK_HZ) then
		lastTickAt = now
		refreshMaps(false)
		local ok, err = pcall(updateEsp)
		if ok then
			drawOk = true
		elseif not drawErr then
			drawErr = tostring(err)
		end
	end
end
unload = function()
	if not running then
		return
	end
	running = false
	for _, conn in ipairs(connections) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	connections = {}
	for key in pairs(entries) do
		destroyEntry(key)
	end
	sweepOrphans()
	stopAntiAfk()
	if watermarkGui then
		pcall(function()
			watermarkGui:Destroy()
		end)
		watermarkGui = nil
		watermarkLabel = nil
	end
	if fovGui then
		pcall(function()
			fovGui:Destroy()
		end)
		fovGui = nil
	end
	if healthGui then
		pcall(function()
			healthGui:Destroy()
		end)
		healthGui = nil
	end
	fovRing = nil
	pcall(destroyFly)
	pcall(destroySpeed)
	pcall(restoreNoclip)
	pcall(function()
		RunService:UnbindFromRenderStep("BBBoxes")
	end)
	pcall(function()
		RunService:UnbindFromRenderStep("BBPostCam")
	end)
	if chamFolder then
		pcall(function()
			chamFolder:Destroy()
		end)
		chamFolder = nil
	end
	if chamWorld then
		pcall(function()
			chamWorld:Destroy()
		end)
		chamWorld = nil
	end
	if type(env) == "table" then
		env.LV_UNLOAD = nil
	end
end
local function boot()
	if type(env) == "table" then
		env.LV_UNLOAD = nil
	end
	if not LocalPlayer then
		return
	end
	bootAt = os.clock()
	Config.persist = false
	ts = loadTS()
	if not ts then
		return
	end
	sweepOrphans()
	refreshMaps(true)
	applyMisc()
	pcall(function()
		RunService:BindToRenderStep("BBPostCam", Enum.RenderPriority.Last.Value + 1, function()
			pcall(updateExploits)
			pcall(updateSkeletons)
			pcall(updateHealthBars)
		end)
	end)
	bind(RunService.Heartbeat, tick)
	bind(UserInputService.InputBegan, function(input)
		if input.KeyCode == Enum.KeyCode.End then
			unload()
			return
		end
		if Config.aimbotMouse and input.UserInputType == Config.aimbotMouse then
			aimBindDown = true
		elseif Config.aimbotKey and input.KeyCode == Config.aimbotKey then
			aimBindDown = true
		end
	end)
	bind(UserInputService.InputEnded, function(input)
		if Config.aimbotMouse and input.UserInputType == Config.aimbotMouse then
			aimBindDown = false
		elseif Config.aimbotKey and input.KeyCode == Config.aimbotKey then
			aimBindDown = false
		end
	end)
	if type(env) == "table" then
		env.LV_UNLOAD = unload
	end
	end
boot()
