do
	local env = (typeof(getgenv) == "function" and getgenv()) or _G
	if type(env) == "table" then
		env.LV_BOOTING = true
		if type(env.LV_UNLOAD) == "function" then
			pcall(env.LV_UNLOAD)
			env.LV_UNLOAD = nil
		end
	end
	pcall(function()
		if not game:IsLoaded() then
			game.Loaded:Wait()
		end
	end)
	pcall(function()
		local player = game:GetService("Players").LocalPlayer
		local playerGui = player and (player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui", 5))
		if not playerGui then
			return
		end
		for _, name in ipairs({
			"LV",
			"LV_ESP_Container",
			"LV_Watermark",
			"LV_Hud",
			"LV_ShotDelay",
			"LV_HopWait",
		}) do
			local inst = playerGui:FindFirstChild(name)
			if inst then
				inst:Destroy()
			end
		end
		local function wipeChams(parent)
			if not parent then
				return
			end
			local chams = parent:FindFirstChild("LV_Chams")
			if chams then
				chams:Destroy()
			end
		end
		wipeChams(workspace)
		wipeChams(workspace.CurrentCamera)
		wipeChams(playerGui)
	end)
	local uptime = 0
	pcall(function()
		uptime = workspace.DistributedGameTime
	end)
	if type(uptime) ~= "number" then
		uptime = 0
	end
	local waited = type(env) == "table" and env.LV_HOP_WAITED == true
	local hop = (type(env) == "table" and env.LV_HOP == true) or (not waited and uptime < 8)
	if type(env) == "table" then
		env.LV_HOP = nil
		env.LV_HOP_WAITED = nil
		env.LV_HOP_BOOT = hop == true
	end
	if waited then
		hop = false
	end
	local persistTimer = true
	pcall(function()
		if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" or not isfile("lv/config.json") then
			return
		end
		local data = game:GetService("HttpService"):JSONDecode(readfile("lv/config.json"))
		if type(data) == "table" and data.persistTimer == false then
			persistTimer = false
		end
	end)
	if hop then
		if type(env) == "table" then
			env.LV_BOOTING = true
		end
		if not persistTimer then
			if type(env) == "table" then
				env.LV_BOOTING = false
			end
		else
		task.spawn(function()
			local seconds = 15
			local skip = false
			local gui, label
			pcall(function()
				local player = game:GetService("Players").LocalPlayer
				local playerGui = player and player:WaitForChild("PlayerGui", 5)
				if not playerGui then
					return
				end
				gui = Instance.new("ScreenGui")
				gui.Name = "LV_HopWait"
				gui.ResetOnSpawn = false
				gui.IgnoreGuiInset = true
				gui.DisplayOrder = 1000000
				gui.Parent = playerGui
				label = Instance.new("TextLabel")
				label.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
				label.BackgroundTransparency = 0.2
				label.BorderSizePixel = 0
				label.AnchorPoint = Vector2.new(0.5, 0)
				label.Position = UDim2.new(0.5, 0, 0, 16)
				label.Size = UDim2.fromOffset(168, 32)
				label.Font = Enum.Font.GothamMedium
				label.TextSize = 15
				label.TextColor3 = Color3.fromRGB(236, 236, 240)
				label.Parent = gui
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 7)
				corner.Parent = label
			end)
			local conn
			pcall(function()
				conn = game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
					if processed then
						return
					end
					if input.KeyCode == Enum.KeyCode.Zero or input.KeyCode == Enum.KeyCode.KeypadZero then
						skip = true
						if type(env) == "table" then
							env.LV_FORCE_UNLOCK = true
							env.LV_BOOTING = false
						end
					end
				end)
			end)
			for left = seconds, 1, -1 do
				if skip then
					break
				end
				if label then
					label.Text = "LV  " .. left .. "s"
				end
				task.wait(1)
			end
			if conn then
				pcall(function()
					conn:Disconnect()
				end)
			end
			if gui then
				pcall(function()
					gui:Destroy()
				end)
			end
			if type(env) == "table" then
				env.LV_BOOTING = false
			end
		end)
		end
	else
		if type(env) == "table" then
			env.LV_BOOTING = false
		end
	end
end
local Loader = (function()
local Loader = {}
function Loader.readModule(path)
	if not readfile or not isfile or not isfile(path) then
		return nil, "file not found: " .. path
	end
	local source = readfile(path)
	local chunk, compileErr = loadstring(source, path)
	if not chunk then
		return nil, compileErr or ("failed to compile: " .. path)
	end
	local ok, result = pcall(chunk)
	if not ok then
		return nil, result
	end
	return result
end
function Loader.readSource(relativePath)
	local path = nil
	if readfile and isfile then
		for _, root in ipairs({ "", "lua/", "lv/", "scripts/" }) do
			local candidate = root .. relativePath
			if isfile(candidate) then
				path = candidate
				break
			end
		end
	end
	if not path then
		return nil, "file not found: " .. relativePath
	end
	return readfile(path), path
end
return Loader
end)()
local Filter = (function()
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Filter = {}
function Filter.normalize(name)
	if type(name) ~= "string" then
		return ""
	end
	return string.lower((name:gsub("^%s+", ""):gsub("%s+$", "")))
end
function Filter.hasName(list, name)
	local key = Filter.normalize(name)
	if key == "" or type(list) ~= "table" then
		return false
	end
	for _, entry in ipairs(list) do
		if Filter.normalize(entry) == key then
			return true
		end
	end
	return false
end
function Filter.sanitizeList(value)
	local result = {}
	local seen = {}
	if type(value) ~= "table" then
		return result
	end
	for _, name in ipairs(value) do
		if type(name) == "string" then
			local trimmed = name:gsub("^%s+", ""):gsub("%s+$", "")
			local key = string.lower(trimmed)
			if key ~= "" and not seen[key] then
				seen[key] = true
				table.insert(result, trimmed)
			end
		end
	end
	return result
end
function Filter.isExcluded(player, config)
	if not player or not config then
		return false
	end
	local list = config.excludedNames
	if type(list) ~= "table" then
		return false
	end
	return Filter.hasName(list, player.Name) or Filter.hasName(list, player.DisplayName)
end
function Filter.teamId(player)
	if not player then
		return nil
	end
	local ok, id = pcall(function()
		return player:GetAttribute("TeamID")
	end)
	if not ok or id == nil or id == "" then
		return nil
	end
	return id
end
function Filter.isTeammate(player)
	if not player or player == LocalPlayer then
		return false
	end
	local mine = Filter.teamId(LocalPlayer)
	local theirs = Filter.teamId(player)
	if mine == nil or theirs == nil then
		return false
	end
	return mine == theirs
end
function Filter.shouldSkip(player, config)
	if Filter.isExcluded(player, config) then
		return true
	end
	local now = os.clock()
	if not Filter.teamCache or now - (Filter.teamAt or 0) > 0.25 then
		Filter.teamCache = {}
		Filter.teamAt = now
	end
	local cached = Filter.teamCache[player]
	if cached ~= nil then
		return cached
	end
	local skip = Filter.isTeammate(player)
	Filter.teamCache[player] = skip
	return skip
end
function Filter.ownerOf(model)
	if typeof(model) ~= "Instance" then
		return nil
	end
	local owner = Players:GetPlayerFromCharacter(model)
	if owner then
		return owner
	end
	local byName = Players:FindFirstChild(model.Name)
	if byName and byName:IsA("Player") then
		return byName
	end
	return nil
end
function Filter.shouldSkipModel(model, config)
	local owner = Filter.ownerOf(model)
	if not owner or owner == LocalPlayer then
		return true
	end
	return Filter.shouldSkip(owner, config)
end
function Filter.add(list, name)
	if type(list) ~= "table" then
		return false
	end
	local trimmed = type(name) == "string" and name:gsub("^%s+", ""):gsub("%s+$", "") or ""
	if Filter.normalize(trimmed) == "" or Filter.hasName(list, trimmed) then
		return false
	end
	table.insert(list, trimmed)
	return true
end
function Filter.remove(list, name)
	if type(list) ~= "table" then
		return false
	end
	local key = Filter.normalize(name)
	for index = #list, 1, -1 do
		if Filter.normalize(list[index]) == key then
			table.remove(list, index)
			return true
		end
	end
	return false
end
return Filter
end)()
local Los = (function()
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer
local Los = {}
Los.params = nil
Los.folders = nil
Los.folderKey = ""
Los.resolveAt = 0
Los.listDirty = true
Los.mode = "include"
Los.excludeAt = 0
Los.excludeList = nil
Los.cache = setmetatable({}, { __mode = "k" })
Los.pointCache = setmetatable({}, { __mode = "k" })
Los.gridCache = {}
Los.pruneAt = 0
Los.ttl = 0.04
function Los.foldersValid()
	if type(Los.folders) ~= "table" or #Los.folders == 0 then
		return false
	end
	for _, inst in ipairs(Los.folders) do
		if typeof(inst) ~= "Instance" or inst.Parent == nil then
			return false
		end
	end
	return true
end
function Los.takeArena(arena)
	if typeof(arena) ~= "Instance" then
		return nil
	end
	local list = {}
	local barriers = arena:FindFirstChild("Barriers")
	local extra = arena:FindFirstChild("Extra")
	if barriers then
		table.insert(list, barriers)
	end
	if extra then
		table.insert(list, extra)
	end
	if #list == 0 then
		return nil
	end
	return list
end
function Los.searchArena()
	local fromDirect = Los.takeArena(workspace:FindFirstChild("Arena"))
	if fromDirect then
		return fromDirect
	end
	local queue = { { workspace, 0 } }
	local index = 1
	while index <= #queue do
		local node = queue[index][1]
		local depth = queue[index][2]
		index = index + 1
		if depth < 3 then
			local ok, children = pcall(function()
				return node:GetChildren()
			end)
			if ok and type(children) == "table" then
				for _, child in ipairs(children) do
					if not child:FindFirstChildOfClass("Humanoid") then
						if child:FindFirstChild("Barriers") and child:FindFirstChild("Extra") then
							local list = Los.takeArena(child)
							if list then
								return list
							end
						end
						table.insert(queue, { child, depth + 1 })
					end
				end
			end
		end
	end
	local list = {}
	local barriers = workspace:FindFirstChild("Barriers")
	local extra = workspace:FindFirstChild("Extra")
	if barriers then
		table.insert(list, barriers)
	end
	if extra then
		table.insert(list, extra)
	end
	return list
end
function Los.occluders()
	if Los.foldersValid() then
		return Los.folders
	end
	local now = os.clock()
	if type(Los.folders) == "table" and now - Los.resolveAt < 1 then
		return Los.folders
	end
	Los.resolveAt = now
	local found = Los.searchArena()
	local key = ""
	for _, inst in ipairs(found) do
		key = key .. inst:GetFullName() .. ";"
	end
	if key ~= Los.folderKey then
		Los.folderKey = key
		Los.listDirty = true
	end
	Los.folders = found
	return found
end
function Los.excludeSet()
	local now = os.clock()
	if Los.excludeList and now - Los.excludeAt < 0.5 then
		return Los.excludeList
	end
	local list = {}
	if LocalPlayer.Character then
		table.insert(list, LocalPlayer.Character)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	pcall(function()
		for _, entity in ipairs(CollectionService:GetTagged("Entity")) do
			table.insert(list, entity)
		end
	end)
	local hurt = workspace:FindFirstChild("HurtEffect")
	if hurt then
		table.insert(list, hurt)
	end
	local viewModels = workspace:FindFirstChild("ViewModels")
	if viewModels then
		table.insert(list, viewModels)
	end
	local chams = workspace:FindFirstChild("LV_Chams")
	if chams then
		table.insert(list, chams)
	end
	local cam = workspace.CurrentCamera
	local camChams = cam and cam:FindFirstChild("LV_Chams")
	if camChams then
		table.insert(list, camChams)
	end
	Los.excludeList = list
	Los.excludeAt = now
	Los.listDirty = true
	return list
end
function Los.ensureParams()
	if not Los.params then
		Los.params = RaycastParams.new()
		Los.params.IgnoreWater = true
		Los.listDirty = true
	end
	local folders = Los.occluders()
	if #folders > 0 then
		if Los.mode ~= "include" then
			Los.mode = "include"
			Los.listDirty = true
		end
		if Los.listDirty then
			Los.params.FilterType = Enum.RaycastFilterType.Include
			Los.params.FilterDescendantsInstances = folders
			Los.listDirty = false
		end
		return Los.params, "include"
	end
	local exclude = Los.excludeSet()
	if #exclude == 0 then
		return nil, "open"
	end
	if Los.mode ~= "exclude" then
		Los.mode = "exclude"
		Los.listDirty = true
	end
	if Los.listDirty then
		Los.params.FilterType = Enum.RaycastFilterType.Exclude
		Los.params.FilterDescendantsInstances = exclude
		Los.listDirty = false
	end
	return Los.params, "exclude"
end
function Los.blocked(origin, point)
	local delta = point - origin
	local dist = delta.Magnitude
	if dist < 0.5 then
		return false
	end
	local params, mode = Los.ensureParams()
	if not params or mode == "open" then
		return false
	end
	local ok, hit = pcall(function()
		return workspace:Raycast(origin, delta.Unit * (dist - 0.15), params)
	end)
	if not ok or typeof(hit) ~= "RaycastResult" or not hit.Instance then
		return false
	end
	if mode == "exclude" then
		local name = string.lower(hit.Instance.Name or "")
		if hit.Instance.CanCollide == false and not string.find(name, "hitbox", 1, true) then
			return false
		end
	end
	return true
end
function Los.quant(pos)
	return math.floor(pos.X * 100 + 0.5) .. "," .. math.floor(pos.Y * 100 + 0.5) .. "," .. math.floor(pos.Z * 100 + 0.5)
end
function Los.pruneGrid(now)
	if now - Los.pruneAt < 1.5 then
		return
	end
	Los.pruneAt = now
	for key, item in pairs(Los.gridCache) do
		if now - item.at > 0.12 then
			Los.gridCache[key] = nil
		end
	end
end
function Los.isClear(worldPos, keyInst)
	if typeof(worldPos) ~= "Vector3" then
		return false
	end
	local now = os.clock()
	Los.pruneGrid(now)
	local key = Los.quant(worldPos)
	local cached = Los.gridCache[key]
	if cached and now - cached.at <= Los.ttl then
		return cached.clear == true
	end
	if keyInst then
		local instCached = Los.pointCache[keyInst]
		if instCached and now - instCached.at <= Los.ttl and instCached.key == key then
			return instCached.clear == true
		end
	end
	local camera = workspace.CurrentCamera
	local clear = camera ~= nil and not Los.blocked(camera.CFrame.Position, worldPos)
	Los.gridCache[key] = { at = now, clear = clear }
	if keyInst then
		Los.pointCache[keyInst] = { at = now, clear = clear, key = key }
	end
	return clear
end
function Los.partVisible(part)
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") or not part.Parent then
		return false
	end
	local cf = part.CFrame
	local s = part.Size * 0.5
	if Los.isClear(cf.Position, part) then
		return true
	end
	if Los.isClear(cf:PointToWorldSpace(Vector3.new(0, s.Y, 0))) then
		return true
	end
	if Los.isClear(cf:PointToWorldSpace(Vector3.new(0, -s.Y, 0))) then
		return true
	end
	if Los.isClear(cf:PointToWorldSpace(Vector3.new(s.X, 0, 0))) then
		return true
	end
	if Los.isClear(cf:PointToWorldSpace(Vector3.new(-s.X, 0, 0))) then
		return true
	end
	return false
end
function Los.headAim(character)
	return character:FindFirstChild("PhysicalHitboxHead")
		or character:FindFirstChild("PhysicalHitboxBody")
		or character:FindFirstChild("HitboxBody")
		or character:FindFirstChild("HitboxHead")
		or character:FindFirstChild("Head")
		or character:FindFirstChild("HumanoidRootPart")
end
function Los.bodyAim(character)
	return character:FindFirstChild("HitboxBody")
		or character:FindFirstChild("PhysicalHitboxBody")
		or character:FindFirstChild("HitboxBodySmall")
		or character:FindFirstChild("HumanoidRootPart")
end
function Los.points(character)
	local points = {}
	local head = character:FindFirstChild("HitboxHead")
		or character:FindFirstChild("HitboxHeadSmall")
		or character:FindFirstChild("PhysicalHitboxHead")
	local body = character:FindFirstChild("HitboxBody")
		or character:FindFirstChild("HitboxBodySmall")
	if head then
		table.insert(points, {
			pos = head.Position,
			part = Los.headAim(character) or head,
		})
	end
	if body then
		local aim = Los.bodyAim(character) or body
		table.insert(points, { pos = body.Position, part = aim })
		table.insert(points, { pos = body.Position + Vector3.new(0, 1.2, 0), part = aim })
		local camera = workspace.CurrentCamera
		local right = camera and camera.CFrame.RightVector or Vector3.new(1, 0, 0)
		table.insert(points, { pos = body.Position + right * 1.2, part = aim })
		table.insert(points, { pos = body.Position - right * 1.2, part = aim })
	end
	if #points == 0 then
		local fallback = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
		if fallback then
			table.insert(points, { pos = fallback.Position, part = fallback })
		end
	end
	return points
end
function Los.visiblePart(character)
	if not character then
		return nil
	end
	local now = os.clock()
	local cached = Los.cache[character]
	if cached and now - cached.at <= Los.ttl then
		return cached.part
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local origin = camera.CFrame.Position
	local part = nil
	for _, item in ipairs(Los.points(character)) do
		if not Los.blocked(origin, item.pos) then
			part = item.part
			break
		end
	end
	Los.cache[character] = { at = now, part = part }
	return part
end
function Los.clear(character)
	if character then
		Los.cache[character] = nil
	end
end
return Los
end)()
local Aimbot = (function()
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Aimbot = {}
Aimbot.remainderX = 0
Aimbot.remainderY = 0
Aimbot.lastPart = nil
Aimbot.heldModel = nil
Aimbot.heldPart = nil
Aimbot.BONES = {
	{ id = "Head", label = "Head", names = { "PhysicalHitboxHead", "HitboxHead", "Head" } },
	{ id = "Neck", label = "Neck", names = { "Neck", "UpperTorso" } },
	{ id = "Chest", label = "Chest", names = { "HitboxBody", "UpperTorso", "Torso" } },
	{ id = "Pelvis", label = "Pelvis", names = { "LowerTorso", "HumanoidRootPart" } },
	{ id = "LeftArm", label = "Left Arm", names = { "LeftUpperArm", "Left Arm" } },
	{ id = "RightArm", label = "Right Arm", names = { "RightUpperArm", "Right Arm" } },
	{ id = "LeftHand", label = "Left Hand", names = { "LeftHand", "LeftLowerArm" } },
	{ id = "RightHand", label = "Right Hand", names = { "RightHand", "RightLowerArm" } },
	{ id = "LeftLeg", label = "Left Leg", names = { "LeftUpperLeg", "Left Leg" } },
	{ id = "RightLeg", label = "Right Leg", names = { "RightUpperLeg", "Right Leg" } },
	{ id = "LeftFoot", label = "Left Foot", names = { "LeftFoot", "LeftLowerLeg" } },
	{ id = "RightFoot", label = "Right Foot", names = { "RightFoot", "RightLowerLeg" } },
}
function Aimbot.getMouseMoveRel()
	if typeof(mousemoverel) == "function" then
		return mousemoverel
	end
	if syn and typeof(syn.mousemoverel) == "function" then
		return syn.mousemoverel
	end
	if fluxus and typeof(fluxus.mousemoverel) == "function" then
		return fluxus.mousemoverel
	end
	return nil
end
function Aimbot.getTargetPart(character)
	if not character then
		return nil
	end
	return character:FindFirstChild("PhysicalHitboxHead")
		or character:FindFirstChild("PhysicalHitboxBody")
		or character:FindFirstChild("HitboxBody")
		or character:FindFirstChild("HitboxHead")
		or character:FindFirstChild("Head")
		or character:FindFirstChild("HumanoidRootPart")
end
function Aimbot.boneById(id)
	for _, bone in ipairs(Aimbot.BONES) do
		if bone.id == id then
			return bone
		end
	end
	return nil
end
function Aimbot.sanitizeBones(list)
	local seen = {}
	local out = {}
	if type(list) == "table" then
		for _, id in ipairs(list) do
			if type(id) == "string" and Aimbot.boneById(id) and not seen[id] then
				seen[id] = true
				table.insert(out, id)
			end
		end
	end
	if #out == 0 then
		table.insert(out, "Head")
	end
	return out
end
function Aimbot.findBonePart(character, bone)
	if not character or not bone then
		return nil
	end
	for _, name in ipairs(bone.names) do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end
function Aimbot.collectBoneParts(character, config)
	local parts = {}
	local seen = {}
	for _, id in ipairs(Aimbot.sanitizeBones(config and config.aimBones)) do
		local part = Aimbot.findBonePart(character, Aimbot.boneById(id))
		if part and not seen[part] then
			seen[part] = true
			table.insert(parts, part)
		end
	end
	if #parts == 0 then
		local fallback = Aimbot.getTargetPart(character)
		if fallback then
			table.insert(parts, fallback)
		end
	end
	return parts
end
function Aimbot.pickAimPart(character, config)
	local parts = Aimbot.collectBoneParts(character, config)
	if #parts == 0 then
		return nil
	end
	local visible = {}
	for i = 1, #parts do
		local part = parts[i]
		if Los.isClear(part.Position, part) then
			table.insert(visible, part)
		end
	end
	local pool
	if #visible > 0 then
		pool = visible
	elseif config ~= nil and config.visibleOnly == false then
		pool = parts
	else
		return nil
	end
	if Aimbot.heldModel == character and Aimbot.heldPart and Aimbot.heldPart.Parent == character then
		for _, part in ipairs(pool) do
			if part == Aimbot.heldPart then
				return part
			end
		end
	end
	local pick = pool[1]
	if #pool > 1 then
		pick = pool[math.random(1, #pool)]
	end
	Aimbot.heldModel = character
	Aimbot.heldPart = pick
	return pick
end
function Aimbot.getHeadPart(character)
	if not character then
		return nil
	end
	return character:FindFirstChild("HitboxHead")
		or character:FindFirstChild("PhysicalHitboxHead")
		or character:FindFirstChild("Head")
		or character:FindFirstChild("HitboxBody")
		or character:FindFirstChild("PhysicalHitboxBody")
		or character:FindFirstChild("HumanoidRootPart")
end
local function eachCombatModel(callback)
	local seen = {}
	local function consider(model)
		if typeof(model) ~= "Instance" or seen[model] then
			return
		end
		seen[model] = true
		callback(model)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			consider(player.Character)
		end
	end
	pcall(function()
		for _, entity in ipairs(CollectionService:GetTagged("Entity")) do
			if entity ~= LocalPlayer.Character then
				consider(entity)
			end
		end
	end)
	local hurt = workspace:FindFirstChild("HurtEffect")
	if hurt then
		for _, child in ipairs(hurt:GetChildren()) do
			if child.ClassName ~= "Highlight" then
				consider(child)
			end
		end
	end
end
local function skipCombatModel(character, config)
	return Filter.shouldSkipModel(character, config)
end
function Aimbot.getClosestTarget(config, isRendered, fovOverride)
	local bestPart = nil
	local bestDistance = math.huge
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local center = camera.ViewportSize * 0.5
	local fov = fovOverride or math.max(config and config.fov or 150, 1)
	local maxDist = math.max(config and config.maxDistance or 400, 50)
	local camPos = camera.CFrame.Position
	eachCombatModel(function(character)
		if skipCombatModel(character, config) then
			return
		end
		if isRendered and not isRendered(character, config) then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local part = Aimbot.getTargetPart(character)
		if not part then
			return
		end
		if humanoid and humanoid.Health <= 0 then
			return
		end
		if (part.Position - camPos).Magnitude > maxDist then
			return
		end
		local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
		if onScreen and screenPos.Z > 0 then
			local dx = screenPos.X - center.X
			local dy = screenPos.Y - center.Y
			local dist = math.sqrt(dx * dx + dy * dy)
			if dist <= fov and dist < bestDistance then
				local aimPart = Aimbot.pickAimPart(character, config)
				if not aimPart then
					return
				end
				bestDistance = dist
				bestPart = aimPart
			end
		end
	end)
	return bestPart
end
function Aimbot.partVelocity(part)
	if not part then
		return Vector3.zero
	end
	local model = part.Parent
	local root = model and (model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso"))
	local source = root or part
	local vel
	pcall(function()
		vel = source.AssemblyLinearVelocity
	end)
	if typeof(vel) ~= "Vector3" then
		pcall(function()
			vel = source.Velocity
		end)
	end
	if typeof(vel) ~= "Vector3" then
		return Vector3.zero
	end
	local speed = vel.Magnitude
	if speed < 1.5 then
		return Vector3.zero
	end
	if speed > 90 then
		return vel.Unit * 90
	end
	return vel
end
function Aimbot.leadTime(origin, targetPos, muzzleSpeed, scale)
	local ping = 0
	pcall(function()
		ping = LocalPlayer:GetNetworkPing()
	end)
	if type(ping) ~= "number" or ping < 0 then
		ping = 0
	end
	if ping > 1 then
		ping = ping / 1000
	end
	ping = math.clamp(ping, 0, 0.25)
	local t = ping * 0.5
	if type(muzzleSpeed) == "number" and muzzleSpeed > 40 and muzzleSpeed < 2000 then
		local distance = (targetPos - origin).Magnitude
		if distance > 0 then
			t = t + distance / muzzleSpeed
		end
	end
	if type(scale) == "number" then
		t = t * scale
	end
	return math.clamp(t, 0, 0.45)
end
function Aimbot.predictedPosition(part, config, muzzleSpeed)
	local pos = part.Position
	if type(config) ~= "table" or not config.prediction then
		return pos
	end
	local vel = Aimbot.partVelocity(part)
	if vel.Magnitude < 1.5 then
		return pos
	end
	local camera = workspace.CurrentCamera
	local origin = camera and camera.CFrame.Position or pos
	local scale = math.clamp((tonumber(config.predictScale) or 80) / 100, 0.5, 1.5)
	local t = Aimbot.leadTime(origin, pos, muzzleSpeed, scale)
	if t <= 0 then
		return pos
	end
	local predicted = pos + vel * t
	t = Aimbot.leadTime(origin, predicted, muzzleSpeed, scale)
	return pos + vel * t
end
function Aimbot.aimAt(part, smoothness, mouseMoveRel, worldPos)
	if not mouseMoveRel then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local aimPos = worldPos or part.Position
	local screenPos, onScreen = camera:WorldToViewportPoint(aimPos)
	if not onScreen then
		return
	end
	local mousePos = UserInputService:GetMouseLocation()
	local deltaX = screenPos.X - mousePos.X
	local deltaY = screenPos.Y - mousePos.Y
	local distance = math.sqrt(deltaX * deltaX + deltaY * deltaY)
	if distance < 3 then
		return
	end
	local factor = 1 / math.max(smoothness, 0.01)
	factor = math.clamp(factor, 0.01, 1)
	Aimbot.remainderX = Aimbot.remainderX + deltaX * factor
	Aimbot.remainderY = Aimbot.remainderY + deltaY * factor
	local moveX = math.round(Aimbot.remainderX)
	local moveY = math.round(Aimbot.remainderY)
	if moveX ~= 0 or moveY ~= 0 then
		mouseMoveRel(moveX, moveY)
		Aimbot.remainderX = Aimbot.remainderX - moveX
		Aimbot.remainderY = Aimbot.remainderY - moveY
	end
end
function Aimbot.resetSmoothing()
	Aimbot.remainderX = 0
	Aimbot.remainderY = 0
	Aimbot.lastPart = nil
	Aimbot.heldModel = nil
	Aimbot.heldPart = nil
end
return Aimbot
end)()
local Weapon = (function()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Weapon = {}
Weapon.controller = false
Weapon.itemLibrary = false
Weapon.aimSpeedSaved = nil
Weapon.aimFlagSaved = nil
function Weapon.getController()
	if Weapon.controller ~= false then
		return Weapon.controller
	end
	local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
	local controllers = scripts and scripts:FindFirstChild("Controllers")
	local module = controllers and controllers:FindFirstChild("FighterController")
	if not module then
		return nil
	end
	local ok, result = pcall(require, module)
	if ok and result then
		Weapon.controller = result
		return result
	end
	Weapon.controller = nil
	return nil
end
function Weapon.getItemLibrary()
	if Weapon.itemLibrary ~= false then
		return Weapon.itemLibrary
	end
	local modules = ReplicatedStorage:FindFirstChild("Modules")
	local module = modules and modules:FindFirstChild("ItemLibrary")
	if not module then
		Weapon.itemLibrary = nil
		return nil
	end
	local ok, result = pcall(require, module)
	if ok and result then
		Weapon.itemLibrary = result
		return result
	end
	Weapon.itemLibrary = nil
	return nil
end
function Weapon.isHolding()
	local character = LocalPlayer.Character
	if character and character:FindFirstChildOfClass("Tool") then
		return true
	end
	local controller = Weapon.getController()
	if not controller or type(controller.GetFighter) ~= "function" then
		return false
	end
	local ok, fighter = pcall(controller.GetFighter, controller, LocalPlayer)
	if not ok or type(fighter) ~= "table" or type(fighter.Items) ~= "table" then
		return false
	end
	for _, item in pairs(fighter.Items) do
		if item and item.IsEquipped then
			return true
		end
	end
	return false
end
Weapon.FIELD_NAMES = {
	"ObjectID",
	"Name",
	"Ammo",
	"CurrentAmmo",
	"MaxAmmo",
	"ClipSize",
	"Magazine",
	"MagazineAmmo",
	"AmmoCount",
	"AmmoInClip",
	"ClipAmmo",
	"Clip",
	"Rounds",
	"ReserveAmmo",
	"AmmoReserve",
	"StoredAmmo",
	"Reloading",
	"IsReloading",
		"ReloadTime",
		"ReloadSpeed",
		"ReloadDuration",
		"TimeToReload",
		"CanReload",
	"CanFire",
	"FireRate",
}
local function itemGet(item, key)
	if not item then
		return nil
	end
	local ok, value = pcall(function()
		if item.Get then
			return item:Get(key)
		end
		return item[key]
	end)
	if ok then
		return value
	end
	return nil
end
local function toEnumKey(item, name)
	if not item or type(item.ToEnum) ~= "function" then
		return nil
	end
	local ok, key = pcall(item.ToEnum, item, name)
	if ok then
		return key
	end
	return nil
end
function Weapon.itemGet(item, key)
	return itemGet(item, key)
end
function Weapon.toEnumKey(item, name)
	return toEnumKey(item, name)
end
function Weapon.findItem(objectID)
	local controller = Weapon.getController()
	if not controller or type(controller.GetFighter) ~= "function" then
		return nil
	end
	local ok, fighter = pcall(controller.GetFighter, controller, LocalPlayer)
	if not ok or type(fighter) ~= "table" or type(fighter.Items) ~= "table" then
		return nil
	end
	for _, item in pairs(fighter.Items) do
		if item and (objectID == nil or itemGet(item, "ObjectID") == objectID) then
			if objectID ~= nil or item.IsEquipped then
				return item
			end
		end
	end
	return nil
end
function Weapon.eachItem(callback)
	local controller = Weapon.getController()
	if not controller or type(controller.GetFighter) ~= "function" then
		return
	end
	local ok, fighter = pcall(controller.GetFighter, controller, LocalPlayer)
	if not ok or type(fighter) ~= "table" or type(fighter.Items) ~= "table" then
		return
	end
	for _, item in pairs(fighter.Items) do
		if item then
			callback(item)
		end
	end
end
function Weapon.readAmmo(item)
	local ammo = tonumber(itemGet(item, "Ammo"))
	if ammo == nil and type(item.Data) == "table" then
		ammo = tonumber(item.Data.Ammo)
	end
	return ammo
end
function Weapon.itemIndex(item)
	if not item then
		return nil
	end
	local index = tonumber(itemGet(item, "ItemIndex"))
	if index then
		return index
	end
	if type(item.Data) == "table" then
		return tonumber(item.Data.ItemIndex)
	end
	return nil
end
function Weapon.isMelee(item)
	if not item then
		return false
	end
	local stats = Weapon.findWeaponStats(item.Name)
	if stats and stats.Type == "Melee" then
		return true
	end
	local name = string.lower(tostring(item.Name or ""))
	return string.find(name, "fist", 1, true)
		or string.find(name, "knife", 1, true)
		or string.find(name, "scythe", 1, true)
		or string.find(name, "dagger", 1, true)
		or string.find(name, "sword", 1, true)
		or string.find(name, "axe", 1, true)
		or string.find(name, "katana", 1, true)
end
function Weapon.isGunEmpty(item)
	if not item or Weapon.isMelee(item) then
		return false
	end
	local ammo = Weapon.readAmmo(item)
	return ammo ~= nil and ammo <= 0
end
function Weapon.equippedItem()
	if Weapon._equipItem and (
		Weapon._equipItem.IsEquipped
		or os.clock() - (Weapon._equipAt or 0) < 0.45
	) then
		return Weapon._equipItem
	end
	local ready, empty
	Weapon.eachItem(function(item)
		if item and item.IsEquipped then
			if Weapon.isMelee(item) or not Weapon.isGunEmpty(item) then
				ready = ready or item
			else
				empty = empty or item
			end
		end
	end)
	return ready or empty
end
function Weapon.readReserve(item)
	if not item then
		return nil
	end
	local reserve = tonumber(itemGet(item, "AmmoReserve"))
	if reserve == nil and type(item.Data) == "table" then
		reserve = tonumber(item.Data.AmmoReserve)
	end
	return reserve
end
function Weapon.hasReserve(item)
	if not item or Weapon.isMelee(item) then
		return false
	end
	local reserve = Weapon.readReserve(item)
	if reserve ~= nil then
		return reserve > 0
	end
	local dryAt = Weapon.dryAt and Weapon.dryAt[item]
	if dryAt and os.clock() - dryAt < 4 then
		return false
	end
	return true
end
function Weapon.equipCooldown(item)
	local stats = item and Weapon.findWeaponStats(item.Name)
	local value = stats and tonumber(stats.EquipCooldown)
	if value and value > 0 then
		return value
	end
	return 0.35
end
function Weapon.reloadDuration(item)
	local stats = item and Weapon.findWeaponStats(item.Name)
	if type(stats) ~= "table" then
		return 2.2
	end
	local ammo = Weapon.readAmmo(item)
	if ammo ~= nil and ammo <= 0 then
		local empty = tonumber(stats.EmptyReloadLength)
		if empty and empty > 0 then
			return empty + 0.3
		end
	end
	local length = tonumber(stats.ReloadLength)
	if length and length > 0 then
		return length + 0.3
	end
	return 2.2
end
function Weapon.clearReload(item)
	if item and Weapon.reloadItem and Weapon.reloadItem ~= item then
		return
	end
	Weapon.reloadUntil = 0
	Weapon.reloadItem = nil
end
function Weapon.isReloading(item)
	item = item or Weapon.equippedItem()
	local reloading = Weapon.reloadItem
	if not reloading then
		return false
	end
	if item and reloading ~= item then
		return false
	end
	if not item and reloading and not reloading.IsEquipped then
		return false
	end
	if not Weapon.isGunEmpty(reloading) then
		Weapon.clearReload()
		if Weapon.dryAt then
			Weapon.dryAt[reloading] = nil
		end
		return false
	end
	if os.clock() < (Weapon.reloadUntil or 0) then
		return true
	end
	if (Weapon.reloadUntil or 0) > 0 then
		Weapon.dryAt = Weapon.dryAt or {}
		Weapon.dryAt[reloading] = os.clock()
		Weapon.clearReload()
	end
	return false
end
function Weapon.busyForCombat()
	if Weapon.isReloading() then
		return true
	end
	local item = Weapon.equippedItem()
	if not item or Weapon.isMelee(item) then
		return false
	end
	return Weapon.isGunEmpty(item)
end
function Weapon.requestReload(item)
	item = item or Weapon.equippedItem()
	if not item or Weapon.isMelee(item) then
		return false
	end
	if not Weapon.isGunEmpty(item) then
		return false
	end
	if not Weapon.hasReserve(item) then
		return false
	end
	local now = os.clock()
	if now - (Weapon.lastReloadAt or 0) < 0.55 then
		return false
	end
	local delay = 0
	if not item.IsEquipped then
		Weapon.equipItem(item)
		delay = Weapon.equipCooldown(item)
	end
	Weapon.lastReloadAt = now
	Weapon.reloadItem = item
	Weapon.reloadUntil = now + delay + Weapon.reloadDuration(item)
	local function pressReload()
		if Weapon.reloadItem ~= item then
			return
		end
		if not item.IsEquipped then
			return
		end
		if not Weapon.isGunEmpty(item) then
			Weapon.reloadUntil = 0
			return
		end
		pcall(function()
			if item.Reload then
				item:Reload()
			end
		end)
		pcall(function()
			if item.StartReload then
				item:StartReload()
			end
		end)
		pcall(function()
			local vim = game:GetService("VirtualInputManager")
			vim:SendKeyEvent(true, Enum.KeyCode.R, false, game)
			vim:SendKeyEvent(false, Enum.KeyCode.R, false, game)
		end)
	end
	if delay > 0 then
		task.delay(delay, pressReload)
	else
		pressReload()
	end
	return true
end
function Weapon.muzzleSpeed(item)
	item = item or Weapon.equippedItem()
	local now = os.clock()
	if item and Weapon.muzzleItem == item and Weapon.muzzleAt and now - Weapon.muzzleAt < 0.12 then
		return Weapon.muzzleCached
	end
	Weapon.muzzleItem = item
	Weapon.muzzleAt = now
	if not item or Weapon.isMelee(item) then
		Weapon.muzzleCached = nil
		return nil
	end
	local stats = Weapon.findWeaponStats(item.Name)
	local speed = stats and tonumber(stats.ProjectileSpeed)
	if (not speed or speed <= 40) and type(item.Data) == "table" then
		speed = tonumber(item.Data.ProjectileSpeed)
	end
	if speed and speed > 40 then
		Weapon.muzzleCached = speed
		return speed
	end
	Weapon.muzzleCached = nil
	return nil
end
function Weapon.shootCooldown(item)
	if not item or Weapon.isMelee(item) then
		return nil
	end
	local stats = Weapon.findWeaponStats(item.Name)
	local shoot = stats and tonumber(stats.ShootCooldown)
	if shoot and shoot > 0 then
		return shoot
	end
	local burst = stats and tonumber(stats.BurstCooldown)
	if burst and burst > 0 then
		return burst
	end
	if type(item.Data) == "table" then
		local data = tonumber(item.Data.ShootCooldown)
		if data and data > 0 then
			return data
		end
	end
	return nil
end
function Weapon.stopShotWatch()
	if Weapon.shotConn then
		pcall(function()
			Weapon.shotConn:Disconnect()
		end)
	end
	Weapon.shotConn = nil
	Weapon.shotWatchItem = nil
end
function Weapon.noteShot(item)
	local cooldown = Weapon.shootCooldown(item)
	if not cooldown or cooldown <= 0 then
		return
	end
	Weapon.shotUntil = os.clock() + cooldown
	local aiming = false
	pcall(function()
		aiming = item and item.Data and item.Data.IsAiming == true
	end)
	if aiming or Weapon.wantsAds() then
		Weapon.keepAdsUntil = os.clock() + math.max(cooldown, 0.35)
		task.delay(0.04, function()
			Weapon.holdAds(item)
			if not Weapon.isAiming(item) then
				Weapon.sendAds(item)
				Weapon.holdAds(item)
			end
		end)
	end
end
function Weapon.watchShotItem(item)
	if item == Weapon.shotWatchItem then
		return
	end
	Weapon.stopShotWatch()
	Weapon.shotWatchItem = item
	Weapon.shotAmmo = item and Weapon.readAmmo(item) or nil
	if not item then
		return
	end
	local shot = item.Shot
	if shot == nil then
		return
	end
	local ok, conn = pcall(function()
		return shot:Connect(function()
			Weapon.noteShot(item)
		end)
	end)
	if ok then
		Weapon.shotConn = conn
	end
end
function Weapon.tickShotDelay()
	local item = Weapon.equippedItem()
	Weapon.watchShotItem(item)
	if item then
		local ammo = Weapon.readAmmo(item)
		if ammo ~= nil and Weapon.shotAmmo ~= nil and ammo < Weapon.shotAmmo then
			Weapon.noteShot(item)
		end
		Weapon.shotAmmo = ammo
	end
	local left = (Weapon.shotUntil or 0) - os.clock()
	if left < 0 then
		return 0
	end
	local cooldown = item and Weapon.shootCooldown(item)
	if not cooldown or cooldown < 0.25 then
		return 0
	end
	return left, cooldown
end
Weapon.enemyReload = {}
function Weapon.reloadLengthForItem(item)
	if not item or Weapon.isMelee(item) then
		return nil
	end
	local stats = Weapon.findWeaponStats(item.Name)
	if type(stats) ~= "table" then
		return nil
	end
	local ammo = Weapon.readAmmo(item)
	if ammo ~= nil and ammo <= 0 then
		local empty = tonumber(stats.EmptyReloadLength)
		if empty and empty > 0 then
			return empty
		end
	end
	local length = tonumber(stats.ReloadLength)
	if length and length > 0 then
		return length
	end
	return nil
end
function Weapon.itemReloading(item)
	if not item then
		return false
	end
	if Weapon.isReloading(item) then
		return true
	end
	if itemGet(item, "Reloading") == true or itemGet(item, "IsReloading") == true then
		return true
	end
	if type(item.Data) == "table" then
		if item.Data.Reloading == true or item.Data.IsReloading == true then
			return true
		end
	end
	local exp
	pcall(function()
		exp = item._reload_cancel_expiration
	end)
	if type(exp) == "number" and exp > 1 then
		local now = exp > 1e9 and tick() or os.clock()
		if exp > now then
			return true
		end
	end
	return false
end
function Weapon.playerEquippedName(player)
	if not player then
		return nil
	end
	local controller = Weapon.getController()
	if not controller or type(controller.GetFighter) ~= "function" then
		return nil
	end
	local ok, fighter = pcall(controller.GetFighter, controller, player)
	if not ok or type(fighter) ~= "table" then
		return nil
	end
	local function itemName(item)
		if not item then
			return nil
		end
		local name = item.Name or itemGet(item, "Name")
		if type(item.Data) == "table" then
			local typed = item.Data.Weapon or item.Data.ItemName
			if type(typed) == "string" and typed ~= "" then
				name = typed
			end
		end
		return Weapon.englishDisplayName(name)
	end
	if type(fighter.Equipped) == "string" and fighter.Equipped ~= "" then
		return Weapon.englishDisplayName(fighter.Equipped)
	end
	local equipped = fighter.EquippedItem or fighter.CurrentItem or fighter.HeldItem
	if type(equipped) == "table" then
		local fromSlot = itemName(equipped)
		if fromSlot then
			return fromSlot
		end
	end
	if type(fighter.Items) == "table" then
		for _, item in pairs(fighter.Items) do
			if item and item.IsEquipped then
				local name = itemName(item)
				if name then
					return name
				end
			end
		end
	end
	return nil
end
function Weapon.playerReloadRemain(player)
	if not player or player == LocalPlayer then
		Weapon.enemyReload[player] = nil
		return nil
	end
	local now = os.clock()
	local item
	local fromExp
	local controller = Weapon.getController()
	if controller and type(controller.GetFighter) == "function" then
		local ok, fighter = pcall(controller.GetFighter, controller, player)
		if ok and type(fighter) == "table" and type(fighter.Items) == "table" then
			for _, candidate in pairs(fighter.Items) do
				if candidate and Weapon.itemReloading(candidate) then
					item = candidate
					local exp
					pcall(function()
						exp = candidate._reload_cancel_expiration
					end)
					if type(exp) == "number" and exp > 1 then
						local clock = exp > 1e9 and tick() or os.clock()
						if exp > clock then
							fromExp = exp - clock
						end
					end
					break
				end
			end
		end
	end
	local animLeft
	local animLen
	if not item then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local animator = humanoid:FindFirstChildOfClass("Animator")
			local tracks
			if animator then
				local ok, result = pcall(function()
					return animator:GetPlayingAnimationTracks()
				end)
				if ok then
					tracks = result
				end
			end
			if type(tracks) ~= "table" then
				local ok, result = pcall(function()
					return humanoid:GetPlayingAnimationTracks()
				end)
				if ok then
					tracks = result
				end
			end
			if type(tracks) == "table" then
				for _, track in ipairs(tracks) do
					local name = string.lower(tostring(track.Name or ""))
					if string.find(name, "reload", 1, true) then
						local length = tonumber(track.Length) or tonumber(track.TimeLength)
						local pos = tonumber(track.TimePosition)
						if length and length > 0 then
							animLen = length
							if pos and pos >= 0 then
								animLeft = math.max(0, length - pos)
							end
						end
						break
					end
				end
			end
		end
	end
	if not item and not animLen and not fromExp then
		Weapon.enemyReload[player] = nil
		return nil
	end
	local duration = (item and Weapon.reloadLengthForItem(item)) or animLen or 2.2
	if duration <= 0 then
		duration = 2.2
	end
	local state = Weapon.enemyReload[player]
	if type(state) ~= "table" or state.item ~= item then
		state = {
			item = item,
			start = now,
			duration = duration,
		}
		Weapon.enemyReload[player] = state
	end
	local left
	if fromExp then
		left = fromExp
		if fromExp > state.duration then
			state.duration = fromExp
		end
	elseif animLeft then
		left = animLeft
		state.duration = animLen or state.duration
	else
		left = state.duration - (now - state.start)
	end
	if left <= 0.04 then
		Weapon.enemyReload[player] = nil
		return nil
	end
	return math.clamp(left / state.duration, 0.04, 1)
end
function Weapon.loadout()
	local slots = {
		primary = nil,
		secondary = nil,
		melee = nil,
	}
	Weapon.eachItem(function(item)
		local index = Weapon.itemIndex(item)
		if index == 1 then
			slots.primary = item
		elseif index == 2 then
			slots.secondary = item
		elseif index == 3 then
			slots.melee = item
		elseif Weapon.isMelee(item) and not slots.melee then
			slots.melee = item
		end
	end)
	return slots
end
function Weapon.equipItem(item)
	if not item then
		return false
	end
	if item.IsEquipped then
		return true
	end
	local now = os.clock()
	if Weapon._equipItem == item and now - (Weapon._equipAt or 0) < 0.2 then
		return item.IsEquipped == true
	end
	Weapon._equipAt = now
	Weapon._equipItem = item
	pcall(function()
		if item.Equip then
			item:Equip()
		end
	end)
	local controller = Weapon.getController()
	local fighter
	if controller and type(controller.GetFighter) == "function" then
		local ok, result = pcall(controller.GetFighter, controller, LocalPlayer)
		if ok then
			fighter = result
		end
	end
	pcall(function()
		if fighter and fighter.EquipItem then
			fighter:EquipItem(item)
		elseif fighter and fighter.Equip then
			fighter:Equip(item)
		end
	end)
	local objectID = itemGet(item, "ObjectID")
	pcall(function()
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local replication = remotes and remotes:FindFirstChild("Replication")
		local folder = replication and replication:FindFirstChild("Fighter")
		local remote = folder and folder:FindFirstChild("EquipItemFeedback")
		if remote and objectID ~= nil then
			remote:InvokeServer(objectID)
		end
	end)
	local index = Weapon.itemIndex(item)
	if index == 1 or index == 2 or index == 3 then
		local keys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }
		pcall(function()
			local vim = game:GetService("VirtualInputManager")
			vim:SendKeyEvent(true, keys[index], false, game)
			vim:SendKeyEvent(false, keys[index], false, game)
		end)
	end
	return item.IsEquipped == true or Weapon.isHolding()
end
function Weapon.findWeaponStats(name)
	if type(name) ~= "string" or name == "" then
		return nil
	end
	local lib = Weapon.getItemLibrary()
	if type(lib) ~= "table" then
		return nil
	end
	local roots = { lib }
	for _, key in ipairs({ "Items", "Weapons", "Info", "Data", "Library" }) do
		if type(lib[key]) == "table" then
			table.insert(roots, lib[key])
		end
	end
	for _, root in ipairs(roots) do
		local entry = root[name]
		if type(entry) == "table" then
			return entry
		end
	end
	return nil
end
function Weapon.englishDisplayName(name)
	if type(name) ~= "string" then
		return nil
	end
	name = string.gsub(name, "^%s+", "")
	name = string.gsub(name, "%s+$", "")
	if name == "" then
		return nil
	end
	if Weapon.findWeaponStats(name) then
		return name
	end
	local lib = Weapon.getItemLibrary()
	if type(lib) == "table" then
		local roots = { lib }
		for _, key in ipairs({ "Items", "Weapons", "Info", "Data", "Library" }) do
			if type(lib[key]) == "table" then
				table.insert(roots, lib[key])
			end
		end
		local lower = string.lower(name)
		for _, root in ipairs(roots) do
			for key, entry in pairs(root) do
				if type(key) == "string" and type(entry) == "table" then
					if string.lower(key) == lower then
						return key
					end
					local aliases = { entry.Name, entry.DisplayName, entry.Id, entry.ID }
					for _, alias in ipairs(aliases) do
						if type(alias) == "string" and string.lower(alias) == lower then
							return key
						end
					end
				end
			end
		end
	end
	if string.match(name, "^[%w %-%+/']+$") then
		return name
	end
	return name
end
function Weapon.restoreReloadStats()
	local lib = Weapon.getItemLibrary()
	local items = lib and lib.Items
	if type(items) ~= "table" then
		return 0
	end
	local fixed = 0
	for name, stats in pairs(items) do
		if type(stats) == "table" then
			local length = tonumber(stats.ReloadLength)
			if length and length > 0 and length < 0.2 then
				local restored = 1.5
				if tonumber(stats.MaxAmmo) == 20 then
					restored = 1.56
				elseif tonumber(stats.MaxAmmo) == 13 then
					restored = 1.4
				end
				stats.ReloadLength = restored
				fixed = fixed + 1
			end
			local empty = tonumber(stats.EmptyReloadLength)
			if empty and empty > 0 and empty < 0.2 then
				stats.EmptyReloadLength = 1.6
				fixed = fixed + 1
			end
		end
	end
	Weapon.eachItem(function(item)
		pcall(function()
			if type(item.Data) == "table" then
				if tonumber(item.Data.ReloadDuration) == 0.05 then
					item.Data.ReloadDuration = nil
				end
				if tonumber(item.Data.TimeToReload) == 0.05 then
					item.Data.TimeToReload = nil
				end
				if tonumber(item.Data.ReloadTime) == 0.05 then
					item.Data.ReloadTime = nil
				end
			end
		end)
	end)
	return fixed
end
function Weapon.eachWeaponStats(callback)
	local lib = Weapon.getItemLibrary()
	local items = lib and lib.Items
	if type(items) ~= "table" then
		return
	end
	for name, stats in pairs(items) do
		if type(stats) == "table" then
			callback(name, stats)
		end
	end
end
function Weapon.isUnscopeKey(key)
	if type(key) ~= "string" then
		return false
	end
	local name = string.lower(key)
	if string.find(name, "unscope", 1, true) or string.find(name, "unaime", 1, true) then
		return true
	end
	if string.find(name, "hipfireafter", 1, true) or string.find(name, "hipfireonshot", 1, true) then
		return true
	end
	if string.find(name, "aim", 1, true)
		and (string.find(name, "shoot", 1, true) or string.find(name, "shot", 1, true) or string.find(name, "fire", 1, true))
		and (string.find(name, "cancel", 1, true) or string.find(name, "reset", 1, true) or string.find(name, "stop", 1, true))
	then
		return true
	end
	return false
end
function Weapon.wantsAds()
	local ok, down = pcall(function()
		return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
	end)
	if ok and down then
		return true
	end
	return type(Weapon.keepAdsUntil) == "number" and os.clock() < Weapon.keepAdsUntil
end
function Weapon.isAiming(item)
	item = item or Weapon.equippedItem()
	local aiming = false
	pcall(function()
		aiming = item and item.Data and item.Data.IsAiming == true
	end)
	return aiming
end
function Weapon.holdAds(item)
	item = item or Weapon.equippedItem()
	if not item or type(item.Data) ~= "table" then
		return
	end
	pcall(function()
		item.Data.IsAiming = true
		if tonumber(item.Data.AimSpeed) and item.Data.AimSpeed < 50 then
			item.Data.AimSpeed = 80
		end
		local stats = Weapon.findWeaponStats(item.Name)
		local offset = stats and tonumber(stats.AimFOVOffset)
		if offset then
			item.Data.FOVOffset = offset
		end
	end)
end
function Weapon.sendAds(item)
	item = item or Weapon.equippedItem()
	if not item then
		return
	end
	local objectID = itemGet(item, "ObjectID")
	if objectID == nil then
		return
	end
	pcall(function()
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local replication = remotes and remotes:FindFirstChild("Replication")
		local folder = replication and replication:FindFirstChild("Fighter")
		local remote = folder and folder:FindFirstChild("UseItem")
		if remote then
			remote:FireServer(objectID, "\x1C", {}, nil)
		end
	end)
end
function Weapon.applyInstantAds()
	if type(Weapon.aimSpeedSaved) ~= "table" then
		Weapon.aimSpeedSaved = {}
	end
	if type(Weapon.aimFlagSaved) ~= "table" then
		Weapon.aimFlagSaved = {}
	end
	local now = os.clock()
	if Weapon.adsStatsAt and now - Weapon.adsStatsAt < 0.15 then
		local item = Weapon.equippedItem()
		if item and type(item.Data) == "table" and (Weapon.wantsAds() or Weapon.isAiming(item)) then
			Weapon.holdAds(item)
		end
		return
	end
	Weapon.adsStatsAt = now
	Weapon.eachWeaponStats(function(name, stats)
		local current = tonumber(stats.AimSpeed)
		if current ~= nil then
			if Weapon.aimSpeedSaved[name] == nil then
				Weapon.aimSpeedSaved[name] = current
			end
			if current < 50 then
				stats.AimSpeed = 80
			end
		end
		local savedFlags = Weapon.aimFlagSaved[name]
		if type(savedFlags) ~= "table" then
			savedFlags = {}
			Weapon.aimFlagSaved[name] = savedFlags
		end
		for key, value in pairs(stats) do
			if value == true and Weapon.isUnscopeKey(key) and savedFlags[key] == nil then
				savedFlags[key] = true
				stats[key] = false
			end
		end
	end)
	local item = Weapon.equippedItem()
	if not item or type(item.Data) ~= "table" then
		return
	end
	pcall(function()
		if tonumber(item.Data.AimSpeed) and item.Data.AimSpeed < 50 then
			item.Data.AimSpeed = 80
		end
	end)
	if Weapon.wantsAds() or Weapon.isAiming(item) then
		Weapon.holdAds(item)
	end
end
function Weapon.restoreAimSpeed()
	if type(Weapon.aimSpeedSaved) == "table" then
		Weapon.eachWeaponStats(function(name, stats)
			local saved = tonumber(Weapon.aimSpeedSaved[name])
			if saved ~= nil then
				stats.AimSpeed = saved
			end
		end)
	end
	if type(Weapon.aimFlagSaved) == "table" then
		Weapon.eachWeaponStats(function(name, stats)
			local savedFlags = Weapon.aimFlagSaved[name]
			if type(savedFlags) ~= "table" then
				return
			end
			for key, value in pairs(savedFlags) do
				stats[key] = value
			end
		end)
	end
	Weapon.aimSpeedSaved = nil
	Weapon.aimFlagSaved = nil
	Weapon.keepAdsUntil = 0
end
function Weapon.ensureEquipped()
	if Weapon.isHolding() then
		return true
	end
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	if humanoid and backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				local ok = pcall(function()
					humanoid:EquipTool(tool)
				end)
				if ok then
					return true
				end
			end
		end
	end
	local controller = Weapon.getController()
	local fighter = nil
	if controller and type(controller.GetFighter) == "function" then
		local ok, result = pcall(controller.GetFighter, controller, LocalPlayer)
		if ok then
			fighter = result
		end
	end
	local best, bestScore = nil, -1
	if type(fighter) == "table" and type(fighter.Items) == "table" then
		for _, item in pairs(fighter.Items) do
			if item then
				local name = string.lower(tostring(item.Name or ""))
				local score = 1
				if string.find(name, "knife", 1, true) or string.find(name, "dagger", 1, true) or string.find(name, "sword", 1, true) then
					score = 50
				elseif string.find(name, "rifle", 1, true) or string.find(name, "pistol", 1, true) or string.find(name, "smg", 1, true) then
					score = 40
				elseif string.find(name, "shot", 1, true) or string.find(name, "sniper", 1, true) or string.find(name, "gun", 1, true) then
					score = 30
				end
				if item.IsEquipped then
					return true
				end
				if score > bestScore then
					bestScore = score
					best = item
				end
			end
		end
	end
	if best then
		pcall(function()
			best:Equip()
		end)
		pcall(function()
			if fighter and fighter.Equip then
				fighter:Equip(best)
			end
		end)
		pcall(function()
			if fighter and fighter.EquipItem then
				fighter:EquipItem(best)
			end
		end)
		pcall(function()
			if controller and controller.EquipItem then
				controller:EquipItem(best)
			end
		end)
		if best.IsEquipped or Weapon.isHolding() then
			return true
		end
	end
	pcall(function()
		local vim = game:GetService("VirtualInputManager")
		vim:SendKeyEvent(true, Enum.KeyCode.One, false, game)
		vim:SendKeyEvent(false, Enum.KeyCode.One, false, game)
	end)
	return Weapon.isHolding()
end
return Weapon
end)()
local Esp = (function()
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Esp = {}
Esp.entries = {}
Esp.container = nil
Esp.font = Enum.Font.BuilderSansMedium
Esp.boxThickness = 1
Esp.maxBoxHeight = 420
Esp.healthBarWidth = 3
Esp.healthBarGap = 3
Esp.skeletonThickness = 1
Esp.skeletonLineCount = 96
Esp.boxEdgeCount = 16
Esp.skeletonColor = Color3.fromRGB(255, 255, 255)
Esp.visGreen = Color3.fromRGB(72, 220, 118)
Esp.visRed = Color3.fromRGB(232, 72, 72)
Esp.reloadColor = Color3.fromRGB(255, 184, 72)
Esp.distanceColor = Color3.fromRGB(200, 200, 208)
Esp.weaponColor = Color3.fromRGB(190, 198, 214)
Esp.boneCache = {}
Esp.fovRing = nil
Esp.r15Bones = {
	{ "Head", "UpperTorso" },
	{ "UpperTorso", "LowerTorso" },
	{ "UpperTorso", "LeftUpperArm" },
	{ "LeftUpperArm", "LeftLowerArm" },
	{ "LeftLowerArm", "LeftHand" },
	{ "UpperTorso", "RightUpperArm" },
	{ "RightUpperArm", "RightLowerArm" },
	{ "RightLowerArm", "RightHand" },
	{ "LowerTorso", "LeftUpperLeg" },
	{ "LeftUpperLeg", "LeftLowerLeg" },
	{ "LeftLowerLeg", "LeftFoot" },
	{ "LowerTorso", "RightUpperLeg" },
	{ "RightUpperLeg", "RightLowerLeg" },
	{ "RightLowerLeg", "RightFoot" },
}
Esp.r6Bones = {
	{ "Head", "Torso" },
	{ "Torso", "Left Arm" },
	{ "Torso", "Right Arm" },
	{ "Torso", "Left Leg" },
	{ "Torso", "Right Leg" },
}
Esp.hitboxBones = {
	{ "PhysicalHitboxHead", "PhysicalHitboxBody" },
	{ "Head", "PhysicalHitboxBody" },
}
Esp.skeletonPartNames = {
	Head = true,
	UpperTorso = true,
	LowerTorso = true,
	Torso = true,
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
	["Left Arm"] = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
	["Right Arm"] = true,
	LeftUpperLeg = true,
	LeftLowerLeg = true,
	LeftFoot = true,
	["Left Leg"] = true,
	RightUpperLeg = true,
	RightLowerLeg = true,
	RightFoot = true,
	["Right Leg"] = true,
	PhysicalHitboxHead = true,
	PhysicalHitboxBody = true,
}
function Esp.getHealthColor(ratio)
	ratio = math.clamp(ratio, 0, 1)
	if ratio > 0.6 then
		return Color3.fromRGB(72, 220, 118)
	end
	if ratio > 0.3 then
		return Color3.fromRGB(245, 166, 55)
	end
	return Color3.fromRGB(235, 72, 72)
end
function Esp.isOnScreen(x, y, w, h)
	local viewport = Camera.ViewportSize
	local margin = 80
	if x + w < -margin or x > viewport.X + margin then
		return false
	end
	if y + h < -margin or y > viewport.Y + margin then
		return false
	end
	return true
end
function Esp.isValidBox(box)
	if not box then
		return false
	end
	if box.w < 8 or box.h < 8 then
		return false
	end
	if box.w > 600 or box.h > Esp.maxBoxHeight then
		return false
	end
	return Esp.isOnScreen(box.x, box.y, box.w, box.h)
end
function Esp.init()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("LV_ESP_Container")
	if existing then
		existing:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "LV_ESP_Container"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 999998
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	Esp.container = gui
end
function Esp.isSupported()
	return Esp.container ~= nil
end
function Esp.getCharacterBox(character)
	local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
	local head = character:FindFirstChild("Head")
	if not root then
		return nil, "missing root"
	end
	local topWorld
	local bottomWorld
	if head then
		topWorld = head.Position + Vector3.new(0, 0.8, 0)
	else
		topWorld = (root.CFrame * CFrame.new(0, 2.5, 0)).Position
	end
	local foot = character:FindFirstChild("LeftFoot")
		or character:FindFirstChild("RightFoot")
		or character:FindFirstChild("Left Leg")
		or character:FindFirstChild("Right Leg")
	if foot then
		bottomWorld = foot.Position - Vector3.new(0, 0.8, 0)
	else
		bottomWorld = (root.CFrame * CFrame.new(0, -3, 0)).Position
	end
	local topPos = Camera:WorldToViewportPoint(topWorld)
	local bottomPos = Camera:WorldToViewportPoint(bottomWorld)
	if topPos.Z <= 0 or bottomPos.Z <= 0 then
		return nil, "behind camera"
	end
	local viewport = Camera.ViewportSize
	local height = math.abs(bottomPos.Y - topPos.Y)
	height = math.clamp(height, 12, math.min(Esp.maxBoxHeight, viewport.Y * 0.75))
	local width = math.clamp(height * 0.55, 8, 360)
	local centerX = (topPos.X + bottomPos.X) * 0.5
	local centerY = (topPos.Y + bottomPos.Y) * 0.5
	local right = Camera.CFrame.RightVector
	local worldW = math.max(1.15, root.Size.X * 1.35)
	local box = {
		x = centerX - width * 0.5,
		y = centerY - height * 0.5,
		w = width,
		h = height,
		topL = topWorld - right * (worldW * 0.5),
		topR = topWorld + right * (worldW * 0.5),
		botL = bottomWorld - right * (worldW * 0.5),
		botR = bottomWorld + right * (worldW * 0.5),
	}
	if not Esp.isValidBox(box) then
		return nil, "invalid box"
	end
	return box, nil
end
function Esp.countBodyParts(character)
	local count = 0
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("BasePart") then
			count = count + 1
		end
	end
	return count
end
function Esp.isCharacterBodyPart(character, part)
	if not part or not part:IsA("BasePart") then
		return false
	end
	if not part:IsDescendantOf(character) then
		return false
	end
	if part:FindFirstAncestorOfClass("Accessory") or part:FindFirstAncestorOfClass("Tool") then
		return false
	end
	if not Esp.skeletonPartNames[part.Name] then
		return false
	end
	return true
end
function Esp.getBoneConnections(character)
	local partCount = Esp.countBodyParts(character)
	local cached = Esp.boneCache[character]
	if cached and cached.partCount == partCount and cached.connections and #cached.connections >= 8 then
		return cached.connections
	end
	local connections = {}
	local seen = {}
	local function addPair(partA, partB)
		if not Esp.isCharacterBodyPart(character, partA) then
			return
		end
		if not Esp.isCharacterBodyPart(character, partB) then
			return
		end
		if partA == partB then
			return
		end
		local key = partA.Name < partB.Name and (partA.Name .. ">" .. partB.Name) or (partB.Name .. ">" .. partA.Name)
		if seen[key] then
			return
		end
		seen[key] = true
		table.insert(connections, { partA, partB })
	end
	for _, pair in ipairs(Esp.r15Bones) do
		addPair(Esp.getPart(character, pair[1]), Esp.getPart(character, pair[2]))
	end
	for _, pair in ipairs(Esp.r6Bones) do
		addPair(Esp.getPart(character, pair[1]), Esp.getPart(character, pair[2]))
	end
	for _, pair in ipairs(Esp.hitboxBones) do
		addPair(Esp.getPart(character, pair[1]), Esp.getPart(character, pair[2]))
	end
	for _, inst in ipairs(character:GetDescendants()) do
		if inst:IsA("Motor6D") and not inst:FindFirstAncestorOfClass("Accessory") then
			addPair(inst.Part0, inst.Part1)
		end
	end
	Esp.boneCache[character] = {
		connections = connections,
		partCount = partCount,
	}
	return connections
end
function Esp.clearBoneCache(character)
	if character then
		Esp.boneCache[character] = nil
	else
		Esp.boneCache = {}
	end
end
function Esp.getBonePairs(character)
	if character:FindFirstChild("UpperTorso") then
		return Esp.r15Bones
	end
	return Esp.r6Bones
end
function Esp.getPart(character, name)
	local part = character:FindFirstChild(name)
	if not part then
		part = character:FindFirstChild(name, true)
	end
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end
function Esp.getPartWorldPos(part, towardPart)
	return part.Position
end
function Esp.worldToScreen(worldPos)
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local pos = camera:WorldToViewportPoint(worldPos)
	if pos.Z <= 0 then
		return nil
	end
	return Vector2.new(pos.X, pos.Y)
end
function Esp.createSkeletonLine()
	local line = Instance.new("Frame")
	line.Name = "SkeletonLine"
	line.BackgroundColor3 = Esp.skeletonColor
	line.BackgroundTransparency = 0
	line.BorderSizePixel = 0
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Visible = false
	line.ZIndex = 8
	line.Parent = Esp.container
	return line
end
function Esp.ensureSkeletonLines(entry)
	if entry.skeletonLines and #entry.skeletonLines > 0 then
		return entry.skeletonLines
	end
	entry.skeletonLines = {}
	for i = 1, Esp.skeletonLineCount do
		entry.skeletonLines[i] = Esp.createSkeletonLine()
	end
	return entry.skeletonLines
end
function Esp.setScreenLineLayout(line, x1, y1, x2, y2)
	local dx = x2 - x1
	local dy = y2 - y1
	local length = math.sqrt(dx * dx + dy * dy)
	if length < 1 then
		line.Visible = false
		return false
	end
	line.Size = UDim2.fromOffset(math.floor(length + 0.5), Esp.skeletonThickness)
	line.Position = UDim2.fromOffset(math.floor((x1 + x2) * 0.5 + 0.5), math.floor((y1 + y2) * 0.5 + 0.5))
	line.Rotation = math.deg(math.atan2(dy, dx))
	line.Visible = true
	return true
end
function Esp.hideSkeleton(entry)
	if not entry.skeletonLines then
		return
	end
	for _, line in ipairs(entry.skeletonLines) do
		line.Visible = false
	end
end
function Esp.destroySkeleton(entry)
	if entry.skeletonLines then
		for _, line in ipairs(entry.skeletonLines) do
			line:Destroy()
		end
		entry.skeletonLines = nil
	end
end
function Esp.updateSkeleton(entry, character, visible, visCheck, tone)
	if not visible or not Esp.container then
		Esp.hideSkeleton(entry)
		return
	end
	local connections = Esp.getBoneConnections(character)
	if #connections == 0 then
		Esp.hideSkeleton(entry)
		return
	end
	local lines = Esp.ensureSkeletonLines(entry)
	local lineIndex = 1
	for _, connection in ipairs(connections) do
		if lineIndex > Esp.skeletonLineCount then
			break
		end
		local partA = connection[1]
		local partB = connection[2]
		if partA and partB and partA.Parent and partB.Parent then
			local a = partA.Position
			local b = partB.Position
			local delta = b - a
			local dist = delta.Magnitude
			local segs = 1
			for s = 0, segs - 1 do
				if lineIndex > Esp.skeletonLineCount then
					break
				end
				local w0 = a + delta * (s / segs)
				local w1 = a + delta * ((s + 1) / segs)
				local screenA = Esp.worldToScreen(w0)
				local screenB = Esp.worldToScreen(w1)
				if screenA and screenB then
					local line = lines[lineIndex]
					if Esp.setScreenLineLayout(line, screenA.X, screenA.Y, screenB.X, screenB.Y) then
						if visCheck then
							line.BackgroundColor3 = tone or Esp.visGreen
						else
							line.BackgroundColor3 = Esp.skeletonColor
						end
						lineIndex = lineIndex + 1
					end
				end
			end
		end
	end
	for i = lineIndex, #lines do
		lines[i].Visible = false
	end
end
function Esp.visTone(clear)
	return clear and Esp.visGreen or Esp.visRed
end
function Esp.refPart(character, names)
	for i = 1, #names do
		local part = character:FindFirstChild(names[i], true)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end
function Esp.ensureBoxEdges(entry)
	if entry.boxEdges and #entry.boxEdges > 0 then
		return entry.boxEdges
	end
	entry.boxEdges = {}
	for i = 1, Esp.boxEdgeCount do
		entry.boxEdges[i] = Esp.createSkeletonLine()
		entry.boxEdges[i].Name = "BoxEdge"
		entry.boxEdges[i].ZIndex = 2
	end
	return entry.boxEdges
end
function Esp.hideBoxEdges(entry)
	if not entry.boxEdges then
		return
	end
	for _, line in ipairs(entry.boxEdges) do
		line.Visible = false
	end
end
function Esp.destroyBoxEdges(entry)
	if entry.boxEdges then
		for _, line in ipairs(entry.boxEdges) do
			line:Destroy()
		end
		entry.boxEdges = nil
	end
end
function Esp.drawWorldEdge(lines, index, a, b, visCheck, limit)
	local delta = b - a
	local dist = delta.Magnitude
	local segs = visCheck and math.clamp(math.floor(dist / 0.2 + 0.5), 1, 3) or 1
	for s = 0, segs - 1 do
		if index > limit then
			return index
		end
		local w0 = a + delta * (s / segs)
		local w1 = a + delta * ((s + 1) / segs)
		local screenA = Esp.worldToScreen(w0)
		local screenB = Esp.worldToScreen(w1)
		if screenA and screenB then
			local line = lines[index]
			if Esp.setScreenLineLayout(line, screenA.X, screenA.Y, screenB.X, screenB.Y) then
				line.BackgroundColor3 = visCheck and Esp.visTone(Los.isClear((w0 + w1) * 0.5)) or Color3.fromRGB(255, 255, 255)
				index = index + 1
			end
		end
	end
	return index
end
function Esp.drawScreenEdge(lines, index, x1, y1, x2, y2, worldA, worldB, visCheck, limit)
	local segs = visCheck and 4 or 1
	for s = 0, segs - 1 do
		if index > limit then
			return index
		end
		local t0 = s / segs
		local t1 = (s + 1) / segs
		local line = lines[index]
		if Esp.setScreenLineLayout(
			line,
			x1 + (x2 - x1) * t0,
			y1 + (y2 - y1) * t0,
			x1 + (x2 - x1) * t1,
			y1 + (y2 - y1) * t1
		) then
			if visCheck and worldA and worldB then
				line.BackgroundColor3 = Esp.visTone(Los.isClear(worldA:Lerp(worldB, (t0 + t1) * 0.5)))
			else
				line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			end
			index = index + 1
		end
	end
	return index
end
function Esp.updateBoxEdges(entry, boxData, show, visCheck, tone)
	if not show or not visCheck or not boxData then
		Esp.hideBoxEdges(entry)
		if entry.boxStroke then
			entry.boxStroke.Transparency = 0
		end
		return
	end
	if entry.boxStroke then
		entry.boxStroke.Transparency = 1
	end
	local x, y, w, h = boxData.x, boxData.y, boxData.w, boxData.h
	local lines = Esp.ensureBoxEdges(entry)
	local index = 1
	index = Esp.drawScreenEdge(lines, index, x, y, x + w, y, nil, nil, false, Esp.boxEdgeCount)
	index = Esp.drawScreenEdge(lines, index, x + w, y, x + w, y + h, nil, nil, false, Esp.boxEdgeCount)
	index = Esp.drawScreenEdge(lines, index, x + w, y + h, x, y + h, nil, nil, false, Esp.boxEdgeCount)
	index = Esp.drawScreenEdge(lines, index, x, y + h, x, y, nil, nil, false, Esp.boxEdgeCount)
	local color = tone or Color3.fromRGB(255, 255, 255)
	for i = 1, index - 1 do
		lines[i].BackgroundColor3 = color
	end
	for i = index, #lines do
		lines[i].Visible = false
	end
end
function Esp.setAccent(entry, color)
	local cache = entry.cache
	if color then
		entry.boxStroke.Color = color
		entry.name.TextColor3 = color
		if entry.weapon then
			entry.weapon.TextColor3 = color
		end
		entry.distance.TextColor3 = color
		entry.healthFill.BackgroundColor3 = color
		if entry.reloadFill then
			entry.reloadFill.BackgroundColor3 = color
		end
		cache.accentOn = true
		return
	end
	if not cache.accentOn then
		return
	end
	entry.boxStroke.Color = Color3.fromRGB(255, 255, 255)
	entry.name.TextColor3 = Color3.fromRGB(255, 255, 255)
	if entry.weapon then
		entry.weapon.TextColor3 = Esp.weaponColor
	end
	entry.distance.TextColor3 = Esp.distanceColor
	if type(cache.healthRatio) == "number" then
		entry.healthFill.BackgroundColor3 = Esp.getHealthColor(cache.healthRatio)
		cache.healthColor = nil
	end
	if entry.reloadFill then
		entry.reloadFill.BackgroundColor3 = Esp.reloadColor
	end
	cache.accentOn = false
end
function Esp.ensureFovRing()
	if Esp.fovRing and Esp.fovRing.Parent then
		return Esp.fovRing
	end
	if not Esp.container then
		return nil
	end
	local ring = Instance.new("Frame")
	ring.Name = "FovRing"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.BackgroundTransparency = 1
	ring.BorderSizePixel = 0
	ring.Visible = false
	ring.ZIndex = 20
	ring.Parent = Esp.container
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(220, 220, 228)
	stroke.Transparency = 0.25
	stroke.Parent = ring
	Esp.fovRing = ring
	return ring
end
function Esp.updateFov(config)
	local env = (typeof(getgenv) == "function" and getgenv()) or _G
	if (type(env) == "table" and env.LV_BOOTING) or not config.drawFov or not Esp.container then
		if Esp.fovRing then
			Esp.fovRing.Visible = false
		end
		return
	end
	local ring = Esp.ensureFovRing()
	if not ring then
		return
	end
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local diameter = math.max(12, math.floor((config.fov or 150) * 2 + 0.5))
	ring.Size = UDim2.fromOffset(diameter, diameter)
	ring.Position = UDim2.fromOffset(math.floor(viewport.X * 0.5 + 0.5), math.floor(viewport.Y * 0.5 + 0.5))
	ring.Visible = true
end
function Esp.ensureEntry(player)
	if Esp.entries[player] then
		return Esp.entries[player]
	end
	if not Esp.container then
		return nil
	end
	local box = Instance.new("Frame")
	box.Name = player.Name .. "_Box"
	box.BackgroundTransparency = 1
	box.BorderSizePixel = 0
	box.Visible = false
	box.ZIndex = 1
	box.Parent = Esp.container
	local boxStroke = Instance.new("UIStroke")
	boxStroke.Color = Color3.fromRGB(255, 255, 255)
	boxStroke.Thickness = Esp.boxThickness
	boxStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	boxStroke.Parent = box
	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.BackgroundTransparency = 1
	name.BorderSizePixel = 0
	name.Font = Esp.font
	name.TextSize = 13
	name.TextColor3 = Color3.fromRGB(255, 255, 255)
	name.TextStrokeTransparency = 0.55
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.Visible = false
	name.ZIndex = 2
	name.Parent = Esp.container
	local weapon = Instance.new("TextLabel")
	weapon.Name = "Weapon"
	weapon.BackgroundTransparency = 1
	weapon.BorderSizePixel = 0
	weapon.Font = Esp.font
	weapon.TextSize = 12
	weapon.TextColor3 = Esp.weaponColor
	weapon.TextStrokeTransparency = 0.55
	weapon.TextXAlignment = Enum.TextXAlignment.Center
	weapon.AutoLocalize = false
	weapon.Visible = false
	weapon.ZIndex = 2
	weapon.Parent = Esp.container
	local distance = Instance.new("TextLabel")
	distance.Name = "Distance"
	distance.BackgroundTransparency = 1
	distance.BorderSizePixel = 0
	distance.Font = Esp.font
	distance.TextSize = 12
	distance.TextColor3 = Color3.fromRGB(200, 200, 208)
	distance.TextStrokeTransparency = 0.55
	distance.TextXAlignment = Enum.TextXAlignment.Center
	distance.Visible = false
	distance.ZIndex = 2
	distance.Parent = Esp.container
	local healthBg = Instance.new("Frame")
	healthBg.Name = "HealthBg"
	healthBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	healthBg.BackgroundTransparency = 0.35
	healthBg.BorderSizePixel = 0
	healthBg.Visible = false
	healthBg.ZIndex = 2
	healthBg.Parent = Esp.container
	local healthFill = Instance.new("Frame")
	healthFill.Name = "HealthFill"
	healthFill.BackgroundColor3 = Color3.fromRGB(72, 220, 118)
	healthFill.BorderSizePixel = 0
	healthFill.AnchorPoint = Vector2.new(0, 1)
	healthFill.Position = UDim2.new(0, 0, 1, 0)
	healthFill.ZIndex = 3
	healthFill.Parent = healthBg
	local reloadBg = Instance.new("Frame")
	reloadBg.Name = "ReloadBg"
	reloadBg.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
	reloadBg.BackgroundTransparency = 0.25
	reloadBg.BorderSizePixel = 0
	reloadBg.Visible = false
	reloadBg.ZIndex = 2
	reloadBg.Parent = Esp.container
	local reloadFill = Instance.new("Frame")
	reloadFill.Name = "ReloadFill"
	reloadFill.BackgroundColor3 = Color3.fromRGB(255, 184, 72)
	reloadFill.BorderSizePixel = 0
	reloadFill.Size = UDim2.fromScale(1, 1)
	reloadFill.ZIndex = 3
	reloadFill.Parent = reloadBg
	Esp.entries[player] = {
		box = box,
		boxStroke = boxStroke,
		name = name,
		weapon = weapon,
		distance = distance,
		healthBg = healthBg,
		healthFill = healthFill,
		reloadBg = reloadBg,
		reloadFill = reloadFill,
		skeletonLines = nil,
		cache = {},
	}
	return Esp.entries[player]
end
function Esp.removeEntry(player)
	local entry = Esp.entries[player]
	if not entry then
		return
	end
	entry.box:Destroy()
	entry.name:Destroy()
	if entry.weapon then
		entry.weapon:Destroy()
	end
	entry.distance:Destroy()
	entry.healthBg:Destroy()
	if entry.reloadBg then
		entry.reloadBg:Destroy()
	end
	Weapon.enemyReload[player] = nil
	Esp.destroySkeleton(entry)
	Esp.destroyBoxEdges(entry)
	Esp.entries[player] = nil
end
function Esp.clear()
	for player in pairs(Esp.entries) do
		Esp.removeEntry(player)
	end
	Esp.clearBoneCache()
end
function Esp.destroy()
	Esp.clear()
	if Esp.container then
		Esp.container:Destroy()
		Esp.container = nil
	end
	Esp.fovRing = nil
end
function Esp.hideEntry(entry)
	entry.box.Visible = false
	entry.name.Visible = false
	if entry.weapon then
		entry.weapon.Visible = false
	end
	entry.distance.Visible = false
	entry.healthBg.Visible = false
	if entry.reloadBg then
		entry.reloadBg.Visible = false
	end
	Esp.hideSkeleton(entry)
	Esp.hideBoxEdges(entry)
	entry.cache = {}
end
function Esp.setBoxLayout(entry, x, y, w, h, showBox)
	local cache = entry.cache
	if showBox then
		if cache.x ~= x or cache.y ~= y or cache.w ~= w or cache.h ~= h or not cache.boxVisible then
			entry.box.Size = UDim2.fromOffset(w, h)
			entry.box.Position = UDim2.fromOffset(x, y)
			entry.box.Visible = true
			cache.x, cache.y, cache.w, cache.h = x, y, w, h
			cache.boxVisible = true
		end
	else
		if cache.boxVisible then
			entry.box.Visible = false
			cache.boxVisible = false
		end
	end
end
function Esp.setNameLayout(entry, text, x, y, w, visible)
	local cache = entry.cache
	if not visible then
		if cache.nameVisible then
			entry.name.Visible = false
			cache.nameVisible = false
		end
		return
	end
	if cache.nameText ~= text then
		entry.name.Text = text
		cache.nameText = text
	end
	if cache.nameX ~= x or cache.nameY ~= y or cache.nameW ~= w or not cache.nameVisible then
		entry.name.Size = UDim2.fromOffset(w, 16)
		entry.name.Position = UDim2.fromOffset(x, y)
		entry.name.Visible = true
		cache.nameX, cache.nameY, cache.nameW = x, y, w
		cache.nameVisible = true
	elseif not entry.name.Visible then
		entry.name.Visible = true
		cache.nameVisible = true
	end
end
function Esp.getCharacterDistance(character, localRoot)
	if not localRoot then
		local localCharacter = LocalPlayer.Character
		if not localCharacter then
			return nil
		end
		localRoot = localCharacter:FindFirstChild("HumanoidRootPart") or localCharacter:FindFirstChild("Torso")
	end
	local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
	if not localRoot or not root then
		return nil
	end
	return (localRoot.Position - root.Position).Magnitude
end
function Esp.isRenderedTarget(character, config)
	if not character then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	local distance = Esp.getCharacterDistance(character)
	if distance and distance > (config.maxDistance or 500) then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
	if not root then
		return false
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return false
	end
	local pos, onScreen = camera:WorldToViewportPoint(root.Position)
	return onScreen == true and pos.Z > 0
end
function Esp.formatDistance(distance)
	return tostring(math.floor(distance + 0.5)) .. "m"
end
function Esp.setWeaponLayout(entry, text, x, y, w, visible)
	local label = entry.weapon
	local cache = entry.cache
	if not label then
		return
	end
	if not visible then
		if cache.weaponVisible then
			label.Visible = false
			cache.weaponVisible = false
		end
		return
	end
	if cache.weaponText ~= text then
		label.Text = text
		cache.weaponText = text
	end
	if cache.weaponX ~= x or cache.weaponY ~= y or cache.weaponW ~= w or not cache.weaponVisible then
		label.Size = UDim2.fromOffset(w, 14)
		label.Position = UDim2.fromOffset(x, y)
		label.Visible = true
		cache.weaponX, cache.weaponY, cache.weaponW = x, y, w
		cache.weaponVisible = true
	elseif not label.Visible then
		label.Visible = true
		cache.weaponVisible = true
	end
end
function Esp.setDistanceLayout(entry, text, x, y, w, visible)
	local cache = entry.cache
	if not visible then
		if cache.distanceVisible then
			entry.distance.Visible = false
			cache.distanceVisible = false
		end
		return
	end
	if cache.distanceText ~= text then
		entry.distance.Text = text
		cache.distanceText = text
	end
	if cache.distanceX ~= x or cache.distanceY ~= y or cache.distanceW ~= w or not cache.distanceVisible then
		entry.distance.Size = UDim2.fromOffset(w, 14)
		entry.distance.Position = UDim2.fromOffset(x, y)
		entry.distance.Visible = true
		cache.distanceX, cache.distanceY, cache.distanceW = x, y, w
		cache.distanceVisible = true
	elseif not entry.distance.Visible then
		entry.distance.Visible = true
		cache.distanceVisible = true
	end
end
function Esp.setReloadLayout(entry, x, y, w, remain, visible)
	local bg = entry.reloadBg
	local fill = entry.reloadFill
	local cache = entry.cache
	if not bg or not fill then
		return
	end
	if not visible or type(remain) ~= "number" or remain <= 0 then
		if cache.reloadVisible then
			bg.Visible = false
			cache.reloadVisible = false
		end
		return
	end
	remain = math.clamp(remain, 0.04, 1)
	local barW = math.max(18, w)
	local fillW = math.max(2, math.floor(barW * remain + 0.5))
	if cache.reloadX ~= x or cache.reloadY ~= y or cache.reloadW ~= barW or not cache.reloadVisible then
		bg.Size = UDim2.fromOffset(barW, 3)
		bg.Position = UDim2.fromOffset(x, y)
		bg.Visible = true
		cache.reloadX, cache.reloadY, cache.reloadW = x, y, barW
		cache.reloadVisible = true
	elseif not bg.Visible then
		bg.Visible = true
		cache.reloadVisible = true
	end
	if cache.reloadFillW ~= fillW then
		fill.Size = UDim2.fromOffset(fillW, 3)
		cache.reloadFillW = fillW
	end
end
function Esp.setHealthBarLayout(entry, boxX, boxY, boxH, ratio, visible)
	local cache = entry.cache
	if not visible then
		if cache.healthVisible then
			entry.healthBg.Visible = false
			cache.healthVisible = false
		end
		return
	end
	ratio = math.clamp(ratio, 0, 1)
	cache.healthRatio = ratio
	local barW = Esp.healthBarWidth
	local x = boxX - barW - Esp.healthBarGap
	local y = boxY
	local h = boxH
	local color = Esp.getHealthColor(ratio)
	local fillH = math.max(1, math.floor(h * ratio + 0.5))
	if cache.healthX ~= x
		or cache.healthY ~= y
		or cache.healthH ~= h
		or not cache.healthVisible then
		entry.healthBg.Size = UDim2.fromOffset(barW, h)
		entry.healthBg.Position = UDim2.fromOffset(x, y)
		entry.healthBg.Visible = true
		cache.healthX, cache.healthY, cache.healthH = x, y, h
		cache.healthVisible = true
	end
	if cache.healthFillH ~= fillH then
		entry.healthFill.Size = UDim2.fromOffset(barW, fillH)
		cache.healthFillH = fillH
	end
	if cache.healthColor ~= color then
		entry.healthFill.BackgroundColor3 = color
		cache.healthColor = color
	end
	if not entry.healthBg.Visible then
		entry.healthBg.Visible = true
		cache.healthVisible = true
	end
end
function Esp.update(config, frameCounter)
	local enabled = config.esp
	if not enabled then
		for _, entry in pairs(Esp.entries) do
			Esp.hideEntry(entry)
		end
		return
	end
	if frameCounter % 2 ~= 0 then
		return
	end
	if not Esp.container then
		return
	end
	local seen = {}
	local localChar = LocalPlayer.Character
	local localRoot = localChar and (localChar:FindFirstChild("HumanoidRootPart") or localChar:FindFirstChild("Torso"))
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			seen[player] = true
			if Filter.shouldSkip(player, config) then
				local excludedEntry = Esp.entries[player]
				if excludedEntry then
					Esp.hideEntry(excludedEntry)
				end
			else
			local entry = Esp.ensureEntry(player)
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if character and humanoid and humanoid.Health > 0 and entry then
				local distance = Esp.getCharacterDistance(character, localRoot)
				if distance and distance > (config.maxDistance or 500) then
					Esp.hideEntry(entry)
				else
				local boxData = Esp.getCharacterBox(character)
				local hasVisual = false
				if boxData then
					local x = math.floor(boxData.x + 0.5)
					local y = math.floor(boxData.y + 0.5)
					local w = math.floor(boxData.w + 0.5)
					local h = math.floor(boxData.h + 0.5)
					Esp.setBoxLayout(entry, x, y, w, h, config.espBoxes)
					local labelW = w + 40
					local displayName = player.DisplayName ~= "" and player.DisplayName or player.Name
					local weaponText = ""
					if config.espWeapon == true then
						if not entry.weaponAt or now - entry.weaponAt > 0.2 then
							entry.weaponAt = now
							entry.weaponName = Weapon.playerEquippedName(player)
						end
						weaponText = entry.weaponName or ""
					end
					local showWeapon = config.espWeapon == true and weaponText ~= ""
					local nameY = showWeapon and (y - 32) or (y - 18)
					Esp.setNameLayout(entry, displayName, x - 20, nameY, labelW, config.espNames)
					Esp.setWeaponLayout(entry, weaponText, x - 20, y - 18, labelW, showWeapon)
					local maxHealth = humanoid.MaxHealth
					local ratio = maxHealth > 0 and humanoid.Health / maxHealth or 0
					Esp.setHealthBarLayout(entry, x, y, h, ratio, config.espHealth)
					local reloadRemain = nil
					if config.enemyReload == true then
						if not entry.reloadAt or now - entry.reloadAt > 0.08 then
							entry.reloadAt = now
							entry.reloadRemain = Weapon.playerReloadRemain(player)
						end
						reloadRemain = entry.reloadRemain
					end
					Esp.setReloadLayout(entry, x, y + h + 3, w, reloadRemain, reloadRemain ~= nil)
					local distanceText = distance and Esp.formatDistance(distance) or ""
					local distanceY = reloadRemain and (y + h + 10) or (y + h + 2)
					Esp.setDistanceLayout(entry, distanceText, x - 20, distanceY, labelW, config.espDistance and distance ~= nil)
					hasVisual = true
				else
					Esp.setBoxLayout(entry, 0, 0, 0, 0, false)
					Esp.setNameLayout(entry, "", 0, 0, 0, false)
					Esp.setWeaponLayout(entry, "", 0, 0, 0, false)
					Esp.setDistanceLayout(entry, "", 0, 0, 0, false)
					Esp.setHealthBarLayout(entry, 0, 0, 0, 0, false)
					Esp.setReloadLayout(entry, 0, 0, 0, nil, false)
					Esp.hideSkeleton(entry)
				end
				local visTone = nil
				if boxData and config.espVisCheck then
					local root = character:FindFirstChild("HumanoidRootPart")
						or character:FindFirstChild("UpperTorso")
						or character:FindFirstChild("Torso")
						or character:FindFirstChild("Head")
					visTone = Esp.visTone(root ~= nil and Los.isClear(root.Position, root))
				end
				Esp.updateSkeleton(entry, character, boxData ~= nil and config.espSkeleton, config.espVisCheck, visTone)
				if config.espSkeleton then
					hasVisual = true
				end
				if config.espVisCheck then
					Esp.updateBoxEdges(entry, boxData, config.espBoxes == true, true, visTone)
					entry.name.TextColor3 = visTone
					if entry.weapon then
						entry.weapon.TextColor3 = visTone
					end
					entry.distance.TextColor3 = visTone
					entry.healthFill.BackgroundColor3 = visTone
					if entry.reloadFill then
						entry.reloadFill.BackgroundColor3 = visTone
					end
					entry.cache.accentOn = true
				else
					Esp.updateBoxEdges(entry, boxData, false, false)
					Esp.setAccent(entry, nil)
				end
				if hasVisual then
				else
					Esp.hideEntry(entry)
				end
				end
			else
				if entry then
					Esp.hideEntry(entry)
				end
			end
			end
		end
	end
	for player in pairs(Esp.entries) do
		if not seen[player] then
			Esp.removeEntry(player)
		end
	end
end
return Esp
end)()
local Cham = (function()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Cham = {}
Cham.entries = {}
Cham.folder = nil
Cham.hlRoot = nil
Cham.MAX = 12
Cham.rankAt = 0
Cham.buildKey = nil
Cham.COLORS = {
	{ id = "green", label = "Green", c = Color3.fromRGB(72, 220, 118) },
	{ id = "red", label = "Red", c = Color3.fromRGB(232, 72, 72) },
	{ id = "cyan", label = "Cyan", c = Color3.fromRGB(64, 220, 230) },
	{ id = "blue", label = "Blue", c = Color3.fromRGB(64, 132, 255) },
	{ id = "purple", label = "Purple", c = Color3.fromRGB(168, 88, 255) },
	{ id = "pink", label = "Pink", c = Color3.fromRGB(255, 96, 180) },
	{ id = "orange", label = "Orange", c = Color3.fromRGB(255, 148, 48) },
	{ id = "yellow", label = "Yellow", c = Color3.fromRGB(255, 220, 64) },
	{ id = "lime", label = "Lime", c = Color3.fromRGB(160, 255, 64) },
	{ id = "white", label = "White", c = Color3.fromRGB(244, 244, 248) },
	{ id = "gold", label = "Gold", c = Color3.fromRGB(232, 188, 72) },
	{ id = "crimson", label = "Crimson", c = Color3.fromRGB(176, 24, 48) },
	{ id = "black", label = "Black", c = Color3.fromRGB(18, 18, 22) },
}
Cham.STYLES = {
	{ id = "xqz", label = "XQZ", split = true, material = "SmoothPlastic" },
	{ id = "flat", label = "Flat", aot = true, material = "SmoothPlastic" },
	{ id = "neon", label = "Neon", split = true, material = "Neon" },
	{ id = "field", label = "Force Field", split = true, material = "ForceField" },
	{ id = "rainbow", label = "Rainbow", split = true, rainbow = true, material = "SmoothPlastic" },
	{ id = "wire", label = "Wireframe", split = true, wire = true, material = "SmoothPlastic" },
}
Cham.LIMBS = {
	"Head",
	"UpperTorso",
	"LowerTorso",
	"Torso",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"Left Arm",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"Right Arm",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"Left Leg",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
	"Right Leg",
	"PhysicalHitboxHead",
	"PhysicalHitboxBody",
}
Cham.LIMB_SET = {}
for i = 1, #Cham.LIMBS do
	Cham.LIMB_SET[Cham.LIMBS[i]] = true
end
function Cham.wipeNamed()
	local function wipe(parent)
		if not parent then
			return
		end
		local inst = parent:FindFirstChild("LV_Chams")
		if inst then
			inst:Destroy()
		end
	end
	wipe(workspace)
	wipe(workspace.CurrentCamera)
	local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
	wipe(pg)
end
function Cham.folderInst()
	if Cham.folder and Cham.folder.Parent == workspace then
		return Cham.folder
	end
	if Cham.folder and Cham.worldHidden and Cham.folder.Parent == nil then
		return Cham.folder
	end
	if Cham.folder and Cham.folder.Parent then
		return Cham.folder
	end
	if Cham.folder then
		pcall(function()
			Cham.folder:Destroy()
		end)
		Cham.folder = nil
	end
	local leftover = workspace:FindFirstChild("LV_Chams")
	if leftover then
		leftover:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "LV_Chams"
	folder.Parent = workspace
	Cham.folder = folder
	return folder
end
function Cham.skipName(name)
	if name == "HumanoidRootPart" or name == "FakeMass" then
		return true
	end
	if Cham.LIMB_SET[name] then
		return false
	end
	local lower = string.lower(name)
	return string.find(lower, "hitbox", 1, true) ~= nil
end
function Cham.findPart(character, name)
	local part = character:FindFirstChild(name)
	if part and part:IsA("BasePart") then
		return part
	end
	part = character:FindFirstChild(name, true)
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end
function Cham.collectParts(character)
	local seen = {}
	local out = {}
	local function add(part)
		if not part or seen[part] or not part:IsA("BasePart") then
			return
		end
		if Cham.skipName(part.Name) then
			return
		end
		if part:FindFirstAncestorOfClass("Tool") then
			return
		end
		if part.Size.Magnitude < 0.16 then
			return
		end
		seen[part] = true
		table.insert(out, part)
	end
	for i = 1, #Cham.LIMBS do
		add(Cham.findPart(character, Cham.LIMBS[i]))
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("BasePart") then
			add(child)
		end
	end
	local extras = {}
	for _, part in ipairs(character:GetDescendants()) do
		if not seen[part] and (part:IsA("MeshPart") or part:IsA("UnionOperation") or (part:IsA("BasePart") and part:FindFirstChildOfClass("SpecialMesh"))) then
			if part.Size.Magnitude >= 0.28 then
				table.insert(extras, part)
			end
		end
	end
	table.sort(extras, function(a, b)
		return a.Size.Magnitude > b.Size.Magnitude
	end)
	for i = 1, #extras do
		if #out >= 32 then
			break
		end
		add(extras[i])
	end
	return out
end
function Cham.partsSig(parts)
	local bits = { tostring(#parts) }
	for i = 1, #parts do
		local part = parts[i]
		local mesh = ""
		if part:IsA("MeshPart") then
			mesh = tostring(part.MeshId)
		end
		bits[i + 1] = part.Name .. ":" .. mesh .. ":" .. string.format("%.2f", part.Size.Magnitude)
	end
	return table.concat(bits, "|")
end
function Cham.setWorldHidden(hidden)
	Cham.worldHidden = hidden == true
	if Cham.folder then
		if Cham.worldHidden then
			Cham.folder.Parent = nil
		elseif Cham.folder.Parent ~= workspace then
			Cham.folder.Parent = workspace
		end
	end
	for _, entry in pairs(Cham.entries) do
		if entry.visHl then
			entry.visHl.Enabled = not Cham.worldHidden
		end
		if entry.hidHl then
			entry.hidHl.Enabled = not Cham.worldHidden
		end
	end
	if Cham.selfHl then
		Cham.selfHl.Enabled = not Cham.worldHidden
	end
	if Cham.selfModel then
		if Cham.worldHidden then
			Cham.selfModel.Parent = nil
		elseif Cham.folder and Cham.selfModel.Parent ~= Cham.folder then
			Cham.selfModel.Parent = Cham.folder
		end
	end
end
function Cham.visExclude()
	local now = os.clock()
	if Cham.visExcludeList and now - (Cham.visExcludeAt or 0) < 0.4 then
		return Cham.visExcludeList
	end
	local exclude = {}
	if Cham.folder then
		table.insert(exclude, Cham.folder)
	end
	local named = workspace:FindFirstChild("LV_Chams")
	if named then
		table.insert(exclude, named)
	end
	if LocalPlayer.Character then
		table.insert(exclude, LocalPlayer.Character)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	local viewModels = workspace:FindFirstChild("ViewModels")
	if viewModels then
		table.insert(exclude, viewModels)
	end
	Cham.visExcludeList = exclude
	Cham.visExcludeAt = now
	Cham.visParamsDirty = true
	return exclude
end
function Cham.visParams()
	if not Cham.rayParams then
		Cham.rayParams = RaycastParams.new()
		Cham.rayParams.FilterType = Enum.RaycastFilterType.Exclude
		Cham.rayParams.IgnoreWater = true
		Cham.visParamsDirty = true
	end
	local exclude = Cham.visExclude()
	if Cham.visParamsDirty then
		Cham.rayParams.FilterDescendantsInstances = exclude
		Cham.visParamsDirty = false
	end
	return Cham.rayParams
end
function Cham.visualClear(part)
	local cam = workspace.CurrentCamera
	if not cam or not part or not part.Parent then
		return false
	end
	local now = os.clock()
	local cache = Cham.visCache
	if type(cache) ~= "table" then
		cache = setmetatable({}, { __mode = "k" })
		Cham.visCache = cache
	end
	local hit = cache[part]
	if hit and now - hit.at < 0.05 then
		return hit.clear
	end
	local origin = cam.CFrame.Position
	local dest = part.Position
	local delta = dest - origin
	local dist = delta.Magnitude
	if dist < 0.25 then
		cache[part] = { at = now, clear = true }
		return true
	end
	local result = workspace:Raycast(origin, delta, Cham.visParams())
	local clear = result == nil or result.Instance == nil
	cache[part] = { at = now, clear = clear }
	return clear
end
function Cham.charClear(character)
	if not character then
		return false
	end
	local now = os.clock()
	local cache = Cham.visCache
	if type(cache) ~= "table" then
		cache = setmetatable({}, { __mode = "k" })
		Cham.visCache = cache
	end
	local hit = cache[character]
	if hit and now - hit.at < 0.05 then
		return hit.clear
	end
	local names = {
		"Head",
		"PhysicalHitboxHead",
		"UpperTorso",
		"Torso",
		"HumanoidRootPart",
		"PhysicalHitboxBody",
	}
	local any = false
	local clear = true
	for i = 1, #names do
		local part = character:FindFirstChild(names[i])
		if part and part:IsA("BasePart") then
			any = true
			if not Cham.visualClear(part) then
				clear = false
				break
			end
		end
	end
	if not any then
		clear = false
	end
	cache[character] = { at = now, clear = clear }
	return clear
end
function Cham.colorById(id)
	for i = 1, #Cham.COLORS do
		if Cham.COLORS[i].id == id then
			return Cham.COLORS[i].c
		end
	end
	return nil
end
function Cham.styleById(id)
	for i = 1, #Cham.STYLES do
		if Cham.STYLES[i].id == id then
			return Cham.STYLES[i]
		end
	end
	return Cham.STYLES[1]
end
function Cham.materialOf(name)
	local ok, material = pcall(function()
		return Enum.Material[name]
	end)
	if ok and material then
		return material
	end
	return Enum.Material.SmoothPlastic
end
function Cham.looks(config)
	local style = Cham.styleById(Cham.activeStyle or (config and config.chamStyle))
	local rainbow = style.rainbow == true
	local looksKey = table.concat({
		tostring(style.id),
		tostring(config and config.chamFill),
		tostring(config and config.chamOutline),
		tostring(config and config.chamVisColor),
		tostring(config and config.chamHidColor),
	}, "|")
	if not rainbow and Cham.looksCached and Cham.looksKey == looksKey then
		return Cham.looksCached
	end
	local wire = style.wire == true
	local fill = math.clamp((config.chamFill or 15) / 100, 0, 0.95)
	local outline = math.clamp((config.chamOutline or 15) / 100, 0, 0.95)
	local hidFill = fill
	local hidOutline = outline
	if wire then
		fill = 1
		outline = 0
		hidFill = 0.28
		hidOutline = 0
	end
	if style.id == "field" then
		fill = 0.38
		outline = 0.04
		hidFill = 0.2
		hidOutline = 0.04
	end
	local vis = Cham.colorById(config.chamVisColor) or Esp.visGreen
	local hid = Cham.colorById(config.chamHidColor) or Esp.visRed
	local speed = (config.chamRainbowSpeed or 70) / 50
	local t = os.clock() * speed
	if rainbow then
		vis = Color3.fromHSV(t % 1, 1, 1)
		hid = Color3.fromHSV((t + 0.5) % 1, 1, 1)
	end
	local looks = {
		style = style,
		fill = fill,
		outline = outline,
		hidFill = hidFill,
		hidOutline = hidOutline,
		vis = vis,
		hid = hid,
		material = Cham.materialOf(style.material),
		split = style.split == true,
		aot = style.aot == true,
		wire = wire,
		rainbow = rainbow,
	}
	if not rainbow then
		Cham.looksKey = looksKey
		Cham.looksCached = looks
	end
	return looks
end
function Cham.rebuildKey(config)
	return tostring(config.chamStyle) .. "|" .. tostring(config.chamOverride)
end
function Cham.attachCopy(src, dst)
	if not src or not dst or not src.Parent or not dst.Parent then
		return
	end
	dst.CFrame = src.CFrame
	for _, child in ipairs(dst:GetChildren()) do
		if child:IsA("WeldConstraint") then
			child:Destroy()
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = src
	weld.Part1 = dst
	weld.Parent = dst
end
function Cham.copyPart(part, material, color)
	local copy
	pcall(function()
		local arch = part.Archivable
		part.Archivable = true
		copy = part:Clone()
		part.Archivable = arch
	end)
	if copy then
		copy:ClearAllChildren()
		if copy:IsA("MeshPart") then
			pcall(function()
				copy.TextureID = ""
			end)
			if copy.MeshId == "" then
				copy:Destroy()
				copy = nil
			end
		end
	end
	if not copy then
		copy = Instance.new("Part")
		copy.Size = part.Size
		copy.CFrame = part.CFrame
		copy.TopSurface = Enum.SurfaceType.Smooth
		copy.BottomSurface = Enum.SurfaceType.Smooth
	end
	copy.Name = part.Name
	copy.Anchored = false
	copy.CanCollide = false
	copy.CanQuery = false
	copy.CanTouch = false
	copy.Massless = true
	copy.CastShadow = false
	copy.Transparency = 0
	copy.LocalTransparencyModifier = 0
	copy.Material = material or Enum.Material.SmoothPlastic
	copy.Color = color or Esp.visRed
	copy.CFrame = part.CFrame
	if part.Name == "Head" or part.Name == "PhysicalHitboxHead" then
		copy.Size = copy.Size * 0.72
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = copy
	weld.Parent = copy
	return copy
end
function Cham.hideOne(inst, hidden)
	if hidden[inst] then
		return
	end
	if inst:IsA("BasePart") then
		hidden[inst] = {
			kind = "part",
			ltm = inst.LocalTransparencyModifier,
			t = inst.Transparency,
		}
		inst.LocalTransparencyModifier = 1
		inst.Transparency = 1
	elseif inst:IsA("Decal") or inst:IsA("Texture") then
		hidden[inst] = { kind = "tex", t = inst.Transparency }
		inst.Transparency = 1
	elseif inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") or inst:IsA("Highlight") then
		hidden[inst] = { kind = "fx", on = inst.Enabled }
		inst.Enabled = false
	end
end
function Cham.hideOriginal(character, entry)
	local hidden = entry.hidden or {}
	for _, inst in ipairs(character:GetDescendants()) do
		Cham.hideOne(inst, hidden)
	end
	entry.hidden = hidden
	if entry.hideConn then
		pcall(function()
			entry.hideConn:Disconnect()
		end)
	end
	entry.hideConn = character.DescendantAdded:Connect(function(inst)
		Cham.hideOne(inst, hidden)
		for _, child in ipairs(inst:GetDescendants()) do
			Cham.hideOne(child, hidden)
		end
		entry.dirty = true
		entry.dirtyAt = os.clock()
	end)
end
function Cham.watchCharacter(character, entry)
	if entry.watchConn then
		pcall(function()
			entry.watchConn:Disconnect()
		end)
	end
	if entry.goneConn then
		pcall(function()
			entry.goneConn:Disconnect()
		end)
	end
	entry.watchConn = character.DescendantAdded:Connect(function(inst)
		if inst:IsA("BasePart") or inst:IsA("Accessory") or inst:IsA("SpecialMesh") then
			entry.dirty = true
			entry.dirtyAt = os.clock()
		end
	end)
	entry.goneConn = character.DescendantRemoving:Connect(function(inst)
		if inst:IsA("BasePart") or inst:IsA("Accessory") then
			entry.dirty = true
			entry.dirtyAt = os.clock()
		end
	end)
end
function Cham.restoreOriginal(entry)
	local hidden = entry and entry.hidden
	if not hidden then
		return
	end
	for inst, saved in pairs(hidden) do
		if inst.Parent then
			pcall(function()
				if saved.kind == "part" then
					inst.LocalTransparencyModifier = saved.ltm or 0
					inst.Transparency = saved.t or 0
				elseif saved.kind == "ltm" then
					inst.LocalTransparencyModifier = saved.v or 0
				elseif saved.kind == "tex" then
					inst.Transparency = saved.t or saved.v or 0
				elseif saved.kind == "fx" then
					inst.Enabled = saved.on == true
				end
			end)
		end
	end
	entry.hidden = nil
end
function Cham.keepHidden(entry)
	local now = os.clock()
	if entry.hideAt and now - entry.hideAt < 0.12 then
		return
	end
	entry.hideAt = now
	local hidden = entry.hidden
	if not hidden then
		return
	end
	for inst, saved in pairs(hidden) do
		if inst.Parent and saved.kind == "part" then
			if inst.LocalTransparencyModifier < 1 then
				inst.LocalTransparencyModifier = 1
			end
			if inst.Transparency < 1 then
				inst.Transparency = 1
			end
		end
	end
end
function Cham.destroyEntry(character)
	local entry = Cham.entries[character]
	if not entry then
		return
	end
	if entry.hideConn then
		pcall(function()
			entry.hideConn:Disconnect()
		end)
		entry.hideConn = nil
	end
	if entry.watchConn then
		pcall(function()
			entry.watchConn:Disconnect()
		end)
		entry.watchConn = nil
	end
	if entry.goneConn then
		pcall(function()
			entry.goneConn:Disconnect()
		end)
		entry.goneConn = nil
	end
	Cham.restoreOriginal(entry)
	if entry.visHl then
		pcall(function()
			entry.visHl:Destroy()
		end)
	end
	if entry.hidHl then
		pcall(function()
			entry.hidHl:Destroy()
		end)
	end
	if entry.visModel then
		pcall(function()
			entry.visModel:Destroy()
		end)
	end
	if entry.hidModel then
		pcall(function()
			entry.hidModel:Destroy()
		end)
	end
	if entry.clone then
		pcall(function()
			entry.clone:Destroy()
		end)
	end
	Cham.entries[character] = nil
end
function Cham.clear()
	for character in pairs(Cham.entries) do
		Cham.destroyEntry(character)
	end
	if Cham.folder then
		pcall(function()
			Cham.folder:Destroy()
		end)
		Cham.folder = nil
	end
	if Cham.hlRoot then
		pcall(function()
			Cham.hlRoot:Destroy()
		end)
		Cham.hlRoot = nil
	end
	Cham.wipeNamed()
	Cham.buildKey = nil
	Cham.lastConfig = nil
	Cham.clearSelf()
	Cham.releaseSelfBind()
end
function Cham.hlFolder()
	local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
	if Cham.hlRoot and Cham.hlRoot.Parent == pg then
		return Cham.hlRoot
	end
	if Cham.hlRoot then
		pcall(function()
			Cham.hlRoot:Destroy()
		end)
		Cham.hlRoot = nil
	end
	if not pg then
		return Cham.folderInst()
	end
	local existing = pg:FindFirstChild("LV_Chams")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "LV_Chams"
	folder.Parent = pg
	Cham.hlRoot = folder
	return folder
end
function Cham.style(highlight, color, throughWalls, fill, outline, enabled)
	if not highlight then
		return
	end
	highlight.Enabled = enabled ~= false
	highlight.DepthMode = throughWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = fill or 0.15
	highlight.OutlineTransparency = outline or 0.1
end
function Cham.makeWireBox(parent, adornee, thickness)
	local box = Instance.new("SelectionBox")
	box.Name = "LV_Wire"
	box.LineThickness = thickness
	box.SurfaceTransparency = 1
	box.Adornee = adornee
	box.Parent = parent
	return box
end
function Cham.ensureWire(rel, color)
	if not rel.wires then
		rel.wires = {}
		table.insert(rel.wires, Cham.makeWireBox(rel.dst, rel.dst, 0.016))
		local name = rel.src and rel.src.Name or ""
		if name == "Head" or name == "PhysicalHitboxHead" then
			table.insert(rel.wires, Cham.makeWireBox(rel.dst, rel.dst, 0.01))
			local mid = Instance.new("Part")
			mid.Name = "LV_HeadWire"
			mid.Size = rel.dst.Size * 0.62
			mid.CFrame = rel.dst.CFrame
			mid.Anchored = false
			mid.CanCollide = false
			mid.CanQuery = false
			mid.CanTouch = false
			mid.Massless = true
			mid.Transparency = 1
			mid.Parent = rel.dst
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = rel.dst
			weld.Part1 = mid
			weld.Parent = mid
			table.insert(rel.wires, Cham.makeWireBox(mid, mid, 0.012))
			local inner = Instance.new("Part")
			inner.Name = "LV_HeadWireIn"
			inner.Size = rel.dst.Size * 0.38
			inner.CFrame = rel.dst.CFrame
			inner.Anchored = false
			inner.CanCollide = false
			inner.CanQuery = false
			inner.CanTouch = false
			inner.Massless = true
			inner.Transparency = 1
			inner.Parent = rel.dst
			local weld2 = Instance.new("WeldConstraint")
			weld2.Part0 = rel.dst
			weld2.Part1 = inner
			weld2.Parent = inner
			table.insert(rel.wires, Cham.makeWireBox(inner, inner, 0.01))
		end
	end
	for i = 1, #rel.wires do
		local box = rel.wires[i]
		if box and box.Parent then
			box.Visible = true
			box.Color3 = color
			box.SurfaceColor3 = color
		end
	end
end
function Cham.paint(entry, looks)
	if Cham.worldHidden then
		return
	end
	if entry.override then
		Cham.keepHidden(entry)
	end
	local flat = looks.style.id == "flat" or (looks.aot and not looks.split)
	local styleKey = string.format(
		"%s|%s|%s|%.3f|%.3f|%s",
		tostring(flat),
		tostring(looks.vis),
		tostring(looks.hid),
		looks.fill,
		looks.outline,
		tostring(not Cham.worldHidden)
	)
	if entry.styleKey ~= styleKey then
		entry.styleKey = styleKey
		if flat then
			Cham.style(entry.visHl, looks.vis, false, looks.fill, looks.outline, false)
			Cham.style(entry.hidHl, looks.vis, true, looks.fill, looks.outline, true)
		else
			Cham.style(entry.visHl, looks.vis, false, looks.fill, looks.outline, true)
			Cham.style(entry.hidHl, looks.hid, true, looks.hidFill or looks.fill, looks.hidOutline or looks.outline, true)
		end
		if entry.visHl and entry.visHl.Adornee ~= entry.visModel then
			entry.visHl.Adornee = entry.visModel
		end
		if entry.hidHl and entry.hidHl.Adornee ~= entry.hidModel then
			entry.hidHl.Adornee = entry.hidModel
		end
	end
	local clear = false
	if not flat then
		clear = Cham.charClear(entry.character)
	end
	local want = (flat or not clear) and entry.hidModel or entry.visModel
	local color = flat and looks.vis or ((flat or not clear) and looks.hid or looks.vis)
	local trans = 0
	if looks.wire then
		trans = clear and 1 or 0.12
	elseif looks.style.id == "field" then
		trans = 0.14
	end
	local restyle = entry.want ~= want or entry.paintColor ~= color or entry.paintTrans ~= trans or looks.rainbow or looks.wire
	entry.want = want
	entry.paintColor = color
	entry.paintTrans = trans
	local list = entry.pairs
	for i = 1, #list do
		local rel = list[i]
		local src, dst = rel.src, rel.dst
		if src and dst and src.Parent and dst.Parent then
			if dst.Parent ~= want then
				dst.Parent = want
				Cham.attachCopy(src, dst)
			elseif (dst.Position - src.Position).Magnitude > 0.25 then
				dst.CFrame = src.CFrame
			end
			if restyle then
			if dst.Color ~= color then
				dst.Color = color
			end
			if dst.Material ~= looks.material then
				dst.Material = looks.material
			end
			if dst.Transparency ~= trans then
				dst.Transparency = trans
			end
			if looks.wire then
				Cham.ensureWire(rel, color)
			elseif rel.wires then
				for w = 1, #rel.wires do
					if rel.wires[w] then
						rel.wires[w].Visible = false
					end
				end
			end
			end
		end
	end
end
function Cham.build(character)
	Cham.destroyEntry(character)
	local folder = Cham.folderInst()
	local hlParent = Cham.hlFolder()
	if not folder or not hlParent then
		return
	end
	local sources = Cham.collectParts(character)
	if #sources == 0 then
		return
	end
	local config = Cham.lastConfig or {}
	local looks = Cham.looks(config)
	local visModel = Instance.new("Model")
	visModel.Name = character.Name .. "_Vis"
	visModel.Parent = folder
	local hidModel = Instance.new("Model")
	hidModel.Name = character.Name .. "_Hid"
	hidModel.Parent = folder
	local pairsList = {}
	for i = 1, #sources do
		local part = sources[i]
		local ok, copy = pcall(Cham.copyPart, part, looks.material, looks.hid)
		if ok and copy then
			copy.Parent = hidModel
			table.insert(pairsList, { src = part, dst = copy })
		end
	end
	if #pairsList == 0 then
		visModel:Destroy()
		hidModel:Destroy()
		return
	end
	local visHl = Instance.new("Highlight")
	visHl.Name = "LV_Vis"
	visHl.Adornee = visModel
	visHl.Parent = hlParent
	local hidHl = Instance.new("Highlight")
	hidHl.Name = "LV_Hid"
	hidHl.Adornee = hidModel
	hidHl.Parent = hlParent
	local entry = {
		visModel = visModel,
		hidModel = hidModel,
		visHl = visHl,
		hidHl = hidHl,
		pairs = pairsList,
		parts = #sources,
		at = os.clock(),
		override = config.chamOverride == true,
		character = character,
		sig = Cham.partsSig(sources),
		dirty = false,
		dirtyAt = 0,
		checkAt = os.clock(),
	}
	if entry.override then
		Cham.hideOriginal(character, entry)
	end
	Cham.watchCharacter(character, entry)
	Cham.entries[character] = entry
	Cham.paint(entry, looks)
end
function Cham.ensure(character)
	local entry = Cham.entries[character]
	local looks = Cham.looks(Cham.lastConfig)
	if entry and entry.visModel and entry.visModel.Parent and entry.hidModel and entry.hidModel.Parent then
		local now = os.clock()
		if now - entry.at > 3 then
			entry.at = now
			if #Cham.collectParts(character) ~= entry.parts then
				Cham.build(character)
				return
			end
		end
		Cham.paint(entry, looks)
		return
	end
	Cham.build(character)
end
function Cham.distance(character)
	local cam = workspace.CurrentCamera
	local root = character:FindFirstChild("HumanoidRootPart", true)
		or character:FindFirstChild("HitboxBody", true)
		or character:FindFirstChild("Torso", true)
		or character:FindFirstChild("UpperTorso", true)
		or character:FindFirstChild("PhysicalHitboxBody", true)
	if cam and root then
		return (cam.CFrame.Position - root.Position).Magnitude
	end
	return Esp.getCharacterDistance(character) or 0
end
function Cham.refreshSet(config)
	local maxDist = config.chamDistance or 250
	local ranked = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and not Filter.shouldSkip(player, config) then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if character and (not humanoid or humanoid.Health > 0) then
				local distance = Cham.distance(character)
				if distance <= maxDist then
					table.insert(ranked, { character = character, distance = distance })
				end
			end
		end
	end
	if #ranked > Cham.MAX then
		table.sort(ranked, function(a, b)
			return a.distance < b.distance
		end)
	end
	local keep = {}
	local limit = math.min(#ranked, Cham.MAX)
	for i = 1, limit do
		keep[ranked[i].character] = true
	end
	for character in pairs(Cham.entries) do
		if not keep[character] then
			Cham.destroyEntry(character)
		end
	end
	for character in pairs(keep) do
		if not Cham.entries[character] then
			Cham.build(character)
		end
	end
end
function Cham.update(config)
	if type(config) ~= "table" or not config.espChams then
		Cham.clear()
		return
	end
	if Cham.worldHidden then
		Cham.lastConfig = config
		return
	end
	Cham.lastConfig = config
	if Cham.activeStyle then
		config.chamStyle = Cham.activeStyle
	end
	local key = Cham.rebuildKey(config)
	if Cham.buildKey ~= key then
		Cham.buildKey = key
		for character in pairs(Cham.entries) do
			Cham.destroyEntry(character)
		end
		Cham.rankAt = 0
	end
	local now = os.clock()
	if now - Cham.rankAt >= 0.4 then
		Cham.rankAt = now
		Cham.refreshSet(config)
	end
	local looks = Cham.looks(config)
	local rebuild = {}
	for character, entry in pairs(Cham.entries) do
		local due = entry.dirty and now - (entry.dirtyAt or 0) >= 0.12
		local periodic = now - (entry.checkAt or 0) >= 1.2
		if due or periodic then
			entry.checkAt = now
			local sources = Cham.collectParts(character)
			local sig = Cham.partsSig(sources)
			if sig ~= entry.sig then
				table.insert(rebuild, character)
			else
				entry.dirty = false
			end
		end
	end
	for i = 1, #rebuild do
		Cham.build(rebuild[i])
	end
	Cham.paintFlip = not Cham.paintFlip
	if looks.rainbow or looks.wire or Cham.paintFlip then
		for _, entry in pairs(Cham.entries) do
			Cham.paint(entry, looks)
		end
	end
	Cham.ensureSelfBind()
end
Cham.SELF_MODES = {
	{ id = "off", label = "Off" },
	{ id = "hide", label = "Hide Arms" },
	{ id = "rainbow", label = "Rainbow Arms" },
}
Cham.SELF_LIMB_NAMES = {
	LeftHand = true,
	RightHand = true,
	LeftLowerArm = true,
	RightLowerArm = true,
	LeftUpperArm = true,
	RightUpperArm = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	LeftGlove = true,
	RightGlove = true,
}
Cham.selfSaved = {}
Cham.selfHl = nil
Cham.selfModel = nil
Cham.selfPairs = nil
Cham.selfSig = nil
Cham.selfActive = false
Cham.selfBound = false
function Cham.isSelfLimb(inst)
	if not inst or not inst:IsA("BasePart") then
		return false
	end
	if inst:FindFirstAncestor("LV_Chams") or inst:FindFirstAncestor("LV_SelfChams") then
		return false
	end
	if Cham.skipName(inst.Name) then
		return false
	end
	local accessory = inst:FindFirstAncestorOfClass("Accessory")
	local name = accessory and accessory.Name or inst.Name
	if Cham.SELF_LIMB_NAMES[name] then
		return true
	end
	local lower = string.lower(name)
	if string.find(lower, "torso", 1, true) or string.find(lower, "head", 1, true) or string.find(lower, "leg", 1, true) or string.find(lower, "foot", 1, true) then
		return false
	end
	return string.find(lower, "arm", 1, true) ~= nil
		or string.find(lower, "hand", 1, true) ~= nil
		or string.find(lower, "sleeve", 1, true) ~= nil
		or string.find(lower, "glove", 1, true) ~= nil
		or string.find(lower, "wrist", 1, true) ~= nil
		or string.find(lower, "finger", 1, true) ~= nil
		or string.find(lower, "thumb", 1, true) ~= nil
end
function Cham.collectSelfLimbs()
	local now = os.clock()
	if Cham.selfLimbCache and now - (Cham.selfLimbAt or 0) < 0.2 then
		return Cham.selfLimbCache
	end
	local roots = {
		LocalPlayer.Character,
		workspace:FindFirstChild("ViewModels"),
		workspace.CurrentCamera,
	}
	local seen = {}
	local parts = {}
	for r = 1, #roots do
		local root = roots[r]
		if root then
			for _, inst in ipairs(root:GetDescendants()) do
				if not seen[inst] and Cham.isSelfLimb(inst) then
					seen[inst] = true
					table.insert(parts, inst)
				end
			end
		end
	end
	Cham.selfLimbCache = parts
	Cham.selfLimbAt = now
	return parts
end
function Cham.restoreSelfHidden()
	for inst, saved in pairs(Cham.selfSaved) do
		if inst.Parent then
			pcall(function()
				if type(saved) == "table" then
					if saved.kind == "part" then
						inst.LocalTransparencyModifier = saved.ltm or 0
						inst.Transparency = saved.t or 0
					elseif saved.kind == "tex" then
						inst.Transparency = saved.t or 0
					elseif saved.kind == "fx" then
						inst.Enabled = saved.on == true
					end
				elseif type(saved) == "number" then
					inst.LocalTransparencyModifier = saved
				end
			end)
		end
	end
	Cham.selfSaved = {}
end
function Cham.destroySelfRainbow()
	if Cham.selfHl then
		pcall(function()
			Cham.selfHl:Destroy()
		end)
		Cham.selfHl = nil
	end
	if Cham.selfModel then
		pcall(function()
			Cham.selfModel:Destroy()
		end)
		Cham.selfModel = nil
	end
	Cham.selfPairs = nil
	Cham.selfSig = nil
end
function Cham.clearSelf()
	Cham.destroySelfRainbow()
	Cham.restoreSelfHidden()
	Cham.selfActive = false
end
function Cham.releaseSelfBind()
	if Cham.selfBound then
		pcall(function()
			RunService:UnbindFromRenderStep("LV_SelfCham")
		end)
		Cham.selfBound = false
	end
end
function Cham.ensureSelfBind()
	if Cham.selfBound then
		return
	end
	Cham.selfBound = true
	RunService:BindToRenderStep("LV_SelfCham", Enum.RenderPriority.Last.Value + 20, function()
		local config = Cham.lastConfig
		if type(config) ~= "table" or not config.espChams then
			return
		end
		Cham.updateSelf(config, Cham.looks(config))
	end)
end
function Cham.hideSelfLimbs(parts)
	for i = 1, #parts do
		local part = parts[i]
		Cham.hideOne(part, Cham.selfSaved)
		for _, child in ipairs(part:GetChildren()) do
			if child:IsA("Decal") or child:IsA("Texture") or child:IsA("ParticleEmitter") then
				Cham.hideOne(child, Cham.selfSaved)
			end
		end
	end
	for inst, saved in pairs(Cham.selfSaved) do
		if inst.Parent and type(saved) == "table" and saved.kind == "part" then
			if inst.LocalTransparencyModifier < 1 then
				inst.LocalTransparencyModifier = 1
			end
			if inst.Transparency < 1 then
				inst.Transparency = 1
			end
		end
	end
end
function Cham.selfPartsSig(parts)
	local bits = { tostring(#parts) }
	for i = 1, #parts do
		bits[i + 1] = parts[i].Name
	end
	return table.concat(bits, "|")
end
function Cham.buildSelfRainbow(parts, looks)
	Cham.destroySelfRainbow()
	local folder = Cham.folderInst()
	local hlParent = Cham.hlFolder()
	if not folder or not hlParent or #parts == 0 then
		return
	end
	local model = Instance.new("Model")
	model.Name = "LV_SelfChams"
	model.Parent = folder
	local pairsList = {}
	for i = 1, #parts do
		local ok, copy = pcall(Cham.copyPart, parts[i], looks.material, looks.vis)
		if ok and copy then
			copy.Parent = model
			table.insert(pairsList, { src = parts[i], dst = copy })
		end
	end
	if #pairsList == 0 then
		model:Destroy()
		return
	end
	local hl = Instance.new("Highlight")
	hl.Name = "LV_Self"
	hl.Adornee = model
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = hlParent
	Cham.selfModel = model
	Cham.selfHl = hl
	Cham.selfPairs = pairsList
	Cham.selfSig = Cham.selfPartsSig(parts)
end
function Cham.paintSelfRainbow(looks, config)
	local hl = Cham.selfHl
	if not hl or not hl.Parent then
		return
	end
	local color = Color3.fromHSV((os.clock() * ((config.chamRainbowSpeed or 70) / 50)) % 1, 1, 1)
	hl.Enabled = true
	hl.FillColor = color
	hl.OutlineColor = color
	hl.FillTransparency = 0.22
	hl.OutlineTransparency = 0.05
	local pairsList = Cham.selfPairs
	if not pairsList then
		return
	end
	for i = 1, #pairsList do
		local dst = pairsList[i].dst
		if dst and dst.Parent then
			dst.Color = color
			dst.Transparency = 0.08
			dst.LocalTransparencyModifier = 0
		end
	end
end
function Cham.updateSelf(config, looks)
	local mode = config.chamSelf or "off"
	if mode == "off" then
		if Cham.selfActive then
			Cham.clearSelf()
		end
		return
	end
	Cham.selfActive = true
	local parts = Cham.collectSelfLimbs()
	if mode == "hide" then
		Cham.destroySelfRainbow()
		Cham.hideSelfLimbs(parts)
		return
	end
	local sig = Cham.selfPartsSig(parts)
	if Cham.selfSig ~= sig or not Cham.selfModel or not Cham.selfModel.Parent then
		Cham.buildSelfRainbow(parts, looks or Cham.looks(config))
	end
	Cham.hideSelfLimbs(parts)
	Cham.paintSelfRainbow(looks or Cham.looks(config), config)
end
return Cham
end)()
local Unlock = (function()
local Unlock = {}
Unlock.PATHS = {
	"features/unlock_all.lua",
	"unlock_all.lua",
	"scripts/unlock_all.lua",
}
Unlock.running = false
Unlock.statusText = "Ready"
Unlock.statusLabel = nil
Unlock.SOURCE = [==[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerScripts = player.PlayerScripts
local controllers = playerScripts.Controllers
local EnumLibrary = require(ReplicatedStorage.Modules:WaitForChild("EnumLibrary", 10))
if EnumLibrary then EnumLibrary:WaitForEnumBuilder() end
local CosmeticLibrary = require(ReplicatedStorage.Modules:WaitForChild("CosmeticLibrary", 10))
local ItemLibrary = require(ReplicatedStorage.Modules:WaitForChild("ItemLibrary", 10))
local DataController = require(controllers:WaitForChild("PlayerDataController", 10))
local equipped, favorites = {}, {}
local constructingWeapon, viewingProfile = nil, nil
local lastUsedWeapon = nil
local cosmeticsCache = CosmeticLibrary.Cosmetics
local ownsCosmeticCache = {}
local stringLower = string.lower
local stringFind = string.find
local tableClone = table.clone
local function safeReplicate(key)
    task.spawn(function()
        task.wait(0.1)
        pcall(function()
            local current = DataController.CurrentData
            if current and current.Replicate then
                current:Replicate(key)
            end
        end)
    end)
end
local function cloneCosmetic(name, cosmeticType, options)
    local base = cosmeticsCache[name]
    if not base then return nil end
    local data = {}
    local keyCount = 0
    for key, value in pairs(base) do
        data[key] = value
        keyCount = keyCount + 1
    end
    data.Name = name
    data.Type = data.Type or cosmeticType
    data.Seed = data.Seed or math.random(1, 1000000)
    if EnumLibrary then
        local success, enumId = pcall(EnumLibrary.ToEnum, EnumLibrary, name)
        if success and enumId then
            data.Enum = enumId
            data.ObjectID = data.ObjectID or enumId
        end
    end
    if options then
        if options.inverted ~= nil then data.Inverted = options.inverted end
        if options.favoritesOnly ~= nil then data.OnlyUseFavorites = options.favoritesOnly end
    end
    return data
end
local saveFile = "unlockall/config.json"
local function saveConfig()
    if not writefile then return end
    pcall(function()
        local config = {equipped = {}, favorites = favorites}
        for weapon, cosmetics in pairs(equipped) do
            local weaponConfig = {}
            for cosmeticType, cosmeticData in pairs(cosmetics) do
                if cosmeticData and cosmeticData.Name then
                    weaponConfig[cosmeticType] = {
                        name = cosmeticData.Name,
                        seed = cosmeticData.Seed,
                        inverted = cosmeticData.Inverted
                    }
                end
            end
            config.equipped[weapon] = weaponConfig
        end
        makefolder("unlockall")
        writefile(saveFile, HttpService:JSONEncode(config))
    end)
end
local function loadConfig()
    if not readfile or not isfile or not isfile(saveFile) then return end
    pcall(function()
        local config = HttpService:JSONDecode(readfile(saveFile))
        if config.equipped then
            for weapon, cosmetics in pairs(config.equipped) do
                equipped[weapon] = {}
                for cosmeticType, cosmeticData in pairs(cosmetics) do
                    local cloned = cloneCosmetic(cosmeticData.name, cosmeticType, {inverted = cosmeticData.inverted})
                    if cloned then
                        cloned.Seed = cosmeticData.seed
                        equipped[weapon][cosmeticType] = cloned
                    end
                end
            end
        end
        favorites = config.favorites or {}
    end)
end
local function isSkin(cosmeticName)
    local cosmetic = cosmeticsCache[cosmeticName]
    return cosmetic and cosmetic.Type == "Skin"
end
CosmeticLibrary.OwnsCosmeticNormally = function(self, inventory, name, weapon)
    return isSkin(name)
end
CosmeticLibrary.OwnsCosmeticUniversally = function(self, inventory, name, weapon)
    return isSkin(name)
end
CosmeticLibrary.OwnsCosmeticForWeapon = function(self, inventory, name, weapon)
    return isSkin(name)
end
local originalOwnsCosmetic = CosmeticLibrary.OwnsCosmetic
CosmeticLibrary.OwnsCosmetic = function(self, inventory, name, weapon)
    if stringFind(name, "MISSING_") then return originalOwnsCosmetic(self, inventory, name, weapon) end
    if isSkin(name) then return true end
    return originalOwnsCosmetic(self, inventory, name, weapon)
end
local originalGet = DataController.Get
DataController.Get = function(self, key)
    local data = originalGet(self, key)
    if key == "CosmeticInventory" then
        local proxy = {}
        if data then
            for k, v in pairs(data) do
                if isSkin(k) then proxy[k] = v end
            end
        end
        return setmetatable(proxy, {__index = function(t, k)
            return isSkin(k) or nil
        end})
    end
    if key == "FavoritedCosmetics" then
        local result = data and tableClone(data) or {}
        for weapon, favs in pairs(favorites) do
            result[weapon] = result[weapon] or {}
            for name, isFav in pairs(favs) do
                if isSkin(name) then result[weapon][name] = isFav end
            end
        end
        return result
    end
    return data
end
local originalGetWeaponData = DataController.GetWeaponData
DataController.GetWeaponData = function(self, weaponName)
    local data = originalGetWeaponData(self, weaponName)
    if not data then return nil end
    local merged = {}
    for key, value in pairs(data) do
        merged[key] = value
    end
    merged.Name = weaponName
    local weaponEquipped = equipped[weaponName]
    if weaponEquipped then
        for cosmeticType, cosmeticData in pairs(weaponEquipped) do
            if cosmeticType == "Skin" then merged[cosmeticType] = cosmeticData end
        end
    end
    return merged
end
local FighterController
pcall(function() FighterController = require(controllers:WaitForChild("FighterController", 10)) end)
if hookmetamethod then
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local dataRemotes = remotes and remotes:FindFirstChild("Data")
    local equipRemote = dataRemotes and dataRemotes:FindFirstChild("EquipCosmetic")
    local favoriteRemote = dataRemotes and dataRemotes:FindFirstChild("FavoriteCosmetic")
    local replicationRemotes = remotes and remotes:FindFirstChild("Replication")
    local fighterRemotes = replicationRemotes and replicationRemotes:FindFirstChild("Fighter")
    local useItemRemote = fighterRemotes and fighterRemotes:FindFirstChild("UseItem")
    if equipRemote then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            if getnamecallmethod() ~= "FireServer" then return oldNamecall(self, ...) end
            local args = {...}
            if useItemRemote and self == useItemRemote then
                local objectID = args[1]
                if FighterController then
                    pcall(function()
                        local fighter = FighterController:GetFighter(player)
                        if fighter and fighter.Items then
                            for _, item in pairs(fighter.Items) do
                                if item:Get("ObjectID") == objectID then
                                    lastUsedWeapon = item.Name
                                    break
                                end
                            end
                        end
                    end)
                end
            end
            if self == equipRemote then
                local weaponName, cosmeticType, cosmeticName, options = args[1], args[2], args[3], args[4] or {}
                if cosmeticType ~= "Skin" then return oldNamecall(self, ...) end
                if cosmeticName and cosmeticName ~= "None" and cosmeticName ~= "" then
                    local inventory = DataController:Get("CosmeticInventory")
                    if inventory and rawget(inventory, cosmeticName) then return oldNamecall(self, ...) end
                end
                equipped[weaponName] = equipped[weaponName] or {}
                if not cosmeticName or cosmeticName == "None" or cosmeticName == "" then
                    equipped[weaponName][cosmeticType] = nil
                    if not next(equipped[weaponName]) then equipped[weaponName] = nil end
                else
                    local cloned = cloneCosmetic(cosmeticName, cosmeticType, {inverted = options.IsInverted, favoritesOnly = options.OnlyUseFavorites})
                    if cloned then equipped[weaponName][cosmeticType] = cloned end
                end
                safeReplicate("WeaponInventory")
                task.defer(saveConfig)
                return
            end
            if self == favoriteRemote then
                if isSkin(args[2]) then
                    favorites[args[1]] = favorites[args[1]] or {}
                    favorites[args[1]][args[2]] = args[3] or nil
                    saveConfig()
                    task.spawn(function()
                        safeReplicate("FavoritedCosmetics")
                    end)
                end
                return
            end
            return oldNamecall(self, ...)
        end)
    end
end
local ClientItem
pcall(function() ClientItem = require(player.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem) end)
if ClientItem and ClientItem._CreateViewModel then
    local originalCreateViewModel = ClientItem._CreateViewModel
    ClientItem._CreateViewModel = function(self, viewmodelRef)
        local weaponName = self.Name
        local weaponPlayer = self.ClientFighter and self.ClientFighter.Player
        constructingWeapon = (weaponPlayer == player) and weaponName or nil
        if weaponPlayer == player and equipped[weaponName] and equipped[weaponName].Skin and viewmodelRef then
            local dataKey = self:ToEnum("Data")
            local skinKey = self:ToEnum("Skin")
            local nameKey = self:ToEnum("Name")
            if viewmodelRef[dataKey] then
                viewmodelRef[dataKey][skinKey] = equipped[weaponName].Skin
                viewmodelRef[dataKey][nameKey] = equipped[weaponName].Skin.Name
            elseif viewmodelRef.Data then
                viewmodelRef.Data.Skin = equipped[weaponName].Skin
                viewmodelRef.Data.Name = equipped[weaponName].Skin.Name
            end
        end
        local result = originalCreateViewModel(self, viewmodelRef)
        constructingWeapon = nil
        return result
    end
end
local viewModelModule = player.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem:FindFirstChild("ClientViewModel")
if viewModelModule then
    local ClientViewModel = require(viewModelModule)
    local originalNew = ClientViewModel.new
    ClientViewModel.new = function(replicatedData, clientItem)
        local weaponPlayer = clientItem.ClientFighter and clientItem.ClientFighter.Player
        local weaponName = constructingWeapon or clientItem.Name
        if weaponPlayer == player and equipped[weaponName] then
            local ReplicatedClass = require(ReplicatedStorage.Modules.ReplicatedClass)
            local dataKey = ReplicatedClass:ToEnum("Data")
            replicatedData[dataKey] = replicatedData[dataKey] or {}
            local cosmetics = equipped[weaponName]
            if cosmetics.Skin then replicatedData[dataKey][ReplicatedClass:ToEnum("Skin")] = cosmetics.Skin end
        end
        local result = originalNew(replicatedData, clientItem)
        return result
    end
end
local originalGetViewModelImage = ItemLibrary.GetViewModelImageFromWeaponData
ItemLibrary.GetViewModelImageFromWeaponData = function(self, weaponData, highRes)
    if not weaponData then return originalGetViewModelImage(self, weaponData, highRes) end
    local weaponName = weaponData.Name
    local weaponEquipped = equipped[weaponName]
    local shouldShowSkin = (weaponData.Skin and weaponEquipped and weaponData.Skin == weaponEquipped.Skin) or (viewingProfile == player and weaponEquipped and weaponEquipped.Skin)
    if shouldShowSkin and weaponEquipped and weaponEquipped.Skin then
        local skinInfo = self.ViewModels[weaponEquipped.Skin.Name]
        if skinInfo then return skinInfo[highRes and "ImageHighResolution" or "Image"] or skinInfo.Image end
    end
    return originalGetViewModelImage(self, weaponData, highRes)
end
local function isCharm(cosmeticName)
    local cosmetic = cosmeticsCache[cosmeticName]
    return cosmetic and (cosmetic.Type == "Charm" or stringLower(cosmeticName):find("charm"))
end
local originalOwnsCosmeticCharm = CosmeticLibrary.OwnsCosmetic
CosmeticLibrary.OwnsCosmetic = function(self, inventory, name, weapon)
    if stringFind(name, "MISSING_") then return originalOwnsCosmeticCharm(self, inventory, name, weapon) end
    if isCharm(name) then return true end
    return originalOwnsCosmeticCharm(self, inventory, name, weapon)
end
local originalGetCharm = DataController.Get
DataController.Get = function(self, key)
    local data = originalGetCharm(self, key)
    if key == "CosmeticInventory" then
        local proxy = {}
        if data then
            for k, v in pairs(data) do
                if isCharm(k) then proxy[k] = v end
            end
        end
        return setmetatable(proxy, {__index = function(t, k)
            return isCharm(k) or nil
        end})
    end
    if key == "FavoritedCosmetics" then
        local result = data and tableClone(data) or {}
        for weapon, favs in pairs(favorites) do
            result[weapon] = result[weapon] or {}
            for name, isFav in pairs(favs) do
                if isCharm(name) then result[weapon][name] = isFav end
            end
        end
        return result
    end
    return data
end
local originalGetWeaponDataCharm = DataController.GetWeaponData
DataController.GetWeaponData = function(self, weaponName)
    local data = originalGetWeaponDataCharm(self, weaponName)
    if not data then return nil end
    local merged = {}
    for key, value in pairs(data) do
        merged[key] = value
    end
    merged.Name = weaponName
    local weaponEquipped = equipped[weaponName]
    if weaponEquipped then
        for cosmeticType, cosmeticData in pairs(weaponEquipped) do
            if cosmeticType == "Charm" then merged[cosmeticType] = cosmeticData end
        end
    end
    return merged
end
if hookmetamethod then
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local dataRemotes = remotes and remotes:FindFirstChild("Data")
    local equipRemote = dataRemotes and dataRemotes:FindFirstChild("EquipCosmetic")
    local favoriteRemote = dataRemotes and dataRemotes:FindFirstChild("FavoriteCosmetic")
    if equipRemote then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            if getnamecallmethod() ~= "FireServer" then return oldNamecall(self, ...) end
            local args = {...}
            if self == equipRemote then
                local weaponName, cosmeticType, cosmeticName, options = args[1], args[2], args[3], args[4] or {}
                if cosmeticType ~= "Charm" then return oldNamecall(self, ...) end
                if cosmeticName and cosmeticName ~= "None" and cosmeticName ~= "" then
                    local inventory = DataController:Get("CosmeticInventory")
                    if inventory and rawget(inventory, cosmeticName) then return oldNamecall(self, ...) end
                end
                equipped[weaponName] = equipped[weaponName] or {}
                if not cosmeticName or cosmeticName == "None" or cosmeticName == "" then
                    equipped[weaponName][cosmeticType] = nil
                    if not next(equipped[weaponName]) then equipped[weaponName] = nil end
                else
                    local cloned = cloneCosmetic(cosmeticName, cosmeticType, {inverted = options.IsInverted, favoritesOnly = options.OnlyUseFavorites})
                    if cloned then equipped[weaponName][cosmeticType] = cloned end
                end
                safeReplicate("WeaponInventory")
                task.defer(saveConfig)
                return
            end
            if self == favoriteRemote then
                if isCharm(args[2]) then
                    favorites[args[1]] = favorites[args[1]] or {}
                    favorites[args[1]][args[2]] = args[3] or nil
                    saveConfig()
                    task.spawn(function()
                        safeReplicate("FavoritedCosmetics")
                    end)
                end
                return
            end
            return oldNamecall(self, ...)
        end)
    end
end
if ClientItem and ClientItem._CreateViewModel then
    local originalCreateViewModelCharm = ClientItem._CreateViewModel
    ClientItem._CreateViewModel = function(self, viewmodelRef)
        local weaponName = self.Name
        local weaponPlayer = self.ClientFighter and self.ClientFighter.Player
        constructingWeapon = (weaponPlayer == player) and weaponName or nil
        if weaponPlayer == player and equipped[weaponName] and equipped[weaponName].Charm and viewmodelRef then
            local dataKey = self:ToEnum("Data")
            local charmKey = self:ToEnum("Charm")
            local nameKey = self:ToEnum("Name")
            if viewmodelRef[dataKey] then
                viewmodelRef[dataKey][charmKey] = equipped[weaponName].Charm
                viewmodelRef[dataKey][nameKey] = equipped[weaponName].Charm.Name
            elseif viewmodelRef.Data then
                viewmodelRef.Data.Charm = equipped[weaponName].Charm
                viewmodelRef.Data.Name = equipped[weaponName].Charm.Name
            end
        end
        local result = originalCreateViewModelCharm(self, viewmodelRef)
        constructingWeapon = nil
        return result
    end
end
if viewModelModule then
    local ClientViewModel = require(viewModelModule)
    if ClientViewModel.GetCharm then
        local originalGetCharmFunc = ClientViewModel.GetCharm
        ClientViewModel.GetCharm = function(self)
            local weaponName = self.ClientItem and self.ClientItem.Name
            local weaponPlayer = self.ClientItem and self.ClientItem.ClientFighter and self.ClientItem.ClientFighter.Player
            if weaponName and weaponPlayer == player and equipped[weaponName] and equipped[weaponName].Charm then
                return equipped[weaponName].Charm
            end
            return originalGetCharmFunc(self)
        end
    end
    local originalNewCharm = ClientViewModel.new
    ClientViewModel.new = function(replicatedData, clientItem)
        local weaponPlayer = clientItem.ClientFighter and clientItem.ClientFighter.Player
        local weaponName = constructingWeapon or clientItem.Name
        if weaponPlayer == player and equipped[weaponName] then
            local ReplicatedClass = require(ReplicatedStorage.Modules.ReplicatedClass)
            local dataKey = ReplicatedClass:ToEnum("Data")
            replicatedData[dataKey] = replicatedData[dataKey] or {}
            local cosmetics = equipped[weaponName]
            if cosmetics.Charm then replicatedData[dataKey][ReplicatedClass:ToEnum("Charm")] = cosmetics.Charm end
        end
        local result = originalNewCharm(replicatedData, clientItem)
        return result
    end
end
local function isDanceOrEmote(cosmeticName)
    local cosmetic = cosmeticsCache[cosmeticName]
    local lowerName = stringLower(cosmeticName)
    return cosmetic and (cosmetic.Type == "Dance" or cosmetic.Type == "Emote" or stringFind(lowerName, "dance") or stringFind(lowerName, "emote"))
end
local originalOwnsCosmeticDance = CosmeticLibrary.OwnsCosmetic
CosmeticLibrary.OwnsCosmetic = function(self, inventory, name, weapon)
    if stringFind(name, "MISSING_") then return originalOwnsCosmeticDance(self, inventory, name, weapon) end
    if isDanceOrEmote(name) then return true end
    return originalOwnsCosmeticDance(self, inventory, name, weapon)
end
local originalGetDance = DataController.Get
DataController.Get = function(self, key)
    local data = originalGetDance(self, key)
    if key == "CosmeticInventory" then
        local proxy = {}
        if data then
            for k, v in pairs(data) do
                if isDanceOrEmote(k) then proxy[k] = v end
            end
        end
        return setmetatable(proxy, {__index = function(t, k)
            return isDanceOrEmote(k) or nil
        end})
    end
    if key == "FavoritedCosmetics" then
        local result = data and tableClone(data) or {}
        for weapon, favs in pairs(favorites) do
            result[weapon] = result[weapon] or {}
            for name, isFav in pairs(favs) do
                if isDanceOrEmote(name) then result[weapon][name] = isFav end
            end
        end
        return result
    end
    return data
end
local originalGetWeaponDataDance = DataController.GetWeaponData
DataController.GetWeaponData = function(self, weaponName)
    local data = originalGetWeaponDataDance(self, weaponName)
    if not data then return nil end
    local merged = {}
    for key, value in pairs(data) do
        merged[key] = value
    end
    merged.Name = weaponName
    return merged
end
if hookmetamethod then
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local dataRemotes = remotes and remotes:FindFirstChild("Data")
    local equipRemote = dataRemotes and dataRemotes:FindFirstChild("EquipCosmetic")
    local favoriteRemote = dataRemotes and dataRemotes:FindFirstChild("FavoriteCosmetic")
    if equipRemote then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            if getnamecallmethod() ~= "FireServer" then return oldNamecall(self, ...) end
            local args = {...}
            if self == equipRemote then
                local weaponName, cosmeticType, cosmeticName, options = args[1], args[2], args[3], args[4] or {}
                if cosmeticType == "Dance" or cosmeticType == "Emote" or (cosmeticName and isDanceOrEmote(cosmeticName)) then
                    equipped.Dances = equipped.Dances or {}
                    if not cosmeticName or cosmeticName == "None" or cosmeticName == "" then
                        equipped.Dances[cosmeticType] = nil
                    else
                        local cloned = cloneCosmetic(cosmeticName, cosmeticType, {inverted = options.IsInverted, favoritesOnly = options.OnlyUseFavorites})
                        if cloned then equipped.Dances[cosmeticType] = cloned end
                    end
                    safeReplicate("CosmeticInventory")
                    task.defer(saveConfig)
                    return
                end
                return oldNamecall(self, ...)
            end
            if self == favoriteRemote then
                if isDanceOrEmote(args[2]) then
                    favorites[args[1]] = favorites[args[1]] or {}
                    favorites[args[1]][args[2]] = args[3] or nil
                    saveConfig()
                    task.spawn(function()
                        safeReplicate("FavoritedCosmetics")
                    end)
                end
                return
            end
            return oldNamecall(self, ...)
        end)
    end
end
local EmoteController
pcall(function()
    EmoteController = require(controllers:WaitForChild("EmoteController", 10))
    if EmoteController and EmoteController.GetEmotes then
        local originalGetEmotes = EmoteController.GetEmotes
        EmoteController.GetEmotes = function(self)
            local emotes = originalGetEmotes(self)
            for name, cosmetic in pairs(cosmeticsCache) do
                if isDanceOrEmote(name) and not emotes[name] then
                    emotes[name] = {
                        Name = name,
                        Type = cosmetic.Type,
                        ObjectID = cosmetic.ObjectID,
                        Enum = cosmetic.Enum
                    }
                end
            end
            return emotes
        end
    end
end)
local function isWrap(cosmeticName)
    local cosmetic = cosmeticsCache[cosmeticName]
    local lowerName = stringLower(cosmeticName)
    return cosmetic and (cosmetic.Type == "Wrap" or cosmetic.Type == "Wrapping" or stringFind(lowerName, "wrap"))
end
local originalOwnsCosmeticWrap = CosmeticLibrary.OwnsCosmetic
CosmeticLibrary.OwnsCosmetic = function(self, inventory, name, weapon)
    if stringFind(name, "MISSING_") then return originalOwnsCosmeticWrap(self, inventory, name, weapon) end
    if isWrap(name) then return true end
    return originalOwnsCosmeticWrap(self, inventory, name, weapon)
end
local originalGetWrapVer = DataController.Get
DataController.Get = function(self, key)
    local data = originalGetWrapVer(self, key)
    if key == "CosmeticInventory" then
        local proxy = {}
        if data then
            for k, v in pairs(data) do
                if isWrap(k) then proxy[k] = v end
            end
        end
        return setmetatable(proxy, {__index = function(t, k)
            return isWrap(k) or nil
        end})
    end
    if key == "FavoritedCosmetics" then
        local result = data and tableClone(data) or {}
        for weapon, favs in pairs(favorites) do
            result[weapon] = result[weapon] or {}
            for name, isFav in pairs(favs) do
                if isWrap(name) then result[weapon][name] = isFav end
            end
        end
        return result
    end
    return data
end
local originalGetWeaponDataWrap = DataController.GetWeaponData
DataController.GetWeaponData = function(self, weaponName)
    local data = originalGetWeaponDataWrap(self, weaponName)
    if not data then return nil end
    local merged = {}
    for key, value in pairs(data) do
        merged[key] = value
    end
    merged.Name = weaponName
    local weaponEquipped = equipped[weaponName]
    if weaponEquipped then
        for cosmeticType, cosmeticData in pairs(weaponEquipped) do
            if cosmeticType == "Wrap" or cosmeticType == "Wrapping" then merged[cosmeticType] = cosmeticData end
        end
    end
    return merged
end
if hookmetamethod then
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local dataRemotes = remotes and remotes:FindFirstChild("Data")
    local equipRemote = dataRemotes and dataRemotes:FindFirstChild("EquipCosmetic")
    local favoriteRemote = dataRemotes and dataRemotes:FindFirstChild("FavoriteCosmetic")
    if equipRemote then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            if getnamecallmethod() ~= "FireServer" then return oldNamecall(self, ...) end
            local args = {...}
            if self == equipRemote then
                local weaponName, cosmeticType, cosmeticName, options = args[1], args[2], args[3], args[4] or {}
                if cosmeticType ~= "Wrap" and cosmeticType ~= "Wrapping" then return oldNamecall(self, ...) end
                if cosmeticName and cosmeticName ~= "None" and cosmeticName ~= "" then
                    local inventory = DataController:Get("CosmeticInventory")
                    if inventory and rawget(inventory, cosmeticName) then return oldNamecall(self, ...) end
                end
                equipped[weaponName] = equipped[weaponName] or {}
                if not cosmeticName or cosmeticName == "None" or cosmeticName == "" then
                    equipped[weaponName][cosmeticType] = nil
                    if not next(equipped[weaponName]) then equipped[weaponName] = nil end
                else
                    local cloned = cloneCosmetic(cosmeticName, cosmeticType, {inverted = options.IsInverted, favoritesOnly = options.OnlyUseFavorites})
                    if cloned then equipped[weaponName][cosmeticType] = cloned end
                end
                safeReplicate("WeaponInventory")
                task.defer(saveConfig)
                return
            end
            if self == favoriteRemote then
                if isWrap(args[2]) then
                    favorites[args[1]] = favorites[args[1]] or {}
                    favorites[args[1]][args[2]] = args[3] or nil
                    saveConfig()
                    task.spawn(function()
                        safeReplicate("FavoritedCosmetics")
                    end)
                end
                return
            end
            return oldNamecall(self, ...)
        end)
    end
end
if ClientItem and ClientItem._CreateViewModel then
    local originalCreateViewModelWrap = ClientItem._CreateViewModel
    ClientItem._CreateViewModel = function(self, viewmodelRef)
        local weaponName = self.Name
        local weaponPlayer = self.ClientFighter and self.ClientFighter.Player
        constructingWeapon = (weaponPlayer == player) and weaponName or nil
        if weaponPlayer == player and equipped[weaponName] and equipped[weaponName].Wrap and viewmodelRef then
            local dataKey = self:ToEnum("Data")
            local wrapKey = self:ToEnum("Wrap")
            local nameKey = self:ToEnum("Name")
            if viewmodelRef[dataKey] then
                viewmodelRef[dataKey][wrapKey] = equipped[weaponName].Wrap
                viewmodelRef[dataKey][nameKey] = equipped[weaponName].Wrap.Name
            elseif viewmodelRef.Data then
                viewmodelRef.Data.Wrap = equipped[weaponName].Wrap
                viewmodelRef.Data.Name = equipped[weaponName].Wrap.Name
            end
        end
        local result = originalCreateViewModelWrap(self, viewmodelRef)
        constructingWeapon = nil
        return result
    end
end
if viewModelModule then
    local ClientViewModel = require(viewModelModule)
    if ClientViewModel.GetWrap then
        local originalGetWrapFunc = ClientViewModel.GetWrap
        ClientViewModel.GetWrap = function(self)
            local weaponName = self.ClientItem and self.ClientItem.Name
            local weaponPlayer = self.ClientItem and self.ClientItem.ClientFighter and self.ClientItem.ClientFighter.Player
            if weaponName and weaponPlayer == player and equipped[weaponName] and equipped[weaponName].Wrap then
                return equipped[weaponName].Wrap
            end
            return originalGetWrapFunc(self)
        end
    end
    local originalNewWrap = ClientViewModel.new
    ClientViewModel.new = function(replicatedData, clientItem)
        local weaponPlayer = clientItem.ClientFighter and clientItem.ClientFighter.Player
        local weaponName = constructingWeapon or clientItem.Name
        if weaponPlayer == player and equipped[weaponName] then
            local ReplicatedClass = require(ReplicatedStorage.Modules.ReplicatedClass)
            local dataKey = ReplicatedClass:ToEnum("Data")
            replicatedData[dataKey] = replicatedData[dataKey] or {}
            local cosmetics = equipped[weaponName]
            if cosmetics.Wrap then replicatedData[dataKey][ReplicatedClass:ToEnum("Wrap")] = cosmetics.Wrap end
        end
        local result = originalNewWrap(replicatedData, clientItem)
        if weaponPlayer == player and equipped[weaponName] and equipped[weaponName].Wrap and result._UpdateWrap then
            result:_UpdateWrap()
            task.delay(0.1, function() if not result._destroyed then result:_UpdateWrap() end end)
        end
        return result
    end
end
pcall(function()
    local ViewProfile = require(player.PlayerScripts.Modules.Pages.ViewProfile)
    if ViewProfile and ViewProfile.Fetch then
        local originalFetch = ViewProfile.Fetch
        ViewProfile.Fetch = function(self, targetPlayer)
            viewingProfile = targetPlayer
            return originalFetch(self, targetPlayer)
        end
    end
end)
local function isFinisher(cosmeticName)
    local cosmetic = cosmeticsCache[cosmeticName]
    local lowerName = stringLower(cosmeticName)
    return cosmetic and (cosmetic.Type == "Finisher" or stringFind(lowerName, "finisher"))
end
local function isUnlockedCosmetic(cosmeticName)
    if not cosmeticName or stringFind(cosmeticName, "MISSING_") then
        return false
    end
    return isSkin(cosmeticName)
        or isCharm(cosmeticName)
        or isDanceOrEmote(cosmeticName)
        or isWrap(cosmeticName)
        or isFinisher(cosmeticName)
end
local originalOwnsCosmeticUnified = CosmeticLibrary.OwnsCosmetic
CosmeticLibrary.OwnsCosmetic = function(self, inventory, name, weapon)
    if isUnlockedCosmetic(name) then return true end
    return originalOwnsCosmeticUnified(self, inventory, name, weapon)
end
CosmeticLibrary.OwnsCosmeticNormally = function(self, inventory, name, weapon)
    return isUnlockedCosmetic(name)
end
CosmeticLibrary.OwnsCosmeticUniversally = function(self, inventory, name, weapon)
    return isUnlockedCosmetic(name)
end
CosmeticLibrary.OwnsCosmeticForWeapon = function(self, inventory, name, weapon)
    return isUnlockedCosmetic(name)
end
local originalGetUnified = DataController.Get
DataController.Get = function(self, key)
    local data = originalGetUnified(self, key)
    if key == "CosmeticInventory" then
        local proxy = {}
        if data then
            for k, v in pairs(data) do
                proxy[k] = v
            end
        end
        return setmetatable(proxy, {__index = function(_, k)
            if isUnlockedCosmetic(k) then
                return true
            end
            return nil
        end})
    end
    if key == "FavoritedCosmetics" then
        local result = data and tableClone(data) or {}
        for weapon, favs in pairs(favorites) do
            result[weapon] = result[weapon] or {}
            for name, isFav in pairs(favs) do
                if isUnlockedCosmetic(name) then
                    result[weapon][name] = isFav
                end
            end
        end
        return result
    end
    return data
end
local originalGetWeaponDataUnified = DataController.GetWeaponData
DataController.GetWeaponData = function(self, weaponName)
    local data = originalGetWeaponDataUnified(self, weaponName)
    if not data then return nil end
    local merged = {}
    if data then
        for keyName, value in pairs(data) do
            merged[keyName] = value
        end
    end
    merged.Name = weaponName
    local weaponEquipped = equipped[weaponName]
    if weaponEquipped then
        for cosmeticType, cosmeticData in pairs(weaponEquipped) do
            merged[cosmeticType] = cosmeticData
        end
    end
    return merged
end
if hookmetamethod then
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local dataRemotes = remotes and remotes:FindFirstChild("Data")
    local equipRemote = dataRemotes and dataRemotes:FindFirstChild("EquipCosmetic")
    local favoriteRemote = dataRemotes and dataRemotes:FindFirstChild("FavoriteCosmetic")
    if equipRemote then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            if getnamecallmethod() ~= "FireServer" then return oldNamecall(self, ...) end
            local args = {...}
            if self == equipRemote then
                local weaponName, cosmeticType, cosmeticName, options = args[1], args[2], args[3], args[4] or {}
                if cosmeticType == "Finisher" or (cosmeticName and isFinisher(cosmeticName)) then
                    equipped.Finishers = equipped.Finishers or {}
                    if not cosmeticName or cosmeticName == "None" or cosmeticName == "" then
                        equipped.Finishers[weaponName] = nil
                    else
                        local cloned = cloneCosmetic(cosmeticName, cosmeticType, {inverted = options.IsInverted, favoritesOnly = options.OnlyUseFavorites})
                        if cloned then equipped.Finishers[weaponName] = cloned end
                    end
                    safeReplicate("CosmeticInventory")
                    task.defer(saveConfig)
                    return
                end
            end
            if self == favoriteRemote then
                if isFinisher(args[2]) then
                    favorites[args[1]] = favorites[args[1]] or {}
                    favorites[args[1]][args[2]] = args[3] or nil
                    saveConfig()
                    task.spawn(function()
                        safeReplicate("FavoritedCosmetics")
                    end)
                    return
                end
            end
            return oldNamecall(self, ...)
        end)
    end
end
loadConfig()
return "Unlock All Carried Out Succesfully"
]==]
function Unlock.isSupported()
	return typeof(hookmetamethod) == "function"
end
function Unlock.setStatus(text, isError)
	Unlock.statusText = text
	if Unlock.statusLabel then
		Unlock.statusLabel.Text = text
		Unlock.statusLabel.TextColor3 = isError
			and Color3.fromRGB(220, 90, 90)
			or Color3.fromRGB(140, 200, 140)
	end
end
function Unlock.getSource(loader)
	if Unlock.SOURCE then
		return Unlock.SOURCE, "unlock_all"
	end
	for _, path in ipairs(Unlock.PATHS) do
		local source, err = loader.readSource(path)
		if source then
			return source, path
		end
	end
	return nil, nil
end
function Unlock.run(loader)
	if Unlock.running then
		return
	end
	if not Unlock.isSupported() then
		Unlock.setStatus("hookmetamethod not supported", true)
		return
	end
	local source, path = Unlock.getSource(loader)
	if not source then
		Unlock.setStatus("unlock_all.lua not found", true)
		return
	end
	Unlock.running = true
	Unlock.setStatus("Running...", false)
	task.spawn(function()
		local ok, result = pcall(function()
			local chunk = loadstring(source, path or "unlock_all")
			if not chunk then
				error("failed to compile unlock_all.lua")
			end
			return chunk()
		end)
		if ok then
			local message = typeof(result) == "string" and result or "Unlock All activated"
			Unlock.setStatus(message, false)
		else
			Unlock.setStatus(tostring(result), true)
		end
		Unlock.running = false
	end)
end
return Unlock
end)()
local Performance = (function()
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Performance = {}
Performance.setFpsCapFn = nil
Performance.originalCap = nil
Performance.touched = false
Performance.graphicsActive = false
Performance.savedLighting = nil
Performance.savedRender = nil
Performance.savedTerrain = nil
Performance.instanceSaved = {}
Performance.watchConns = {}
Performance.sweepToken = 0
local VFX_ENABLED = {
	ParticleEmitter = true,
	Trail = true,
	Beam = true,
	Fire = true,
	Smoke = true,
	Sparkles = true,
	Highlight = true,
	Clouds = true,
}
function Performance.getFpsCap()
	local candidates = {
		typeof(getfpscap) == "function" and getfpscap or nil,
	}
	if typeof(getgenv) == "function" then
		local env = getgenv()
		if type(env) == "table" and typeof(env.getfpscap) == "function" then
			table.insert(candidates, env.getfpscap)
		end
	end
	if syn and typeof(syn.getfpscap) == "function" then
		table.insert(candidates, syn.getfpscap)
	end
	for _, fn in ipairs(candidates) do
		if typeof(fn) == "function" then
			local ok, value = pcall(fn)
			if ok and type(value) == "number" then
				return value
			end
		end
	end
	return nil
end
function Performance.captureOriginal()
	if Performance.originalCap ~= nil then
		return
	end
	Performance.originalCap = Performance.getFpsCap()
	if Performance.originalCap == nil then
		Performance.originalCap = 0
	end
end
function Performance.getSetFpsCap()
	if Performance.setFpsCapFn then
		return Performance.setFpsCapFn
	end
	local candidates = {
		setfpscap,
		set_fps_cap,
	}
	if typeof(getgenv) == "function" then
		local env = getgenv()
		if type(env) == "table" then
			table.insert(candidates, env.setfpscap)
			table.insert(candidates, env.set_fps_cap)
		end
	end
	if syn then
		table.insert(candidates, syn.setfpscap)
		table.insert(candidates, syn.set_fps_cap)
	end
	for _, fn in ipairs(candidates) do
		if typeof(fn) == "function" then
			Performance.setFpsCapFn = fn
			return fn
		end
	end
	return nil
end
function Performance.isFpsCapSupported()
	return Performance.getSetFpsCap() ~= nil
end
function Performance.applyFpsCap(config)
	local fn = Performance.getSetFpsCap()
	if not fn then
		return false
	end
	Performance.captureOriginal()
	Performance.touched = true
	if config.uncappedFps then
		pcall(fn, 0)
		pcall(fn, 999)
	else
		local cap = Performance.originalCap
		if type(cap) ~= "number" or cap <= 0 then
			pcall(fn, 0)
		else
			pcall(fn, cap)
		end
	end
	return true
end
function Performance.restoreFpsCap()
	local fn = Performance.getSetFpsCap()
	if not fn or not Performance.touched then
		return false
	end
	local cap = Performance.originalCap
	if type(cap) ~= "number" or cap <= 0 then
		pcall(fn, 0)
	else
		pcall(fn, cap)
	end
	return true
end
function Performance.shouldSkipAimbotScan(config, frameCounter)
	if not config.performanceMode then
		return false
	end
	return frameCounter % 2 == 0
end
function Performance.shouldSkipEspUpdate(config, frameCounter)
	return config.performanceMode and frameCounter % 2 ~= 0
end
local function disconnectWatchers()
	for _, conn in ipairs(Performance.watchConns) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	Performance.watchConns = {}
end
local function remember(inst, kind, value)
	if Performance.instanceSaved[inst] ~= nil then
		return
	end
	Performance.instanceSaved[inst] = { kind = kind, value = value }
end
local function isPlayerCharacter(inst)
	local current = inst
	while current and current ~= workspace do
		if current:IsA("Model") and Players:GetPlayerFromCharacter(current) then
			return true
		end
		current = current.Parent
	end
	return false
end
local function underSkip(inst, skip)
	if not skip then
		return isPlayerCharacter(inst)
	end
	local current = inst
	while current and current ~= workspace do
		if skip[current] then
			return true
		end
		current = current.Parent
	end
	return false
end
function Performance.stripInstance(inst, skip)
	if not inst or not inst.Parent then
		return
	end
	if inst:IsA("Terrain") then
		return
	end
	if inst:IsA("PostEffect") then
		remember(inst, "enabled", inst.Enabled)
		inst.Enabled = false
		return
	end
	if inst:IsA("Atmosphere") then
		remember(inst, "atmosphere", inst.Density)
		inst.Density = 0
		return
	end
	if VFX_ENABLED[inst.ClassName] or inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") or inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") then
		local ok, enabled = pcall(function()
			return inst.Enabled
		end)
		if ok then
			remember(inst, "enabled", enabled)
			inst.Enabled = false
		end
		return
	end
	if inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight") then
		local ok, shadows = pcall(function()
			return inst.Shadows
		end)
		if ok and shadows then
			remember(inst, "lightShadow", true)
			inst.Shadows = false
		end
		return
	end
	if inst:IsA("BasePart") and not underSkip(inst, skip) then
		if inst.CastShadow then
			remember(inst, "shadow", true)
			inst.CastShadow = false
		end
	end
end
local function applyRenderSettings()
	if not Performance.savedRender then
		local saved = {}
		pcall(function()
			saved.QualityLevel = settings().Rendering.QualityLevel
		end)
		pcall(function()
			saved.MeshPartDetailLevel = settings().Rendering.MeshPartDetailLevel
		end)
		pcall(function()
			saved.EnableFRM = settings().Rendering.EnableFRM
		end)
		pcall(function()
			local ugs = UserSettings():GetService("UserGameSettings")
			saved.SavedQualityLevel = ugs.SavedQualityLevel
		end)
		pcall(function()
			if typeof(gethiddenproperty) == "function" then
				saved.Technology = gethiddenproperty(Lighting, "Technology")
			end
		end)
		Performance.savedRender = saved
	end
	pcall(function()
		settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
	end)
	pcall(function()
		settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04
	end)
	pcall(function()
		settings().Rendering.EnableFRM = true
	end)
	pcall(function()
		UserSettings():GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
	end)
	pcall(function()
		if typeof(sethiddenproperty) == "function" then
			sethiddenproperty(Lighting, "Technology", Enum.Technology.Compatibility)
		end
	end)
end
local function restoreRenderSettings()
	local saved = Performance.savedRender
	if not saved then
		return
	end
	pcall(function()
		if saved.QualityLevel ~= nil then
			settings().Rendering.QualityLevel = saved.QualityLevel
		end
	end)
	pcall(function()
		if saved.MeshPartDetailLevel ~= nil then
			settings().Rendering.MeshPartDetailLevel = saved.MeshPartDetailLevel
		end
	end)
	pcall(function()
		if saved.EnableFRM ~= nil then
			settings().Rendering.EnableFRM = saved.EnableFRM
		end
	end)
	pcall(function()
		if saved.SavedQualityLevel ~= nil then
			UserSettings():GetService("UserGameSettings").SavedQualityLevel = saved.SavedQualityLevel
		end
	end)
	pcall(function()
		if saved.Technology ~= nil and typeof(sethiddenproperty) == "function" then
			sethiddenproperty(Lighting, "Technology", saved.Technology)
		end
	end)
	Performance.savedRender = nil
end
local function applyLightingCheap()
	if not Performance.savedLighting then
		Performance.savedLighting = {
			GlobalShadows = Lighting.GlobalShadows,
			FogEnd = Lighting.FogEnd,
			FogStart = Lighting.FogStart,
		}
	end
	Lighting.GlobalShadows = false
	Lighting.FogEnd = 1000000
	local terrain = workspace.Terrain
	if terrain and not Performance.savedTerrain then
		Performance.savedTerrain = {
			WaterWaveSize = terrain.WaterWaveSize,
			WaterWaveSpeed = terrain.WaterWaveSpeed,
			WaterReflectance = terrain.WaterReflectance,
		}
		terrain.WaterWaveSize = 0
		terrain.WaterWaveSpeed = 0
		terrain.WaterReflectance = 0
	end
end
local function restoreLightingCheap()
	local saved = Performance.savedLighting
	if saved then
		pcall(function()
			Lighting.GlobalShadows = saved.GlobalShadows
			Lighting.FogEnd = saved.FogEnd
			Lighting.FogStart = saved.FogStart
		end)
		Performance.savedLighting = nil
	end
	local terrain = workspace.Terrain
	local water = Performance.savedTerrain
	if terrain and water then
		pcall(function()
			terrain.WaterWaveSize = water.WaterWaveSize
			terrain.WaterWaveSpeed = water.WaterWaveSpeed
			terrain.WaterReflectance = water.WaterReflectance
		end)
	end
	Performance.savedTerrain = nil
end
local function restoreInstances()
	for inst, saved in pairs(Performance.instanceSaved) do
		if inst.Parent and saved then
			pcall(function()
				if saved.kind == "enabled" then
					inst.Enabled = saved.value
				elseif saved.kind == "shadow" then
					inst.CastShadow = saved.value
				elseif saved.kind == "lightShadow" then
					inst.Shadows = saved.value
				elseif saved.kind == "atmosphere" then
					inst.Density = saved.value
				end
			end)
		end
	end
	Performance.instanceSaved = {}
end
local function startSweep()
	Performance.sweepToken = Performance.sweepToken + 1
	local token = Performance.sweepToken
	task.spawn(function()
		local skip = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if player.Character then
				skip[player.Character] = true
			end
		end
		local lightingKids = Lighting:GetDescendants()
		for i = 1, #lightingKids do
			if token ~= Performance.sweepToken or not Performance.graphicsActive then
				return
			end
			pcall(Performance.stripInstance, lightingKids[i], skip)
		end
		local descendants = workspace:GetDescendants()
		local n = 0
		for i = 1, #descendants do
			if token ~= Performance.sweepToken or not Performance.graphicsActive then
				return
			end
			pcall(Performance.stripInstance, descendants[i], skip)
			n = n + 1
			if n % 200 == 0 then
				task.wait()
			end
		end
	end)
end
local function startWatchers()
	disconnectWatchers()
	table.insert(Performance.watchConns, workspace.DescendantAdded:Connect(function(inst)
		if Performance.graphicsActive then
			task.defer(function()
				if Performance.graphicsActive then
					pcall(Performance.stripInstance, inst)
				end
			end)
		end
	end))
	table.insert(Performance.watchConns, Lighting.DescendantAdded:Connect(function(inst)
		if Performance.graphicsActive then
			task.defer(function()
				if Performance.graphicsActive then
					pcall(Performance.stripInstance, inst)
				end
			end)
		end
	end))
end
function Performance.applyGraphics(config)
	if not config or not config.performanceMode then
		Performance.restoreGraphics()
		return
	end
	if Performance.graphicsActive then
		applyLightingCheap()
		applyRenderSettings()
		return
	end
	Performance.graphicsActive = true
	applyRenderSettings()
	applyLightingCheap()
	startWatchers()
	startSweep()
end
function Performance.restoreGraphics()
	Performance.sweepToken = Performance.sweepToken + 1
	disconnectWatchers()
	if not Performance.graphicsActive and not Performance.savedLighting and next(Performance.instanceSaved) == nil then
		return
	end
	restoreInstances()
	restoreLightingCheap()
	restoreRenderSettings()
	Performance.graphicsActive = false
end
return Performance
end)()
local ConfigStore = (function()
local HttpService = game:GetService("HttpService")
local ConfigStore = {}
ConfigStore.PATH = "lv/config.json"
ConfigStore.pendingSave = false
function ConfigStore.isSupported()
	return typeof(writefile) == "function"
		and typeof(readfile) == "function"
		and typeof(isfile) == "function"
end
function ConfigStore.findEnumItem(enumTypeName, itemName)
	if type(enumTypeName) ~= "string" or type(itemName) ~= "string" or itemName == "" then
		return nil
	end
	local okEnum, enumObj = pcall(function()
		return Enum[enumTypeName]
	end)
	if not okEnum or enumObj == nil then
		return nil
	end
	local okDirect, direct = pcall(function()
		return enumObj[itemName]
	end)
	if okDirect and typeof(direct) == "EnumItem" then
		return direct
	end
	local okItems, items = pcall(function()
		return enumObj:GetEnumItems()
	end)
	if okItems and type(items) == "table" then
		for _, item in ipairs(items) do
			if item.Name == itemName then
				return item
			end
		end
	end
	return nil
end
function ConfigStore.parseEnum(str)
	if typeof(str) == "EnumItem" then
		return str
	end
	if type(str) ~= "string" then
		return nil
	end
	str = (str:gsub("^%s+", ""):gsub("%s+$", ""))
	if str == "" then
		return nil
	end
	local enumType, enumName = string.match(str, "^Enum%.(%w+)%.(.+)$")
	if not enumType then
		enumType, enumName = string.match(str, "^(%w+)%.(.+)$")
	end
	if enumType and enumName then
		return ConfigStore.findEnumItem(enumType, enumName)
	end
	return ConfigStore.findEnumItem("KeyCode", str)
		or ConfigStore.findEnumItem("UserInputType", str)
end
function ConfigStore.serializeEnum(value)
	if value == nil then
		return nil
	end
	if typeof(value) == "EnumItem" then
		local ok, packed = pcall(function()
			return value.EnumType.Name .. "." .. value.Name
		end)
		if ok and type(packed) == "string" and packed ~= "" then
			return packed
		end
		local okName, name = pcall(function()
			return value.Name
		end)
		if okName and type(name) == "string" and name ~= "" then
			if string.sub(name, 1, 5) == "Mouse" then
				return "UserInputType." .. name
			end
			return "KeyCode." .. name
		end
	end
	if type(value) == "string" then
		return value
	end
	return tostring(value)
end
local BIND_SPECS = {
	{ kind = "aimbot", key = "aimbotKey", mouse = "aimbotMouse" },
	{ kind = "fly", key = "flyKey", mouse = "flyMouse" },
	{ kind = "jump", key = "jumpKey", mouse = "jumpMouse" },
	{ kind = "freecam", key = "freecamKey", mouse = "freecamMouse" },
}
function ConfigStore.packBind(value)
	return ConfigStore.serializeEnum(value) or ""
end
function ConfigStore.bindIsMouse(packed, item)
	if type(packed) == "string" then
		if string.find(packed, "UserInputType", 1, true) or string.find(packed, "MouseButton", 1, true) then
			return true
		end
	end
	if item then
		local ok, name = pcall(function()
			return item.Name
		end)
		if ok and type(name) == "string" and string.sub(name, 1, 5) == "Mouse" then
			return true
		end
	end
	return false
end
function ConfigStore.applyPackedBind(config, spec, packed)
	config[spec.key] = nil
	config[spec.mouse] = nil
	if type(packed) ~= "string" or packed == "" then
		return false
	end
	local item = ConfigStore.parseEnum(packed)
	if not item then
		return false
	end
	if ConfigStore.bindIsMouse(packed, item) then
		config[spec.mouse] = item
	else
		config[spec.key] = item
	end
	return true
end
function ConfigStore.syncBinds(config)
	local binds = {}
	if type(config.binds) == "table" then
		for key, value in pairs(config.binds) do
			if type(value) == "string" then
				binds[key] = value
			end
		end
	end
	for _, spec in ipairs(BIND_SPECS) do
		local value = config[spec.mouse] or config[spec.key]
		binds[spec.kind] = ConfigStore.packBind(value)
	end
	config.binds = binds
	return binds
end
function ConfigStore.getDefaults()
	return {
		aimbot = false,
		aimbotKey = Enum.KeyCode.E,
		aimbotMouse = nil,
		esp = false,
		espBoxes = true,
		espNames = true,
		espHealth = true,
		espSkeleton = false,
		espDistance = true,
		espWeapon = true,
		maxDistance = 500,
		smoothness = 12,
		fov = 150,
		drawFov = false,
		fly = false,
		flyKey = Enum.KeyCode.F,
		flyMouse = nil,
		flySpeed = 50,
		jump = false,
		jumpKey = Enum.KeyCode.J,
		jumpMouse = nil,
		jumpPower = 90,
		killAll = false,
		ammoAwareAim = true,
		visibleOnly = true,
		aimBones = { "Head" },
		prediction = true,
		predictScale = 80,
		espVisCheck = true,
		espChams = false,
		chamStyle = "xqz",
		chamDistance = 250,
		chamOverride = true,
		chamVisColor = "green",
		chamHidColor = "red",
		chamFill = 15,
		chamOutline = 20,
		chamRainbowSpeed = 70,
		chamSelf = "off",
		instantAds = true,
		shotDelay = true,
		enemyReload = true,
		persist = true,
		persistTimer = true,
		watermark = true,
		f9Debug = false,
		unlockAll = true,
		uncappedFps = false,
		performanceMode = true,
		streamproof = false,
		excludedNames = {},
		speed = false,
		walkSpeed = 80,
		infJump = false,
		noclip = false,
		spinbot = false,
		spinRate = 20,
		invis = false,
		godmode = false,
		antiFling = false,
		antiFlingLimit = 220,
		antiVoid = false,
		antiVoidFloor = -120,
		antiAfk = false,
		hitbox = false,
		hitboxSize = 15,
		cameraFovEnabled = false,
		cameraFov = 100,
		fullbright = false,
		xray = false,
		freecam = false,
		freecamKey = Enum.KeyCode.V,
		freecamMouse = nil,
		freecamSpeed = 80,
		worldGravity = false,
		gravityValue = 60,
		timeOfDay = false,
		timeHour = 14,
	}
end
function ConfigStore.toSaveData(config)
	local defaults = ConfigStore.getDefaults()
	local data = {}
	local enumKeys = {
		aimbotKey = true,
		aimbotMouse = true,
		flyKey = true,
		flyMouse = true,
		jumpKey = true,
		jumpMouse = true,
		freecamKey = true,
		freecamMouse = true,
	}
	for key, defaultValue in pairs(defaults) do
		if enumKeys[key] then
			data[key] = ConfigStore.serializeEnum(config[key]) or ""
		else
			local value = config[key]
			if value == nil then
				value = defaultValue
			end
			if key == "excludedNames" then
				data[key] = Filter.sanitizeList(value)
			elseif key == "aimBones" then
				data[key] = Aimbot.sanitizeBones(value)
			elseif type(defaultValue) == "boolean" then
				data[key] = value == true
			elseif type(defaultValue) == "number" then
				data[key] = tonumber(value) or defaultValue
			else
				data[key] = value
			end
		end
	end
	data.espChams = config.espChams == true
	data.chamStyle = type(config.chamStyle) == "string" and config.chamStyle or "xqz"
	data.chamDistance = tonumber(config.chamDistance) or 250
	data.chamOverride = config.chamOverride ~= false
	data.chamVisColor = type(config.chamVisColor) == "string" and config.chamVisColor or "green"
	data.chamHidColor = type(config.chamHidColor) == "string" and config.chamHidColor or "red"
	data.chamFill = tonumber(config.chamFill) or 15
	data.chamOutline = tonumber(config.chamOutline) or 20
	data.chamRainbowSpeed = tonumber(config.chamRainbowSpeed) or 70
	data.chamSelf = type(config.chamSelf) == "string" and config.chamSelf or "off"
	data.persistTimer = config.persistTimer ~= false
	data.watermark = config.watermark ~= false
	data.f9Debug = config.f9Debug == true
	data.streamproof = config.streamproof == true
	data.unlockAll = config.unlockAll == true
	data.persist = config.persist == true
	data.binds = ConfigStore.syncBinds(config)
	for _, spec in ipairs(BIND_SPECS) do
		data[spec.key] = ConfigStore.packBind(config[spec.key])
		data[spec.mouse] = ConfigStore.packBind(config[spec.mouse])
	end
	for key, value in pairs(config) do
		if data[key] == nil and key ~= "binds" then
			local valueType = type(value)
			if valueType == "boolean" or valueType == "number" or valueType == "string" then
				data[key] = value
			end
		end
	end
	return data
end
local JSON_ESCAPES = {
	['"'] = '\\"',
	["\\"] = "\\\\",
	["\b"] = "\\b",
	["\f"] = "\\f",
	["\n"] = "\\n",
	["\r"] = "\\r",
	["\t"] = "\\t",
}
function ConfigStore.encodeString(value)
	local escaped = string.gsub(value, '["\\%c]', function(char)
		local mapped = JSON_ESCAPES[char]
		if mapped then
			return mapped
		end
		return string.format("\\u%04x", string.byte(char))
	end)
	return '"' .. escaped .. '"'
end
function ConfigStore.encodeJson(value)
	local valueType = type(value)
	if valueType == "boolean" then
		return value and "true" or "false"
	end
	if valueType == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return "0"
		end
		return tostring(value)
	end
	if valueType == "string" then
		return ConfigStore.encodeString(value)
	end
	if valueType ~= "table" then
		return "null"
	end
	local isArray = true
	local count = 0
	for key, _ in pairs(value) do
		count = count + 1
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
			isArray = false
			break
		end
	end
	if isArray and count ~= #value then
		isArray = false
	end
	if isArray then
		local parts = {}
		for index, item in ipairs(value) do
			parts[index] = ConfigStore.encodeJson(item)
		end
		return "[" .. table.concat(parts, ",") .. "]"
	end
	local parts = {}
	for key, item in pairs(value) do
		table.insert(parts, ConfigStore.encodeString(tostring(key)) .. ":" .. ConfigStore.encodeJson(item))
	end
	table.sort(parts)
	return "{" .. table.concat(parts, ",") .. "}"
end
function ConfigStore.loadInto(config)
	if not ConfigStore.isSupported() or not isfile(ConfigStore.PATH) then
		return false
	end
	local ok, saved = pcall(function()
		return HttpService:JSONDecode(readfile(ConfigStore.PATH))
	end)
	if not ok or type(saved) ~= "table" then
		return false
	end
	local defaults = ConfigStore.getDefaults()
	for key, defaultValue in pairs(defaults) do
		local savedValue = saved[key]
		if savedValue ~= nil then
			if key == "aimbotKey" or key == "flyKey" or key == "jumpKey" or key == "freecamKey" then
				if savedValue == "" then
					config[key] = nil
				else
					config[key] = ConfigStore.parseEnum(savedValue) or defaultValue
				end
			elseif key == "aimbotMouse" or key == "flyMouse" or key == "jumpMouse" or key == "freecamMouse" then
				config[key] = savedValue == "" and nil or ConfigStore.parseEnum(savedValue)
			elseif type(defaultValue) == "boolean" then
				config[key] = savedValue == true
			elseif type(defaultValue) == "number" then
				config[key] = tonumber(savedValue) or defaultValue
			else
				config[key] = savedValue
			end
		end
	end
	local savedBinds = type(saved.binds) == "table" and saved.binds or nil
	local function applyBindSpec(spec)
		local packed = savedBinds and savedBinds[spec.kind]
		if type(packed) == "string" then
			ConfigStore.applyPackedBind(config, spec, packed)
			return
		end
		local savedMouse = saved[spec.mouse]
		local savedKey = saved[spec.key]
		if savedMouse ~= nil then
			config[spec.mouse] = ConfigStore.parseEnum(savedMouse)
		end
		if savedKey ~= nil then
			if savedKey == "" then
				config[spec.key] = nil
			else
				config[spec.key] = ConfigStore.parseEnum(savedKey) or config[spec.key]
			end
		end
		if config[spec.mouse] then
			config[spec.key] = nil
		elseif not config[spec.key] and savedKey == nil and savedMouse == nil then
			config[spec.key] = defaults[spec.key]
		end
	end
	for _, spec in ipairs(BIND_SPECS) do
		applyBindSpec(spec)
	end
	ConfigStore.syncBinds(config)
	config.smoothness = math.clamp(math.floor(config.smoothness + 0.5), 1, 50)
	config.fov = math.clamp(math.floor((config.fov or 150) + 0.5), 20, 600)
	config.predictScale = 80
	config.maxDistance = math.clamp(math.floor((config.maxDistance or 500) + 0.5), 50, 2000)
	config.chamDistance = math.clamp(math.floor((config.chamDistance or 250) + 0.5), 50, 250)
	config.flySpeed = math.clamp(math.floor((config.flySpeed or 50) + 0.5), 1, 250)
	config.jumpPower = math.clamp(math.floor((config.jumpPower or 50) + 0.5), 1, 500)
	config.walkSpeed = math.clamp(math.floor((config.walkSpeed or 80) + 0.5), 16, 400)
	config.spinRate = math.clamp(math.floor((config.spinRate or 20) + 0.5), 1, 60)
	config.antiFlingLimit = math.clamp(math.floor((config.antiFlingLimit or 220) + 0.5), 50, 800)
	config.antiVoidFloor = math.clamp(math.floor((config.antiVoidFloor or -120) + 0.5), -500, 0)
	config.hitboxSize = math.clamp(math.floor((config.hitboxSize or 15) + 0.5), 4, 60)
	config.cameraFov = math.clamp(math.floor((config.cameraFov or 100) + 0.5), 20, 120)
	config.aimBones = Aimbot.sanitizeBones(config.aimBones)
	config.freecamSpeed = math.clamp(math.floor((config.freecamSpeed or 80) + 0.5), 10, 400)
	config.gravityValue = math.clamp(math.floor((config.gravityValue or 60) + 0.5), 0, 250)
	config.timeHour = math.clamp(math.floor((config.timeHour or 14) + 0.5), 0, 24)
	config.excludedNames = Filter.sanitizeList(saved.excludedNames or config.excludedNames)
	if saved.autoUnlockAll ~= nil and saved.unlockAll == nil then
		config.unlockAll = saved.autoUnlockAll == true
	end
	for key, savedValue in pairs(saved) do
		if config[key] == nil and key ~= "binds" then
			local valueType = type(savedValue)
			if valueType == "boolean" or valueType == "number" or valueType == "string" then
				config[key] = savedValue
			end
		end
	end
	return true
end
function ConfigStore.save(config)
	if not ConfigStore.isSupported() then
		return false
	end
	if makefolder then
		pcall(makefolder, "lv")
	end
	local payload = ConfigStore.toSaveData(config)
	local encoded = nil
	local okEncode = pcall(function()
		encoded = ConfigStore.encodeJson(payload)
	end)
	if not okEncode or type(encoded) ~= "string" or encoded == "" then
		encoded = nil
		pcall(function()
			encoded = HttpService:JSONEncode(payload)
		end)
	end
	if type(encoded) ~= "string" or encoded == "" then
		return false
	end
	local ok = pcall(function()
		writefile(ConfigStore.PATH, encoded)
	end)
	return ok
end
function ConfigStore.scheduleSave(config)
	ConfigStore.pending = config
	if ConfigStore.flushing then
		return true
	end
	ConfigStore.flushing = true
	task.delay(0.05, function()
		ConfigStore.flushing = false
		local pending = ConfigStore.pending
		ConfigStore.pending = nil
		if pending then
			ConfigStore.save(pending)
		end
	end)
	return true
end
function ConfigStore.startAutosave(config)
	if ConfigStore.autosaveStop then
		return
	end
	local running = true
	ConfigStore.autosaveStop = function()
		running = false
	end
	task.spawn(function()
		while running do
			task.wait(2)
			if running and type(config) == "table" then
				ConfigStore.save(config)
			end
		end
	end)
end
function ConfigStore.stopAutosave()
	if ConfigStore.autosaveStop then
		ConfigStore.autosaveStop()
		ConfigStore.autosaveStop = nil
	end
	if ConfigStore.pending then
		ConfigStore.save(ConfigStore.pending)
		ConfigStore.pending = nil
	end
end
return ConfigStore
end)()
local Streamproof = (function()
local Players = game:GetService("Players")
local Streamproof = {}
Streamproof.enabled = false
Streamproof.overlays = {}
function Streamproof.getPlayerGui()
	local player = Players.LocalPlayer
	if not player then
		return nil
	end
	return player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui")
end
function Streamproof.isSupported()
	return true
end
function Streamproof.destroyExisting(name)
	local parents = {
		Streamproof.getPlayerGui(),
	}
	pcall(function()
		if typeof(gethui) == "function" then
			table.insert(parents, gethui())
		end
	end)
	pcall(function()
		table.insert(parents, game:GetService("CoreGui"))
	end)
	for _, parent in ipairs(parents) do
		if parent then
			local found = parent:FindFirstChild(name)
			if found then
				found:Destroy()
			end
		end
	end
end
function Streamproof.syncOverlays()
	for i = 1, #Streamproof.overlays do
		local gui = Streamproof.overlays[i]
		if gui then
			pcall(function()
				gui.Enabled = not Streamproof.enabled
			end)
		end
	end
end
function Streamproof.stripWorld()
	pcall(function()
		Esp.clear()
		if Esp.fovRing then
			Esp.fovRing.Visible = false
		end
	end)
	pcall(function()
		Cham.clear()
		Cham.clearSelf()
		Cham.releaseSelfBind()
	end)
	pcall(function()
		Hud.updateShot(0)
	end)
	pcall(function()
		Performance.restoreGraphics()
		Extras.restoreFullbright()
		Extras.restoreXray()
		Extras.restoreTime()
		Extras.restoreCameraFov()
		Extras.restoreHitbox()
	end)
end
function Streamproof.applyAll(enabled, overlays, config)
	Streamproof.enabled = enabled == true
	Streamproof.overlays = type(overlays) == "table" and overlays or {}
	Streamproof.syncOverlays()
	if Streamproof.enabled then
		Streamproof.stripWorld()
	elseif type(config) == "table" then
		pcall(function()
			Performance.applyGraphics(config)
		end)
	end
	return true
end
return Streamproof
end)()
local Watermark = (function()
local Players = game:GetService("Players")
local Watermark = {}
Watermark.gui = nil
Watermark.label = nil
Watermark.enabled = true
Watermark.frames = 0
Watermark.elapsed = 0
Watermark.fps = 0
function Watermark.init()
	Streamproof.destroyExisting("LV_Watermark")
	local gui = Instance.new("ScreenGui")
	gui.Name = "LV_Watermark"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 1000000
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.AutoLocalize = false
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.AutoLocalize = false
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Position = UDim2.fromOffset(12, 8)
	label.Size = UDim2.fromOffset(280, 16)
	label.Font = Enum.Font.BuilderSansMedium
	label.Text = "LV Software  0"
	label.TextColor3 = Color3.fromRGB(228, 228, 234)
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextStrokeTransparency = 0.65
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	Watermark.gui = gui
	Watermark.label = label
	Watermark.setVisible(Watermark.enabled ~= false)
end
function Watermark.setVisible(on)
	Watermark.enabled = on ~= false
	if Watermark.gui then
		Watermark.gui.Enabled = Watermark.enabled
	end
end
function Watermark.update(dt)
	if not Watermark.enabled or not Watermark.label then
		return
	end
	Watermark.frames = Watermark.frames + 1
	Watermark.elapsed = Watermark.elapsed + (dt or 0)
	if Watermark.elapsed < 0.25 then
		return
	end
	Watermark.fps = math.floor(Watermark.frames / Watermark.elapsed + 0.5)
	Watermark.frames = 0
	Watermark.elapsed = 0
	Watermark.label.Text = "LV Software  " .. tostring(Watermark.fps)
end
function Watermark.destroy()
	if Watermark.gui then
		Watermark.gui:Destroy()
	end
	Watermark.gui = nil
	Watermark.label = nil
end
return Watermark
end)()
local Hud = (function()
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Hud = {}
Hud.gui = nil
Hud.shot = nil
Hud.shotFill = nil
Hud.shotShown = false
local WAIT = Color3.fromRGB(255, 184, 72)
local READY = Color3.fromRGB(244, 244, 248)
local DONE = Color3.fromRGB(80, 220, 130)
local TRACK = Color3.fromRGB(16, 16, 16)
function Hud.init()
	Streamproof.destroyExisting("LV_Hud")
	Streamproof.destroyExisting("LV_ShotDelay")
	local gui = Instance.new("ScreenGui")
	gui.Name = "LV_Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 1000000
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.AutoLocalize = false
	local shot = Instance.new("TextLabel")
	shot.Name = "Shot"
	shot.AutoLocalize = false
	shot.AnchorPoint = Vector2.new(0.5, 1)
	shot.BackgroundTransparency = 1
	shot.BorderSizePixel = 0
	shot.Position = UDim2.new(0.5, 0, 0.38, 0)
	shot.Size = UDim2.fromOffset(140, 36)
	shot.Font = Enum.Font.BuilderSansBold
	shot.Text = ""
	shot.TextColor3 = WAIT
	shot.TextSize = 28
	shot.TextXAlignment = Enum.TextXAlignment.Center
	shot.TextYAlignment = Enum.TextYAlignment.Bottom
	shot.TextStrokeTransparency = 0.35
	shot.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	shot.Visible = false
	shot.Parent = gui
	local shotTrack = Instance.new("Frame")
	shotTrack.Name = "ShotTrack"
	shotTrack.AnchorPoint = Vector2.new(0.5, 0)
	shotTrack.BackgroundColor3 = TRACK
	shotTrack.BackgroundTransparency = 0.25
	shotTrack.BorderSizePixel = 0
	shotTrack.Position = UDim2.new(0.5, 0, 1, 6)
	shotTrack.Size = UDim2.fromOffset(72, 4)
	shotTrack.Visible = false
	shotTrack.Parent = shot
	local shotCorner = Instance.new("UICorner")
	shotCorner.CornerRadius = UDim.new(1, 0)
	shotCorner.Parent = shotTrack
	local shotFill = Instance.new("Frame")
	shotFill.Name = "Fill"
	shotFill.BackgroundColor3 = WAIT
	shotFill.BorderSizePixel = 0
	shotFill.Size = UDim2.fromScale(1, 1)
	shotFill.Parent = shotTrack
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = shotFill
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	Hud.gui = gui
	Hud.shot = shot
	Hud.shotTrack = shotTrack
	Hud.shotFill = shotFill
	Hud.shotShown = false
end
function Hud.updateShot(left, cooldown)
	if not Hud.shot then
		return
	end
	if type(left) ~= "number" or left < 0.05 then
		Hud.shot.Visible = false
		if Hud.shotTrack then
			Hud.shotTrack.Visible = false
		end
		Hud.shotShown = false
		return
	end
	local span = (type(cooldown) == "number" and cooldown > 0) and cooldown or 1
	local frac = math.clamp(left / span, 0, 1)
	local color = left < 0.18 and DONE or WAIT:Lerp(READY, 1 - frac)
	Hud.shot.Text = string.format("%.2f", left)
	Hud.shot.TextColor3 = color
	Hud.shot.Visible = true
	if Hud.shotTrack then
		Hud.shotTrack.Visible = true
		Hud.shotFill.BackgroundColor3 = color
		Hud.shotFill.Size = UDim2.fromScale(frac, 1)
	end
	if not Hud.shotShown then
		Hud.shotShown = true
		Hud.shot.TextSize = 34
		pcall(function()
			TweenService:Create(Hud.shot, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextSize = 28,
			}):Play()
		end)
	end
end
function Hud.destroy()
	if Hud.gui then
		Hud.gui:Destroy()
	end
	Hud.gui = nil
	Hud.shot = nil
	Hud.shotTrack = nil
	Hud.shotFill = nil
	Hud.shotShown = false
end
return Hud
end)()
local Core = (function()
local Core = {}
Core.running = true
Core.connections = {}
function Core.isRunning()
	return Core.running
end
function Core.track(connection)
	if connection then
		table.insert(Core.connections, connection)
	end
	return connection
end
function Core.stop()
	Core.running = false
end
function Core.disconnectAll()
	for _, connection in ipairs(Core.connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	Core.connections = {}
end
return Core
end)()
local Input = (function()
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local Input = {}
Input.keyHeld = false
Input.listening = false
Input.listeningKind = "aimbot"
Input.connections = {}
Input.held = {}
Input.pressedNow = {}
Input.padDown = {}
Input.listenIgnore = {}
Input.listenAt = 0
Input.config = nil
Input.onChanged = nil
local function enumItem(enum, name)
	local ok, value = pcall(function()
		return enum[name]
	end)
	if ok and typeof(value) == "EnumItem" then
		return value
	end
	return nil
end
local MOUSE_BUTTONS = {}
local MOUSE_BIND_SET = {}
for _, name in ipairs({
	"MouseButton1",
	"MouseButton2",
	"MouseButton3",
	"MouseButton4",
	"MouseButton5",
}) do
	local item = enumItem(Enum.UserInputType, name)
	if item then
		table.insert(MOUSE_BUTTONS, item)
		MOUSE_BIND_SET[item] = true
	end
end
local SIDE_MOUSE_BUTTONS = {}
for _, name in ipairs({ "MouseButton4", "MouseButton5" }) do
	local item = enumItem(Enum.UserInputType, name)
	if item then
		table.insert(SIDE_MOUSE_BUTTONS, item)
	end
end
local BIND_NAMES = {
	MouseButton1 = "Mouse1",
	MouseButton2 = "Mouse2",
	MouseButton3 = "Mouse3",
	MouseButton4 = "Mouse4",
	MouseButton5 = "Mouse5",
	ButtonA = "A",
	ButtonB = "B",
	ButtonX = "X",
	ButtonY = "Y",
	ButtonL1 = "L1",
	ButtonR1 = "R1",
	ButtonL2 = "L2",
	ButtonR2 = "R2",
	ButtonL3 = "L3",
	ButtonR3 = "R3",
	ButtonStart = "Start",
	ButtonSelect = "Select",
	DPadLeft = "DLeft",
	DPadRight = "DRight",
	DPadUp = "DUp",
	DPadDown = "DDown",
}
local IGNORE_KEYS = {
	[Enum.KeyCode.Unknown] = true,
	[Enum.KeyCode.Thumbstick1] = true,
	[Enum.KeyCode.Thumbstick2] = true,
}
local GAMEPAD_LIST = {}
local GAMEPAD_KEYS = {}
for _, name in ipairs({
	"ButtonA",
	"ButtonB",
	"ButtonX",
	"ButtonY",
	"ButtonL1",
	"ButtonR1",
	"ButtonL2",
	"ButtonR2",
	"ButtonL3",
	"ButtonR3",
	"ButtonStart",
	"ButtonSelect",
	"DPadLeft",
	"DPadRight",
	"DPadUp",
	"DPadDown",
}) do
	local key = enumItem(Enum.KeyCode, name)
	if key then
		table.insert(GAMEPAD_LIST, key)
		GAMEPAD_KEYS[key] = true
	end
end
local GAMEPAD_TYPES = {}
local GAMEPAD_TYPE_LIST = {}
for index = 1, 8 do
	local pad = enumItem(Enum.UserInputType, "Gamepad" .. index)
	if pad then
		GAMEPAD_TYPES[pad] = true
		table.insert(GAMEPAD_TYPE_LIST, pad)
	end
end
function Input.getBindFields(kind)
	if kind == "fly" then
		return "flyKey", "flyMouse"
	end
	if kind == "jump" then
		return "jumpKey", "jumpMouse"
	end
	if kind == "freecam" then
		return "freecamKey", "freecamMouse"
	end
	return "aimbotKey", "aimbotMouse"
end
function Input.prettyName(value)
	if value == nil then
		return "None"
	end
	local raw = tostring(value)
	local name = string.match(raw, "%.([%w]+)$") or raw
	return BIND_NAMES[name] or name
end
function Input.getBindName(config, kind)
	local keyField, mouseField = Input.getBindFields(kind)
	if config[mouseField] then
		return Input.prettyName(config[mouseField])
	end
	if config[keyField] then
		return Input.prettyName(config[keyField])
	end
	return "None"
end
function Input.setKeyboardBind(config, keyCode, kind)
	local keyField, mouseField = Input.getBindFields(kind)
	config[keyField] = keyCode
	config[mouseField] = nil
	if Input.onChanged then
		Input.onChanged()
	end
end
function Input.setMouseBind(config, inputType, kind)
	local keyField, mouseField = Input.getBindFields(kind)
	config[keyField] = nil
	config[mouseField] = inputType
	if Input.onChanged then
		Input.onChanged()
	end
end
function Input.isMouseBind(value)
	if MOUSE_BIND_SET[value] then
		return true
	end
	if typeof(value) ~= "EnumItem" then
		return false
	end
	local name = value.Name
	return name == "MouseButton1"
		or name == "MouseButton2"
		or name == "MouseButton3"
		or name == "MouseButton4"
		or name == "MouseButton5"
end
function Input.isGamepadType(value)
	if GAMEPAD_TYPES[value] then
		return true
	end
	if typeof(value) ~= "EnumItem" then
		return false
	end
	return string.sub(value.Name, 1, 7) == "Gamepad"
end
function Input.isGamepadKey(value)
	if GAMEPAD_KEYS[value] then
		return true
	end
	if typeof(value) ~= "EnumItem" then
		return false
	end
	local name = value.Name
	return string.sub(name, 1, 6) == "Button" or string.sub(name, 1, 4) == "DPad"
end
function Input.isBindable(input)
	if Input.isMouseBind(input.UserInputType) then
		return true
	end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		return input.KeyCode ~= Enum.KeyCode.Unknown and not IGNORE_KEYS[input.KeyCode]
	end
	if Input.isGamepadType(input.UserInputType) then
		return Input.isGamepadKey(input.KeyCode)
	end
	return false
end
function Input.markHeld(input, down)
	if Input.isMouseBind(input.UserInputType) then
		Input.held[input.UserInputType] = down or nil
	end
	if input.KeyCode and input.KeyCode ~= Enum.KeyCode.Unknown then
		Input.held[input.KeyCode] = down or nil
	end
end
function Input.setPadDown(keyCode, down)
	if not Input.isGamepadKey(keyCode) then
		return
	end
	if down then
		Input.padDown[keyCode] = true
		Input.held[keyCode] = true
	else
		Input.padDown[keyCode] = nil
		Input.held[keyCode] = nil
		Input.listenIgnore[keyCode] = nil
	end
end
function Input.captureKey(keyCode)
	if not Input.listening or not Input.config or not keyCode then
		return false
	end
	if os.clock() < Input.listenAt or Input.listenIgnore[keyCode] then
		return false
	end
	if IGNORE_KEYS[keyCode] then
		return false
	end
	Input.setKeyboardBind(Input.config, keyCode, Input.listeningKind)
	Input.listening = false
	if Input.onChanged then
		Input.onChanged()
	end
	return true
end
function Input.captureInput(input, _processed)
	if not Input.listening or not input then
		return false
	end
	if Input.isMouseBind(input.UserInputType) then
		if os.clock() < Input.listenAt or Input.listenIgnore[input.UserInputType] then
			return false
		end
		Input.setMouseBind(Input.config, input.UserInputType, Input.listeningKind)
		Input.listening = false
		if Input.onChanged then
			Input.onChanged()
		end
		return true
	end
	if input.KeyCode and (input.UserInputType == Enum.UserInputType.Keyboard or Input.isGamepadType(input.UserInputType) or Input.isGamepadKey(input.KeyCode)) then
		return Input.captureKey(input.KeyCode)
	end
	return false
end
function Input.pollPads()
	local now = {}
	local sources = 0
	local okKeys, keys = pcall(function()
		return UserInputService:GetKeysPressed()
	end)
	if okKeys and type(keys) == "table" then
		sources = sources + 1
		for _, obj in ipairs(keys) do
			if obj and obj.KeyCode and obj.KeyCode ~= Enum.KeyCode.Unknown then
				now[obj.KeyCode] = true
			end
		end
	end
	local okMouse, mouse = pcall(function()
		return UserInputService:GetMouseButtonsPressed()
	end)
	if okMouse and type(mouse) == "table" then
		sources = sources + 1
		for _, obj in ipairs(mouse) do
			if obj and obj.UserInputType then
				now[obj.UserInputType] = true
			end
		end
	end
	for _, pad in ipairs(GAMEPAD_TYPE_LIST) do
		local okState, states = pcall(function()
			return UserInputService:GetGamepadState(pad)
		end)
		if okState and type(states) == "table" then
			sources = sources + 1
			for _, obj in ipairs(states) do
				if obj and Input.isGamepadKey(obj.KeyCode) then
					local pos = obj.Position
					if typeof(pos) == "Vector3" and pos.Magnitude >= 0.45 then
						now[obj.KeyCode] = true
					end
				end
			end
		end
		for _, key in ipairs(GAMEPAD_LIST) do
			local okDown, isDown = pcall(function()
				return UserInputService:IsGamepadButtonDown(pad, key)
			end)
			if okDown and isDown then
				now[key] = true
			end
		end
	end
	for _, button in ipairs(MOUSE_BUTTONS) do
		local ok, down = pcall(function()
			return UserInputService:IsMouseButtonPressed(button)
		end)
		if ok and down then
			now[button] = true
		end
	end
	Input.pressedNow = now
	if sources > 0 then
		for value in pairs(Input.listenIgnore) do
			if not now[value] then
				Input.listenIgnore[value] = nil
			end
		end
	end
	if sources > 0 or next(now) ~= nil then
		for value in pairs(now) do
			if Input.isGamepadKey(value) then
				Input.setPadDown(value, true)
			else
				Input.held[value] = true
			end
			if Input.listening then
				if Input.isMouseBind(value) then
					Input.captureInput({ UserInputType = value, KeyCode = Enum.KeyCode.Unknown }, false)
				else
					Input.captureKey(value)
				end
			end
		end
		for key in pairs(Input.padDown) do
			if not now[key] then
				Input.setPadDown(key, false)
			end
		end
	end
end
function Input.isHeld(value)
	if value == nil then
		return false
	end
	if Input.pressedNow[value] or Input.held[value] or Input.padDown[value] then
		return true
	end
	if Input.isMouseBind(value) then
		local ok, down = pcall(function()
			return UserInputService:IsMouseButtonPressed(value)
		end)
		if ok and down then
			return true
		end
		local okList, list = pcall(function()
			return UserInputService:GetMouseButtonsPressed()
		end)
		if okList and type(list) == "table" then
			for _, obj in ipairs(list) do
				if obj and obj.UserInputType == value then
					return true
				end
			end
		end
		return false
	end
	if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then
		local ok, down = pcall(function()
			return UserInputService:IsKeyDown(value)
		end)
		if ok and down then
			return true
		end
		local okKeys, keys = pcall(function()
			return UserInputService:GetKeysPressed()
		end)
		if okKeys and type(keys) == "table" then
			for _, obj in ipairs(keys) do
				if obj and obj.KeyCode == value then
					return true
				end
			end
		end
		if Input.isGamepadKey(value) then
			for _, pad in ipairs(GAMEPAD_TYPE_LIST) do
				local okDown, isDown = pcall(function()
					return UserInputService:IsGamepadButtonDown(pad, value)
				end)
				if okDown and isDown then
					return true
				end
			end
		end
	end
	return false
end
function Input.isActive(config, kind)
	local keyField, mouseField = Input.getBindFields(kind)
	if config[mouseField] then
		return Input.isHeld(config[mouseField])
	end
	if config[keyField] then
		return Input.isHeld(config[keyField])
	end
	return true
end
function Input.start(config, onConfigChanged)
	Input.config = config
	Input.onChanged = onConfigChanged
	local function onBegan(input, processed)
		Input.markHeld(input, true)
		if Input.isGamepadKey(input.KeyCode) then
			Input.setPadDown(input.KeyCode, true)
		end
		if Input.listening then
			Input.captureInput(input, processed)
		end
	end
	local function onEnded(input)
		Input.markHeld(input, false)
		if Input.isGamepadKey(input.KeyCode) then
			Input.setPadDown(input.KeyCode, false)
		end
		if Input.isMouseBind(input.UserInputType) then
			Input.listenIgnore[input.UserInputType] = nil
		end
	end
	local function onChanged(input)
		if Input.isGamepadType(input.UserInputType) and Input.isGamepadKey(input.KeyCode) then
			local pos = input.Position
			local down = typeof(pos) == "Vector3" and pos.Magnitude >= 0.45
			Input.setPadDown(input.KeyCode, down)
			if down and Input.listening then
				Input.captureKey(input.KeyCode)
			end
		end
	end
	table.insert(Input.connections, UserInputService.InputBegan:Connect(onBegan))
	table.insert(Input.connections, UserInputService.InputEnded:Connect(onEnded))
	table.insert(Input.connections, UserInputService.InputChanged:Connect(onChanged))
	table.insert(Input.connections, RunService.Heartbeat:Connect(function()
		Input.pollPads()
	end))
	pcall(function()
		ContextActionService:UnbindAction("LVInputPad")
	end)
	pcall(function()
		ContextActionService:BindActionAtPriority(
			"LVInputPad",
			function(_, state, input)
				if not input or not Input.isGamepadKey(input.KeyCode) then
					return Enum.ContextActionResult.Pass
				end
				local down = state == Enum.UserInputState.Begin
				if state == Enum.UserInputState.Change then
					local pos = input.Position
					down = typeof(pos) == "Vector3" and pos.Magnitude >= 0.45
				elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
					down = false
				end
				Input.setPadDown(input.KeyCode, down)
				if down then
					Input.captureKey(input.KeyCode)
				end
				if Input.listening then
					return Enum.ContextActionResult.Sink
				end
				return Enum.ContextActionResult.Pass
			end,
			false,
			3000,
			Enum.KeyCode.ButtonA,
			Enum.KeyCode.ButtonB,
			Enum.KeyCode.ButtonX,
			Enum.KeyCode.ButtonY,
			Enum.KeyCode.ButtonL1,
			Enum.KeyCode.ButtonR1,
			Enum.KeyCode.ButtonL2,
			Enum.KeyCode.ButtonR2,
			Enum.KeyCode.ButtonL3,
			Enum.KeyCode.ButtonR3,
			Enum.KeyCode.ButtonStart,
			Enum.KeyCode.ButtonSelect,
			Enum.KeyCode.DPadLeft,
			Enum.KeyCode.DPadRight,
			Enum.KeyCode.DPadUp,
			Enum.KeyCode.DPadDown
		)
	end)
end
function Input.beginListening(kind)
	Input.listening = false
	Input.listeningKind = kind or "aimbot"
	Input.listenIgnore = {}
	Input.pollPads()
	for value in pairs(Input.pressedNow) do
		Input.listenIgnore[value] = true
	end
	for key in pairs(Input.padDown) do
		Input.listenIgnore[key] = true
	end
	for _, button in ipairs(MOUSE_BUTTONS) do
		local ok, down = pcall(function()
			return UserInputService:IsMouseButtonPressed(button)
		end)
		if ok and down then
			Input.listenIgnore[button] = true
		end
	end
	Input.listenAt = os.clock() + 0.2
	task.delay(0.2, function()
		if Input.listeningKind == (kind or "aimbot") then
			Input.listening = true
		end
	end)
end
function Input.stop()
	Input.listening = false
	Input.keyHeld = false
	Input.held = {}
	Input.pressedNow = {}
	Input.padDown = {}
	Input.listenIgnore = {}
	Input.config = nil
	Input.onChanged = nil
	pcall(function()
		ContextActionService:UnbindAction("LVInputPad")
	end)
	for _, connection in ipairs(Input.connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	Input.connections = {}
end
	return Input
end)()
local Fly = (function()
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Fly = {}
Fly.active = false
Fly.latched = false
Fly.bindWasDown = false
Fly.savedGravity = 196.2
Fly.savedPlatformStand = false
function Fly.clearLatch()
	Fly.latched = false
	Fly.bindWasDown = false
end
function Fly.restore()
	if not Fly.active then
		return
	end
	pcall(function()
		workspace.Gravity = Fly.savedGravity
	end)
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = Fly.savedPlatformStand
	end
	Fly.active = false
end
function Fly.getMoveDirection(camera)
	local direction = Vector3.new(0, 0, 0)
	local look = camera.CFrame.LookVector
	local right = camera.CFrame.RightVector
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		direction = direction + look
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		direction = direction - look
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		direction = direction - right
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		direction = direction + right
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.E) then
		direction = direction + Vector3.new(0, 1, 0)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		or UserInputService:IsKeyDown(Enum.KeyCode.Q)
	then
		direction = direction - Vector3.new(0, 1, 0)
	end
	if direction.Magnitude < 0.01 then
		return Vector3.new(0, 0, 0), false
	end
	return direction.Unit, true
end
function Fly.apply(config)
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	if not root or not humanoid or humanoid.Health <= 0 or not camera then
		Fly.restore()
		return
	end
	if not Fly.active then
		Fly.savedGravity = workspace.Gravity
		Fly.savedPlatformStand = humanoid.PlatformStand
		Fly.active = true
	end
	workspace.Gravity = 0
	humanoid.PlatformStand = true
	local direction, moving = Fly.getMoveDirection(camera)
	local speed = config.flySpeed or 50
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
		speed = speed * 2
	end
	local velocity = moving and (direction * speed) or Vector3.new(0, 0, 0)
	root.AssemblyLinearVelocity = velocity
end
return Fly
end)()
local Jump = (function()
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Jump = {}
Jump.active = false
Jump.hasSnapshot = false
Jump.lastPower = nil
Jump.savedJumpPower = 50
Jump.savedJumpHeight = 7.2
Jump.savedUseJumpPower = true
Jump.requestConn = nil
local DEFAULT_JUMP_POWER = 50
local DEFAULT_JUMP_HEIGHT = 7.2
function Jump.getHumanoid()
	local character = LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end
function Jump.isBoosted(humanoid, power)
	if not humanoid then
		return false
	end
	power = power or Jump.lastPower
	if not power then
		return false
	end
	local jumpPower = humanoid.JumpPower
	local jumpHeight = humanoid.JumpHeight
	return jumpPower == power or math.abs(jumpHeight - power * 0.144) < 0.05
end
function Jump.capture(humanoid)
	if not humanoid then
		return
	end
	if Jump.isBoosted(humanoid, Jump.lastPower) then
		return
	end
	Jump.savedJumpPower = humanoid.JumpPower
	Jump.savedJumpHeight = humanoid.JumpHeight
	local ok, useJumpPower = pcall(function()
		return humanoid.UseJumpPower
	end)
	Jump.savedUseJumpPower = ok and useJumpPower or true
	Jump.hasSnapshot = true
end
function Jump.cancelBoostVelocity()
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local velocity = root.AssemblyLinearVelocity
	if velocity.Y > DEFAULT_JUMP_POWER then
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, math.min(velocity.Y, DEFAULT_JUMP_POWER), velocity.Z)
	end
end
function Jump.writeRestore()
	local humanoid = Jump.getHumanoid()
	if not humanoid then
		Jump.active = false
		return
	end
	pcall(function()
		humanoid.UseJumpPower = Jump.hasSnapshot and Jump.savedUseJumpPower or true
		humanoid.JumpPower = DEFAULT_JUMP_POWER
		humanoid.JumpHeight = DEFAULT_JUMP_HEIGHT
	end)
	Jump.active = false
end
function Jump.stopRequest()
	if Jump.requestConn then
		Jump.requestConn:Disconnect()
		Jump.requestConn = nil
	end
end
function Jump.startRequest()
	if Jump.requestConn then
		return
	end
	Jump.requestConn = UserInputService.JumpRequest:Connect(function()
		if not Jump.active or UserInputService:GetFocusedTextBox() then
			return
		end
		local humanoid = Jump.getHumanoid()
		local character = LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root or humanoid.Health <= 0 then
			return
		end
		local power = Jump.lastPower or 90
		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			local velocity = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(velocity.X, math.max(velocity.Y, power), velocity.Z)
		end)
	end)
end
function Jump.restore()
	local wasBoosting = Jump.active or Jump.requestConn ~= nil
	Jump.stopRequest()
	if wasBoosting then
		Jump.cancelBoostVelocity()
	end
	Jump.writeRestore()
	Jump.lastPower = nil
end
function Jump.apply(config)
	local humanoid = Jump.getHumanoid()
	if not humanoid or humanoid.Health <= 0 then
		Jump.active = false
		return
	end
	Jump.capture(humanoid)
	local power = config.jumpPower or 90
	Jump.lastPower = power
	Jump.active = true
	Jump.startRequest()
	pcall(function()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		humanoid.UseJumpPower = true
		humanoid.JumpPower = power
		humanoid.JumpHeight = power * 0.144
	end)
end
return Jump
end)()
local Persist = (function()
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Persist = {}
Persist.enabled = false
Persist.queued = false
Persist.conn = nil
function Persist.queueFn()
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
function Persist.source()
	return table.concat({
		[[task.spawn(function()
	local env = (typeof(getgenv) == "function" and getgenv()) or _G
	if type(env) == "table" then
		if env.LV_PERSIST_STARTED then
			return
		end
		env.LV_PERSIST_STARTED = true
		env.LV_HOP = true
		env.LV_HOP_WAITED = true
		env.LV_BOOTING = true
	end
	pcall(function()
		if not game:IsLoaded() then
			game.Loaded:Wait()
		end
	end)
	local gui, label
	pcall(function()
		local player = game:GetService("Players").LocalPlayer
		local playerGui = player and player:WaitForChild("PlayerGui", 8)
		if not playerGui then
			return
		end
		gui = Instance.new("ScreenGui")
		gui.Name = "LV_HopWait"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 1000000
		gui.Parent = playerGui
		label = Instance.new("TextLabel")
		label.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
		label.BackgroundTransparency = 0.2
		label.BorderSizePixel = 0
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.new(0.5, 0, 0, 16)
		label.Size = UDim2.fromOffset(168, 32)
		label.Font = Enum.Font.GothamMedium
		label.TextSize = 15
		label.TextColor3 = Color3.fromRGB(236, 236, 240)
		label.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 7)
		corner.Parent = label
	end)
	local waitSec = 15
	pcall(function()
		if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile("lv/config.json") then
			local data = game:GetService("HttpService"):JSONDecode(readfile("lv/config.json"))
			if type(data) == "table" and data.persistTimer == false then
				waitSec = 0
			end
		end
	end)
	local skip = waitSec <= 0
	local conn
	pcall(function()
		conn = game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			if input.KeyCode == Enum.KeyCode.Zero or input.KeyCode == Enum.KeyCode.KeypadZero then
				skip = true
				if type(env) == "table" then
					env.LV_FORCE_UNLOCK = true
					env.LV_BOOTING = false
				end
			end
		end)
	end)
	for left = waitSec, 1, -1 do
		if skip then
			break
		end
		if label then
			label.Text = "LV  " .. left .. "s"
		end
		task.wait(1)
	end
	if conn then
		pcall(function()
			conn:Disconnect()
		end)
	end
	if gui then
		pcall(function()
			gui:Destroy()
		end)
	end
	if type(env) == "table" then
		env.LV_BOOTING = false
	end
	task.wait(1)
	task.spawn(function()
		local src
		if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile("script.lua") then
			src = readfile("script.lua")
		end
		if type(src) == "string" and src ~= "" then
			local fn = loadstring(src, "script.lua")
			if type(fn) == "function" then
				task.spawn(fn)
			end
		end
	end)
end)]]],
	})
end
function Persist.queue()
	if Persist.queued then
		return true
	end
	local qot = Persist.queueFn()
	if typeof(qot) ~= "function" then
		return false
	end
	local src = Persist.source()
	if typeof(writefile) == "function" then
		pcall(writefile, "lv/boot.lua", src)
	end
	local ok = pcall(qot, src)
	if ok then
		Persist.queued = true
	end
	return ok
end
function Persist.arm(config)
	Persist.enabled = type(config) == "table" and config.persist == true
	if Persist.conn then
		pcall(function()
			Persist.conn:Disconnect()
		end)
		Persist.conn = nil
	end
	if not Persist.enabled then
		return
	end
	Persist.queue()
	local ok, conn = pcall(function()
		return LocalPlayer.OnTeleport:Connect(function(state)
			if not Persist.enabled then
				return
			end
			if state == Enum.TeleportState.Failed then
				Persist.queued = false
				return
			end
		end)
	end)
	if ok then
		Persist.conn = conn
		if Core and Core.track then
			Core.track(conn)
		end
	end
end
function Persist.stop()
	Persist.enabled = false
	if Persist.conn then
		pcall(function()
			Persist.conn:Disconnect()
		end)
		Persist.conn = nil
	end
end
return Persist
end)()
local Extras = (function()
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Extras = {}
Extras.speedActive = false
Extras.savedWalkSpeed = 16
Extras.noclipActive = false
Extras.noclipSaved = {}
Extras.noclipModel = nil
Extras.noclipParts = nil
Extras.noclipScanAt = 0
Extras.infJumpConn = nil
Extras.spinActive = false
Extras.invisActive = false
Extras.invisSaved = {}
Extras.invisConn = nil
Extras.invisModel = nil
Extras.invisAt = 0
Extras.godActive = false
Extras.godHum = nil
Extras.godConns = {}
Extras.godBoxes = {}
Extras.voidLastSafe = nil
Extras.antiAfkConn = nil
Extras.hitboxSaved = {}
Extras.fovActive = false
Extras.savedFov = 70
Extras.fbActive = false
Extras.savedLighting = nil
Extras.xrayTouched = {}
Extras.xraySweepAt = 0
Extras.freecamActive = false
Extras.freecamLatched = false
Extras.freecamBindWasDown = false
Extras.freecamLookConn = nil
Extras.savedCamType = nil
Extras.savedCamSubject = nil
Extras.freecamPos = nil
Extras.freecamPitch = 0
Extras.freecamYaw = 0
Extras.gravityActive = false
Extras.savedGravity = 196.2
Extras.timeActive = false
Extras.savedClock = 14
Extras.mark = nil
Extras.hopping = false
local function character()
	return LocalPlayer.Character
end
local function humanoid()
	local model = character()
	return model and model:FindFirstChildOfClass("Humanoid")
end
local function rootPart()
	local model = character()
	return model and model:FindFirstChild("HumanoidRootPart")
end
local function isAlive()
	local hum = humanoid()
	return hum ~= nil and hum.Health > 0 and rootPart() ~= nil
end
function Extras.getRoot(player)
	local model = player and player.Character
	return model and model:FindFirstChild("HumanoidRootPart")
end
function Extras.teleportTo(cf)
	local root = rootPart()
	if not root or typeof(cf) ~= "CFrame" then
		return false
	end
	root.CFrame = cf
	root.AssemblyLinearVelocity = Vector3.zero
	return true
end
function Extras.teleportToPlayer(player, config)
	if Filter.isTeammate(player) or (config and Filter.isExcluded(player, config)) then
		return false
	end
	local target = Extras.getRoot(player)
	if not target then
		return false
	end
	return Extras.teleportTo(target.CFrame * CFrame.new(0, 0, 4))
end
function Extras.markHere()
	local root = rootPart()
	if not root then
		return false
	end
	Extras.mark = root.CFrame
	return true
end
function Extras.returnToMark()
	if not Extras.mark then
		return false
	end
	return Extras.teleportTo(Extras.mark)
end
function Extras.applySpeed(config, dt)
	local hum = humanoid()
	local root = rootPart()
	if not hum or hum.Health <= 0 or not root then
		return
	end
	if not Extras.speedActive then
		Extras.savedWalkSpeed = hum.WalkSpeed
		Extras.speedActive = true
	end
	local speed = config.walkSpeed or 80
	pcall(function()
		hum.WalkSpeed = speed
	end)
	local move = hum.MoveDirection
	if move.Magnitude < 0.05 then
		return
	end
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(move.X * speed, velocity.Y, move.Z * speed)
	local extra = math.max(0, speed - 16)
	if extra > 0 then
		root.CFrame = root.CFrame + move.Unit * extra * math.min(dt or 0.016, 0.1)
	end
end
function Extras.restoreSpeed()
	if not Extras.speedActive then
		return
	end
	local hum = humanoid()
	if hum then
		pcall(function()
			hum.WalkSpeed = Extras.savedWalkSpeed
		end)
	end
	Extras.speedActive = false
end
function Extras.startInfJump()
	if Extras.infJumpConn then
		return
	end
	Extras.infJumpConn = UserInputService.JumpRequest:Connect(function()
		if UserInputService:GetFocusedTextBox() then
			return
		end
		local hum = humanoid()
		if hum and hum.Health > 0 then
			pcall(function()
				hum:ChangeState(Enum.HumanoidStateType.Jumping)
			end)
		end
	end)
end
function Extras.stopInfJump()
	if Extras.infJumpConn then
		Extras.infJumpConn:Disconnect()
		Extras.infJumpConn = nil
	end
end
function Extras.applyNoclip()
	local model = character()
	if not model then
		return
	end
	local now = os.clock()
	if Extras.noclipModel ~= model or not Extras.noclipParts or now - Extras.noclipScanAt > 0.35 then
		local parts = {}
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				table.insert(parts, part)
			end
		end
		Extras.noclipModel = model
		Extras.noclipParts = parts
		Extras.noclipScanAt = now
	end
	Extras.noclipActive = true
	for _, part in ipairs(Extras.noclipParts) do
		if part.Parent and part.CanCollide then
			if Extras.noclipSaved[part] == nil then
				Extras.noclipSaved[part] = true
			end
			part.CanCollide = false
		end
	end
end
function Extras.restoreNoclip()
	if not Extras.noclipActive and next(Extras.noclipSaved) == nil then
		return
	end
	for part in pairs(Extras.noclipSaved) do
		if part.Parent then
			pcall(function()
				part.CanCollide = true
			end)
		end
	end
	Extras.noclipSaved = {}
	Extras.noclipParts = nil
	Extras.noclipModel = nil
	Extras.noclipActive = false
end
function Extras.applySpin(config, dt)
	local root = rootPart()
	if not isAlive() or not root then
		return
	end
	Extras.spinActive = true
	local rate = config.spinRate or 20
	root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(rate * math.min(dt or 0.016, 0.1) * 60), 0)
end
function Extras.restoreSpin()
	Extras.spinActive = false
end
function Extras.stopInvisWatch()
	if Extras.invisConn then
		pcall(function()
			Extras.invisConn:Disconnect()
		end)
		Extras.invisConn = nil
	end
	Extras.invisModel = nil
end
function Extras.hideVisual(inst)
	if not inst then
		return
	end
	if inst:IsA("BasePart") then
		if Extras.invisSaved[inst] == nil then
			Extras.invisSaved[inst] = {
				kind = "part",
				t = inst.Transparency,
				lt = inst.LocalTransparencyModifier,
			}
		end
		inst.Transparency = 1
		inst.LocalTransparencyModifier = 1
	elseif inst:IsA("Decal") or inst:IsA("Texture") then
		if Extras.invisSaved[inst] == nil then
			Extras.invisSaved[inst] = { kind = "tex", t = inst.Transparency }
		end
		inst.Transparency = 1
	elseif inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") or inst:IsA("Highlight") or inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") then
		if Extras.invisSaved[inst] == nil then
			Extras.invisSaved[inst] = { kind = "fx", on = inst.Enabled }
		end
		inst.Enabled = false
	elseif inst:IsA("BillboardGui") or inst:IsA("SurfaceGui") then
		if Extras.invisSaved[inst] == nil then
			Extras.invisSaved[inst] = { kind = "gui", on = inst.Enabled }
		end
		inst.Enabled = false
	elseif inst:IsA("Accessory") or inst:IsA("Hat") then
		local handle = inst:FindFirstChild("Handle")
		if handle then
			Extras.hideVisual(handle)
		end
	end
end
function Extras.hideModelTree(model)
	if not model then
		return
	end
	for _, inst in ipairs(model:GetDescendants()) do
		Extras.hideVisual(inst)
	end
	if model:IsA("BasePart") then
		Extras.hideVisual(model)
	end
end
function Extras.watchModel(model)
	if Extras.invisModel == model and Extras.invisConn then
		return
	end
	Extras.stopInvisWatch()
	if not model then
		return
	end
	Extras.invisConn = model.DescendantAdded:Connect(function(inst)
		Extras.hideVisual(inst)
		for _, child in ipairs(inst:GetDescendants()) do
			Extras.hideVisual(child)
		end
	end)
	Extras.invisModel = model
end
function Extras.applyInvis()
	local model = character()
	if not model then
		return
	end
	Extras.watchModel(model)
	Extras.invisActive = true
	Extras.hideModelTree(model)
	local viewModels = workspace:FindFirstChild("ViewModels")
	if viewModels then
		Extras.hideModelTree(viewModels)
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		pcall(function()
			humanoid.NameDisplayDistance = 0
			humanoid.HealthDisplayDistance = 0
		end)
	end
end
function Extras.restoreInvis()
	if not Extras.invisActive then
		return
	end
	Extras.stopInvisWatch()
	local model = character()
	if model then
		for _, inst in ipairs(model:GetDescendants()) do
			if inst:IsA("BasePart") then
				pcall(function()
					inst.LocalTransparencyModifier = 0
				end)
			end
		end
	end
	for inst, saved in pairs(Extras.invisSaved) do
		if inst.Parent then
			pcall(function()
				if type(saved) == "table" then
					if saved.kind == "part" then
						inst.Transparency = saved.t
						if inst:IsA("BasePart") then
							inst.LocalTransparencyModifier = saved.lt or 0
						end
					elseif saved.kind == "tex" then
						inst.Transparency = saved.t
					elseif saved.kind == "fx" or saved.kind == "gui" then
						inst.Enabled = saved.on
					end
				elseif inst:IsA("Decal") or inst:IsA("Texture") then
					inst.Transparency = saved
				elseif inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") or inst:IsA("Highlight") then
					inst.Enabled = saved
				end
			end)
		end
	end
	Extras.invisSaved = {}
	Extras.invisActive = false
end
local GOD_BOXES = {
	"HitboxHead",
	"HitboxBody",
	"PhysicalHitboxHead",
	"PhysicalHitboxBody",
}
function Extras.clearGodConns()
	for _, conn in ipairs(Extras.godConns) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	Extras.godConns = {}
	Extras.godHum = nil
end
function Extras.applyGod()
	local model = character()
	local hum = humanoid()
	if not model or not hum then
		return
	end
	Extras.godActive = true
	pcall(function()
		if hum.MaxHealth < 100 then
			hum.MaxHealth = 100
		end
		hum.Health = hum.MaxHealth
		hum.BreakJointsOnDeath = false
		hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	end)
	if Extras.godHum ~= hum then
		Extras.clearGodConns()
		Extras.godHum = hum
		table.insert(Extras.godConns, hum:GetPropertyChangedSignal("Health"):Connect(function()
			if Extras.godActive and hum.Parent then
				pcall(function()
					hum.Health = hum.MaxHealth
				end)
			end
		end))
	end
	for _, name in ipairs(GOD_BOXES) do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			if Extras.godBoxes[part] == nil then
				Extras.godBoxes[part] = {
					CanQuery = part.CanQuery,
					CanTouch = part.CanTouch,
				}
			end
			part.CanQuery = false
			part.CanTouch = false
		end
	end
end
function Extras.restoreGod()
	if not Extras.godActive then
		return
	end
	Extras.clearGodConns()
	for part, saved in pairs(Extras.godBoxes) do
		if part.Parent then
			pcall(function()
				part.CanQuery = saved.CanQuery
				part.CanTouch = saved.CanTouch
			end)
		end
	end
	Extras.godBoxes = {}
	Extras.godActive = false
	local hum = humanoid()
	if hum then
		pcall(function()
			hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
			hum.BreakJointsOnDeath = true
		end)
	end
end
function Extras.applyAntiFling(config)
	local root = rootPart()
	if not root then
		return
	end
	local limit = config.antiFlingLimit or 220
	local velocity = root.AssemblyLinearVelocity
	if velocity.Magnitude > limit then
		root.AssemblyLinearVelocity = velocity.Unit * limit
	end
	if root.AssemblyAngularVelocity.Magnitude > 30 then
		root.AssemblyAngularVelocity = Vector3.zero
	end
end
function Extras.applyAntiVoid(config)
	local root = rootPart()
	if not root then
		return
	end
	local floor = config.antiVoidFloor or -120
	if root.Position.Y < floor then
		if Extras.voidLastSafe then
			root.CFrame = Extras.voidLastSafe
			root.AssemblyLinearVelocity = Vector3.zero
		end
	elseif root.Position.Y > floor + 25 then
		Extras.voidLastSafe = root.CFrame
	end
end
function Extras.startAntiAfk()
	if Extras.antiAfkConn then
		return
	end
	Extras.antiAfkConn = LocalPlayer.Idled:Connect(function()
		pcall(function()
			local virtualUser = game:GetService("VirtualUser")
			virtualUser:CaptureController()
			virtualUser:ClickButton2(Vector2.new())
		end)
	end)
end
function Extras.stopAntiAfk()
	if Extras.antiAfkConn then
		Extras.antiAfkConn:Disconnect()
		Extras.antiAfkConn = nil
	end
end
function Extras.applyHitbox(config)
	local size = Vector3.one * (config.hitboxSize or 15)
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			local part = player.Character:FindFirstChild("HumanoidRootPart")
			if part and part:IsA("BasePart") then
				if Filter.shouldSkip(player, config) then
					local saved = Extras.hitboxSaved[part]
					if saved then
						pcall(function()
							part.Size = saved.Size
							part.Transparency = saved.Transparency
							part.CanCollide = saved.CanCollide
							part.Massless = saved.Massless
						end)
						Extras.hitboxSaved[part] = nil
					end
				else
					if not Extras.hitboxSaved[part] then
						Extras.hitboxSaved[part] = {
							Size = part.Size,
							Transparency = part.Transparency,
							CanCollide = part.CanCollide,
							Massless = part.Massless,
						}
					end
					part.Size = size
					part.Transparency = 0.75
					part.CanCollide = false
					part.Massless = true
				end
			end
		end
	end
end
function Extras.restoreHitbox()
	if next(Extras.hitboxSaved) == nil then
		return
	end
	for part, saved in pairs(Extras.hitboxSaved) do
		if part.Parent then
			pcall(function()
				part.Size = saved.Size
				part.Transparency = saved.Transparency
				part.CanCollide = saved.CanCollide
				part.Massless = saved.Massless
			end)
		end
	end
	Extras.hitboxSaved = {}
end
function Extras.applyCameraFov(config)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local fov = config.cameraFov or 100
	if not Extras.fovActive then
		Extras.savedFov = camera.FieldOfView
		Extras.fovActive = true
	elseif Extras.fovSet == fov then
		return
	end
	Extras.fovSet = fov
	camera.FieldOfView = fov
end
function Extras.restoreCameraFov()
	if not Extras.fovActive then
		return
	end
	local camera = workspace.CurrentCamera
	if camera then
		pcall(function()
			camera.FieldOfView = Extras.savedFov
		end)
	end
	Extras.fovActive = false
	Extras.fovSet = nil
end
function Extras.applyFullbright()
	if not Extras.fbActive then
		Extras.savedLighting = {
			Ambient = Lighting.Ambient,
			OutdoorAmbient = Lighting.OutdoorAmbient,
			Brightness = Lighting.Brightness,
			FogEnd = Lighting.FogEnd,
			GlobalShadows = Lighting.GlobalShadows,
		}
		Extras.fbActive = true
		Extras.fbApplied = false
	end
	if Extras.fbApplied then
		return
	end
	Lighting.Ambient = Color3.new(1, 1, 1)
	Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
	Lighting.Brightness = 2
	Lighting.FogEnd = 1000000
	Lighting.GlobalShadows = false
	Extras.fbApplied = true
end
function Extras.restoreFullbright()
	if not Extras.fbActive or not Extras.savedLighting then
		return
	end
	local saved = Extras.savedLighting
	pcall(function()
		Lighting.Ambient = saved.Ambient
		Lighting.OutdoorAmbient = saved.OutdoorAmbient
		Lighting.Brightness = saved.Brightness
		Lighting.FogEnd = Performance.graphicsActive and 1000000 or saved.FogEnd
		Lighting.GlobalShadows = (not Performance.graphicsActive) and saved.GlobalShadows or false
	end)
	Extras.fbActive = false
	Extras.fbApplied = false
	Extras.savedLighting = nil
end
function Extras.applyXray(now, interval)
	if now and now - Extras.xraySweepAt < (interval or 1) then
		return
	end
	Extras.xraySweepAt = now or 0
	local localChar = character()
	for _, part in ipairs(workspace:GetDescendants()) do
		if part:IsA("BasePart") and not part:IsA("Terrain") and part.Transparency < 1 then
			local model = part:FindFirstAncestorOfClass("Model")
			local owner = model and Players:GetPlayerFromCharacter(model)
			if not owner and not (localChar and part:IsDescendantOf(localChar)) then
				Extras.xrayTouched[part] = true
				part.LocalTransparencyModifier = 0.65
			end
		end
	end
end
function Extras.restoreXray()
	for part in pairs(Extras.xrayTouched) do
		pcall(function()
			part.LocalTransparencyModifier = 0
		end)
	end
	Extras.xrayTouched = {}
	Extras.xraySweepAt = 0
end
function Extras.clearFreecamLatch()
	Extras.freecamLatched = false
	Extras.freecamBindWasDown = false
end
function Extras.applyFreecam(config, dt)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if not Extras.freecamActive then
		Extras.savedCamType = camera.CameraType
		Extras.savedCamSubject = camera.CameraSubject
		local cf = camera.CFrame
		local pitch, yaw = cf:ToOrientation()
		Extras.freecamPitch = pitch
		Extras.freecamYaw = yaw
		Extras.freecamPos = cf.Position
		camera.CameraType = Enum.CameraType.Scriptable
		Extras.freecamActive = true
		if not Extras.freecamLookConn then
			Extras.freecamLookConn = UserInputService.InputChanged:Connect(function(input)
				if not Extras.freecamActive then
					return
				end
				if input.UserInputType == Enum.UserInputType.MouseMovement
					and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
				then
					Extras.freecamYaw = Extras.freecamYaw - input.Delta.X * 0.005
					Extras.freecamPitch = math.clamp(Extras.freecamPitch - input.Delta.Y * 0.005, -1.4, 1.4)
				end
			end)
		end
	end
	local rot = CFrame.fromOrientation(Extras.freecamPitch, Extras.freecamYaw, 0)
	local move = Vector3.new(0, 0, 0)
	if not UserInputService:GetFocusedTextBox() then
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			move = move + rot.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			move = move - rot.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			move = move - rot.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			move = move + rot.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.E) then
			move = move + Vector3.new(0, 1, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then
			move = move - Vector3.new(0, 1, 0)
		end
	end
	local speed = config.freecamSpeed or 80
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
		speed = speed * 2
	end
	if move.Magnitude > 0.01 then
		Extras.freecamPos = Extras.freecamPos + move.Unit * speed * math.min(dt or 0.016, 0.1)
	end
	camera.CFrame = CFrame.new(Extras.freecamPos) * rot
end
function Extras.restoreFreecam()
	if not Extras.freecamActive then
		return
	end
	local camera = workspace.CurrentCamera
	if camera then
		pcall(function()
			camera.CameraType = Extras.savedCamType or Enum.CameraType.Custom
			if Extras.savedCamSubject then
				camera.CameraSubject = Extras.savedCamSubject
			end
		end)
	end
	if Extras.freecamLookConn then
		Extras.freecamLookConn:Disconnect()
		Extras.freecamLookConn = nil
	end
	Extras.freecamActive = false
end
function Extras.applyGravity(config)
	if not Extras.gravityActive then
		Extras.savedGravity = workspace.Gravity
		Extras.gravityActive = true
	end
	workspace.Gravity = config.gravityValue or 60
end
function Extras.restoreGravity()
	if not Extras.gravityActive then
		return
	end
	pcall(function()
		workspace.Gravity = Extras.savedGravity
	end)
	Extras.gravityActive = false
end
function Extras.applyTime(config)
	if not Extras.timeActive then
		Extras.savedClock = Lighting.ClockTime
		Extras.timeActive = true
	end
	local hour = (config.timeHour or 14) % 24
	if Extras.timeSet == hour then
		return
	end
	Extras.timeSet = hour
	Lighting.ClockTime = hour
end
function Extras.restoreTime()
	if not Extras.timeActive then
		return
	end
	pcall(function()
		Lighting.ClockTime = Extras.savedClock
	end)
	Extras.timeActive = false
	Extras.timeSet = nil
end
function Extras.rejoin()
	if Persist.enabled then
		Persist.queue()
	end
	pcall(function()
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
	end)
end
function Extras.serverHop()
	if Extras.hopping then
		return
	end
	if typeof(game.HttpGet) ~= "function" then
		return
	end
	Extras.hopping = true
	task.spawn(function()
		local ok, body = pcall(function()
			return game:HttpGet(
				"https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Desc&limit=100"
			)
		end)
		if not ok or type(body) ~= "string" then
			Extras.hopping = false
			return
		end
		local decodedOk, data = pcall(function()
			return HttpService:JSONDecode(body)
		end)
		if not decodedOk or type(data) ~= "table" or type(data.data) ~= "table" then
			Extras.hopping = false
			return
		end
		local candidates = {}
		for _, server in ipairs(data.data) do
			if server.id
				and server.id ~= game.JobId
				and type(server.playing) == "number"
				and type(server.maxPlayers) == "number"
				and server.playing < server.maxPlayers
			then
				table.insert(candidates, server)
			end
		end
		if #candidates == 0 then
			Extras.hopping = false
			return
		end
		local pick = candidates[math.random(1, #candidates)]
		if Persist.enabled then
			Persist.queue()
		end
		pcall(function()
			TeleportService:TeleportToPlaceInstance(game.PlaceId, pick.id, LocalPlayer)
		end)
		Extras.hopping = false
	end)
end
function Extras.setDevConsole(visible)
	pcall(function()
		game:GetService("StarterGui"):SetCore("DevConsoleVisible", visible == true)
	end)
end
function Extras.applyF9Debug(config)
	if not config or config.f9Debug == true then
		return
	end
	local now = os.clock()
	if Extras.f9HideAt and now - Extras.f9HideAt < 0.2 then
		return
	end
	Extras.f9HideAt = now
	local open = false
	pcall(function()
		open = game:GetService("StarterGui"):GetCore("DevConsoleVisible") == true
	end)
	if open then
		Extras.setDevConsole(false)
	end
end
function Extras.restoreAll()
	Extras.restoreSpeed()
	Extras.stopInfJump()
	Extras.restoreNoclip()
	Extras.restoreSpin()
	Extras.restoreInvis()
	Extras.restoreGod()
	Extras.stopAntiAfk()
	Extras.restoreHitbox()
	Extras.restoreCameraFov()
	Extras.restoreFullbright()
	Extras.restoreXray()
	Extras.restoreFreecam()
	Extras.clearFreecamLatch()
	Extras.restoreGravity()
	Extras.restoreTime()
end
return Extras
end)()
local KillAll = (function()
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local KillAll = {}
KillAll.victim = nil
KillAll.part = nil
KillAll.firing = false
KillAll.waiting = false
KillAll.enabled = false
KillAll.lastClick = 0
KillAll.lastEquip = 0
KillAll.lastScan = 0
KillAll.warnAt = 0
KillAll.ignoreOffUntil = 0
KillAll.maxDistance = 300
KillAll.bornAt = {}
KillAll.spawnGrace = 3
KillAll.flick = 0
KillAll.slot = "primary"
KillAll.lastSwap = 0
KillAll.reloadHoldUntil = 0
KillAll.fireWaitUntil = 0
KillAll.immuneUntil = 0
KillAll.immuneVictim = nil
local IMMUNE_WAIT = 1.5
local FLICK_OFFSETS = {
	Vector3.new(0, 0, 0),
	Vector3.new(0, 0.35, 0),
	Vector3.new(0, 1.15, 0),
	Vector3.new(0, 0.7, 0),
	Vector3.new(1.15, 0.35, 0),
	Vector3.new(-1.15, 0.35, 0),
	Vector3.new(0, 0.35, 1.15),
	Vector3.new(0, 0.35, -1.15),
	Vector3.new(0.85, 0.9, 0.85),
	Vector3.new(-0.85, 0.9, -0.85),
	Vector3.new(0.85, 0.2, -0.85),
	Vector3.new(-0.85, 0.2, 0.85),
	Vector3.new(0, 1.8, 0),
	Vector3.new(0, -0.25, 0),
}
local IMMUNE_ATTRS = {
	"Immune",
	"Immunity",
	"Invincible",
	"Invulnerable",
	"SpawnProtection",
	"SpawnImmune",
	"GodMode",
	"IFrames",
	"iFrames",
	"Protected",
}
local function truthy(value)
	return value == true or value == 1 or value == "true"
end
local function hasImmuneAttr(inst)
	if typeof(inst) ~= "Instance" then
		return false
	end
	for _, name in ipairs(IMMUNE_ATTRS) do
		if truthy(inst:GetAttribute(name)) then
			return true
		end
	end
	return false
end
local function markBorn(character)
	if typeof(character) == "Instance" then
		KillAll.bornAt[character] = os.clock()
	end
end
for _, player in ipairs(Players:GetPlayers()) do
	if player ~= LocalPlayer then
		player.CharacterAdded:Connect(markBorn)
	end
end
Players.PlayerAdded:Connect(function(player)
	if player ~= LocalPlayer then
		player.CharacterAdded:Connect(markBorn)
	end
end)
local function localRoot()
	local character = LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end
local function modelAlive(model)
	if typeof(model) ~= "Instance" or not model.Parent then
		return false
	end
	if model == LocalPlayer.Character then
		return false
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health <= 0 then
		return false
	end
	return Aimbot.getHeadPart(model) ~= nil
end
function KillAll.isImmune(model)
	if typeof(model) ~= "Instance" or not model.Parent then
		return false
	end
	if model:FindFirstChildWhichIsA("ForceField", true) then
		return true
	end
	if hasImmuneAttr(model) then
		return true
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hasImmuneAttr(hum) then
		return true
	end
	local player = Players:GetPlayerFromCharacter(model)
	if hasImmuneAttr(player) then
		return true
	end
	local ok, tags = pcall(function()
		return CollectionService:GetTags(model)
	end)
	if ok and type(tags) == "table" then
		for _, tag in ipairs(tags) do
			local key = string.lower(tostring(tag))
			if string.find(key, "immun", 1, true)
				or string.find(key, "invinc", 1, true)
				or string.find(key, "forcefield", 1, true)
				or string.find(key, "spawnprotect", 1, true)
			then
				return true
			end
		end
	end
	if model:FindFirstChild("Immune")
		or model:FindFirstChild("Immunity")
		or model:FindFirstChild("SpawnShield")
		or model:FindFirstChild("Invincible")
	then
		return true
	end
	local born = KillAll.bornAt[model]
	if born and os.clock() - born < KillAll.spawnGrace then
		return true
	end
	return false
end
local function eachVictim(config, callback)
	local seen = {}
	local function consider(model)
		if typeof(model) ~= "Instance" or seen[model] then
			return
		end
		if Filter.shouldSkipModel(model, config) then
			return
		end
		seen[model] = true
		callback(model)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			consider(player.Character)
		end
	end
	pcall(function()
		for _, entity in ipairs(CollectionService:GetTagged("Entity")) do
			if entity ~= LocalPlayer.Character then
				consider(entity)
			end
		end
	end)
	local hurt = workspace:FindFirstChild("HurtEffect")
	if hurt then
		for _, child in ipairs(hurt:GetChildren()) do
			if child.ClassName ~= "Highlight" then
				consider(child)
			end
		end
	end
end
function KillAll.closest(config, origin)
	local bestOpen, bestOpenPart, bestOpenDist = nil, nil, math.huge
	local bestAny, bestAnyPart, bestAnyDist = nil, nil, math.huge
	eachVictim(config, function(model)
		if not modelAlive(model) then
			return
		end
		local part = Aimbot.getHeadPart(model)
		if not part then
			return
		end
		local dist = (part.Position - origin).Magnitude
		if dist > KillAll.maxDistance then
			return
		end
		if dist < bestAnyDist then
			bestAnyDist = dist
			bestAny = model
			bestAnyPart = part
		end
		if not KillAll.isImmune(model) and dist < bestOpenDist then
			bestOpenDist = dist
			bestOpen = model
			bestOpenPart = part
		end
	end)
	if bestOpen then
		return bestOpen, bestOpenPart, false
	end
	return bestAny, bestAnyPart, bestAny ~= nil
end
function KillAll.press(down)
	if down then
		if typeof(mouse1press) == "function" then
			pcall(mouse1press)
		else
			pcall(function()
				VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
			end)
		end
	else
		if typeof(mouse1release) == "function" then
			pcall(mouse1release)
		else
			pcall(function()
				VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
			end)
		end
	end
end
function KillAll.activateTool()
	local character = LocalPlayer.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if tool then
		pcall(function()
			tool:Activate()
		end)
	end
end
function KillAll.manageWeapons()
	local now = os.clock()
	if now - KillAll.lastSwap < 0.25 then
		return
	end
	local slots = Weapon.loadout()
	local primary = slots.primary
	local secondary = slots.secondary
	local melee = slots.melee
	local function gunReady(item)
		return item and not Weapon.isGunEmpty(item)
	end
	local function swap(item, name, reason)
		if not item then
			return false
		end
		if KillAll.firing then
			KillAll.press(false)
			KillAll.firing = false
		end
		KillAll.lastSwap = now
		KillAll.slot = name
		Weapon.equipItem(item)
		if not Weapon.isGunEmpty(item) then
			if Weapon.reloadItem and Weapon.reloadItem ~= item then
				Weapon.clearReload()
			end
			KillAll.reloadHoldUntil = 0
			KillAll.fireWaitUntil = now + Weapon.equipCooldown(item)
		end
		return true
	end
	if gunReady(primary) then
		if not primary.IsEquipped then
			swap(primary, "primary", "primary ready")
		else
			KillAll.slot = "primary"
		end
		return
	end
	if gunReady(secondary) then
		if not secondary.IsEquipped then
			swap(secondary, "secondary", "secondary ready")
		else
			KillAll.slot = "secondary"
		end
		return
	end
	if Weapon.isReloading() or now < KillAll.reloadHoldUntil then
		return
	end
	local reloadItem, reloadName
	if primary and Weapon.hasReserve(primary) then
		reloadItem, reloadName = primary, "primary"
	elseif secondary and Weapon.hasReserve(secondary) then
		reloadItem, reloadName = secondary, "secondary"
	end
	if reloadItem then
		if not reloadItem.IsEquipped then
			swap(reloadItem, reloadName, "reload")
		else
			KillAll.slot = reloadName
		end
		if Weapon.requestReload(reloadItem) then
			KillAll.reloadHoldUntil = Weapon.reloadUntil or (now + 2)
			KillAll.lastSwap = now
		end
		return
	end
	if melee then
		if not melee.IsEquipped then
			swap(melee, "melee", "guns empty")
		else
			KillAll.slot = "melee"
		end
	end
end
function KillAll.want()
	return KillAll.enabled == true
end
function KillAll.setEnabled(on)
	if on then
		KillAll.enabled = true
		KillAll.ignoreOffUntil = os.clock() + 0.75
		KillAll.slot = "primary"
		KillAll.reloadHoldUntil = 0
		KillAll.fireWaitUntil = 0
		KillAll.immuneUntil = 0
		KillAll.immuneVictim = nil
		return
	end
	if os.clock() < KillAll.ignoreOffUntil then
		KillAll.enabled = true
		return
	end
	KillAll.enabled = false
	KillAll.stop()
end
function KillAll.stop()
	if KillAll.firing then
		KillAll.press(false)
	end
	KillAll.firing = false
	KillAll.victim = nil
	KillAll.part = nil
	KillAll.waiting = false
	KillAll.flick = 0
	KillAll.immuneUntil = 0
	KillAll.immuneVictim = nil
end
function KillAll.stick(part)
	local root = localRoot()
	if not root or typeof(part) ~= "Instance" or not part.Parent then
		return false
	end
	KillAll.flick = KillAll.flick + 1
	local offset = FLICK_OFFSETS[(KillAll.flick % #FLICK_OFFSETS) + 1]
	local jitter = Vector3.new(
		(math.random() - 0.5) * 0.55,
		(math.random() - 0.5) * 0.4,
		(math.random() - 0.5) * 0.55
	)
	local targetRoot = part.Parent:FindFirstChild("HumanoidRootPart")
	local destPos
	if targetRoot then
		destPos = (targetRoot.CFrame * CFrame.new(offset + jitter)).Position
	else
		destPos = part.Position + offset + jitter
	end
	local look = part.Position
	if (look - destPos).Magnitude < 0.12 then
		if targetRoot then
			look = destPos + targetRoot.CFrame.LookVector
		else
			look = destPos + Vector3.new(0, 0, -1)
		end
	end
	local cf = CFrame.lookAt(destPos, look)
	local character = LocalPlayer.Character
	pcall(function()
		if character and character.PivotTo then
			character:PivotTo(cf)
		end
	end)
	root.CFrame = cf
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return true
end
function KillAll.lookAt(part)
	local camera = workspace.CurrentCamera
	if not camera or typeof(part) ~= "Instance" or not part.Parent then
		return
	end
	local dest = part.Position
	local origin = camera.CFrame.Position
	if (dest - origin).Magnitude < 0.2 then
		dest = dest + Vector3.new(0, 0, 0.4)
	end
	camera.CFrame = CFrame.lookAt(origin, dest)
end
function KillAll.step(config)
	if not KillAll.want() then
		return
	end
	if config then
		config.killAll = true
	end
	Extras.applyInvis()
	Extras.applyGod()
	local now = os.clock()
	if now - KillAll.lastEquip > 0.2 then
		KillAll.lastEquip = now
		KillAll.manageWeapons()
	end
	local root = localRoot()
	if not root then
		return
	end
	if now - KillAll.lastScan >= 0.05 or not (KillAll.part and KillAll.part.Parent) then
		KillAll.lastScan = now
		local model, part, immune = KillAll.closest(config, root.Position)
		KillAll.victim = model
		KillAll.part = part
		KillAll.waiting = immune == true
	elseif KillAll.victim then
		KillAll.waiting = KillAll.isImmune(KillAll.victim)
	end
	if not KillAll.part then
		if KillAll.firing then
			KillAll.press(false)
			KillAll.firing = false
		end
		return
	end
	KillAll.stick(KillAll.part)
	KillAll.lookAt(KillAll.part)
	local immune = KillAll.waiting or (KillAll.victim and KillAll.isImmune(KillAll.victim))
	if immune then
		if KillAll.immuneVictim ~= KillAll.victim or now >= KillAll.immuneUntil then
			KillAll.immuneVictim = KillAll.victim
			KillAll.immuneUntil = now + IMMUNE_WAIT
		end
		if KillAll.firing then
			KillAll.press(false)
			KillAll.firing = false
		end
		return
	end
	if now < KillAll.immuneUntil then
		if KillAll.firing then
			KillAll.press(false)
			KillAll.firing = false
		end
		return
	end
	if KillAll.immuneVictim then
		KillAll.immuneVictim = nil
	end
	if Weapon.isReloading() or now < KillAll.reloadHoldUntil or now < (KillAll.fireWaitUntil or 0) then
		if KillAll.firing then
			KillAll.press(false)
			KillAll.firing = false
		end
		return
	end
	local held = Weapon.equippedItem()
	if held and not Weapon.isMelee(held) and Weapon.isGunEmpty(held) then
		if KillAll.firing then
			KillAll.press(false)
			KillAll.firing = false
		end
		return
	end
	if not KillAll.firing then
		KillAll.press(true)
		KillAll.firing = true
	end
	if now - KillAll.lastClick >= 0.1 then
		KillAll.lastClick = now
		KillAll.activateTool()
		if typeof(mouse1press) == "function" then
			pcall(mouse1press)
		end
	end
end
return KillAll
end)()
local UI = (function()
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UI = {}
UI.NAME = "LV"
UI.open = false
UI.gui = nil
UI.frame = nil
UI.running = false
UI.cursorGrab = false
UI.savedMouseIcon = nil
UI.savedMouseBehavior = nil
UI.connections = {}
UI.popups = {}
UI.menuKey = Enum.KeyCode.Insert
UI.menuKeys = {
	[Enum.KeyCode.Insert] = true,
	[Enum.KeyCode.Eight] = true,
	[Enum.KeyCode.KeypadEight] = true,
	[Enum.KeyCode.ButtonSelect] = true,
}
function UI.track(connection)
	if connection then
		table.insert(UI.connections, connection)
	end
	return connection
end
function UI.destroy()
	UI.running = false
	UI.closePopups()
	UI.popups = {}
	for _, connection in ipairs(UI.connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	UI.connections = {}
	if UI.gui then
		UI.gui:Destroy()
		UI.gui = nil
	end
	UI.frame = nil
	UI.open = false
	UI.cursorGrab = false
	UI.savedMouseIcon = nil
	UI.savedMouseBehavior = nil
end
local function px(n)
	return math.floor(n + 0.5)
end
local function offset(x, y)
	return UDim2.fromOffset(px(x), px(y))
end
local function hex(value)
	if Color3.fromHex then
		return Color3.fromHex(value)
	end
	local n = tonumber(value, 16) or 0
	return Color3.fromRGB(math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256)
end
local T = {
	bg = hex("101010"),
	shellLine = hex("252525"),
	titleLine = hex("1c1c1c"),
	panel = hex("101010"),
	panelLine = hex("2a2a2a"),
	field = hex("1c1c1c"),
	fieldLine = hex("323232"),
	button = hex("1c1c1c"),
	buttonLine = hex("333333"),
	hover = hex("262626"),
	hoverLine = hex("454545"),
	toggleOff = hex("2c2c2c"),
	toggleOn = hex("8a8a8a"),
	knobOff = hex("7a7a7a"),
	knobOn = hex("ececec"),
	press = hex("101010"),
	optHover = hex("262626"),
	text = hex("f2f2f2"),
	title = hex("dcdcdc"),
	label = hex("cfcfcf"),
	muted = hex("b0b0b0"),
	note = hex("9a9a9a"),
	tag = hex("8c8c8c"),
	track = hex("1a1a1a"),
	scroll = hex("3d3d3d"),
	white = hex("ffffff"),
	black = hex("000000"),
	dim = hex("e7e7e7"),
	red = hex("ff5f57"),
	yellow = hex("febc2e"),
	green = hex("28c840"),
}
local FONT = Enum.Font.BuilderSans
local FONT_MED = Enum.Font.BuilderSansMedium
local FONT_BOLD = Enum.Font.BuilderSansBold
local FONT_MONO = Enum.Font.Code
local MOTION = {
	micro = TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	hover = TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
	enter = TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	knob = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
	pill = TweenInfo.new(0.30, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	card = TweenInfo.new(0.30, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
}
local ZW = "\u{200B}"
local function freeze(text)
	if type(text) ~= "string" or text == "" then
		return text
	end
	return (string.gsub(text, "(%S)", "%1" .. ZW))
end
local function lockLocale(inst)
	if inst:IsA("GuiObject") then
		pcall(function()
			inst.AutoLocalize = false
		end)
	end
end
local function new(class, props)
	local inst = Instance.new(class)
	lockLocale(inst)
	for key, value in pairs(props or {}) do
		inst[key] = value
	end
	lockLocale(inst)
	return inst
end
local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = inst
	return c
end
local function pill(inst)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = inst
	return c
end
local function pad(inst, top, bottom, left, right)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, top or 0)
	p.PaddingBottom = UDim.new(0, bottom or top or 0)
	p.PaddingLeft = UDim.new(0, left or 0)
	p.PaddingRight = UDim.new(0, right or left or 0)
	p.Parent = inst
	return p
end
local function vlist(inst, gap)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap or 8)
	layout.Parent = inst
	return layout
end
local function hlist(inst, gap)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap or 8)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = inst
	return layout
end
local function tw(inst, info, goal)
	local tween = TweenService:Create(inst, info, goal)
	tween:Play()
	return tween
end
local function hoverable(btn, base, hoverColor)
	btn.MouseEnter:Connect(function()
		tw(btn, MOTION.hover, { BackgroundColor3 = hoverColor })
	end)
	btn.MouseLeave:Connect(function()
		tw(btn, MOTION.hover, { BackgroundColor3 = base })
	end)
end
function UI.closePopups()
	for _, closeFn in ipairs(UI.popups) do
		pcall(closeFn)
	end
end
function UI.applyCursor()
	if not UI.running then
		return
	end
	if UI.open then
		if not UI.cursorGrab then
			UI.savedMouseIcon = UserInputService.MouseIconEnabled
			UI.savedMouseBehavior = UserInputService.MouseBehavior
			UI.cursorGrab = true
		end
		UserInputService.MouseIconEnabled = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		return
	end
	if UI.cursorGrab then
		UserInputService.MouseIconEnabled = UI.savedMouseIcon == true
		if UI.savedMouseBehavior then
			UserInputService.MouseBehavior = UI.savedMouseBehavior
		end
		UI.cursorGrab = false
	end
end
function UI.setMenuOpen(state)
	UI.open = state
	if UI.frame then
		UI.frame.Visible = state
	end
	if not state then
		UI.closePopups()
	end
	UI.applyCursor()
end
function UI.toggleMenu()
	local env = (typeof(getgenv) == "function" and getgenv()) or _G
	if type(env) == "table" and env.LV_BOOTING then
		return
	end
	UI.setMenuOpen(not UI.open)
end
function UI.startMenuToggle(inputModule)
	UI.track(UserInputService.InputBegan:Connect(function(input, processed)
		if not UI.running or processed or inputModule.listening then
			return
		end
		local env = (typeof(getgenv) == "function" and getgenv()) or _G
		if type(env) == "table" and env.LV_BOOTING then
			return
		end
		if UI.menuKeys[input.KeyCode] then
			UI.toggleMenu()
		end
	end))
end
function UI.build(config, callbacks, warnings, inputModule)
	local Players = game:GetService("Players")
	local LocalPlayer = Players.LocalPlayer
	UI.popups = {}
	Streamproof.destroyExisting(UI.NAME)
	local existing = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild(UI.NAME)
	if existing then
		existing:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = UI.NAME
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 999999
	gui.AutoLocalize = false
	UI.track(gui.DescendantAdded:Connect(lockLocale))
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	UI.gui = gui
	UI.running = true
	local camera = Workspace.CurrentCamera
	local vp = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local W = px(math.clamp(640, 320, math.max(320, vp.X - 40)))
	local H = px(math.clamp(460, 260, math.max(260, vp.Y - 40)))
	local SIDEBAR_W = px(math.clamp(W * 0.22, 118, 148))
	local start = Vector2.new(px((vp.X - W) / 2), px((vp.Y - H) / 2))
	local root = new("Frame", {
		Name = "Main",
		BackgroundTransparency = 1,
		Size = offset(W, H),
		Position = offset(start.X, start.Y),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
	UI.frame = root
	local function addShadow(grow, transparency, z)
		local layer = new("Frame", {
			BackgroundColor3 = T.black,
			BackgroundTransparency = transparency,
			Position = offset(-grow, -grow),
			Size = UDim2.new(1, grow * 2, 1, grow * 2),
			BorderSizePixel = 0,
			ZIndex = z,
			Parent = root,
		})
		corner(layer, 16 + math.floor(grow * 0.5))
		return layer
	end
	addShadow(12, 0.9, 8)
	addShadow(6, 0.84, 9)
	local shell = new("Frame", {
		BackgroundColor3 = T.bg,
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 10,
		Parent = root,
	})
	corner(shell, 18)
	local canvas = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 11,
		Parent = shell,
	})
	local titleBar = new("Frame", {
		BackgroundColor3 = T.bg,
		Size = UDim2.new(1, 0, 0, 32),
		BorderSizePixel = 0,
		ZIndex = 12,
		Parent = canvas,
	})
	corner(titleBar, 18)
	new("Frame", {
		BackgroundColor3 = T.bg,
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.new(0, 0, 1, -16),
		BorderSizePixel = 0,
		ZIndex = 12,
		Parent = titleBar,
	})
	new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = FONT_BOLD,
		Text = freeze("LV"),
		TextSize = 14,
		TextColor3 = T.title,
		ZIndex = 13,
		Parent = titleBar,
	})
	local lightRow = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = offset(56, 12),
		ZIndex = 13,
		Parent = titleBar,
	})
	hlist(lightRow, 6)
	local function trafficLight(color, order, onClick)
		local button = new("TextButton", {
			BackgroundColor3 = color,
			Size = offset(12, 12),
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 14,
			Parent = lightRow,
		})
		pill(button)
		button.Activated:Connect(function()
			if onClick then
				onClick()
			end
		end)
		return button
	end
	trafficLight(T.green, 1)
	trafficLight(T.yellow, 2, function()
		UI.setMenuOpen(false)
	end)
	trafficLight(T.red, 3, function()
		if callbacks.onUnload then
			callbacks.onUnload()
		end
	end)
	local dragging = false
	local dragStart
	local startPos
	UI.track(titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = root.Position
		end
	end))
	UI.track(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end))
	UI.track(UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart
			root.Position = offset(
				startPos.X.Offset + delta.X,
				startPos.Y.Offset + delta.Y
			)
		end
	end))
	local contentHolder = new("Frame", {
		BackgroundTransparency = 1,
		Position = offset(0, 32),
		Size = UDim2.new(1, 0, 1, -32),
		ZIndex = 11,
		Parent = canvas,
	})
	local sidebar = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, SIDEBAR_W, 1, 0),
		ZIndex = 11,
		Parent = contentHolder,
	})
	pad(sidebar, 8, 8, 8, 8)
	local TAB_H, TAB_GAP = 26, 2
	local tabLayer = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -28),
		ZIndex = 11,
		Parent = sidebar,
	})
	local tabPill = new("Frame", {
		BackgroundColor3 = T.optHover,
		Size = UDim2.new(1, 0, 0, TAB_H),
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = tabLayer,
	})
	pill(tabPill)
	local tabScroller = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -28),
		ZIndex = 12,
		Parent = sidebar,
	})
	vlist(tabScroller, TAB_GAP)
	new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 2, 1, 0),
		Size = UDim2.new(1, 0, 0, 20),
		Font = FONT,
		Text = freeze("Insert / 8"),
		TextSize = 12,
		TextColor3 = T.tag,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 11,
		Parent = sidebar,
	})
	local main = new("Frame", {
		BackgroundTransparency = 1,
		Position = offset(SIDEBAR_W, 0),
		Size = UDim2.new(1, -SIDEBAR_W, 1, 0),
		ZIndex = 11,
		Parent = contentHolder,
	})
	pad(main, 8, 8, 8, 8)
	local searchWrap = new("Frame", {
		BackgroundColor3 = T.field,
		Size = UDim2.new(1, 0, 0, 28),
		BorderSizePixel = 0,
		ZIndex = 12,
		Parent = main,
	})
	pill(searchWrap)
	pad(searchWrap, 0, 0, 8, 8)
	local searchBox = new("TextBox", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = FONT,
		Text = "",
		PlaceholderText = freeze("Search"),
		PlaceholderColor3 = T.tag,
		TextSize = 13,
		TextColor3 = T.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		ZIndex = 13,
		Parent = searchWrap,
	})
	searchBox.Focused:Connect(function()
		tw(searchWrap, MOTION.hover, { BackgroundColor3 = T.hover })
	end)
	searchBox.FocusLost:Connect(function()
		tw(searchWrap, MOTION.hover, { BackgroundColor3 = T.field })
	end)
	local PAGE_Y = 36
	local page = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = offset(0, PAGE_Y),
		Size = UDim2.new(1, 0, 1, -PAGE_Y),
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = T.scroll,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 11,
		Parent = main,
	})
	vlist(page, 6)
	pad(page, 0, 12, 0, 4)
	local TABS = { "Aimbot", "Visuals", "Chams", "World", "Combat", "Movement", "Exploits", "Players", "Misc" }
	local currentTab = TABS[1]
	local tabButtons = {}
	local cards = {}
	local cardOrder = 0
	local function refreshVisibility()
		local query = string.lower((searchBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
		local searching = query ~= ""
		for _, entry in ipairs(cards) do
			if searching then
				entry.frame.Visible = string.find(entry.query, query, 1, true) ~= nil
			else
				entry.frame.Visible = entry.tab == currentTab
			end
		end
	end
	local function movePill(index)
		tw(tabPill, MOTION.pill, { Position = offset(0, (index - 1) * (TAB_H + TAB_GAP)) })
	end
	local function makeTabButton(name, idx)
		local button = new("TextButton", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, TAB_H),
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			LayoutOrder = idx,
			ZIndex = 12,
			Parent = tabScroller,
		})
		pill(button)
		local label = new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Font = FONT_MED,
			Text = freeze(name),
			TextSize = 13,
			TextColor3 = idx == 1 and T.white or T.muted,
			ZIndex = 13,
			Parent = button,
		})
		button.Activated:Connect(function()
			if currentTab == name then
				return
			end
			currentTab = name
			searchBox.Text = ""
			for tabName, entry in pairs(tabButtons) do
				tw(entry.label, MOTION.hover, { TextColor3 = tabName == name and T.white or T.muted })
			end
			movePill(idx)
			page.CanvasPosition = Vector2.new()
			refreshVisibility()
		end)
		tabButtons[name] = { button = button, label = label }
	end
	for index, name in ipairs(TABS) do
		makeTabButton(name, index)
	end
	searchBox:GetPropertyChangedSignal("Text"):Connect(refreshVisibility)
	local function makeCard(tab, title, desc, keywords)
		cardOrder = cardOrder + 1
		local card = new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BorderSizePixel = 0,
			LayoutOrder = cardOrder,
			Visible = tab == currentTab,
			ZIndex = 12,
			Parent = page,
		})
		pad(card, 2, 4, 0, 0)
		vlist(card, 4)
		local head = new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 16),
			LayoutOrder = 1,
			ZIndex = 13,
			Parent = card,
		})
		new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			Font = FONT_BOLD,
			Text = freeze(title),
			TextSize = 13,
			TextColor3 = T.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 14,
			Parent = head,
		})
		table.insert(cards, {
			frame = card,
			tab = tab,
			query = string.lower(tab .. " " .. title .. " " .. (desc or "") .. " " .. (keywords or "")),
		})
		return card
	end
	local function labelRow(parent, text, orderIdx, height)
		local row = new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, height or 24),
			LayoutOrder = orderIdx or 2,
			ZIndex = 13,
			Parent = parent,
		})
		new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 92, 1, 0),
			Font = FONT_MED,
			Text = freeze(text),
			TextSize = 12,
			TextColor3 = T.label,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 14,
			Parent = row,
		})
		local slot = new("Frame", {
			BackgroundTransparency = 1,
			Position = offset(96, 0),
			Size = UDim2.new(1, -96, 1, 0),
			ZIndex = 13,
			Parent = row,
		})
		return slot, row
	end
	local function Toggle(parent, cfg)
		local state = cfg.value and true or false
		local button = new("TextButton", {
			BackgroundColor3 = state and T.toggleOn or T.toggleOff,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = offset(32, 18),
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			ZIndex = 14,
			Parent = parent,
		})
		pill(button)
		local knob = new("Frame", {
			BackgroundColor3 = state and T.knobOn or T.knobOff,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, state and 16 or 2, 0.5, 0),
			Size = offset(14, 14),
			BorderSizePixel = 0,
			ZIndex = 15,
			Parent = button,
		})
		pill(knob)
		local function render(value)
			state = value and true or false
			tw(button, MOTION.hover, { BackgroundColor3 = state and T.toggleOn or T.toggleOff })
			tw(knob, MOTION.knob, {
				Position = UDim2.new(0, state and 16 or 2, 0.5, 0),
				BackgroundColor3 = state and T.knobOn or T.knobOff,
			})
		end
		button.Activated:Connect(function()
			if cfg.onChange then
				cfg.onChange(not state)
			end
			render(cfg.get and cfg.get() or not state)
		end)
		return { set = render, get = function() return state end }
	end
	local function Slider(parent, cfg)
		local minValue, maxValue = cfg.min, cfg.max
		local value = math.clamp(cfg.value or minValue, minValue, maxValue)
		local holder = new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 14,
			Parent = parent,
		})
		local valueLabel = new("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = offset(32, 18),
			Font = FONT_MED,
			Text = tostring(value),
			TextSize = 12,
			TextColor3 = T.muted,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 15,
			Parent = holder,
		})
		local track = new("Frame", {
			BackgroundColor3 = T.track,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(1, -38, 0, 4),
			BorderSizePixel = 0,
			ZIndex = 15,
			Parent = holder,
		})
		pill(track)
		local fill = new("Frame", {
			BackgroundColor3 = T.knobOn,
			Size = UDim2.fromScale((value - minValue) / (maxValue - minValue), 1),
			BorderSizePixel = 0,
			ZIndex = 16,
			Parent = track,
		})
		pill(fill)
		local knob = new("Frame", {
			BackgroundColor3 = T.knobOn,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new((value - minValue) / (maxValue - minValue), 0, 0.5, 0),
			Size = offset(12, 12),
			BorderSizePixel = 0,
			ZIndex = 17,
			Parent = track,
		})
		pill(knob)
		local hit = new("TextButton", {
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.new(0, 0, 0.5, -10),
			ZIndex = 18,
			Parent = track,
		})
		local function apply(nextValue, fire)
			value = math.clamp(math.floor(nextValue + 0.5), minValue, maxValue)
			local alpha = (value - minValue) / (maxValue - minValue)
			fill.Size = UDim2.fromScale(alpha, 1)
			knob.Position = UDim2.new(alpha, 0, 0.5, 0)
			valueLabel.Text = tostring(value)
			if fire and cfg.onChange then
				cfg.onChange(value)
			end
		end
		local sliding = false
		hit.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				sliding = true
				local alpha = math.clamp((input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
				apply(minValue + alpha * (maxValue - minValue), true)
			end
		end)
		UI.track(UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				sliding = false
			end
		end))
		UI.track(UserInputService.InputChanged:Connect(function(input)
			if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then
				local alpha = math.clamp((input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
				apply(minValue + alpha * (maxValue - minValue), true)
			end
		end))
		return { set = function(v) apply(v, false) end }
	end
	local function BindButton(parent, kind)
		local button = new("TextButton", {
			BackgroundColor3 = T.button,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0, 100, 0, 22),
			Text = inputModule.getBindName(config, kind),
			Font = FONT_MED,
			TextSize = 12,
			TextColor3 = T.title,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			Selectable = false,
			Active = true,
			ZIndex = 14,
			Parent = parent,
		})
		pill(button)
		hoverable(button, T.button, T.hover)
		local function startListen()
			inputModule.beginListening(kind)
		end
		button.Activated:Connect(startListen)
		button.MouseButton1Click:Connect(startListen)
		return button
	end
	local function setRowsVisible(rows, visible)
		for _, row in ipairs(rows) do
			row.Visible = visible
		end
	end
	local function sectionLabel(parent, text, orderIdx)
		local row = new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 16),
			LayoutOrder = orderIdx or 2,
			ZIndex = 13,
			Parent = parent,
		})
		new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			Font = FONT_MED,
			Text = freeze(text),
			TextSize = 11,
			TextColor3 = T.muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 14,
			Parent = row,
		})
		return row
	end
	local function persist()
		if callbacks.onConfigChanged then
			callbacks.onConfigChanged()
		end
	end
	local function addToggle(card, label, order, get, set, extras)
		local slot = labelRow(card, label, order)
		local function syncExtras()
			if extras then
				setRowsVisible(extras, get())
			end
		end
		Toggle(slot, {
			value = get(),
			get = get,
			onChange = function()
				set()
				persist()
				syncExtras()
			end,
		})
		syncExtras()
	end
	local function addSlider(card, label, order, minValue, maxValue, getValue, setValue)
		local slot, row = labelRow(card, label, order)
		Slider(slot, {
			min = minValue,
			max = maxValue,
			value = getValue(),
			onChange = function(value)
				setValue(value)
				persist()
			end,
		})
		return row
	end
	local function Select(parent, items, getId, setId)
		local function labelOf(id)
			for i = 1, #items do
				if items[i].id == id then
					return items[i].label
				end
			end
			return items[1] and items[1].label or "?"
		end
		local button = new("TextButton", {
			BackgroundColor3 = T.button,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0, 112, 0, 22),
			Text = freeze(labelOf(getId())),
			Font = FONT_MED,
			TextSize = 12,
			TextColor3 = T.title,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			ZIndex = 14,
			Parent = parent,
		})
		pill(button)
		hoverable(button, T.button, T.hover)
		local panel
		local function closePanel()
			if panel then
				panel:Destroy()
				panel = nil
			end
		end
		table.insert(UI.popups, closePanel)
		local function openPanel()
			closePanel()
			local height = math.min(220, 8 + #items * 24)
			panel = new("Frame", {
				BackgroundColor3 = T.panel,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(148, height),
				ZIndex = 40,
				Parent = UI.gui,
			})
			corner(panel, 8)
			local list = new("ScrollingFrame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, -8, 1, -8),
				Position = UDim2.fromOffset(4, 4),
				CanvasSize = UDim2.fromOffset(0, #items * 24),
				ScrollBarThickness = 3,
				ZIndex = 41,
				Parent = panel,
			})
			vlist(list, 2)
			local current = getId()
			for index, item in ipairs(items) do
				local row = new("TextButton", {
					BackgroundColor3 = item.id == current and T.hover or T.button,
					Size = UDim2.new(1, 0, 0, 22),
					Text = freeze(item.label),
					Font = FONT_MED,
					TextSize = 12,
					TextColor3 = T.text,
					AutoButtonColor = false,
					BorderSizePixel = 0,
					LayoutOrder = index,
					ZIndex = 42,
					Parent = list,
				})
				pill(row)
				row.Activated:Connect(function()
					setId(item.id)
					button.Text = freeze(item.label)
					persist()
					closePanel()
				end)
			end
			local function place()
				if not UI.open then
					closePanel()
					return
				end
				if not panel or not panel.Parent or not button.Parent then
					return
				end
				local pos = button.AbsolutePosition
				local size = button.AbsoluteSize
				panel.Position = UDim2.fromOffset(pos.X + size.X - 148, pos.Y + size.Y + 4)
			end
			place()
		end
		button.Activated:Connect(function()
			if panel then
				closePanel()
			else
				openPanel()
			end
		end)
		UI.track(UserInputService.InputBegan:Connect(function(input)
			if not panel or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			local pos = input.Position
			local p = panel.AbsolutePosition
			local s = panel.AbsoluteSize
			local b = button.AbsolutePosition
			local bs = button.AbsoluteSize
			local inPanel = pos.X >= p.X and pos.X <= p.X + s.X and pos.Y >= p.Y and pos.Y <= p.Y + s.Y
			local inBtn = pos.X >= b.X and pos.X <= b.X + bs.X and pos.Y >= b.Y and pos.Y <= b.Y + bs.Y
			if not inPanel and not inBtn then
				closePanel()
			end
		end))
		return button
	end
	local function ActionButton(parent, text, order, size, onClick)
		local button = new("TextButton", {
			BackgroundColor3 = T.button,
			Size = size or UDim2.new(0, 52, 1, 0),
			Text = freeze(text),
			Font = FONT_MED,
			TextSize = 12,
			TextColor3 = T.text,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			LayoutOrder = order or 1,
			ZIndex = 14,
			Parent = parent,
		})
		pill(button)
		hoverable(button, T.button, T.hover)
		button.Activated:Connect(function()
			if onClick then
				onClick()
			end
		end)
		return button
	end
	local function MultiBoneSelect(parent)
		local function selectedIds()
			return Aimbot.sanitizeBones(config.aimBones)
		end
		local function summary()
			local ids = selectedIds()
			if #ids == 1 then
				local bone = Aimbot.boneById(ids[1])
				return bone and bone.label or ids[1]
			end
			return tostring(#ids) .. " bones"
		end
		local button = new("TextButton", {
			BackgroundColor3 = T.button,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0, 100, 0, 22),
			Text = freeze(summary()),
			Font = FONT_MED,
			TextSize = 12,
			TextColor3 = T.title,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			ZIndex = 14,
			Parent = parent,
		})
		pill(button)
		hoverable(button, T.button, T.hover)
		local panel
		local function closePanel()
			if panel then
				panel:Destroy()
				panel = nil
			end
		end
		table.insert(UI.popups, closePanel)
		local function openPanel()
			closePanel()
			local ids = selectedIds()
			local picked = {}
			for _, id in ipairs(ids) do
				picked[id] = true
			end
			panel = new("Frame", {
				BackgroundColor3 = T.panel,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(168, 220),
				ZIndex = 40,
				Parent = UI.gui,
			})
			corner(panel, 8)
			local list = new("ScrollingFrame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, -8, 1, -8),
				Position = UDim2.fromOffset(4, 4),
				CanvasSize = UDim2.fromOffset(0, #Aimbot.BONES * 24),
				ScrollBarThickness = 3,
				ZIndex = 41,
				Parent = panel,
			})
			vlist(list, 2)
			for index, bone in ipairs(Aimbot.BONES) do
				local row = new("TextButton", {
					BackgroundColor3 = picked[bone.id] and T.hover or T.button,
					Size = UDim2.new(1, 0, 0, 22),
					Text = freeze(bone.label),
					Font = FONT_MED,
					TextSize = 12,
					TextColor3 = T.text,
					AutoButtonColor = false,
					BorderSizePixel = 0,
					LayoutOrder = index,
					ZIndex = 42,
					Parent = list,
				})
				pill(row)
				row.Activated:Connect(function()
					local nextIds = selectedIds()
					local has = false
					for i = #nextIds, 1, -1 do
						if nextIds[i] == bone.id then
							table.remove(nextIds, i)
							has = true
						end
					end
					if not has then
						table.insert(nextIds, bone.id)
					end
					config.aimBones = Aimbot.sanitizeBones(nextIds)
					button.Text = freeze(summary())
					if callbacks.onConfigChanged then
						callbacks.onConfigChanged()
					end
					openPanel()
				end)
			end
			local function place()
				if not UI.open then
					closePanel()
					return
				end
				if not panel or not panel.Parent or not button.Parent then
					return
				end
				local pos = button.AbsolutePosition
				local size = button.AbsoluteSize
				panel.Position = UDim2.fromOffset(pos.X + size.X - 168, pos.Y + size.Y + 4)
			end
			place()
			if not button:GetAttribute("LVBonePlace") then
				button:SetAttribute("LVBonePlace", true)
				UI.track(RunService.RenderStepped:Connect(function()
					if panel and panel.Parent then
						place()
					end
				end))
			end
		end
		button.Activated:Connect(function()
			if panel then
				closePanel()
			else
				openPanel()
			end
		end)
		UI.track(UserInputService.InputBegan:Connect(function(input)
			if not panel or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			local pos = input.Position
			local p = panel.AbsolutePosition
			local s = panel.AbsoluteSize
			local b = button.AbsolutePosition
			local bs = button.AbsoluteSize
			local inPanel = pos.X >= p.X and pos.X <= p.X + s.X and pos.Y >= p.Y and pos.Y <= p.Y + s.Y
			local inBtn = pos.X >= b.X and pos.X <= b.X + bs.X and pos.Y >= b.Y and pos.Y <= b.Y + bs.Y
			if not inPanel and not inBtn then
				closePanel()
			end
		end))
		return button, closePanel
	end
	local aimCard = makeCard("Aimbot", "Aimbot", "Hold bind. Requires a weapon and line of sight. Selected bones share equal chance. Prediction is fixed at 80. Pauses while reloading or empty.", "aimbot fov ammo predict visible los bone")
	do
		local toggleSlot = labelRow(aimCard, "Enabled", 2)
		local keySlot, keyRow = labelRow(aimCard, "Bind", 3)
		local optionsHead = sectionLabel(aimCard, "Options", 4)
		local ammoSlot, ammoRow = labelRow(aimCard, "Ammo-aware", 5)
		local predSlot, predRow = labelRow(aimCard, "Prediction", 6)
		local visSlot, visRow = labelRow(aimCard, "Visible only", 7)
		local fovToggleSlot, fovToggleRow = labelRow(aimCard, "Show FOV", 8)
		local valuesHead = sectionLabel(aimCard, "Values", 9)
		local smoothSlot, smoothRow = labelRow(aimCard, "Smoothness", 10)
		local fovSlot, fovRow = labelRow(aimCard, "FOV", 11)
		local boneSlot, boneRow = labelRow(aimCard, "Bones", 12)
		local extras = { keyRow, optionsHead, ammoRow, predRow, visRow, fovToggleRow, valuesHead, smoothRow, boneRow }
		local function refreshAimRows()
			setRowsVisible(extras, config.aimbot)
			fovRow.Visible = config.aimbot and config.drawFov
		end
		Toggle(toggleSlot, {
			value = config.aimbot,
			get = function()
				return config.aimbot
			end,
			onChange = function()
				callbacks.onAimbotToggle()
				refreshAimRows()
				if callbacks.onConfigChanged then
					callbacks.onConfigChanged()
				end
			end,
		})
		local aimBind = BindButton(keySlot, "aimbot")
		Toggle(ammoSlot, {
			value = config.ammoAwareAim,
			get = function()
				return config.ammoAwareAim
			end,
			onChange = function()
				config.ammoAwareAim = not config.ammoAwareAim
				if callbacks.onConfigChanged then
					callbacks.onConfigChanged()
				end
			end,
		})
		Toggle(predSlot, {
			value = config.prediction,
			get = function()
				return config.prediction
			end,
			onChange = function()
				config.prediction = not config.prediction
				if callbacks.onConfigChanged then
					callbacks.onConfigChanged()
				end
			end,
		})
		Toggle(visSlot, {
			value = config.visibleOnly,
			get = function()
				return config.visibleOnly
			end,
			onChange = function()
				config.visibleOnly = not config.visibleOnly
				if callbacks.onConfigChanged then
					callbacks.onConfigChanged()
				end
			end,
		})
		Toggle(fovToggleSlot, {
			value = config.drawFov,
			get = function()
				return config.drawFov
			end,
			onChange = function()
				config.drawFov = not config.drawFov
				refreshAimRows()
				if callbacks.onConfigChanged then
					callbacks.onConfigChanged()
				end
			end,
		})
		Slider(smoothSlot, {
			min = 1,
			max = 50,
			value = config.smoothness,
			onChange = function(value)
				config.smoothness = value
				if callbacks.onConfigChanged then
					callbacks.onConfigChanged()
				end
			end,
		})
		Slider(fovSlot, {
			min = 20,
			max = 600,
			value = config.fov,
			onChange = function(value)
				config.fov = value
				if callbacks.onConfigChanged then
					callbacks.onConfigChanged()
				end
			end,
		})
		MultiBoneSelect(boneSlot)
		refreshAimRows()
		UI._aimBind = aimBind
	end
	local espCard = makeCard("Visuals", "ESP", "Draws every player on screen, walls included. Visibility tints box, name, bars, and bones green to red from how much of them is exposed. Weapon ESP shows their current gun under the name.", "esp box name health skeleton distance weapon visible los")
	do
		local extraRows = {}
		local function addSwitch(label, order, get, set, extra)
			local slot, row = labelRow(espCard, label, order)
			Toggle(slot, {
				value = get(),
				get = get,
				onChange = function()
					set()
					persist()
				end,
			})
			if extra then
				table.insert(extraRows, row)
			end
			return row
		end
		local distRow = addSlider(espCard, "Max Distance", 10, 50, 2000, function()
			return config.maxDistance
		end, function(value)
			config.maxDistance = value
		end)
		table.insert(extraRows, distRow)
		addSwitch("Boxes", 3, function()
			return config.espBoxes
		end, function()
			config.espBoxes = not config.espBoxes
		end, true)
		addSwitch("Names", 4, function()
			return config.espNames
		end, function()
			config.espNames = not config.espNames
		end, true)
		addSwitch("Health Bar", 5, function()
			return config.espHealth
		end, function()
			config.espHealth = not config.espHealth
		end, true)
		addSwitch("Skeleton", 6, function()
			return config.espSkeleton
		end, function()
			config.espSkeleton = not config.espSkeleton
		end, true)
		addSwitch("Distance", 7, function()
			return config.espDistance
		end, function()
			config.espDistance = not config.espDistance
		end, true)
		addSwitch("Weapon ESP", 8, function()
			return config.espWeapon
		end, function()
			config.espWeapon = not config.espWeapon
		end, true)
		addSwitch("Visibility", 9, function()
			return config.espVisCheck
		end, function()
			config.espVisCheck = not config.espVisCheck
		end, true)
		addToggle(espCard, "Enabled", 2, function()
			return config.esp
		end, callbacks.onEspToggle, extraRows)
	end
	local chamCard = makeCard("Chams", "Chams", "Replaces enemy skins with local meshes. XQZ is green on exposed mesh and red through walls.", "chams xqz rainbow wireframe neon forcefield override vis hid")
	do
		local extraRows = {}
		local function keep(row)
			table.insert(extraRows, row)
			return row
		end
		local styleSlot, styleRow = labelRow(chamCard, "Style", 3)
		keep(styleRow)
		Select(styleSlot, Cham.STYLES, function()
			return config.chamStyle or "xqz"
		end, function(id)
			config.chamStyle = id
			Cham.activeStyle = id
			local style = Cham.styleById(id)
			if style.vis then
				config.chamVisColor = style.vis
			end
			if style.hid then
				config.chamHidColor = style.hid
			end
		end)
		local visSlot, visRow = labelRow(chamCard, "Visible", 4)
		keep(visRow)
		Select(visSlot, Cham.COLORS, function()
			return config.chamVisColor or "green"
		end, function(id)
			config.chamVisColor = id
		end)
		local hidSlot, hidRow = labelRow(chamCard, "Hidden", 5)
		keep(hidRow)
		Select(hidSlot, Cham.COLORS, function()
			return config.chamHidColor or "red"
		end, function(id)
			config.chamHidColor = id
		end)
		keep(addSlider(chamCard, "Fill", 6, 0, 90, function()
			return config.chamFill
		end, function(value)
			config.chamFill = value
		end))
		keep(addSlider(chamCard, "Outline", 7, 0, 90, function()
			return config.chamOutline
		end, function(value)
			config.chamOutline = value
		end))
		keep(addSlider(chamCard, "Rainbow Speed", 8, 10, 200, function()
			return config.chamRainbowSpeed
		end, function(value)
			config.chamRainbowSpeed = value
		end))
		keep(addSlider(chamCard, "Distance", 9, 50, 250, function()
			return config.chamDistance or 250
		end, function(value)
			config.chamDistance = value
		end))
		local selfSlot, selfRow = labelRow(chamCard, "Self", 10)
		keep(selfRow)
		Select(selfSlot, Cham.SELF_MODES, function()
			return config.chamSelf or "off"
		end, function(id)
			config.chamSelf = id
			if id == "off" then
				Cham.clearSelf()
			end
		end)
		local overrideSlot, overrideRow = labelRow(chamCard, "Override Skins", 11)
		keep(overrideRow)
		Toggle(overrideSlot, {
			value = config.chamOverride,
			get = function()
				return config.chamOverride
			end,
			onChange = function()
				config.chamOverride = not config.chamOverride
				persist()
			end,
		})
		addToggle(chamCard, "Enabled", 2, function()
			return config.espChams
		end, function()
			config.espChams = not config.espChams
			if not config.espChams then
				Cham.clear()
			end
		end, extraRows)
	end
	local hudCard = makeCard("Visuals", "HUD", "Shot Delay is your next-shot wait. Enemy Reload is a countdown bar under their box.", "hud shot delay reload enemy sniper")
	do
		addToggle(hudCard, "Shot Delay", 2, function()
			return config.shotDelay
		end, function()
			config.shotDelay = not config.shotDelay
			if not config.shotDelay then
				Hud.updateShot(0)
				Weapon.stopShotWatch()
			end
		end)
		addToggle(hudCard, "Enemy Reload", 3, function()
			return config.enemyReload
		end, function()
			config.enemyReload = not config.enemyReload
		end)
	end
	local worldCard = makeCard("World", "World", "Camera and lighting only.", "fov fullbright xray time camera")
	do
		local fovRow = addSlider(worldCard, "FOV", 3, 20, 120, function()
			return config.cameraFov
		end, function(value)
			config.cameraFov = value
		end)
		addToggle(worldCard, "Camera FOV", 2, function()
			return config.cameraFovEnabled
		end, function()
			config.cameraFovEnabled = not config.cameraFovEnabled
			if not config.cameraFovEnabled then
				Extras.restoreCameraFov()
			end
		end, { fovRow })
		addToggle(worldCard, "Fullbright", 4, function()
			return config.fullbright
		end, function()
			config.fullbright = not config.fullbright
			if not config.fullbright then
				Extras.restoreFullbright()
			end
		end)
		addToggle(worldCard, "X-Ray", 5, function()
			return config.xray
		end, function()
			config.xray = not config.xray
			if not config.xray then
				Extras.restoreXray()
			end
		end)
		local hourRow = addSlider(worldCard, "Hour", 7, 0, 24, function()
			return config.timeHour
		end, function(value)
			config.timeHour = value
		end)
		addToggle(worldCard, "Time of Day", 6, function()
			return config.timeOfDay
		end, function()
			config.timeOfDay = not config.timeOfDay
			if not config.timeOfDay then
				Extras.restoreTime()
			end
		end, { hourRow })
	end
	local moveCard = makeCard("Movement", "Movement", nil, "fly jump speed noclip gravity freecam")
	do
		local flyBindSlot, flyBindRow = labelRow(moveCard, "Bind", 3)
		UI._flyBind = BindButton(flyBindSlot, "fly")
		local flySpeedRow = addSlider(moveCard, "Speed", 4, 1, 250, function()
			return config.flySpeed
		end, function(value)
			config.flySpeed = value
		end)
		addToggle(moveCard, "Fly", 2, function()
			return config.fly
		end, callbacks.onFlyToggle, { flyBindRow, flySpeedRow })
		local jumpBindSlot, jumpBindRow = labelRow(moveCard, "Bind", 6)
		UI._jumpBind = BindButton(jumpBindSlot, "jump")
		local jumpPowerRow = addSlider(moveCard, "Power", 6, 1, 500, function()
			return config.jumpPower
		end, function(value)
			config.jumpPower = value
		end)
		addToggle(moveCard, "Jump", 5, function()
			return config.jump
		end, callbacks.onJumpToggle, { jumpBindRow, jumpPowerRow })
		local walkSpeedRow = addSlider(moveCard, "Walk Speed", 8, 16, 400, function()
			return config.walkSpeed
		end, function(value)
			config.walkSpeed = value
		end)
		addToggle(moveCard, "Speed", 7, function()
			return config.speed
		end, function()
			config.speed = not config.speed
			if not config.speed then
				Extras.restoreSpeed()
			end
		end, { walkSpeedRow })
		addToggle(moveCard, "Inf Jump", 9, function()
			return config.infJump
		end, function()
			config.infJump = not config.infJump
			if not config.infJump then
				Extras.stopInfJump()
			end
		end)
		addToggle(moveCard, "Noclip", 10, function()
			return config.noclip
		end, function()
			config.noclip = not config.noclip
			if not config.noclip then
				Extras.restoreNoclip()
			end
		end)
		local gravityRow = addSlider(moveCard, "Value", 12, 0, 250, function()
			return config.gravityValue
		end, function(value)
			config.gravityValue = value
		end)
		addToggle(moveCard, "Gravity", 11, function()
			return config.worldGravity
		end, function()
			config.worldGravity = not config.worldGravity
			if not config.worldGravity then
				Extras.restoreGravity()
			end
		end, { gravityRow })
		local freecamBindSlot, freecamBindRow = labelRow(moveCard, "Bind", 14)
		UI._freecamBind = BindButton(freecamBindSlot, "freecam")
		local freecamSpeedRow = addSlider(moveCard, "Speed", 15, 10, 400, function()
			return config.freecamSpeed
		end, function(value)
			config.freecamSpeed = value
		end)
		addToggle(moveCard, "Freecam", 13, function()
			return config.freecam
		end, function()
			config.freecam = not config.freecam
			if not config.freecam then
				Extras.clearFreecamLatch()
				Extras.restoreFreecam()
			end
		end, { freecamBindRow, freecamSpeedRow })
	end
	local killCard = makeCard("Combat", "Combat", "Kill All flickers the closest player. Instant ADS skips the scope tween and keeps you scoped after a sniper shot. Pauses 1.5s if the target is immune.", "kill all killall ads scope sniper")
	do
		addToggle(killCard, "Kill All", 2, function()
			return KillAll.want() or config.killAll
		end, function()
			local on = not (KillAll.want() or config.killAll)
			config.killAll = on
			KillAll.setEnabled(on)
			if KillAll.want() then
				config.killAll = true
				UI.setMenuOpen(false)
			end
		end)
		addToggle(killCard, "Instant ADS", 3, function()
			return config.instantAds
		end, function()
			config.instantAds = not config.instantAds
			if not config.instantAds then
				Weapon.restoreAimSpeed()
			end
		end)
		local hitboxRow = addSlider(killCard, "Size", 5, 4, 60, function()
			return config.hitboxSize
		end, function(value)
			config.hitboxSize = value
		end)
		addToggle(killCard, "Hitbox", 4, function()
			return config.hitbox
		end, function()
			config.hitbox = not config.hitbox
			if not config.hitbox then
				Extras.restoreHitbox()
			end
		end, { hitboxRow })
	end
	local exploitCard = makeCard("Exploits", "Player", nil, "invis spinbot antifling antivoid")
	do
		local spinRow = addSlider(exploitCard, "Rate", 3, 1, 60, function()
			return config.spinRate
		end, function(value)
			config.spinRate = value
		end)
		addToggle(exploitCard, "Spinbot", 2, function()
			return config.spinbot
		end, function()
			config.spinbot = not config.spinbot
			if not config.spinbot then
				Extras.restoreSpin()
			end
		end, { spinRow })
		addToggle(exploitCard, "Invis", 4, function()
			return config.invis
		end, function()
			config.invis = not config.invis
			if not config.invis and not KillAll.want() then
				Extras.restoreInvis()
			end
		end)
		local antiFlingRow = addSlider(exploitCard, "Max Vel", 7, 50, 800, function()
			return config.antiFlingLimit
		end, function(value)
			config.antiFlingLimit = value
		end)
		addToggle(exploitCard, "Anti-Fling", 6, function()
			return config.antiFling
		end, function()
			config.antiFling = not config.antiFling
		end, { antiFlingRow })
		local antiVoidRow = addSlider(exploitCard, "Y Floor", 9, -500, 0, function()
			return config.antiVoidFloor
		end, function(value)
			config.antiVoidFloor = value
		end)
		addToggle(exploitCard, "Anti-Void", 8, function()
			return config.antiVoid
		end, function()
			config.antiVoid = not config.antiVoid
		end, { antiVoidRow })
	end
	local playersCard = makeCard("Players", "Lobby", nil, "teleport teammate mark return exclude")
	do
		local actions = new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 22),
			LayoutOrder = 2,
			ZIndex = 13,
			Parent = playersCard,
		})
		hlist(actions, 6)
		ActionButton(actions, "Mark", 1, UDim2.new(0.5, -3, 1, 0), function()
			Extras.markHere()
		end)
		ActionButton(actions, "Return", 2, UDim2.new(0.5, -3, 1, 0), function()
			Extras.returnToMark()
		end)
		local list = new("ScrollingFrame", {
			BackgroundColor3 = T.field,
			Size = UDim2.new(1, 0, 0, 220),
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = T.scroll,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			LayoutOrder = 3,
			ZIndex = 13,
			Parent = playersCard,
		})
		corner(list, 8)
		pad(list, 4, 4, 4, 4)
		vlist(list, 3)
		local function refreshPlayers()
			for _, child in ipairs(list:GetChildren()) do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end
			local others = {}
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer then
					table.insert(others, player)
				end
			end
			table.sort(others, function(a, b)
				return string.lower(a.Name) < string.lower(b.Name)
			end)
			if #others == 0 then
				new("TextLabel", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 22),
					Font = FONT,
					Text = freeze("No other players"),
					TextSize = 11,
					TextColor3 = T.tag,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 14,
					Parent = list,
				})
				return
			end
			for index, player in ipairs(others) do
				local teammate = Filter.isExcluded(player, config) or Filter.isTeammate(player)
				local row = new("Frame", {
					BackgroundColor3 = T.panel,
					Size = UDim2.new(1, 0, 0, 24),
					BorderSizePixel = 0,
					LayoutOrder = index,
					ZIndex = 14,
					Parent = list,
				})
				corner(row, 8)
				new("TextLabel", {
					BackgroundTransparency = 1,
					Position = offset(6, 0),
					Size = UDim2.new(1, -112, 1, 0),
					Font = FONT,
					Text = player.DisplayName ~= player.Name
						and (player.DisplayName .. "  @" .. player.Name)
						or player.Name,
					TextSize = 11,
					TextColor3 = teammate and T.muted or T.text,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					ZIndex = 15,
					Parent = row,
				})
				local buttons = new("Frame", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -4, 0.5, 0),
					Size = offset(100, 18),
					ZIndex = 15,
					Parent = row,
				})
				hlist(buttons, 4)
				ActionButton(buttons, "TP", 1, UDim2.new(0, 34, 1, 0), function()
					Extras.teleportToPlayer(player, config)
				end)
				local teamBtn = ActionButton(buttons, teammate and "Unteam" or "Team", 2, UDim2.new(0, 62, 1, 0), function()
					if Filter.isExcluded(player, config) then
						Filter.remove(config.excludedNames, player.Name)
						Filter.remove(config.excludedNames, player.DisplayName)
					else
						Filter.add(config.excludedNames, player.Name)
					end
					persist()
					refreshPlayers()
				end)
				if teammate then
					teamBtn.TextColor3 = T.yellow
				end
			end
		end
		refreshPlayers()
		UI.track(Players.PlayerAdded:Connect(refreshPlayers))
		UI.track(Players.PlayerRemoving:Connect(function()
			task.defer(refreshPlayers)
		end))
	end
	local miscCard = makeCard("Misc", "Client", nil, "fps performance streamproof unlock antiafk persist timer watermark f9 debug console hop rejoin vfx graphics potato")
	do
		addToggle(miscCard, "Persist", 2, function()
			return config.persist
		end, function()
			config.persist = not config.persist
			if config.persist then
				Persist.arm(config)
			else
				Persist.stop()
			end
		end)
		addToggle(miscCard, "Persist Timer", 3, function()
			return config.persistTimer ~= false
		end, function()
			config.persistTimer = not (config.persistTimer ~= false)
		end)
		addToggle(miscCard, "Watermark", 4, function()
			return config.watermark ~= false
		end, callbacks.onWatermarkToggle)
		addToggle(miscCard, "F9 Debug", 5, function()
			return config.f9Debug == true
		end, callbacks.onF9DebugToggle)
		addToggle(miscCard, "Uncapped FPS", 6, function()
			return config.uncappedFps
		end, callbacks.onUncappedFpsToggle)
		addToggle(miscCard, "Performance", 7, function()
			return config.performanceMode
		end, callbacks.onPerformanceModeToggle)
		addToggle(miscCard, "Streamproof", 8, function()
			return config.streamproof
		end, callbacks.onStreamproofToggle)
		addToggle(miscCard, "Unlock All", 9, function()
			return config.unlockAll
		end, callbacks.onUnlockAllToggle)
		addToggle(miscCard, "Anti-AFK", 10, function()
			return config.antiAfk
		end, function()
			config.antiAfk = not config.antiAfk
			if not config.antiAfk then
				Extras.stopAntiAfk()
			end
		end)
		local serverRow = new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 22),
			LayoutOrder = 11,
			ZIndex = 13,
			Parent = miscCard,
		})
		hlist(serverRow, 6)
		ActionButton(serverRow, "Rejoin", 1, UDim2.new(0.5, -3, 1, 0), function()
			Extras.rejoin()
		end)
		ActionButton(serverRow, "Server Hop", 2, UDim2.new(0.5, -3, 1, 0), function()
			Extras.serverHop()
		end)
	end
	if warnings and #warnings > 0 then
		local warnCard = makeCard("Misc", "Warnings", nil, table.concat(warnings, " "))
		warnCard.LayoutOrder = 99
		new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Font = FONT,
			Text = table.concat(warnings, "  ·  "),
			TextSize = 11,
			TextColor3 = T.note,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
			ZIndex = 14,
			Parent = warnCard,
		})
	end
	task.spawn(function()
		local function syncBind(button, kind)
			if not button then
				return
			end
			if inputModule.listening and inputModule.listeningKind == kind then
				button.Text = freeze("press any")
				button.TextColor3 = T.yellow
			else
				button.Text = inputModule.getBindName(config, kind)
				button.TextColor3 = T.title
			end
		end
		while UI.running and gui.Parent do
			syncBind(UI._aimBind, "aimbot")
			syncBind(UI._flyBind, "fly")
			syncBind(UI._jumpBind, "jump")
			syncBind(UI._freecamBind, "freecam")
			task.wait(0.1)
		end
	end)
	UI.startMenuToggle(inputModule)
	UI.setMenuOpen(false)
	return {
		setOpen = UI.setMenuOpen,
		toggle = UI.toggleMenu,
	}
end
return UI
end)()
    LV â€” Lua executor script
    Execute lv.lua only â€” everything is bundled (aimbot, ESP, unlock all).
    For development: copy this folder to your executor workspace and run main.lua.
]]
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Config = ConfigStore.getDefaults()
local loadedConfig = ConfigStore.loadInto(Config)
local function saveConfig()
	if Cham.activeStyle then
		Config.chamStyle = Cham.activeStyle
	end
	ConfigStore.save(Config)
	ConfigStore.scheduleSave(Config)
end
local function applyStreamproof()
	Streamproof.applyAll(Config.streamproof, { Esp.container, Watermark.gui, Hud.gui }, Config)
	if Watermark.gui then
		Watermark.setVisible(Config.watermark ~= false and not Config.streamproof)
	end
end
local env = (typeof(getgenv) == "function" and getgenv()) or _G
if type(env) == "table" and type(env.LV_UNLOAD) == "function" then
	pcall(env.LV_UNLOAD)
end
local function unload()
	if not Core.isRunning() then
		return
	end
	Core.stop()
	pcall(function()
		RunService:UnbindFromRenderStep("LVCamera")
	end)
	if Config.persist then
		Persist.queue()
	end
	ConfigStore.stopAutosave()
	ConfigStore.save(Config)
	Performance.restoreGraphics()
	Performance.restoreFpsCap()
	Streamproof.applyAll(false, { Esp.container, Watermark.gui, Hud.gui }, Config)
	Fly.clearLatch()
	Fly.restore()
	Jump.restore()
	KillAll.enabled = false
	KillAll.stop()
	Weapon.restoreAimSpeed()
	Weapon.stopShotWatch()
	Hud.destroy()
	Extras.restoreAll()
	Input.stop()
	Core.disconnectAll()
	Cham.clear()
	Esp.destroy()
	UI.destroy()
	Watermark.destroy()
	UserInputService.MouseIconEnabled = true
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end
local runtimeStarted = false
local function startRuntime()
	if runtimeStarted then
		return
	end
	runtimeStarted = true
Performance.captureOriginal()
Performance.applyFpsCap(Config)
task.delay(8, function()
	if Core.isRunning() then
		Performance.applyFpsCap(Config)
		if not Config.streamproof then
			Performance.applyGraphics(Config)
		end
	end
end)
local mouseMoveRel = Aimbot.getMouseMoveRel()
Streamproof.destroyExisting("LV_ESP_Container")
Streamproof.destroyExisting("LV")
Streamproof.destroyExisting("LV_Watermark")
Streamproof.destroyExisting("LV_ShotDelay")
Streamproof.destroyExisting("LV_Hud")
if type(env) ~= "table" or not env.LV_BOOTING then
	Streamproof.destroyExisting("LV_HopWait")
end
Esp.init()
Watermark.init()
Watermark.setVisible(Config.watermark ~= false and not Config.streamproof)
Hud.init()
local warnings = {}
if not mouseMoveRel then
	table.insert(warnings, "No mousemoverel API")
end
if not Unlock.isSupported() then
	table.insert(warnings, "No hookmetamethod API")
end
if not Performance.isFpsCapSupported() then
	table.insert(warnings, "No setfpscap API")
end
if not ConfigStore.isSupported() then
	table.insert(warnings, "No writefile API")
end
if Persist.queueFn() == nil then
	table.insert(warnings, "No queue_on_teleport API")
end
Input.start(Config, saveConfig)
UI.build(Config, {
	onConfigChanged = saveConfig,
	onUnload = unload,
	onAimbotToggle = function()
		Config.aimbot = not Config.aimbot
		Aimbot.resetSmoothing()
	end,
	onFlyToggle = function()
		Config.fly = not Config.fly
		if not Config.fly then
			Fly.clearLatch()
			Fly.restore()
		end
	end,
	onJumpToggle = function()
		Config.jump = not Config.jump
		if not Config.jump then
			Jump.restore()
		end
	end,
	onEspToggle = function()
		Config.esp = not Config.esp
		if not Config.esp then
			Esp.clear()
		end
	end,
	onUnlockAllToggle = function()
		Config.unlockAll = not Config.unlockAll
		if Config.unlockAll then
			Unlock.run(Loader)
		end
	end,
	onUncappedFpsToggle = function()
		Config.uncappedFps = not Config.uncappedFps
		Performance.applyFpsCap(Config)
	end,
	onPerformanceModeToggle = function()
		Config.performanceMode = not Config.performanceMode
		if not Config.streamproof then
			Performance.applyGraphics(Config)
		end
	end,
	onStreamproofToggle = function()
		Config.streamproof = not Config.streamproof
		applyStreamproof()
	end,
	onWatermarkToggle = function()
		Config.watermark = not (Config.watermark ~= false)
		if not Config.streamproof then
			Watermark.setVisible(Config.watermark)
		end
	end,
	onF9DebugToggle = function()
		Config.f9Debug = not Config.f9Debug
		Extras.setDevConsole(Config.f9Debug == true)
	end,
}, warnings, Input)
applyStreamproof()
if not Config.f9Debug then
	Extras.setDevConsole(false)
end
saveConfig()
ConfigStore.startAutosave(Config)
Cham.activeStyle = Config.chamStyle
Core.track(Players.PlayerRemoving:Connect(function(player)
	if player.Character then
		Esp.clearBoneCache(player.Character)
		Los.clear(player.Character)
	end
	Esp.removeEntry(player)
end))
local function shouldAimbotRun()
	if UI.open then
		Aimbot.resetSmoothing()
		return false
	end
	if not Config.aimbot then
		return false
	end
	if not Weapon.isHolding() then
		Aimbot.resetSmoothing()
		return false
	end
	if Config.ammoAwareAim and Weapon.busyForCombat() then
		Aimbot.resetSmoothing()
		return false
	end
	return Input.isActive(Config, "aimbot")
end
local function shouldFlyRun()
	if not Config.fly then
		Fly.clearLatch()
		return false
	end
	if not Config.flyKey and not Config.flyMouse then
		return true
	end
	if Input.listening then
		return Fly.latched
	end
	local down = Input.isActive(Config, "fly")
	if down and not Fly.bindWasDown then
		Fly.latched = not Fly.latched
	end
	Fly.bindWasDown = down
	return Fly.latched
end
local function shouldJumpRun()
	return Config.jump == true
end
local function shouldFreecamRun()
	if not Config.freecam then
		Extras.clearFreecamLatch()
		return false
	end
	if not Config.freecamKey and not Config.freecamMouse then
		return true
	end
	if Input.listening then
		return Extras.freecamLatched
	end
	local down = Input.isActive(Config, "freecam")
	if down and not Extras.freecamBindWasDown then
		Extras.freecamLatched = not Extras.freecamLatched
	end
	Extras.freecamBindWasDown = down
	return Extras.freecamLatched
end
local frameCounter = 0
Core.track(RunService.RenderStepped:Connect(function(dt)
	if not Core.isRunning() then
		return
	end
	frameCounter = frameCounter + 1
	if not Config.streamproof then
		Watermark.update(dt)
	end
	if Config.uncappedFps and frameCounter % 120 == 0 then
		Performance.applyFpsCap(Config)
	end
	if Config.streamproof or not Config.drawFov then
		if Esp.fovRing and Esp.fovRing.Visible then
			Esp.fovRing.Visible = false
		end
	else
		Esp.updateFov(Config)
	end
	local booting = type(env) == "table" and env.LV_BOOTING == true
	if not booting then
		if Config.streamproof then
			if next(Esp.entries) then
				Esp.clear()
			end
			if Cham.folder or next(Cham.entries) or Cham.selfActive then
				Cham.clear()
				Cham.clearSelf()
			end
		else
			if Config.esp and not Performance.shouldSkipEspUpdate(Config, frameCounter) then
				Esp.update(Config, frameCounter)
			end
			if Config.espChams then
				Cham.update(Config)
			elseif Cham.folder or next(Cham.entries) then
				Cham.clear()
			end
		end
	end
	local runAim = shouldAimbotRun()
	local killOn = KillAll.want() or Config.killAll
	if killOn then
		Config.killAll = true
		KillAll.enabled = true
		KillAll.step(Config)
	elseif runAim then
		local part = Aimbot.lastPart
		if not Performance.shouldSkipAimbotScan(Config, frameCounter) then
			part = Aimbot.getClosestTarget(Config, Esp.isRenderedTarget)
			Aimbot.lastPart = part
		elseif part and part.Parent then
			part = Aimbot.pickAimPart(part.Parent, Config)
			Aimbot.lastPart = part
		end
		if part then
			local aimPos = Aimbot.predictedPosition(part, Config, Weapon.muzzleSpeed())
			Aimbot.aimAt(part, Config.smoothness, mouseMoveRel, aimPos)
		end
	end
	if Config.spinbot then
		Extras.applySpin(Config, dt)
	end
	if Config.freecam and not Fly.active and shouldFreecamRun() then
		Extras.applyFreecam(Config, dt)
	else
		Extras.restoreFreecam()
	end
end))
Core.track(RunService.Heartbeat:Connect(function(dt)
	if not Core.isRunning() then
		return
	end
	if shouldFlyRun() then
		Fly.apply(Config)
	else
		Fly.restore()
		if Config.worldGravity then
			Extras.applyGravity(Config)
		else
			Extras.restoreGravity()
		end
	end
	if shouldJumpRun() then
		Jump.apply(Config)
	elseif Jump.active or Jump.requestConn then
		Jump.restore()
	end
	if Config.speed and not Fly.active then
		Extras.applySpeed(Config, dt)
	else
		Extras.restoreSpeed()
	end
	local killOn = KillAll.want() or Config.killAll
	if Config.instantAds then
		Weapon.applyInstantAds()
	elseif Weapon.aimSpeedSaved then
		Weapon.restoreAimSpeed()
	end
	if Config.shotDelay or Config.instantAds then
		local left, cooldown = Weapon.tickShotDelay()
		if Config.shotDelay and not Config.streamproof then
			Hud.updateShot(left, cooldown)
		else
			Hud.updateShot(0)
		end
	else
		Weapon.stopShotWatch()
		Hud.updateShot(0)
	end
	if killOn then
		Config.killAll = true
		KillAll.enabled = true
		if KillAll.part then
			KillAll.stick(KillAll.part)
		end
	end
	if Config.infJump then
		Extras.startInfJump()
	else
		Extras.stopInfJump()
	end
	if Config.invis or killOn then
		Extras.applyInvis()
	else
		Extras.restoreInvis()
	end
	if killOn then
		Extras.applyGod()
	else
		Extras.restoreGod()
	end
	if Config.antiFling then
		Extras.applyAntiFling(Config)
	end
	if Config.antiVoid then
		Extras.applyAntiVoid(Config)
	end
	if Config.antiAfk then
		Extras.startAntiAfk()
	else
		Extras.stopAntiAfk()
	end
	if Config.hitbox and not Config.streamproof then
		local interval = Config.performanceMode and 16 or 8
		if frameCounter % interval == 0 then
			Extras.applyHitbox(Config)
		end
	else
		Extras.restoreHitbox()
	end
	if Config.cameraFovEnabled and not Config.streamproof then
		Extras.applyCameraFov(Config)
	else
		Extras.restoreCameraFov()
	end
	if Config.fullbright and not Config.streamproof then
		Extras.applyFullbright()
	else
		Extras.restoreFullbright()
	end
	if Config.xray and not Config.streamproof then
		Extras.applyXray(os.clock(), Config.performanceMode and 3 or 1)
	else
		Extras.restoreXray()
	end
	if Config.timeOfDay and not Config.streamproof then
		Extras.applyTime(Config)
	else
		Extras.restoreTime()
	end
	Extras.applyF9Debug(Config)
end))
Core.track(RunService.Stepped:Connect(function()
	if not Core.isRunning() then
		return
	end
	if Config.noclip or KillAll.want() or Config.killAll then
		Extras.applyNoclip()
		if (KillAll.want() or Config.killAll) and KillAll.part then
			KillAll.stick(KillAll.part)
		end
	else
		Extras.restoreNoclip()
	end
end))
local function hookLocalCharacter(character)
	if not character then
		return
	end
	Core.track(character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			Fly.restore()
			Jump.restore()
			Extras.restoreSpeed()
			Extras.restoreNoclip()
			if not (KillAll.want() or Config.killAll or Config.invis) then
				Extras.restoreInvis()
			end
			if not (KillAll.want() or Config.killAll or Config.godmode) then
				Extras.restoreGod()
			end
		end
	end))
	task.spawn(function()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			humanoid = character:WaitForChild("Humanoid", 5)
		end
		if humanoid and Core.isRunning() then
			Jump.hasSnapshot = false
			Jump.lastPower = nil
			Jump.capture(humanoid)
			Core.track(humanoid.Died:Connect(function()
				Fly.restore()
				Jump.restore()
				Extras.restoreSpeed()
				Extras.restoreNoclip()
				if not (KillAll.want() or Config.killAll or Config.invis) then
					Extras.restoreInvis()
				end
				if not (KillAll.want() or Config.killAll or Config.godmode) then
					Extras.restoreGod()
				end
			end))
		end
	end)
end
if LocalPlayer.Character then
	hookLocalCharacter(LocalPlayer.Character)
end
Core.track(LocalPlayer.CharacterAdded:Connect(hookLocalCharacter))
Core.track(LocalPlayer.CharacterRemoving:Connect(function()
	Fly.restore()
	Jump.restore()
	Extras.restoreSpeed()
	Extras.restoreNoclip()
	if not (KillAll.want() or Config.killAll or Config.invis) then
		Extras.restoreInvis()
	end
	if not (KillAll.want() or Config.killAll or Config.godmode) then
		Extras.restoreGod()
	end
end))
pcall(function()
	RunService:UnbindFromRenderStep("LVCamera")
end)
RunService:BindToRenderStep("LVCamera", Enum.RenderPriority.Last.Value, function()
	if not Core.isRunning() then
		return
	end
	if Config.cameraFovEnabled and not Config.streamproof then
		Extras.applyCameraFov(Config)
	end
	if Config.invis or KillAll.want() or Config.killAll then
		Extras.applyInvis()
	end
	if (KillAll.want() or Config.killAll) and KillAll.part then
		KillAll.stick(KillAll.part)
		KillAll.lookAt(KillAll.part)
	end
end)
pcall(function()
	Weapon.restoreReloadStats()
end)
end
local function runUnlockAfter(seconds)
	task.delay(seconds, function()
		if Core.isRunning() and Config.unlockAll then
			Unlock.run(Loader)
		end
	end)
end
local function finishBoot()
	if not Core.isRunning() then
		return
	end
	task.wait(0.5)
	if not Core.isRunning() then
		return
	end
	startRuntime()
	local hopBoot = type(env) == "table" and env.LV_HOP_BOOT == true
	local function fireUnlock()
		Unlock.run(Loader)
	end
	local forceUnlock = type(env) == "table" and env.LV_FORCE_UNLOCK == true
	if forceUnlock then
		env.LV_FORCE_UNLOCK = nil
		fireUnlock()
	elseif Config.unlockAll then
		if hopBoot then
			runUnlockAfter(8)
			runUnlockAfter(16)
		else
			runUnlockAfter(5)
		end
	end
	if hopBoot or forceUnlock then
		local zeroConn
		zeroConn = UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			if input.KeyCode == Enum.KeyCode.Zero or input.KeyCode == Enum.KeyCode.KeypadZero then
				fireUnlock()
				if zeroConn then
					zeroConn:Disconnect()
					zeroConn = nil
				end
			end
		end)
		Core.track(zeroConn)
		task.delay(20, function()
			if zeroConn then
				zeroConn:Disconnect()
				zeroConn = nil
			end
		end)
	end
	task.delay(hopBoot and 6 or 3, function()
		if Core.isRunning() and Config.persist then
			Persist.arm(Config)
		end
	end)
end
if type(env) == "table" then
	env.LV_UNLOAD = unload
end
task.spawn(function()
	local hopBoot = type(env) == "table" and env.LV_HOP_BOOT == true
	if hopBoot then
		while Core.isRunning() and type(env) == "table" and env.LV_BOOTING == true do
			task.wait(0.15)
		end
		task.wait(1)
	end
	finishBoot()
end)
