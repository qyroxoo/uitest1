--[[
	Prestige Alpha v5.2.0 — universal client utility framework
	Right Shift = show / hide the window
]]

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Lighting         = game:GetService("Lighting")
local Workspace        = game:GetService("Workspace")
local TeleportService  = game:GetService("TeleportService")
local StarterGui       = game:GetService("StarterGui")
local HttpService      = game:GetService("HttpService")
local VirtualUser      = game:GetService("VirtualUser")

local player = Players.LocalPlayer

-- ============================================================
-- DRAWING DETECTION
-- ============================================================
local hasDrawing = false
pcall(function()
	if typeof(Drawing) == "table" or type(Drawing) == "table" then
		local t = Drawing.new("Square")
		if t.Remove then t:Remove()
		elseif t.Destroy then t:Destroy()
		elseif t.remove then t:remove() end
		hasDrawing = true
	end
end)

-- ============================================================
-- CONFIG
-- ============================================================
local TITLE, TITLE_ACCENT = "Prestige", "Alpha"
local SUBTITLE = "ALPHA RELEASE 5.2.0"
local CHIP_TEXT = "All"
local TOGGLE_KEY = Enum.KeyCode.RightShift
local ORIGINAL_ACCENT = Color3.fromRGB(139, 125, 255)

local C = {
	bg      = Color3.fromRGB(9, 10, 36),
	bg2     = Color3.fromRGB(6, 7, 26),
	sidebar = Color3.fromRGB(13, 14, 44),
	row     = Color3.fromRGB(14, 16, 50),
	stroke  = Color3.fromRGB(32, 36, 82),
	text    = Color3.fromRGB(245, 245, 255),
	muted   = Color3.fromRGB(110, 115, 165),
	accent  = ORIGINAL_ACCENT,
	offBg   = Color3.fromRGB(9, 10, 32),
	knobOff = Color3.fromRGB(235, 235, 245),
}

local UI = {}

-- ============================================================
-- CUSTOM NOTIFICATIONS
-- ============================================================
local Notifications = { holder = nil, order = 0, enabled = true }

local KIND_COLORS = {
	info    = function() return C.accent end,
	success = function() return Color3.fromRGB(80, 220, 130) end,
	warning = function() return Color3.fromRGB(255, 180, 70) end,
	error   = function() return Color3.fromRGB(255, 90, 110) end,
}

function Notifications.setup()
	local sg = Instance.new("ScreenGui")
	sg.Name = "PrestigeNotifications"
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.DisplayOrder = 1000
	sg.Parent = player:WaitForChild("PlayerGui")

	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.Position = UDim2.new(1, -16, 0, 16)
	holder.Size = UDim2.fromOffset(320, 600)
	holder.BackgroundTransparency = 1
	holder.Parent = sg

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder

	Notifications.holder = holder
	Notifications.gui = sg
end

function Notifications.push(title, text, kind, duration)
	if not Notifications.enabled then return end
	if not Notifications.holder then Notifications.setup() end
	kind = kind or "info"
	duration = duration or 4
	Notifications.order += 1
	local color = (KIND_COLORS[kind] or KIND_COLORS.info)()

	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = C.bg
	card.BackgroundTransparency = 0.05
	card.LayoutOrder = Notifications.order
	card.ClipsDescendants = true
	card.Parent = Notifications.holder
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
	local st = Instance.new("UIStroke", card)
	st.Color = color
	st.Thickness = 1

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 3, 1, 0)
	bar.BackgroundColor3 = color
	bar.BorderSizePixel = 0
	bar.Parent = card

	local titleL = Instance.new("TextLabel")
	titleL.BackgroundTransparency = 1
	titleL.Position = UDim2.fromOffset(14, 10)
	titleL.Size = UDim2.new(1, -20, 0, 16)
	titleL.Font = Enum.Font.GothamBold
	titleL.TextSize = 13
	titleL.TextColor3 = color
	titleL.TextXAlignment = Enum.TextXAlignment.Left
	titleL.Text = title
	titleL.Parent = card

	local bodyL = Instance.new("TextLabel")
	bodyL.BackgroundTransparency = 1
	bodyL.Position = UDim2.fromOffset(14, 28)
	bodyL.Size = UDim2.new(1, -20, 0, 0)
	bodyL.AutomaticSize = Enum.AutomaticSize.Y
	bodyL.Font = Enum.Font.Gotham
	bodyL.TextSize = 12
	bodyL.TextColor3 = C.text
	bodyL.TextXAlignment = Enum.TextXAlignment.Left
	bodyL.TextWrapped = true
	bodyL.Text = text or ""
	bodyL.Parent = card

	local pad = Instance.new("UIPadding", card)
	pad.PaddingBottom = UDim.new(0, 10)

	card.Position = UDim2.new(1, 40, 0, 0)
	TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0, 0, 0, 0) }):Play()

	task.delay(duration, function()
		if not card.Parent then return end
		local out = TweenService:Create(card,
			TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
			{ Position = UDim2.new(1, 40, 0, 0), BackgroundTransparency = 1 })
		out:Play()
		out.Completed:Connect(function() card:Destroy() end)
	end)
end

local function notify(text, kind, duration)
	Notifications.push("Prestige", text, kind or "info", duration or 3)
end

-- ============================================================
-- CHARACTER HELPERS
-- ============================================================
local function getChar() return player.Character end
local function getHum()
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function getRoot()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end
local function getCam() return Workspace.CurrentCamera end

-- ============================================================
-- FEATURE REGISTRY
-- ============================================================
local Features = {}

local function feature(def)
	def.options = def.options or {}
	def.state = {}
	def.enabled = false
	for _, o in ipairs(def.options) do
		def.state[o.name] = o.value
	end
	table.insert(Features, def)
	return def
end

local function setOption(f, opt, value)
	opt.value = value
	f.state[opt.name] = value
	if f.onOption then
		local ok, err = pcall(f.onOption, f.state, opt.name, value, opt)
		if not ok then warn("[Prestige] " .. f.name .. " onOption: " .. tostring(err)) end
	end
end

local function setEnabled(f, on)
	if f.enabled == on then return end
	f.enabled = on
	local fn = on and f.enable or f.disable
	if fn then
		local ok, err = pcall(fn, f.state)
		if not ok then
			warn("[Prestige] " .. f.name .. ": " .. tostring(err))
			notify(f.name .. " failed: " .. tostring(err), "error", 5)
		end
	end
end

-- ============================================================
-- ESP
-- ============================================================
local ESP = { conn = nil, cache = {}, running = false, highlights = {}, settings = nil }

local function safeNewDrawing(kind)
	local obj
	local ok = pcall(function() obj = Drawing.new(kind) end)
	if ok then return obj end
	return nil
end

function ESP.makeObjects()
	local o = {}
	o.box = safeNewDrawing("Square")
	o.name = safeNewDrawing("Text")
	o.dist = safeNewDrawing("Text")
	o.hpBg = safeNewDrawing("Square")
	o.hpBar = safeNewDrawing("Square")
	o.tracer = safeNewDrawing("Line")
	if not (o.box and o.name and o.dist and o.hpBg and o.hpBar and o.tracer) then
		return nil
	end
	o.box.Thickness = 1; o.box.Filled = false; o.box.Transparency = 1; o.box.Visible = false
	o.name.Size = 14; o.name.Center = true; o.name.Outline = true
	o.name.OutlineColor = Color3.new(0, 0, 0); o.name.Visible = false
	o.dist.Size = 12; o.dist.Center = true; o.dist.Outline = true
	o.dist.OutlineColor = Color3.new(0, 0, 0); o.dist.Visible = false
	o.hpBg.Filled = true; o.hpBg.Color = Color3.new(0, 0, 0)
	o.hpBg.Transparency = 0.5; o.hpBg.Visible = false
	o.hpBar.Filled = true; o.hpBar.Transparency = 1; o.hpBar.Visible = false
	o.tracer.Thickness = 1; o.tracer.Visible = false
	return o
end

function ESP.hide(o)
	if not o then return end
	pcall(function()
		o.box.Visible = false
		o.name.Visible = false
		o.dist.Visible = false
		o.hpBg.Visible = false
		o.hpBar.Visible = false
		o.tracer.Visible = false
	end)
end

function ESP.update(plr, o, s)
	local char = plr.Character
	if not char then ESP.hide(o); return end
	local hum  = char:FindFirstChildOfClass("Humanoid")
	local head = char:FindFirstChild("Head")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not (hum and head and root and hum.Health > 0) then ESP.hide(o); return end
	if plr == player and not s["Show Local"] then ESP.hide(o); return end
	if s["Team Check"] and plr.Team and player.Team and plr.Team == player.Team then
		ESP.hide(o); return
	end

	local cam = getCam()
	if not cam then ESP.hide(o); return end
	local myRoot = getRoot()
	local dist = myRoot and (root.Position - myRoot.Position).Magnitude or 0
	if dist > s["Max Distance"] then ESP.hide(o); return end

	local topPos = head.Position + Vector3.new(0, head.Size.Y * 0.5, 0)
	local botPos = root.Position - Vector3.new(0, root.Size.Y * 0.5, 0)
	local topS, topOn = cam:WorldToViewportPoint(topPos)
	local botS, botOn = cam:WorldToViewportPoint(botPos)
	if not topOn or not botOn or topS.Z <= 0 or botS.Z <= 0 then
		ESP.hide(o); return
	end

	local height = math.abs(botS.Y - topS.Y)
	local width  = math.max(height * 0.55, 12)
	local x = topS.X - width / 2
	local y = topS.Y

	if s["Box"] then
		o.box.Visible = true
		o.box.Position = Vector2.new(x, y)
		o.box.Size = Vector2.new(width, height)
		o.box.Color = s["Box Color"]
	end

	if s["Name"] then
		o.name.Visible = true
		o.name.Text = plr.Name
		o.name.Position = Vector2.new(x + width / 2, y - 18)
		o.name.Color = s["Name Color"]
	end

	if s["Distance"] then
		o.dist.Visible = true
		o.dist.Text = string.format("[%d]", math.floor(dist))
		o.dist.Position = Vector2.new(x + width / 2, y + height + 4)
		o.dist.Color = Color3.fromRGB(220, 220, 220)
	end

	if s["Health Bar"] then
		local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
		local hpW = 3
		local hpX = x - hpW - 4
		o.hpBg.Visible = true
		o.hpBg.Position = Vector2.new(hpX, y)
		o.hpBg.Size = Vector2.new(hpW, height)
		o.hpBar.Visible = true
		o.hpBar.Position = Vector2.new(hpX, y + height * (1 - pct))
		o.hpBar.Size = Vector2.new(hpW, height * pct)
		o.hpBar.Color = Color3.fromRGB(255, 0, 0):Lerp(Color3.fromRGB(0, 255, 100), pct)
	end

	if s["Tracer"] then
		o.tracer.Visible = true
		o.tracer.From = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
		o.tracer.To   = Vector2.new(x + width / 2, y + height)
		o.tracer.Color = s["Tracer Color"]
	end
end

function ESP.stop()
	if ESP.conn then ESP.conn:Disconnect(); ESP.conn = nil end
	for _, o in pairs(ESP.cache) do
		for _, obj in pairs(o) do pcall(function() obj:Remove() end) end
	end
	ESP.cache = {}
	for _, h in pairs(ESP.highlights) do pcall(function() h:Destroy() end) end
	ESP.highlights = {}
	ESP.running = false
end

function ESP.startFallback(s)
	ESP.stop()
	ESP.running = true
	ESP.settings = s
	local function attach(char)
		if not char then return end
		local existing = char:FindFirstChild("PrestigeESP")
		if existing then existing:Destroy() end
		local h = Instance.new("Highlight")
		h.Name = "PrestigeESP"
		h.Adornee = char
		h.FillColor = s["Box Color"]
		h.OutlineColor = s["Box Color"]
		h.FillTransparency = s["Tracer"] and 1 or 0.75
		h.OutlineTransparency = 0
		h.Parent = char
	end
	ESP.conn = RunService.Heartbeat:Connect(function()
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= player or s["Show Local"] then
				local char = plr.Character
				if char and not char:FindFirstChild("PrestigeESP") then
					attach(char)
				end
				if char then
					local h = char:FindFirstChild("PrestigeESP")
					if h then h.FillColor = s["Box Color"]; h.OutlineColor = s["Box Color"] end
				end
			end
		end
	end)
end

function ESP.start(s)
	if not hasDrawing then ESP.startFallback(s); return end
	ESP.stop()
	local test = ESP.makeObjects()
	if not test then ESP.startFallback(s); return end
	for _, obj in pairs(test) do pcall(function() obj:Remove() end) end

	ESP.running = true
	ESP.settings = s
	ESP.conn = RunService.RenderStepped:Connect(function()
		for _, plr in ipairs(Players:GetPlayers()) do
			local o = ESP.cache[plr]
			if not o then
				o = ESP.makeObjects()
				if o then ESP.cache[plr] = o end
			end
			if o then
				local ok, err = pcall(ESP.update, plr, o, ESP.settings)
				if not ok then ESP.hide(o) end
			end
		end
	end)
end

-- ============================================================
-- FEATURES — MOVEMENT
-- ============================================================
feature{
	tab = "Movement", name = "Walkspeed",
	desc = "Set your character's movement speed",
	options = { { type = "slider", name = "Speed", min = 8, max = 250, value = 16 } },
	enable  = function(s) local h = getHum(); if h then h.WalkSpeed = s.Speed end end,
	disable = function() local h = getHum(); if h then h.WalkSpeed = 16 end end,
	onOption = function(s, n, v)
		if n == "Speed" then local h = getHum(); if h then h.WalkSpeed = v end end
	end,
}

feature{
	tab = "Movement", name = "Jump Power",
	desc = "Set how high you jump",
	options = { { type = "slider", name = "Power", min = 0, max = 400, value = 50 } },
	enable = function(s)
		local h = getHum(); if h then h.UseJumpPower = true; h.JumpPower = s.Power end
	end,
	disable = function() local h = getHum(); if h then h.JumpPower = 50 end end,
	onOption = function(s, n, v)
		if n == "Power" then
			local h = getHum(); if h then h.UseJumpPower = true; h.JumpPower = v end
		end
	end,
}

feature{
	tab = "Movement", name = "Infinite Jump",
	desc = "Jump again while still in the air",
	enable = function(s)
		s.conn = UserInputService.JumpRequest:Connect(function()
			local h = getHum()
			if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
		end)
	end,
	disable = function(s) if s.conn then s.conn:Disconnect(); s.conn = nil end end,
}

feature{
	tab = "Movement", name = "Fly",
	desc = "WASD · Space up · Left Ctrl down",
	options = { { type = "slider", name = "Speed", min = 10, max = 300, value = 60 } },
	enable = function(s)
		local root = getRoot(); if not root then return end
		s.bv = Instance.new("BodyVelocity")
		s.bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
		s.bv.Velocity = Vector3.zero
		s.bv.Parent = root
		s.gyro = Instance.new("BodyGyro")
		s.gyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
		s.gyro.P = 1e4
		s.gyro.Parent = root
		s.conn = RunService.RenderStepped:Connect(function()
			local h = getHum(); if h then h.PlatformStand = true end
			local cam = getCam(); if not cam then return end
			local move = Vector3.zero
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += cam.CFrame.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= cam.CFrame.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= cam.CFrame.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += cam.CFrame.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.yAxis end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.yAxis end
			local r = getRoot()
			if not r or not s.bv then return end
			s.bv.Velocity = move.Magnitude > 0 and move.Unit * s.Speed or Vector3.zero
			s.gyro.CFrame = cam.CFrame
		end)
	end,
	disable = function(s)
		if s.conn then s.conn:Disconnect(); s.conn = nil end
		if s.bv then s.bv:Destroy(); s.bv = nil end
		if s.gyro then s.gyro:Destroy(); s.gyro = nil end
		local h = getHum(); if h then h.PlatformStand = false end
	end,
}

feature{
	tab = "Movement", name = "Noclip",
	desc = "Walk through walls",
	enable = function(s)
		s.conn = RunService.Stepped:Connect(function()
			local c = getChar(); if not c then return end
			for _, p in ipairs(c:GetDescendants()) do
				if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
			end
		end)
	end,
	disable = function(s)
		if s.conn then s.conn:Disconnect(); s.conn = nil end
		local c = getChar(); if not c then return end
		for _, p in ipairs(c:GetDescendants()) do
			if p:IsA("BasePart") then p.CanCollide = true end
		end
	end,
}

feature{
	tab = "Movement", name = "Hip Height",
	desc = "Raise or lower your character off the ground",
	options = { { type = "slider", name = "Height", min = -5, max = 25, value = 2 } },
	enable  = function(s) local h = getHum(); if h then h.HipHeight = s.Height end end,
	disable = function() local h = getHum(); if h then h.HipHeight = 2 end end,
	onOption = function(s, n, v)
		if n == "Height" then local h = getHum(); if h then h.HipHeight = v end end
	end,
}

feature{
	tab = "Movement", name = "Gravity",
	desc = "Change world gravity for your client",
	options = { { type = "slider", name = "Gravity", min = 0, max = 300, value = 196 } },
	enable = function(s) s.old = Workspace.Gravity; Workspace.Gravity = s.Gravity end,
	disable = function(s) Workspace.Gravity = s.old or 196 end,
	onOption = function(_, n, v) if n == "Gravity" then Workspace.Gravity = v end end,
}

feature{
	tab = "Movement", name = "Freeze",
	desc = "Anchor your character in place",
	enable = function(s)
		s.conn = RunService.Heartbeat:Connect(function()
			local r = getRoot(); if r then r.Anchored = true end
		end)
	end,
	disable = function(s)
		if s.conn then s.conn:Disconnect(); s.conn = nil end
		local r = getRoot(); if r then r.Anchored = false end
	end,
}

feature{
	tab = "Movement", name = "Sprint",
	desc = "Hold Left Shift to sprint",
	options = { { type = "slider", name = "Boost", min = 20, max = 200, value = 60 } },
	enable = function(s)
		s.conn = RunService.Heartbeat:Connect(function()
			local h = getHum(); if not h then return end
			h.WalkSpeed = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and s.Boost or 16
		end)
	end,
	disable = function(s)
		if s.conn then s.conn:Disconnect(); s.conn = nil end
		local h = getHum(); if h then h.WalkSpeed = 16 end
	end,
}

-- ============================================================
-- FEATURES — VISUAL (includes ESP)
-- ============================================================
feature{
	tab = "Visual", name = "Player ESP",
	desc = hasDrawing and "Boxes, names, health, tracers" or "Highlight fallback (no Drawing API)",
	options = {
		{ type = "toggle", name = "Box",          value = true },
		{ type = "color",  name = "Box Color",    value = Color3.fromRGB(139, 125, 255) },
		{ type = "toggle", name = "Name",         value = true },
		{ type = "color",  name = "Name Color",   value = Color3.fromRGB(255, 255, 255) },
		{ type = "toggle", name = "Health Bar",   value = true },
		{ type = "toggle", name = "Distance",     value = true },
		{ type = "toggle", name = "Tracer",       value = false },
		{ type = "color",  name = "Tracer Color", value = Color3.fromRGB(139, 125, 255) },
		{ type = "toggle", name = "Team Check",   value = true },
		{ type = "toggle", name = "Show Local",   value = false },
		{ type = "slider", name = "Max Distance", min = 50, max = 5000, value = 1000 },
	},
	enable  = function(s) ESP.start(s) end,
	disable = function() ESP.stop() end,
}

feature{
	tab = "Visual", name = "Fullbright",
	desc = "Brighten the entire map",
	enable = function(s)
		s.old = { Brightness = Lighting.Brightness, Ambient = Lighting.Ambient,
			OutdoorAmbient = Lighting.OutdoorAmbient, ClockTime = Lighting.ClockTime, FogEnd = Lighting.FogEnd }
		Lighting.Brightness = 2
		Lighting.Ambient = Color3.new(1, 1, 1)
		Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
		Lighting.ClockTime = 14
		Lighting.FogEnd = 1e6
	end,
	disable = function(s)
		if not s.old then return end
		for k, v in pairs(s.old) do Lighting[k] = v end
		s.old = nil
	end,
}

feature{
	tab = "Visual", name = "Field of View",
	desc = "Change your camera's FOV",
	options = { { type = "slider", name = "FOV", min = 30, max = 140, value = 70 } },
	enable  = function(s) local c = getCam(); if c then c.FieldOfView = s.FOV end end,
	disable = function() local c = getCam(); if c then c.FieldOfView = 70 end end,
	onOption = function(_, n, v) if n == "FOV" then local c = getCam(); if c then c.FieldOfView = v end end end,
}

feature{
	tab = "Visual", name = "Time of Day",
	desc = "Set the clock time",
	options = { { type = "slider", name = "Hour", min = 0, max = 24, value = 14 } },
	enable = function(s) s.old = Lighting.ClockTime; Lighting.ClockTime = s.Hour end,
	disable = function(s) Lighting.ClockTime = s.old or 14 end,
	onOption = function(_, n, v) if n == "Hour" then Lighting.ClockTime = v end end,
}

feature{
	tab = "Visual", name = "Fog",
	desc = "Control fog near / far distance",
	options = {
		{ type = "slider", name = "Start", min = 0,   max = 500,  value = 0 },
		{ type = "slider", name = "End",   min = 100, max = 5000, value = 1000 },
	},
	enable = function(s)
		s.old = { Lighting.FogStart, Lighting.FogEnd }
		Lighting.FogStart = s.Start; Lighting.FogEnd = s.End
	end,
	disable = function(s)
		if not s.old then return end
		Lighting.FogStart = s.old[1]; Lighting.FogEnd = s.old[2]
	end,
	onOption = function(_, n, v)
		if n == "Start" then Lighting.FogStart = v
		elseif n == "End" then Lighting.FogEnd = v end
	end,
}

feature{
	tab = "Visual", name = "Camera Zoom",
	desc = "Max zoom-out distance",
	options = { { type = "slider", name = "Distance", min = 0, max = 500, value = 128 } },
	enable = function(s) s.old = player.CameraMaxZoomDistance; player.CameraMaxZoomDistance = s.Distance end,
	disable = function(s) player.CameraMaxZoomDistance = s.old or 128 end,
	onOption = function(_, n, v) if n == "Distance" then player.CameraMaxZoomDistance = v end end,
}

feature{
	tab = "Visual", name = "Brightness",
	desc = "Lighting brightness",
	options = { { type = "slider", name = "Level", min = 0, max = 10, value = 2 } },
	enable = function(s) s.old = Lighting.Brightness; Lighting.Brightness = s.Level end,
	disable = function(s) Lighting.Brightness = s.old or 2 end,
	onOption = function(_, n, v) if n == "Level" then Lighting.Brightness = v end end,
}

feature{
	tab = "Visual", name = "Ambient Light",
	desc = "Indoor ambient brightness",
	options = { { type = "slider", name = "Level", min = 0, max = 255, value = 70 } },
	enable = function(s) s.old = Lighting.Ambient; Lighting.Ambient = Color3.fromRGB(s.Level, s.Level, s.Level) end,
	disable = function(s) Lighting.Ambient = s.old or Color3.fromRGB(70, 70, 70) end,
	onOption = function(_, n, v) if n == "Level" then Lighting.Ambient = Color3.fromRGB(v, v, v) end end,
}

feature{
	tab = "Visual", name = "Exposure",
	desc = "Exposure compensation",
	options = { { type = "slider", name = "Value", min = -3, max = 3, value = 0 } },
	enable = function(s) s.old = Lighting.ExposureCompensation; Lighting.ExposureCompensation = s.Value end,
	disable = function(s) Lighting.ExposureCompensation = s.old or 0 end,
	onOption = function(_, n, v) if n == "Value" then Lighting.ExposureCompensation = v end end,
}

feature{
	tab = "Visual", name = "Remove Sky",
	desc = "Delete Sky objects",
	enable = function(s)
		s.removed = {}
		for _, d in ipairs(Lighting:GetChildren()) do
			if d:IsA("Sky") then s.removed[d] = d.Parent; d.Parent = nil end
		end
	end,
	disable = function(s)
		for d, p in pairs(s.removed or {}) do if d then d.Parent = p end end
		s.removed = nil
	end,
}

feature{
	tab = "Visual", name = "Remove Sun Rays",
	desc = "Delete SunRaysEffect instances",
	enable = function(s)
		s.removed = {}
		for _, d in ipairs(Lighting:GetChildren()) do
			if d:IsA("SunRaysEffect") then s.removed[d] = d.Parent; d.Parent = nil end
		end
	end,
	disable = function(s)
		for d, p in pairs(s.removed or {}) do if d then d.Parent = p end end
		s.removed = nil
	end,
}

-- ============================================================
-- FEATURES — WORLD
-- ============================================================
feature{
	tab = "World", name = "Remove Blur",
	desc = "Delete BlurEffect instances",
	enable = function(s)
		s.removed = {}
		for _, d in ipairs(Lighting:GetChildren()) do
			if d:IsA("BlurEffect") then s.removed[d] = d.Parent; d.Parent = nil end
		end
	end,
	disable = function(s)
		for d, p in pairs(s.removed or {}) do if d then d.Parent = p end end
		s.removed = nil
	end,
}

feature{
	tab = "World", name = "Disable Shadows",
	desc = "Turn off global shadows",
	enable = function(s) s.old = Lighting.GlobalShadows; Lighting.GlobalShadows = false end,
	disable = function(s) Lighting.GlobalShadows = s.old ~= false end,
}

feature{
	tab = "World", name = "Hide Particles",
	desc = "Suppress ParticleEmitters, Trails and Beams",
	enable = function(s)
		s.hidden = {}
		local function hide(d)
			if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam")
				or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then
				s.hidden[d] = d.Enabled
				d.Enabled = false
			end
		end
		for _, d in ipairs(Workspace:GetDescendants()) do hide(d) end
		s.conn = Workspace.DescendantAdded:Connect(hide)
	end,
	disable = function(s)
		if s.conn then s.conn:Disconnect(); s.conn = nil end
		for d, was in pairs(s.hidden or {}) do
			if d and d.Parent then d.Enabled = was end
		end
		s.hidden = nil
	end,
}

feature{
	tab = "World", name = "Disable Post FX",
	desc = "Strip DepthOfField, Bloom and ColorCorrection",
	enable = function(s)
		s.removed = {}
		for _, d in ipairs(Lighting:GetChildren()) do
			if d:IsA("DepthOfFieldEffect") or d:IsA("BloomEffect")
				or d:IsA("ColorCorrectionEffect") or d:IsA("ColorGradingEffect") then
				s.removed[d] = d.Parent; d.Parent = nil
			end
		end
	end,
	disable = function(s)
		for d, p in pairs(s.removed or {}) do if d then d.Parent = p end end
		s.removed = nil
	end,
}

-- ============================================================
-- FEATURES — PLAYER
-- ============================================================
feature{
	tab = "Player", name = "Player List",
	desc = "Floating list of players with HP and distance",
	enable = function(s)
		local sg = Instance.new("ScreenGui")
		sg.Name = "PrestigePlayerList"; sg.ResetOnSpawn = false
		sg.IgnoreGuiInset = true
		sg.Parent = player:WaitForChild("PlayerGui")

		local frame = Instance.new("Frame")
		frame.Position = UDim2.new(0, 14, 0, 90)
		frame.Size = UDim2.fromOffset(220, 300)
		frame.BackgroundColor3 = C.bg
		frame.BackgroundTransparency = 0.1
		frame.Parent = sg
		Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)
		local st = Instance.new("UIStroke", frame); st.Color = C.stroke

		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromOffset(14, 8)
		title.Size = UDim2.new(1, -20, 0, 20)
		title.Font = Enum.Font.GothamBold
		title.TextSize = 12
		title.TextColor3 = C.text
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = "PLAYERS"
		title.Parent = frame

		local scroll = Instance.new("ScrollingFrame")
		scroll.Position = UDim2.fromOffset(8, 34)
		scroll.Size = UDim2.new(1, -16, 1, -42)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 2
		scroll.ScrollBarImageColor3 = C.stroke
		scroll.CanvasSize = UDim2.new()
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.Parent = frame
		Instance.new("UIListLayout", scroll).Padding = UDim.new(0, 2)

		s.gui = sg
		s.rows = {}

		local function makeRow(plr)
			local r = Instance.new("Frame")
			r.Size = UDim2.new(1, 0, 0, 26)
			r.BackgroundColor3 = C.row
			r.BackgroundTransparency = 0.4
			r.Parent = scroll
			Instance.new("UICorner", r).CornerRadius = UDim.new(0, 6)
			local nm = Instance.new("TextLabel")
			nm.BackgroundTransparency = 1
			nm.Position = UDim2.fromOffset(8, 0)
			nm.Size = UDim2.new(0.55, 0, 1, 0)
			nm.Font = Enum.Font.GothamMedium
			nm.TextSize = 11
			nm.TextColor3 = plr == player and C.accent or C.text
			nm.TextXAlignment = Enum.TextXAlignment.Left
			nm.Text = plr.Name
			nm.Parent = r
			local info = Instance.new("TextLabel")
			info.BackgroundTransparency = 1
			info.AnchorPoint = Vector2.new(1, 0)
			info.Position = UDim2.new(1, -8, 0, 0)
			info.Size = UDim2.new(0.45, 0, 1, 0)
			info.Font = Enum.Font.Gotham
			info.TextSize = 10
			info.TextColor3 = C.muted
			info.TextXAlignment = Enum.TextXAlignment.Right
			info.Text = ""
			info.Parent = r
			return r, info
		end

		s.conn = RunService.Heartbeat:Connect(function()
			local present = {}
			for _, plr in ipairs(Players:GetPlayers()) do
				present[plr] = true
				local data = s.rows[plr]
				if not data then
					local row, info = makeRow(plr)
					data = { row = row, info = info }
					s.rows[plr] = data
				end
				local char = plr.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local myRoot = getRoot()
				if hum and root and myRoot then
					local d = math.floor((root.Position - myRoot.Position).Magnitude)
					data.info.Text = string.format("%d HP  •  %dm", math.floor(hum.Health), d)
				else
					data.info.Text = "—"
				end
			end
			for plr, data in pairs(s.rows) do
				if not present[plr] then
					data.row:Destroy()
					s.rows[plr] = nil
				end
			end
		end)
	end,
	disable = function(s)
		if s.conn then s.conn:Disconnect(); s.conn = nil end
		if s.gui then s.gui:Destroy(); s.gui = nil end
		s.rows = nil
	end,
}

feature{
	tab = "Player", name = "Teleport to Nearest",
	desc = "Teleport to the closest player",
	action = true,
	run = function()
		local myRoot = getRoot(); if not myRoot then return end
		local best, bestD
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= player then
				local r = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
				if r then
					local d = (r.Position - myRoot.Position).Magnitude
					if not bestD or d < bestD then bestD = d; best = r end
				end
			end
		end
		if best then
			myRoot.CFrame = best.CFrame * CFrame.new(0, 0, 4)
			notify("Teleported to " .. (best.Parent and best.Parent.Name or "player"), "success")
		end
	end,
}

feature{
	tab = "Player", name = "Click Teleport",
	desc = "Hold Left Ctrl and click a spot to teleport",
	enable = function(s)
		s.conn = UserInputService.InputBegan:Connect(function(input, gp)
			if gp then return end
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			if not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then return end
			local cam = getCam(); local myRoot = getRoot()
			if not (cam and myRoot) then return end
			local ray = cam:ScreenPointToRay(input.Position.X, input.Position.Y)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { getChar() }
			local result = Workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
			if result then
				myRoot.CFrame = CFrame.new(result.Position + Vector3.new(0, 3, 0))
			end
		end)
	end,
	disable = function(s)
		if s.conn then s.conn:Disconnect(); s.conn = nil end
	end,
}

feature{
	tab = "Player", name = "Spectate",
	desc = "Camera follows another player · click to cycle",
	options = { { type = "mode", name = "Target", values = { "None" }, index = 1 } },
	enable = function(s)
		s.conn = RunService.RenderStepped:Connect(function()
			local target = s.Target
			if not target or target == "None" then return end
			local plr = Players:FindFirstChild(target)
			local cam = getCam()
			if plr and cam then
				local r = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
				if r then cam.CFrame = CFrame.new(r.Position + Vector3.new(0, 4, 12), r.Position) end
			end
		end)
	end,
	disable = function(s)
		if s.conn then s.conn:Disconnect(); s.conn = nil end
	end,
}

-- ============================================================
-- FEATURES — CHARACTER
-- ============================================================
feature{
	tab = "Character", name = "Scale",
	desc = "Resize your whole character",
	options = { { type = "slider", name = "Size", min = 1, max = 20, value = 5 } },
	enable = function(s)
		local h = getHum()
		if h then
			h.BodyDepthScale.Value = s.Size / 5
			h.BodyHeightScale.Value = s.Size / 5
			h.BodyWidthScale.Value = s.Size / 5
		end
	end,
	disable = function()
		local h = getHum()
		if h then h.BodyDepthScale.Value = 1; h.BodyHeightScale.Value = 1; h.BodyWidthScale.Value = 1 end
	end,
	onOption = function(s, n, v)
		if n == "Size" then
			local h = getHum()
			if h then h.BodyDepthScale.Value = v / 5; h.BodyHeightScale.Value = v / 5; h.BodyWidthScale.Value = v / 5 end
		end
	end,
}

feature{
	tab = "Character", name = "Rainbow Character",
	desc = "Cycle your character through rainbow colors",
	enable = function(s)
		s.conn = RunService.Heartbeat:Connect(function()
			local c = getChar(); if not c then return end
			local hue = (tick() * 0.4) % 1
			local col = Color3.fromHSV(hue, 0.8, 1)
			for _, p in ipairs(c:GetDescendants()) do
				if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
					p.Color = col
				end
			end
		end)
	end,
	disable = function(s)
		if s.conn then s.conn:Disconnect(); s.conn = nil end
	end,
}

feature{
	tab = "Character", name = "Spin",
	desc = "Spin your character on the spot",
	options = { { type = "slider", name = "Speed", min = 1, max = 60, value = 15 } },
	enable = function(s)
		s.conn = RunService.Heartbeat:Connect(function()
			local r = getRoot(); if not r then return end
			r.CFrame = r.CFrame * CFrame.Angles(0, math.rad(s.Speed), 0)
		end)
	end,
	disable = function(s)
		if s.conn then s.conn:Disconnect(); s.conn = nil end
	end,
}

feature{
	tab = "Character", name = "Invisible",
	desc = "Hide your character locally",
	enable = function(s)
		s.conn = RunService.Stepped:Connect(function()
			local c = getChar(); if not c then return end
			for _, p in ipairs(c:GetDescendants()) do
				if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
					p.Transparency = 1
					p.CanCollide = false
				elseif p:IsA("Decal") then
					p.Transparency = 1
				end
			end
		end)
	end,
	disable = function(s)
		if s.conn then s.conn:Disconnect(); s.conn = nil end
		local c = getChar(); if not c then return end
		for _, p in ipairs(c:GetDescendants()) do
			if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
				p.Transparency = 0
				p.CanCollide = true
			elseif p:IsA("Decal") then
				p.Transparency = 0
			end
		end
	end,
}

-- ============================================================
-- FEATURES — MISC
-- ============================================================
feature{
	tab = "Misc", name = "Anti AFK",
	desc = "Stop Roblox from idling you out",
	enable = function(s)
		s.conn = player.Idled:Connect(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end,
	disable = function(s) if s.conn then s.conn:Disconnect(); s.conn = nil end end,
}

feature{
	tab = "Misc", name = "Anti Fling",
	desc = "Block fling attempts on your character",
	enable = function(s)
		s.conn = RunService.Heartbeat:Connect(function()
			local r = getRoot()
			if r and r.Velocity.Magnitude > 500 then r.Velocity = Vector3.zero end
		end)
	end,
	disable = function(s) if s.conn then s.conn:Disconnect(); s.conn = nil end end,
}

feature{
	tab = "Misc", name = "Anti Void",
	desc = "Teleport back up if you fall below the map",
	enable = function(s)
		s.conn = RunService.Heartbeat:Connect(function()
			local r = getRoot()
			if r and r.Position.Y < -100 then r.CFrame = CFrame.new(0, 50, 0) end
		end)
	end,
	disable = function(s) if s.conn then s.conn:Disconnect(); s.conn = nil end end,
}

feature{
	tab = "Misc", name = "Hide GUI",
	desc = "Hide the window (Right Shift brings it back)",
	enable  = function() if UI.gui then UI.gui.Enabled = false end end,
	disable = function() if UI.gui then UI.gui.Enabled = true end end,
}

feature{
	tab = "Misc", name = "Performance Overlay",
	desc = "Show FPS and ping in the top-right corner",
	enable = function(s)
		local sg = Instance.new("ScreenGui")
		sg.Name = "PrestigePerf"; sg.ResetOnSpawn = false
		sg.IgnoreGuiInset = true
		sg.Parent = player:WaitForChild("PlayerGui")

		local box = Instance.new("Frame")
		box.AnchorPoint = Vector2.new(1, 0)
		box.Position = UDim2.new(1, -16, 0, 10)
		box.Size = UDim2.fromOffset(170, 26)
		box.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		box.BackgroundTransparency = 0.4
		box.Parent = sg
		Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)

		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.Font = Enum.Font.Code
		lbl.TextSize = 13
		lbl.TextColor3 = C.accent
		lbl.Text = ""
		lbl.Parent = box

		s.gui, s.frames, s.acc, s.fps = sg, 0, 0, 0
		s.conn = RunService.RenderStepped:Connect(function(dt)
			s.frames += 1
			s.acc += dt
			if s.acc >= 0.5 then
				s.fps = math.floor(s.frames / s.acc + 0.5)
				s.frames, s.acc = 0, 0
			end
			local ok, ping = pcall(function()
				return math.floor(player:GetNetworkPing() * 1000 + 0.5)
			end)
			lbl.Text = string.format("FPS %d  •  PING %s", s.fps, ok and ping or "?")
		end)
	end,
	disable = function(s)
		if s.conn then s.conn:Disconnect(); s.conn = nil end
		if s.gui then s.gui:Destroy(); s.gui = nil end
	end,
}

feature{
	tab = "Misc", name = "Coordinates",
	desc = "Show your position in the top-right corner",
	enable = function(s)
		local sg = Instance.new("ScreenGui")
		sg.Name = "PrestigeCoords"; sg.ResetOnSpawn = false
		sg.IgnoreGuiInset = true
		sg.Parent = player:WaitForChild("PlayerGui")

		local lbl = Instance.new("TextLabel")
		lbl.AnchorPoint = Vector2.new(1, 0)
		lbl.Position = UDim2.new(1, -16, 0, 42)
		lbl.Size = UDim2.fromOffset(170, 22)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.Code
		lbl.TextSize = 12
		lbl.TextColor3 = C.accent
		lbl.TextXAlignment = Enum.TextXAlignment.Right
		lbl.Text = ""
		lbl.Parent = sg

		s.gui = sg
		s.conn = RunService.RenderStepped:Connect(function()
			local r = getRoot()
			if r then
				local p = r.Position
				lbl.Text = string.format("X %.0f  Y %.0f  Z %.0f", p.X, p.Y, p.Z)
			else
				lbl.Text = "X -  Y -  Z -"
			end
		end)
	end,
	disable = function(s)
		if s.conn then s.conn:Disconnect(); s.conn = nil end
		if s.gui then s.gui:Destroy(); s.gui = nil end
	end,
}

feature{
	tab = "Misc", name = "Server Hop",
	desc = "Jump to a different server in this game",
	action = true,
	run = function()
		local ok, result = pcall(function()
			return HttpService:JSONDecode(game:HttpGet(
				"https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
			))
		end)
		if not ok or not result or not result.data then
			notify("Could not fetch server list", "error"); return
		end
		local target
		for _, srv in ipairs(result.data) do
			if srv.id ~= game.JobId and srv.playing < srv.maxPlayers then
				target = srv.id; break
			end
		end
		if target then
			notify("Hopping servers...", "info")
			TeleportService:TeleportToPlaceInstance(game.PlaceId, target, player)
		else
			notify("No open servers found", "warning")
		end
	end,
}

feature{
	tab = "Misc", name = "Rejoin",
	desc = "Teleport back into this server",
	action = true,
	run = function()
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
	end,
}

feature{
	tab = "Misc", name = "Copy Job ID",
	desc = "Copy this server's JobId to the clipboard",
	action = true,
	run = function()
		if setclipboard then
			setclipboard(game.JobId)
			notify("JobId copied to clipboard", "success")
		else
			notify("JobId: " .. game.JobId, "info", 6)
		end
	end,
}

feature{
	tab = "Misc", name = "Reset Character",
	desc = "Kill your own character",
	action = true,
	run = function()
		local h = getHum()
		if h then h.Health = 0 end
	end,
}

feature{
	tab = "Misc", name = "Test Notification",
	desc = "Fire a sample notification (kind picker below)",
	action = true,
	options = {
		{ type = "mode", name = "Kind", values = { "info", "success", "warning", "error" }, index = 1 },
	},
	run = function(s)
		local kind = s.Kind or "info"
		notify("This is a " .. kind .. " notification. Custom-styled, no Roblox UI.", kind, 4)
	end,
}

-- ============================================================
-- FEATURES — SETTINGS
-- ============================================================
feature{
	tab = "Settings", name = "Window Opacity",
	desc = "How see-through the window is",
	options = { { type = "slider", name = "Transparency", min = 0, max = 100, value = 4 } },
	enable = function(s)
		if UI.main then UI.main.BackgroundTransparency = s.Transparency / 100 end
	end,
	disable = function() if UI.main then UI.main.BackgroundTransparency = 0.04 end end,
	onOption = function(_, n, v)
		if n == "Transparency" and UI.main then
			UI.main.BackgroundTransparency = v / 100
		end
	end,
}

feature{
	tab = "Settings", name = "Notifications",
	desc = "Enable or disable custom notification popups",
	enable  = function() Notifications.enabled = true end,
	disable = function() Notifications.enabled = false end,
}

-- ============================================================
-- FEATURES — THEME
-- ============================================================
local function recolorAccent(oldA, newA)
	if not UI.gui then return end
	for _, d in ipairs(UI.gui:GetDescendants()) do
		pcall(function()
			if d:IsA("GuiObject") then
				if d.BackgroundColor3 == oldA then d.BackgroundColor3 = newA end
			end
			if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
				if d.TextColor3 == oldA then d.TextColor3 = newA end
			end
			if d:IsA("UIStroke") then
				if d.Color == oldA then d.Color = newA end
			end
		end)
	end
end

feature{
	tab = "Theme", name = "Accent Color",
	desc = "Change the UI accent · click the swatch to cycle",
	control = true,
	options = { { type = "color", name = "Color", value = ORIGINAL_ACCENT } },
	onOption = function(_, n, v)
		if n == "Color" then
			local old = C.accent
			C.accent = v
			recolorAccent(old, v)
		end
	end,
}

feature{
	tab = "Theme", name = "Reset Theme",
	desc = "Restore the original violet theme",
	action = true,
	run = function()
		local old = C.accent
		C.accent = ORIGINAL_ACCENT
		recolorAccent(old, ORIGINAL_ACCENT)
		notify("Theme reset to Violet", "success")
	end,
}

local PRESETS = {
	{ name = "Violet",  c = Color3.fromRGB(139, 125, 255) },
	{ name = "Crimson", c = Color3.fromRGB(255, 80, 100) },
	{ name = "Emerald", c = Color3.fromRGB(60, 220, 130) },
	{ name = "Ocean",   c = Color3.fromRGB(60, 170, 255) },
	{ name = "Sunset",  c = Color3.fromRGB(255, 150, 60) },
	{ name = "Rose",    c = Color3.fromRGB(255, 105, 180) },
	{ name = "Mono",    c = Color3.fromRGB(200, 200, 210) },
}

for _, p in ipairs(PRESETS) do
	feature{
		tab = "Theme", name = p.name .. " Preset",
		desc = "Apply the " .. p.name .. " theme",
		action = true,
		run = function()
			local old = C.accent
			C.accent = p.c
			recolorAccent(old, p.c)
			notify(p.name .. " theme applied", "success")
		end,
	}
end

-- ============================================================
-- FEATURES — CONFIGS
-- ============================================================
local function collectConfig()
	local out = {}
	for _, f in ipairs(Features) do
		local entry = { enabled = f.enabled, options = {} }
		for _, o in ipairs(f.options) do
			if typeof(o.value) == "Color3" then
				entry.options[o.name] = { o.value.R, o.value.G, o.value.B }
			else
				entry.options[o.name] = o.value
			end
		end
		out[f.name] = entry
	end
	return out
end

local function applyConfig(cfg)
	for _, f in ipairs(Features) do
		local e = cfg[f.name]
		if type(e) ~= "table" then continue end
		for _, o in ipairs(f.options) do
			local v = e.options and e.options[o.name]
			if typeof(v) == "table" and v[1] then
				o.value = Color3.new(v[1], v[2], v[3])
				f.state[o.name] = o.value
			elseif v ~= nil then
				o.value = v
				f.state[o.name] = v
			end
			if f.onOption then pcall(f.onOption, f.state, o.name, o.value, o) end
		end
		if e.enabled ~= nil and e.enabled ~= f.enabled then
			setEnabled(f, e.enabled)
		end
	end
end

feature{
	tab = "Configs", name = "Save Config",
	desc = "Write your setup to prestige_config.json",
	action = true,
	run = function()
		if not writefile then notify("writefile unavailable here", "error"); return end
		writefile("prestige_config.json", HttpService:JSONEncode(collectConfig()))
		notify("Config saved", "success")
	end,
}

feature{
	tab = "Configs", name = "Load Config",
	desc = "Read prestige_config.json and apply it",
	action = true,
	run = function()
		if not (isfile and readfile) then notify("readfile unavailable here", "error"); return end
		if not isfile("prestige_config.json") then notify("No saved config", "warning"); return end
		local ok, cfg = pcall(function()
			return HttpService:JSONDecode(readfile("prestige_config.json"))
		end)
		if not ok then notify("Corrupt config file", "error"); return end
		applyConfig(cfg)
		if UI.rebuild then UI.rebuild() end
		notify("Config loaded", "success")
	end,
}

-- ============================================================
-- HELPERS
-- ============================================================
local connections = {}
local function track(conn) table.insert(connections, conn); return conn end

local function create(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do inst[k] = v end
	inst.Parent = parent
	return inst
end

local function round(parent, r)
	return create("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end

local function stroke(parent, color, thickness)
	return create("UIStroke", {
		Color = color, Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function label(parent, props)
	local base = {
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextColor3 = C.text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for k, v in pairs(props) do base[k] = v end
	return create("TextLabel", base, parent)
end

local switchInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function createSwitch(parent, position, state, onChange, w, h)
	w, h = w or 44, h or 22
	local k = h - 6
	local track = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = position,
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = state and C.accent or C.offBg,
		AutoButtonColor = false, Text = "",
	}, parent)
	round(track, h / 2)
	local trackStroke = stroke(track, state and C.accent or C.stroke, 1)
	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = state and UDim2.new(1, -(k + 3), 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(k, k),
		BackgroundColor3 = C.knobOff,
	}, track)
	round(knob, k / 2)

	local function render(animate)
		local t  = { BackgroundColor3 = state and C.accent or C.offBg }
		local kn = { Position = state and UDim2.new(1, -(k + 3), 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }
		local s  = { Color = state and C.accent or C.stroke }
		if animate then
			TweenService:Create(track, switchInfo, t):Play()
			TweenService:Create(knob, switchInfo, kn):Play()
			TweenService:Create(trackStroke, switchInfo, s):Play()
		else
			track.BackgroundColor3 = t.BackgroundColor3
			knob.Position = kn.Position
			trackStroke.Color = s.Color
		end
	end

	track.MouseButton1Click:Connect(function()
		state = not state
		render(true)
		if onChange then onChange(state) end
	end)
	return track
end

-- ============================================================
-- WINDOW
-- ============================================================
local gui = create("ScreenGui", {
	Name = "ModulesUI", ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))
UI.gui = gui

local main = create("Frame", {
	Size = UDim2.fromOffset(840, 560),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.04,
}, gui)
UI.main = main
round(main, 20)
stroke(main, C.stroke, 1)
create("UIGradient", { Color = ColorSequence.new(C.bg, C.bg2), Rotation = 60 }, main)

local dragStrip = create("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1 }, main)

local function windowButton(x, color, glyph)
	local b = create("TextButton", {
		Position = UDim2.fromOffset(x, 12),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(20, 20, 40),
		Text = glyph,
		ZIndex = 10,
	}, main)
	round(b, 8)
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = 0.25 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = 0 }):Play()
	end)
	return b
end

local closeBtn = windowButton(16, Color3.fromRGB(255, 95, 110), "×")
local hideBtn  = windowButton(38, Color3.fromRGB(255, 189, 80), "–")

closeBtn.MouseButton1Click:Connect(function()
	for _, c in ipairs(connections) do c:Disconnect() end
	ESP.stop()
	gui:Destroy()
end)

hideBtn.MouseButton1Click:Connect(function() main.Visible = false end)

track(UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == TOGGLE_KEY then
		gui.Enabled = true
		main.Visible = not main.Visible
	end
end))

-- ============================================================
-- SIDEBAR
-- ============================================================
local sidebar = create("Frame", {
	Position = UDim2.fromOffset(12, 38),
	Size = UDim2.new(0, 200, 1, -50),
	BackgroundColor3 = C.sidebar,
	BackgroundTransparency = 0.2,
}, main)
round(sidebar, 14)
stroke(sidebar, C.stroke, 1)

label(sidebar, {
	Position = UDim2.fromOffset(18, 18),
	Size = UDim2.fromOffset(18, 20),
	TextSize = 15,
	TextColor3 = C.accent,
	TextXAlignment = Enum.TextXAlignment.Center,
	Text = "♛",
})
label(sidebar, {
	Position = UDim2.fromOffset(42, 14),
	Size = UDim2.new(1, -50, 0, 20),
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	RichText = true,
	Text = string.format('%s <i><font color="rgb(139,125,255)">%s</font></i>', TITLE, TITLE_ACCENT),
})
label(sidebar, {
	Position = UDim2.fromOffset(42, 34),
	Size = UDim2.new(1, -50, 0, 12),
	TextSize = 9, TextColor3 = C.muted,
	Text = SUBTITLE,
})

create("Frame", {
	Position = UDim2.fromOffset(14, 60),
	Size = UDim2.new(1, -28, 0, 1),
	BackgroundColor3 = C.stroke,
	BorderSizePixel = 0,
}, sidebar)

local sideBody = create("ScrollingFrame", {
	Position = UDim2.fromOffset(0, 70),
	Size = UDim2.new(1, 0, 1, -80),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, sidebar)
create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, sideBody)

local function sectionHeader(text, order)
	local f = create("Frame", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1, LayoutOrder = order,
	}, sideBody)
	label(f, {
		Position = UDim2.fromOffset(18, 4),
		Size = UDim2.new(1, -18, 1, -4),
		Font = Enum.Font.GothamMedium, TextSize = 10,
		TextColor3 = C.muted, Text = text,
	})
end

local function sectionContainer(order)
	local f = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, LayoutOrder = order,
	}, sideBody)
	create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, f)
	create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, f)
	return f
end

sectionHeader("MODULES", 1)
local modulesTabs = sectionContainer(2)
sectionHeader("GENERAL", 3)
local generalTabs = sectionContainer(4)

-- ============================================================
-- CONTENT AREA
-- ============================================================
local content = create("Frame", {
	Position = UDim2.fromOffset(232, 0),
	Size = UDim2.new(1, -256, 1, 0),
	BackgroundTransparency = 1,
}, main)

local pageTitle = label(content, {
	Position = UDim2.fromOffset(0, 20),
	Size = UDim2.new(0.6, 0, 0, 30),
	Font = Enum.Font.GothamBold, TextSize = 24,
	RichText = true, Text = "",
})
local counter = label(content, {
	Position = UDim2.fromOffset(0, 52),
	Size = UDim2.new(0.6, 0, 0, 14),
	TextSize = 11, TextColor3 = C.muted, Text = "",
})

local searchBox = create("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 20),
	Size = UDim2.fromOffset(240, 34),
	BackgroundColor3 = C.row,
}, content)
round(searchBox, 10)
stroke(searchBox, C.stroke, 1)
label(searchBox, {
	Position = UDim2.fromOffset(10, 0),
	Size = UDim2.fromOffset(18, 34),
	TextSize = 16, TextColor3 = C.muted,
	TextXAlignment = Enum.TextXAlignment.Center,
	Text = "⌕",
})
local search = create("TextBox", {
	Position = UDim2.fromOffset(34, 0),
	Size = UDim2.new(1, -44, 1, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham, TextSize = 12,
	TextColor3 = C.text,
	PlaceholderText = "Search modules",
	PlaceholderColor3 = C.muted,
	TextXAlignment = Enum.TextXAlignment.Left,
	ClearTextOnFocus = false, Text = "",
}, searchBox)

local chip = create("TextLabel", {
	Position = UDim2.fromOffset(0, 82),
	Size = UDim2.fromOffset(#CHIP_TEXT * 8 + 28, 26),
	BackgroundColor3 = C.row,
	Font = Enum.Font.GothamMedium, TextSize = 11,
	TextColor3 = C.text, Text = CHIP_TEXT,
}, content)
round(chip, 8)
stroke(chip, C.stroke, 1)

-- ============================================================
-- OPTION WIDGETS
-- ============================================================
local function createSlider(parent, f, opt, order)
	local row = create("Frame", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1, LayoutOrder = order,
	}, parent)
	label(row, { Size = UDim2.new(0.4, 0, 1, 0), TextSize = 12, Text = opt.name })
	local valueLabel = label(row, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(38, 28),
		TextSize = 11, TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = tostring(opt.value),
	})
	local trackBar = create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -48, 0.5, 0),
		Size = UDim2.fromOffset(170, 6),
		BackgroundColor3 = C.offBg,
	}, row)
	round(trackBar, 3); stroke(trackBar, C.stroke, 1)
	local span = math.max(opt.max - opt.min, 1)
	local fill = create("Frame", {
		Size = UDim2.new((opt.value - opt.min) / span, 0, 1, 0),
		BackgroundColor3 = C.accent,
	}, trackBar)
	round(fill, 3)
	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = C.knobOff,
	}, fill)
	round(knob, 6)

	local hit = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -48, 0.5, 0),
		Size = UDim2.fromOffset(170, 24),
		BackgroundTransparency = 1, Text = "",
	}, row)

	local function setFromX(x)
		local rel = math.clamp((x - trackBar.AbsolutePosition.X) / trackBar.AbsoluteSize.X, 0, 1)
		local v = math.floor(opt.min + rel * span + 0.5)
		if v == opt.value then return end
		fill.Size = UDim2.new((v - opt.min) / span, 0, 1, 0)
		valueLabel.Text = tostring(v)
		setOption(f, opt, v)
	end

	hit.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then return end
		setFromX(input.Position.X)
		local moveConn, endConn
		moveConn = UserInputService.InputChanged:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement
				or i.UserInputType == Enum.UserInputType.Touch then
				setFromX(i.Position.X)
			end
		end)
		endConn = UserInputService.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1
				or i.UserInputType == Enum.UserInputType.Touch then
				moveConn:Disconnect(); endConn:Disconnect()
			end
		end)
	end)
end

local function createToggleOption(parent, f, opt, order)
	local row = create("Frame", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1, LayoutOrder = order,
	}, parent)
	label(row, { Size = UDim2.new(0.5, 0, 1, 0), TextSize = 12, Text = opt.name })
	createSwitch(row, UDim2.new(1, 0, 0.5, 0), opt.value, function(on)
		setOption(f, opt, on)
	end, 36, 18)
end

local function createModeOption(parent, f, opt, order)
	local row = create("Frame", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1, LayoutOrder = order,
	}, parent)
	label(row, { Size = UDim2.new(0.5, 0, 1, 0), TextSize = 12, Text = opt.name })
	local btn = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(120, 24),
		BackgroundColor3 = C.offBg,
		AutoButtonColor = false,
		Font = Enum.Font.GothamMedium, TextSize = 11,
		TextColor3 = C.text,
		Text = opt.values[opt.index] .. "  ▾",
	}, row)
	round(btn, 8); stroke(btn, C.stroke, 1)
	btn.MouseButton1Click:Connect(function()
		opt.index = opt.index % #opt.values + 1
		btn.Text = opt.values[opt.index] .. "  ▾"
		setOption(f, opt, opt.values[opt.index])
	end)
end

local PALETTE = {
	Color3.fromRGB(139, 125, 255), Color3.fromRGB(255, 95, 110),
	Color3.fromRGB(255, 189, 80), Color3.fromRGB(0, 255, 100),
	Color3.fromRGB(0, 200, 255), Color3.fromRGB(255, 100, 255),
	Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 150),
	Color3.fromRGB(0, 0, 0), Color3.fromRGB(255, 255, 0),
	Color3.fromRGB(255, 130, 0), Color3.fromRGB(100, 255, 200),
}

local function createColorOption(parent, f, opt, order)
	local row = create("Frame", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1, LayoutOrder = order,
	}, parent)
	label(row, { Size = UDim2.new(0.5, 0, 1, 0), TextSize = 12, Text = opt.name })

	local swatch = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(90, 22),
		BackgroundColor3 = opt.value,
		AutoButtonColor = false, Text = "",
	}, row)
	round(swatch, 7); stroke(swatch, C.stroke, 1)

	local idx = 1
	for i, c in ipairs(PALETTE) do
		if c == opt.value then idx = i; break end
	end
	swatch.MouseButton1Click:Connect(function()
		idx = idx % #PALETTE + 1
		swatch.BackgroundColor3 = PALETTE[idx]
		setOption(f, opt, PALETTE[idx])
	end)
end

-- ============================================================
-- MODULE LIST
-- ============================================================
local list = create("ScrollingFrame", {
	Position = UDim2.fromOffset(0, 124),
	Size = UDim2.new(1, 0, 1, -140),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = C.stroke,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, content)
create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
create("UIPadding", { PaddingRight = UDim.new(0, 6) }, list)

local currentTab
local rows = {}

local function updateCounter()
	if not currentTab then return end
	local n = 0
	for _, f in ipairs(currentTab.features) do
		if f.enabled then n += 1 end
	end
	counter.Text = string.format("%d modules · %d enabled", #currentTab.features, n)
end

local ROW_H = 58
local expandInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function makeRow(index, f)
	local opts = f.options
	local hasOpts = #opts > 0
	local panelH = #opts * 28 + math.max(#opts - 1, 0) * 6 + 20
	local collapsedH = ROW_H + 2
	local expandedH = collapsedH + 6 + panelH + 2

	local wrapper = create("Frame", {
		Size = UDim2.new(1, 0, 0, collapsedH),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		LayoutOrder = index,
	}, list)

	local row = create("Frame", {
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 0, ROW_H),
		BackgroundColor3 = C.row,
		BackgroundTransparency = 0.15,
	}, wrapper)
	round(row, 12); stroke(row, C.stroke, 1)

	label(row, {
		Position = UDim2.fromOffset(18, 11),
		Size = UDim2.new(1, -150, 0, 18),
		Font = Enum.Font.GothamBold, TextSize = 13,
		Text = f.name,
	})
	label(row, {
		Position = UDim2.fromOffset(18, 31),
		Size = UDim2.new(1, -150, 0, 14),
		TextSize = 10, TextColor3 = C.muted,
		Text = f.desc or "",
	})

	if hasOpts then
		local arrow = create("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -72, 0.5, 0),
			Size = UDim2.fromOffset(34, 34),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Font = Enum.Font.GothamBold, TextSize = 20,
			TextColor3 = C.muted, Text = "›",
		}, row)
		local open = false
		arrow.MouseButton1Click:Connect(function()
			open = not open
			TweenService:Create(wrapper, expandInfo, {
				Size = UDim2.new(1, 0, 0, open and expandedH or collapsedH),
			}):Play()
			TweenService:Create(arrow, expandInfo, { Rotation = open and 90 or 0 }):Play()
			arrow.TextColor3 = open and C.accent or C.muted
		end)
	end

	if f.action then
		local runBtn = create("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -18, 0.5, 0),
			Size = UDim2.fromOffset(64, 28),
			BackgroundColor3 = C.accent,
			AutoButtonColor = false,
			Font = Enum.Font.GothamBold, TextSize = 12,
			TextColor3 = Color3.new(1, 1, 1), Text = "Run",
		}, row)
		round(runBtn, 9)
		runBtn.MouseButton1Click:Connect(function()
			if f.run then
				local ok, err = pcall(f.run, f.state)
				if not ok then warn("[Prestige] " .. f.name .. ": " .. tostring(err)) end
			end
		end)
	elseif f.control then
		-- control features don't get a switch
	else
		createSwitch(row, UDim2.new(1, -18, 0.5, 0), f.enabled, function(on)
			setEnabled(f, on); updateCounter()
		end)
	end

	if hasOpts then
		local panel = create("Frame", {
			Position = UDim2.fromOffset(1, collapsedH + 6),
			Size = UDim2.new(1, -2, 0, panelH),
			BackgroundColor3 = C.row,
			BackgroundTransparency = 0.15,
		}, wrapper)
		round(panel, 12); stroke(panel, C.stroke, 1)
		create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, panel)
		create("UIPadding", {
			PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18),
		}, panel)

		for i, opt in ipairs(opts) do
			if opt.type == "slider" then createSlider(panel, f, opt, i)
			elseif opt.type == "toggle" then createToggleOption(panel, f, opt, i)
			elseif opt.type == "mode" then createModeOption(panel, f, opt, i)
			elseif opt.type == "color" then createColorOption(panel, f, opt, i) end
		end
	end

	rows[index] = wrapper
end

local function applySearch()
	if not currentTab then return end
	local q = string.lower(search.Text)
	for i, f in ipairs(currentTab.features) do
		if rows[i] then
			rows[i].Visible = q == "" or string.find(string.lower(f.name), q, 1, true) ~= nil
		end
	end
end

search:GetPropertyChangedSignal("Text"):Connect(applySearch)

-- ============================================================
-- TABS
-- ============================================================
local tabDefs = {
	{ section = "MODULES", name = "Movement",  icon = "◆" },
	{ section = "MODULES", name = "Visual",    icon = "◆" },
	{ section = "MODULES", name = "World",     icon = "◆" },
	{ section = "MODULES", name = "Player",    icon = "◆" },
	{ section = "MODULES", name = "Character", icon = "◆" },
	{ section = "MODULES", name = "Misc",      icon = "◆" },
	{ section = "GENERAL", name = "Settings",  icon = "●" },
	{ section = "GENERAL", name = "Theme",     icon = "●" },
	{ section = "GENERAL", name = "Configs",   icon = "●" },
}

for _, t in ipairs(tabDefs) do
	t.features = {}
	for _, f in ipairs(Features) do
		if f.tab == t.name then table.insert(t.features, f) end
	end
end

local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function styleTab(tab, active)
	TweenService:Create(tab.button, tweenInfo, {
		BackgroundTransparency = active and 0.7 or 1,
	}):Play()
	TweenService:Create(tab.stroke, tweenInfo, {
		Transparency = active and 0.2 or 1,
	}):Play()
	tab.nameLabel.TextColor3 = active and C.text or C.muted
	tab.iconLabel.TextColor3 = active and C.accent or C.muted
end

local function selectTab(tab)
	if currentTab == tab then return end
	if currentTab then styleTab(currentTab, false) end
	currentTab = tab
	styleTab(tab, true)

	for _, r in pairs(rows) do r:Destroy() end
	rows = {}
	list.CanvasPosition = Vector2.new(0, 0)

	pageTitle.Text = string.format('<i><font color="rgb(139,125,255)">%s</font></i> Modules', tab.name)
	for i, f in ipairs(tab.features) do makeRow(i, f) end
	updateCounter()
	applySearch()
end

UI.rebuild = function()
	if not currentTab then return end
	local t = currentTab
	currentTab = nil
	selectTab(t)
end

local orderCount = { MODULES = 0, GENERAL = 0 }
for _, tab in ipairs(tabDefs) do
	local parent = tab.section == "GENERAL" and generalTabs or modulesTabs
	orderCount[tab.section] += 1

	local b = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = C.accent,
		BackgroundTransparency = 1,
		AutoButtonColor = false, Text = "",
		LayoutOrder = orderCount[tab.section],
	}, parent)
	round(b, 9)
	tab.button = b
	tab.stroke = stroke(b, C.accent, 1)
	tab.stroke.Transparency = 1

	tab.iconLabel = label(b, {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.fromOffset(18, 32),
		TextSize = 11, TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = tab.icon,
	})
	tab.nameLabel = label(b, {
		Position = UDim2.fromOffset(36, 0),
		Size = UDim2.new(1, -80, 1, 0),
		Font = Enum.Font.GothamMedium, TextSize = 13,
		TextColor3 = C.muted, Text = tab.name,
	})
	label(b, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 0),
		Size = UDim2.fromOffset(30, 32),
		TextSize = 10, TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = tostring(#tab.features),
	})

	b.MouseButton1Click:Connect(function() selectTab(tab) end)
	b.MouseEnter:Connect(function()
		if currentTab ~= tab then
			TweenService:Create(b, tweenInfo, { BackgroundTransparency = 0.88 }):Play()
		end
	end)
	b.MouseLeave:Connect(function()
		if currentTab ~= tab then
			TweenService:Create(b, tweenInfo, { BackgroundTransparency = 1 }):Play()
		end
	end)
end

selectTab(tabDefs[2]) -- start on Visual so ESP is visible first

-- ============================================================
-- RESPAWN HANDLING
-- ============================================================
player.CharacterAdded:Connect(function()
	task.wait(0.6)
	for _, f in ipairs(Features) do
		if f.enabled then
			if f.disable then pcall(f.disable, f.state) end
			if f.enable  then pcall(f.enable,  f.state) end
		end
	end
end)

-- ============================================================
-- DRAGGING
-- ============================================================
local dragging, dragStart, startPos
dragStrip.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging, dragStart, startPos = true, input.Position, main.Position
	end
end)

track(UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then
		local d = input.Position - dragStart
		main.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + d.X,
			startPos.Y.Scale, startPos.Y.Offset + d.Y
		)
	end
end))

track(UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end))

-- welcome notification
task.delay(1, function()
	notify("Welcome to Prestige Alpha — press Right Shift to toggle", "info", 5)
end)