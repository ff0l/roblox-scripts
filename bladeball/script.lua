local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not game:IsLoaded() then
	game.Loaded:Wait()
end
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	LocalPlayer = Players.LocalPlayer
end
local env = (typeof(getgenv) == "function" and getgenv()) or _G
if type(env) == "table" and type(env.BB_UNLOAD) == "function" then
	pcall(env.BB_UNLOAD)
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
local mouseDown = pickFn(
	typeof(mouse1press) == "function" and mouse1press,
	env and env.mouse1press
)
local mouseUp = pickFn(
	typeof(mouse1release) == "function" and mouse1release,
	env and env.mouse1release
)
local mouseClick = pickFn(
	typeof(mouse1click) == "function" and mouse1click,
	env and env.mouse1click
)
local writeFile = pickFn(
	typeof(writefile) == "function" and writefile,
	env and env.writefile
)
local appendFile = pickFn(
	typeof(appendfile) == "function" and appendfile,
	env and env.appendfile
)
local readFile = pickFn(
	typeof(readfile) == "function" and readfile,
	env and env.readfile
)
local makeFolder = pickFn(
	typeof(makefolder) == "function" and makefolder,
	env and env.makefolder
)
local T = {
	bg = Color3.fromRGB(24, 24, 26),
	text = Color3.fromRGB(232, 232, 230),
	on = Color3.fromRGB(232, 232, 230),
	off = Color3.fromRGB(52, 52, 56),
	knobOn = Color3.fromRGB(24, 24, 26),
	knobOff = Color3.fromRGB(168, 168, 172),
	close = Color3.fromRGB(255, 95, 87),
	closeHover = Color3.fromRGB(255, 120, 112),
	muted = Color3.fromRGB(138, 138, 142),
	ready = Color3.fromRGB(210, 210, 208),
}
local FONT = Enum.Font.BuilderSans
local FONT_BOLD = Enum.Font.BuilderSansBold
local Config = {
	autoParry = true,
	spam = false,
	humanize = true,
	abilityEsp = true,
	parryWindow = 0.38,
	minSpeed = 5,
	cooldown = 0.08,
	clashCooldown = 0.05,
	clashRange = 36,
	clashSpeed = 40,
	maxReach = 40,
	minSafeEta = 0.12,
	preciseSpeed = 80,
	preciseEta = 0.12,
	contactR = 6,
	maxFireDist = 26,
	rescueLead = 0.08,
	rescueGap = 0.08,
	spamLead = 0.16,
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
local HttpService = game:GetService("HttpService")
local Log = {
	PATH = "bladeball/parry.log",
	DIR = "bladeball",
	last = {},
	firedAt = 0,
	firedInfo = nil,
	shouldAt = 0,
	shouldInfo = nil,
}
local function round(n, d)
	if type(n) ~= "number" or n ~= n then
		return n
	end
	if n == math.huge or n == -math.huge then
		return n
	end
	local m = 10 ^ (d or 2)
	return math.floor(n * m + 0.5) / m
end
function Log.write(event, data)
	if not writeFile and not appendFile then
		return
	end
	local row = data or {}
	row.t = round(os.clock(), 3)
	row.event = event
	local line
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(row)
	end)
	if ok then
		line = encoded .. "\n"
	else
		line = event .. "\n"
	end
	if appendFile then
		pcall(appendFile, Log.PATH, line)
		return
	end
	local prev = ""
	if readFile then
		pcall(function()
			prev = readFile(Log.PATH) or ""
		end)
	end
	pcall(writeFile, Log.PATH, prev .. line)
end
function Log.once(key, gap, event, data)
	local now = os.clock()
	if Log.last[key] and now - Log.last[key] < (gap or 0.35) then
		return
	end
	Log.last[key] = now
	Log.write(event, data)
end
function Log.snapshot(info, plan, extra)
	local row = extra or {}
	if info then
		row.eta = info.eta == math.huge and "inf" or round(info.eta, 3)
		row.dist = round(info.dist, 2)
		row.speed = round(info.speed, 1)
		row.reach = round(info.reach, 1)
		row.window = round(info.window, 3)
		row.precise = info.precise and true or false
		if info.lead then
			row.lead = info.lead == math.huge and "inf" or round(info.lead, 3)
		end
		if info.fireLead then
			row.fireLead = round(info.fireLead, 3)
		end
		if info.vy then
			row.vy = round(info.vy, 1)
		end
	end
	if plan then
		row.react = round(plan.react, 3)
		row.fireEta = round(plan.fireEta, 3)
		row.hold = round(plan.hold, 3)
		row.minSafe = round(plan.minSafe, 3)
	end
	row.humanize = Config.humanize
	if info then
		if info.xz then
			row.xz = round(info.xz, 2)
		end
		if info.height then
			row.h = round(info.height, 2)
		end
		if info.diving then
			row.dive = true
		end
		if info.incoming == false then
			row.inb = false
		end
	end
	return row
end
function Log.start()
	if makeFolder then
		pcall(makeFolder, Log.DIR)
	end
	local exists = false
	if readFile then
		exists = pcall(function()
			readFile(Log.PATH)
		end)
	end
	if writeFile and not exists then
		pcall(writeFile, Log.PATH, "")
	end
	Log.write("session", {
		place = game.PlaceId,
		humanize = Config.humanize,
	})
end
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
local function pill(inst)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = inst
	return c
end
local UI = {
	NAME = "Menu",
	gui = nil,
	root = nil,
	hud = nil,
	open = true,
	stats = nil,
}
function UI.setOpen(state)
	UI.open = state and true or false
	if UI.root then
		UI.root.Visible = UI.open
	end
	if UI.open then
		UserInputService.MouseIconEnabled = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end
function UI.toggle()
	UI.setOpen(not UI.open)
end
function UI.destroy()
	if UI.gui then
		pcall(function()
			UI.gui:Destroy()
		end)
	end
	UI.gui = nil
	UI.root = nil
	UI.hud = nil
	UI.stats = nil
end
function UI.build(onUnload)
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild(UI.NAME)
	if existing then
		existing:Destroy()
	end
	local gui = new("ScreenGui", {
		Name = UI.NAME,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 100,
		AutoLocalize = false,
		Parent = playerGui,
	})
	UI.gui = gui
	local W, H = 240, 188
	local camera = Workspace.CurrentCamera
	local vp = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local x = math.floor((vp.X - W) * 0.5)
	local y = math.floor(vp.Y * 0.22)
	local root = new("Frame", {
		Name = "Main",
		BackgroundColor3 = T.bg,
		Size = UDim2.fromOffset(W, H),
		Position = UDim2.fromOffset(x, y),
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = gui,
	})
	UI.root = root
	corner(root, 16)
	local titleBar = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
		ZIndex = 12,
		Parent = root,
	})
	new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(1, -48, 1, 0),
		Font = FONT_BOLD,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.text,
		Text = "Blade Ball",
		ZIndex = 13,
		Parent = titleBar,
	})
	local close = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = T.close,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 20,
		Parent = titleBar,
	})
	pill(close)
	Core.track(close.MouseEnter:Connect(function()
		TweenService:Create(close, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = T.closeHover,
			Size = UDim2.fromOffset(13, 13),
		}):Play()
	end))
	Core.track(close.MouseLeave:Connect(function()
		TweenService:Create(close, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = T.close,
			Size = UDim2.fromOffset(12, 12),
		}):Play()
	end))
	Core.track(close.Activated:Connect(function()
		if onUnload then
			onUnload()
		end
	end))
	local dragging = false
	local dragStart
	local startPos
	Core.track(titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = root.Position
		end
	end))
	Core.track(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))
	Core.track(UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - dragStart
			root.Position = UDim2.fromOffset(
				startPos.X.Offset + delta.X,
				startPos.Y.Offset + delta.Y
			)
		end
	end))
	local function toggleRow(label, key, y)
		local row = new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(18, y),
			Size = UDim2.new(1, -36, 0, 28),
			ZIndex = 12,
			Parent = root,
		})
		new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -46, 1, 0),
			Font = FONT,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = T.text,
			Text = label,
			ZIndex = 13,
			Parent = row,
		})
		local track = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(36, 20),
			BackgroundColor3 = Config[key] and T.on or T.off,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 13,
			Parent = row,
		})
		corner(track, 10)
		local knob = new("Frame", {
			Size = UDim2.fromOffset(14, 14),
			Position = Config[key] and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7),
			BackgroundColor3 = Config[key] and T.knobOn or T.knobOff,
			BorderSizePixel = 0,
			ZIndex = 14,
			Parent = track,
		})
		corner(knob, 7)
		Core.track(track.Activated:Connect(function()
			Config[key] = not Config[key]
			track.BackgroundColor3 = Config[key] and T.on or T.off
			knob.Position = Config[key] and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
			knob.BackgroundColor3 = Config[key] and T.knobOn or T.knobOff
		end))
	end
	local hud = new("Frame", {
		Name = "BallMatrix",
		BackgroundColor3 = T.bg,
		Position = UDim2.fromOffset(16, 72),
		Size = UDim2.fromOffset(168, 78),
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = gui,
	})
	UI.hud = hud
	corner(hud, 14)
	new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 14),
		Font = FONT_BOLD,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.muted,
		Text = "BALL",
		ZIndex = 9,
		Parent = hud,
	})
	local function hudLine(y, label)
		local row = new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(14, y),
			Size = UDim2.new(1, -28, 0, 18),
			ZIndex = 9,
			Parent = hud,
		})
		new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(48, 18),
			Font = FONT,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = T.muted,
			Text = label,
			ZIndex = 10,
			Parent = row,
		})
		local value = new("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(52, 0),
			Size = UDim2.new(1, -52, 1, 0),
			Font = FONT,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = T.text,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = "—",
			ZIndex = 10,
			Parent = row,
		})
		return value
	end
	UI.stats = {
		vel = hudLine(28, "Vel"),
		target = hudLine(48, "Target"),
	}
	toggleRow("Auto Parry", "autoParry", 48)
	toggleRow("Spam", "spam", 78)
	toggleRow("Humanize", "humanize", 108)
	toggleRow("Ability ESP", "abilityEsp", 138)
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
local Parry = {
	lastParry = 0,
	parrying = false,
	lastSuccess = 0,
	plans = {},
	prevPos = {},
	prevClock = {},
	lastDist = {},
	prevY = {},
	samples = {},
	ep = nil,
	gateLogAt = 0,
}
local function isCombatReady()
	local character = LocalPlayer.Character
	if not character then
		return false, "no_character"
	end
	if not character:FindFirstChild("HumanoidRootPart") then
		return false, "no_hrp"
	end
	local parent = character.Parent
	if parent and parent.Name == "Dead" then
		return false, "dead"
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		return false, "no_health"
	end
	return true
end
local function getRoot()
	local character = LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end
local function nearestEnemyDist(root)
	local alive = Workspace:FindFirstChild("Alive")
	if not alive then
		return math.huge
	end
	local mine = LocalPlayer.Character
	local best = math.huge
	for _, character in ipairs(alive:GetChildren()) do
		if character ~= mine then
			local other = character:FindFirstChild("HumanoidRootPart")
			if other then
				local dist = (other.Position - root.Position).Magnitude
				if dist < best then
					best = dist
				end
			end
		end
	end
	return best
end
local function randRange(a, b)
	return a + math.random() * (b - a)
end
local function pressClick(hold)
	if hold <= 0.02 and mouseClick then
		mouseClick()
		return
	end
	if mouseDown and mouseUp then
		mouseDown()
		task.wait(hold)
		mouseUp()
		return
	end
	if mouseClick then
		mouseClick()
		return
	end
end
local function wantPrecise(speed)
	return (not Config.humanize) or speed >= Config.preciseSpeed
end
local function planFor(ball, speed)
	local existing = Parry.plans[ball]
	local precise = wantPrecise(speed)
	if existing then
		if precise and not existing.precise then
			existing.precise = true
			existing.react = 0
			existing.hold = 0
			existing.fireEta = Config.preciseEta
			existing.minSafe = Config.preciseEta
		end
		return existing
	end
	if precise then
		local plan = {
			noticedAt = os.clock(),
			react = 0,
			fireEta = Config.preciseEta,
			hold = 0,
			minSafe = Config.preciseEta,
			precise = true,
		}
		Parry.plans[ball] = plan
		return plan
	end
	local minSafe = Config.minSafeEta
	if speed > 180 then
		minSafe += 0.05
	elseif speed > 120 then
		minSafe += 0.03
	end
	local plan = {
		noticedAt = os.clock(),
		react = randRange(0.02, 0.08),
		fireEta = randRange(minSafe + 0.02, 0.16),
		hold = randRange(0.03, 0.07),
		minSafe = minSafe,
		precise = false,
	}
	if plan.fireEta < plan.minSafe then
		plan.fireEta = plan.minSafe + 0.03
	end
	Parry.plans[ball] = plan
	return plan
end
local function forgetStalePlans(aliveBalls)
	for ball in pairs(Parry.plans) do
		if not ball.Parent or not aliveBalls[ball] then
			Parry.plans[ball] = nil
			Parry.prevPos[ball] = nil
			Parry.prevClock[ball] = nil
			Parry.lastDist[ball] = nil
			Parry.prevY[ball] = nil
			Parry.samples[ball] = nil
		end
	end
end
local function getBallBody(ball)
	if ball:IsA("BasePart") then
		return ball
	end
	local body = ball:FindFirstChild("Body")
	if body and body:IsA("BasePart") then
		return body
	end
	return ball:FindFirstChildWhichIsA("BasePart")
end
local function isRealBall(ball)
	return ball:GetAttribute("realBall") ~= false
end
local AbilitiesMod
task.spawn(function()
	pcall(function()
		local shared = ReplicatedStorage:FindFirstChild("Shared")
		local module = shared and (shared:FindFirstChild("Abilities") or shared:WaitForChild("Abilities", 3))
		if module then
			AbilitiesMod = require(module)
		end
	end)
end)
local Overlay = {
	labels = {},
}
local function fmtNum(n)
	if type(n) ~= "number" or n ~= n then
		return "—"
	end
	return tostring(math.floor(n + 0.5))
end
local function pickRealBall()
	local folder = Workspace:FindFirstChild("Balls")
	if not folder then
		return nil
	end
	for _, ball in ipairs(folder:GetChildren()) do
		if isRealBall(ball) then
			return ball
		end
	end
	return nil
end
function Overlay.updateStats()
	local labels = UI.stats
	if not labels then
		return
	end
	local ball = pickRealBall()
	if not ball then
		labels.vel.Text = "—"
		labels.target.Text = "—"
		return
	end
	local body = getBallBody(ball)
	local phys = body and body.AssemblyLinearVelocity.Magnitude or 0
	local attr = ball:GetAttribute("CurrentSpeed")
	local vel = (type(attr) == "number" and attr > phys) and attr or phys
	local target = ball:GetAttribute("target")
	if type(target) ~= "string" or target == "" then
		target = "—"
	elseif target == LocalPlayer.Name then
		target = "You"
	end
	labels.vel.Text = fmtNum(vel)
	labels.target.Text = target
end
local function attrString(inst, name)
	if not inst then
		return nil
	end
	local value = inst:GetAttribute(name)
	if type(value) == "string" and value ~= "" then
		return value
	end
	return nil
end
local function remainingFrom(cd)
	if type(cd) == "number" then
		return math.max(0, cd)
	end
	if type(cd) ~= "table" then
		return nil
	end
	for _, key in ipairs({ "remaining", "timeLeft", "left", "cooldown" }) do
		if type(cd[key]) == "number" then
			return math.max(0, cd[key])
		end
	end
	local now = workspace:GetServerTimeNow()
	for _, key in ipairs({ "endsAt", "endTime", "EndTime" }) do
		if type(cd[key]) == "number" then
			local value = cd[key]
			if value > 1e9 then
				return math.max(0, value - now)
			end
			return math.max(0, value)
		end
	end
	if type(cd.usesRemaining) == "number" then
		return cd.usesRemaining <= 0 and 0.01 or 0
	end
	return nil
end
local function readAbility(player, character)
	local name = attrString(player, "CurrentlyEquippedAbility")
		or attrString(character, "CurrentlyEquippedAbility")
	if not name and AbilitiesMod and character and type(AbilitiesMod.getCharacterAbility) == "function" then
		local ok, ability = pcall(AbilitiesMod.getCharacterAbility, character)
		if ok and ability then
			if type(ability) == "string" then
				name = ability
			elseif typeof(ability) == "Instance" then
				name = ability.Name
			elseif type(ability) == "table" then
				name = ability.Name or ability.name
			end
		end
	end
	local second = attrString(player, "CurrentlyEquippedSecondAbility")
		or attrString(character, "CurrentlyEquippedSecondAbility")
	return name, second
end
local function readCooldown(player, character)
	if AbilitiesMod and character and type(AbilitiesMod.getCooldown) == "function" then
		local ok, cd = pcall(AbilitiesMod.getCooldown, character)
		if ok then
			local left = remainingFrom(cd)
			if left ~= nil then
				return left
			end
		end
	end
	if character and character:GetAttribute("AbilityActive") == true then
		return 0.01
	end
	local endTime = character and character:GetAttribute("AbilityBlockEndTime")
	if type(endTime) == "number" then
		return math.max(0, endTime - workspace:GetServerTimeNow())
	end
	local name = attrString(player, "CurrentlyEquippedAbility") or attrString(character, "CurrentlyEquippedAbility")
	if name and character then
		local stamped = character:GetAttribute(name .. "Cooldown") or player:GetAttribute(name .. "Cooldown")
		if type(stamped) == "number" then
			if stamped > 1e8 then
				return math.max(0, stamped - workspace:GetServerTimeNow())
			end
			if stamped > 1 and stamped < 120 then
				return stamped
			end
		end
	end
	return 0
end
local function destroyPack(pack)
	if not pack then
		return
	end
	pcall(function()
		if pack.top then
			pack.top:Destroy()
		end
		if pack.bottom then
			pack.bottom:Destroy()
		end
	end)
end
function Overlay.clearEsp()
	for _, pack in pairs(Overlay.labels) do
		destroyPack(pack)
	end
	Overlay.labels = {}
end
local function makeLabel(offsetY, name, size)
	local gui = UI.gui
	if not gui then
		return nil
	end
	local bill = new("BillboardGui", {
		Name = name,
		AlwaysOnTop = true,
		Size = UDim2.fromOffset(160, 20),
		StudsOffset = Vector3.new(0, offsetY, 0),
		MaxDistance = 220,
		LightInfluence = 0,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = gui,
	})
	local text = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = size == "title" and FONT_BOLD or FONT,
		TextSize = size == "title" and 13 or 12,
		TextColor3 = T.text,
		TextStrokeColor3 = Color3.fromRGB(16, 16, 18),
		TextStrokeTransparency = 0.35,
		Text = "—",
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 1,
		Parent = bill,
	})
	return bill, text
end
local function makeEsp()
	local top, topText = makeLabel(3.2, "BB_ESP_Top", "title")
	local bottom, bottomText = makeLabel(-2.4, "BB_ESP_Bottom", "meta")
	if not top or not bottom then
		if top then
			top:Destroy()
		end
		if bottom then
			bottom:Destroy()
		end
		return nil
	end
	return {
		top = top,
		bottom = bottom,
		topText = topText,
		bottomText = bottomText,
	}
end
function Overlay.updateEsp()
	if not Config.abilityEsp or not UI.gui then
		if next(Overlay.labels) then
			Overlay.clearEsp()
		end
		return
	end
	local alive = Workspace:FindFirstChild("Alive")
	local seen = {}
	if alive then
		for _, character in ipairs(alive:GetChildren()) do
			if character ~= LocalPlayer.Character then
				local root = character:FindFirstChild("HumanoidRootPart")
				local player = Players:GetPlayerFromCharacter(character)
				if root and player then
					seen[character] = true
					local pack = Overlay.labels[character]
					if not pack or not pack.top or not pack.top.Parent then
						destroyPack(pack)
						pack = makeEsp()
						Overlay.labels[character] = pack
					end
					if pack then
						pack.top.Adornee = root
						pack.bottom.Adornee = root
						local name, second = readAbility(player, character)
						local left = readCooldown(player, character)
						if name and second then
							name = name .. "  ·  " .. second
						end
						pack.topText.Text = name or "—"
						pack.topText.TextColor3 = name and T.text or T.muted
						if type(left) == "number" and left > 0.05 then
							pack.bottomText.Text = string.format("%.1fs", left)
							pack.bottomText.TextColor3 = T.close
						else
							pack.bottomText.Text = "ready"
							pack.bottomText.TextColor3 = T.ready
						end
					end
				end
			end
		end
	end
	for character, pack in pairs(Overlay.labels) do
		if not seen[character] then
			destroyPack(pack)
			Overlay.labels[character] = nil
		end
	end
end
function Overlay.step()
	Overlay.updateStats()
	Overlay.updateEsp()
end
local function isTargetingUs(ball)
	if ball:GetAttribute("target") == LocalPlayer.Name then
		return true
	end
	local whitelist = ball:FindFirstChild("CollisionWhitelist")
	return whitelist ~= nil
		and whitelist:IsA("ObjectValue")
		and whitelist.Value == LocalPlayer.Character
end
local function pushSample(ball, pos, now)
	local ring = Parry.samples[ball]
	if not ring then
		ring = {}
		Parry.samples[ball] = ring
	end
	local last = ring[#ring]
	if last and (pos - last.pos).Magnitude > 25 then
		ring = {}
		Parry.samples[ball] = ring
	end
	table.insert(ring, { pos = pos, t = now })
	while #ring > 4 do
		table.remove(ring, 1)
	end
	return ring
end
local function measuredMotion(ball, body)
	local now = os.clock()
	local pos = body.Position
	local ring = pushSample(ball, pos, now)
	local phys = body.AssemblyLinearVelocity
	local attr = ball:GetAttribute("CurrentSpeed")
	if type(attr) ~= "number" or attr ~= attr then
		attr = 0
	end
	local vel = phys
	if #ring >= 2 then
		local a = ring[1]
		local b = ring[#ring]
		local dt = b.t - a.t
		if dt >= 0.03 then
			vel = (b.pos - a.pos) / dt
		end
	end
	if vel.Magnitude < 5 and attr >= 5 then
		if vel.Magnitude > 0.05 then
			vel = vel.Unit * attr
		end
	end
	local accel = Vector3.zero
	if #ring >= 3 then
		local mid = ring[#ring - 1]
		local dt1 = mid.t - ring[1].t
		local dt2 = ring[#ring].t - mid.t
		if dt1 > 0.01 and dt2 > 0.01 then
			local v1 = (mid.pos - ring[1].pos) / dt1
			local v2 = (ring[#ring].pos - mid.pos) / dt2
			accel = (v2 - v1) / ((dt1 + dt2) * 0.5)
			if accel.Magnitude < 20 then
				accel = Vector3.zero
			elseif accel.Magnitude > 250 then
				accel = accel.Unit * 250
			end
		end
	end
	return vel, accel, math.max(vel.Magnitude, attr)
end
local function capsuleDist(point, hrpPos)
	local cy = math.clamp(point.Y, hrpPos.Y - 2.5, hrpPos.Y + 2.5)
	return (point - Vector3.new(hrpPos.X, cy, hrpPos.Z)).Magnitude
end
local function predictLead(ballPos, vel, accel, hrpPos)
	if capsuleDist(ballPos, hrpPos) <= Config.contactR then
		return 0
	end
	local lastD = math.huge
	for i = 1, 50 do
		local t = i * 0.02
		local p = ballPos + vel * t + accel * (0.5 * t * t)
		local d = capsuleDist(p, hrpPos)
		if d <= Config.contactR then
			return t
		end
		if d > lastD + 1.25 and d > 12 then
			break
		end
		lastD = d
	end
	return math.huge
end
local function fallbackLead(dist, xz, height, speed, incoming)
	if not incoming or speed < Config.minSpeed then
		return math.huge
	end
	if dist <= Config.contactR then
		return 0
	end
	if math.abs(height) <= 4 then
		return math.max(0, (xz - Config.contactR) / speed)
	end
	return math.max(0, (dist - Config.contactR) / speed)
end
local function fireLeadFor(speed, ping)
	local base = 0.145
	if speed >= 160 then
		base = 0.118
	elseif speed >= 90 then
		base = 0.128
	end
	return base + math.clamp(ping or 0, 0, 0.08) * 0.35
end
function Parry.fire(_plan, kind)
	local now = os.clock()
	local spamClick = kind == "spam" or kind == "rescue"
	local waitFor = spamClick and Config.clashCooldown or Config.cooldown
	if now - Parry.lastParry < waitFor then
		return false, "cooldown"
	end
	Parry.lastParry = now
	pcall(pressClick, 0)
	return true
end
local function readBall(ball, root)
	if not isRealBall(ball) then
		return nil
	end
	if not isTargetingUs(ball) then
		return nil
	end
	local body = getBallBody(ball)
	if not body then
		return nil
	end
	local vel, accel, speed = measuredMotion(ball, body)
	local frozen = ball:GetAttribute("Frozen") == true
	local pos = body.Position
	local hrpVel = root.AssemblyLinearVelocity
	local rel = vel - hrpVel
	local offset = root.Position - pos
	local dist = offset.Magnitude
	local xz = Vector3.new(offset.X, 0, offset.Z).Magnitude
	local height = pos.Y - root.Position.Y
	local incoming = offset.Magnitude > 0.05 and rel:Dot(offset) > 0
	local pred = predictLead(pos, rel, accel, root.Position)
	local flat = fallbackLead(dist, xz, height, speed, incoming)
	local lead = pred
	if lead == math.huge then
		lead = flat
	elseif flat ~= math.huge then
		lead = math.min(lead, flat)
	end
	if lead == math.huge and incoming and dist <= 16 then
		lead = 0
	end
	local ping = 0
	pcall(function()
		ping = LocalPlayer:GetNetworkPing()
	end)
	local fireLead = fireLeadFor(speed, ping)
	return {
		eta = lead,
		lead = lead,
		fireLead = fireLead,
		dist = dist,
		xz = xz,
		height = height,
		vy = vel.Y,
		diving = height > 3.5 and vel.Y < -8,
		incoming = incoming,
		speed = speed,
		window = Config.parryWindow + ping,
		reach = Config.maxFireDist,
		precise = wantPrecise(speed),
		ping = ping,
		frozen = frozen,
	}
end
function Parry.step()
	if not Core.running or not Config.autoParry then
		return
	end
	local ready, gate = isCombatReady()
	if not ready then
		if gate and gate ~= "dead" and os.clock() - Parry.gateLogAt > 2 then
			Parry.gateLogAt = os.clock()
			Log.once("gate", 2, "skip", { why = gate })
		end
		return
	end
	local root = getRoot()
	local balls = Workspace:FindFirstChild("Balls")
	if not root or not balls then
		return
	end
	local live = {}
	local now = os.clock()
	local bestBall, bestInfo, bestPlan
	for _, ball in ipairs(balls:GetChildren()) do
		local info = readBall(ball, root)
		if info then
			live[ball] = true
			local plan = planFor(ball, info.speed)
			if not plan.loggedNotice then
				plan.loggedNotice = true
				Log.write("notice", Log.snapshot(info, plan, {}))
			end
			if not bestInfo or (info.lead < bestInfo.lead) then
				bestBall, bestInfo, bestPlan = ball, info, plan
			end
		end
	end
	forgetStalePlans(live)
	if not bestInfo then
		return
	end
	local ep = Parry.ep
	if not ep or ep.ball ~= bestBall then
		ep = { ball = bestBall, clicks = 0, lastClickAt = 0, minDist = bestInfo.dist }
		Parry.ep = ep
	end
	if bestInfo.dist < ep.minDist then
		ep.minDist = bestInfo.dist
	end
	if bestInfo.dist > ep.minDist + 10 or bestInfo.lead > 0.40 then
		ep = { ball = bestBall, clicks = 0, lastClickAt = 0, minDist = bestInfo.dist }
		Parry.ep = ep
	end
	local lead = bestInfo.lead
	local height = bestInfo.height or 0
	local vy = bestInfo.vy or 0
	local fireLead = bestInfo.fireLead
	if Config.humanize and not bestInfo.precise and bestPlan then
		fireLead = math.max(0.09, fireLead - (bestPlan.react or 0))
	end
	local highArc = height > 4.5 and vy > -8 and lead > 0.09
	local panic = (not bestInfo.frozen)
		and bestInfo.incoming
		and bestInfo.dist <= 16
		and (lead == math.huge or lead <= 0.14)
	local inWindow = (not bestInfo.frozen)
		and lead ~= math.huge
		and lead <= fireLead
		and bestInfo.dist <= Config.maxFireDist
		and not highArc
	if panic then
		inWindow = true
	end
	local rescue = (not Config.spam)
		and ep.clicks == 1
		and lead ~= math.huge
		and lead <= Config.rescueLead
		and now - ep.lastClickAt >= Config.rescueGap
	local spamReady = Config.spam
		and ep.clicks >= 1
		and lead ~= math.huge
		and lead <= Config.spamLead
		and bestInfo.dist <= Config.maxFireDist + 2
		and now - ep.lastClickAt >= Config.clashCooldown
	local kind = nil
	if inWindow and ep.clicks == 0 then
		kind = "parry"
	elseif rescue then
		kind = "rescue"
	elseif spamReady then
		kind = "spam"
	end
	if inWindow or rescue then
		Log.once("should", 0.2, "should", Log.snapshot(bestInfo, bestPlan, {
			spam = Config.spam,
			kind = kind,
		}))
		Log.shouldAt = now
		Log.shouldInfo = Log.snapshot(bestInfo, bestPlan, {})
	end
	if kind then
		local ok, why = Parry.fire(bestPlan, kind)
		if ok then
			ep.clicks += 1
			ep.lastClickAt = now
			Parry.lastSuccess = now
			Log.firedAt = now
			Log.firedInfo = Log.snapshot(bestInfo, bestPlan, { kind = kind, clicks = ep.clicks })
			Log.write(kind, Log.firedInfo)
		elseif kind == "parry" or kind == "rescue" then
			Log.once("skip_" .. (why or "fire"), 0.25, "skip", Log.snapshot(bestInfo, bestPlan, {
				why = why or "fire",
			}))
		end
	end
end
local function watchDeath(character)
	if not character then
		return
	end
	Core.track(character:GetPropertyChangedSignal("Parent"):Connect(function()
		if not Core.running then
			return
		end
		local parent = character.Parent
		local dead = Workspace:FindFirstChild("Dead")
		if parent ~= dead then
			return
		end
		local now = os.clock()
		if Log.firedAt > 0 and now - Log.firedAt <= 1.6 then
			Log.write("fail", {
				why = "died_after_parry",
				since = round(now - Log.firedAt, 3),
				last = Log.firedInfo,
			})
		elseif Log.shouldAt > 0 and now - Log.shouldAt <= 1.6 then
			Log.write("fail", {
				why = "died_after_should",
				since = round(now - Log.shouldAt, 3),
				last = Log.shouldInfo,
			})
		else
			Log.once("fail_dead", 1.2, "fail", { why = "died" })
		end
		Log.firedAt = 0
		Log.shouldAt = 0
	end))
end
function Parry.start()
	Log.start()
	watchDeath(LocalPlayer.Character)
	Core.track(LocalPlayer.CharacterAdded:Connect(function(character)
		watchDeath(character)
	end))
	Core.track(RunService.Heartbeat:Connect(function()
		Parry.step()
		Overlay.step()
	end))
end
local function unload()
	if not Core.running then
		return
	end
	Core.running = false
	Config.autoParry = false
	Log.write("unload", {})
	Overlay.clearEsp()
	Core.disconnectAll()
	UI.destroy()
	if type(env) == "table" then
		env.BB_UNLOAD = nil
	end
end
if type(env) == "table" then
	env.BB_UNLOAD = unload
end
UI.build(unload)
Parry.start()
