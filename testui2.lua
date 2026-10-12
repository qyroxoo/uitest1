--[[
	Prestige Alpha — universal client utility framework
	LocalScript in StarterPlayer > StarterPlayerScripts
	Right Shift = show / hide the window

	Everything in here only touches YOUR OWN client:
	your character, your camera, your Lighting, your screen.
	There is deliberately no aimbot / ESP / target-selection code.
]]

---------------------------------------------------------------------
-- SERVICES
---------------------------------------------------------------------
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Lighting         = game:GetService("Lighting")
local Workspace        = game:GetService("Workspace")
local TeleportService  = game:GetService("TeleportService")
local StarterGui       = game:GetService("StarterGui")
local HttpService      = game:GetService("HttpService")

local player = Players.LocalPlayer

---------------------------------------------------------------------
-- CONFIG
---------------------------------------------------------------------
local TITLE        = "Prestige"
local TITLE_ACCENT = "Alpha"
local SUBTITLE     = "ALPHA RELEASE 5.0.0"
local CHIP_TEXT    = "All"
local TOGGLE_KEY   = Enum.KeyCode.RightShift

local C = {
	bg      = Color3.fromRGB(9, 10, 36),
	bg2     = Color3.fromRGB(6, 7, 26),
	sidebar = Color3.fromRGB(13, 14, 44),
	row     = Color3.fromRGB(14, 16, 50),
	stroke  = Color3.fromRGB(32, 36, 82),
	text    = Color3.fromRGB(245, 245, 255),
	muted   = Color3.fromRGB(110, 115, 165),
	accent  = Color3.fromRGB(139, 125, 255),
	offBg   = Color3.fromRGB(9, 10, 32),
	knobOff = Color3.fromRGB(235, 235, 245),
}

-- forward declaration: features need to poke the window, the window
-- is built further down.
local UI = {}

---------------------------------------------------------------------
-- CHARACTER HELPERS
---------------------------------------------------------------------
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

---------------------------------------------------------------------
-- FEATURE REGISTRY
---------------------------------------------------------------------
local Features = {}

local function feature(def)
	def.options = def.options or {}
	def.state   = {}
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
			StarterGui:SetCore("SendNotification", {
				Title = "Prestige", Text = f.name .. " failed: " .. tostring(err), Duration = 4,
			})
		end
	end
end

---------------------------------------------------------------------
-- FEATURES — MOVEMENT
---------------------------------------------------------------------
feature{
	tab = "Movement", name = "Walkspeed",
	desc = "Set your character's movement speed",
	options = { { type = "slider", name = "Speed", min = 8, max = 250, value = 16 } },
	enable  = function(s) local h = getHum(); if h then h.WalkSpeed = s.Speed end end,
	disable = function(s) local h = getHum(); if h then h.WalkSpeed = 16 end end,
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
	disable = function(s)
		local h = getHum(); if h then h.JumpPower = 50 end
	end,
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
	disable = function(s)
		if s.conn then s.conn:Disconnect(); s.conn = nil end
	end,
}

feature{
	tab = "Movement", name = "Fly",
	desc = "WASD to move · Space up · Left Ctrl down",
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
			local h = getHum()
			if h then h.PlatformStand = true end
			local cam = getCam()
			if not cam then return end

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
		local h = getHum()
		if h then h.PlatformStand = false end
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
	disable = function(s) local h = getHum(); if h then h.HipHeight = 2 end end,
	onOption = function(s, n, v)
		if n == "Height" then local h = getHum(); if h then h.HipHeight = v end end
	end,
}

feature{
	tab = "Movement", name = "Gravity",
	desc = "Change world gravity for your client",
	options = { { type = "slider", name = "Gravity", min = 0, max = 300, value = 196 } },
	enable = function(s)
		s.old = Workspace.Gravity
		Workspace.Gravity = s.Gravity
	end,
	disable = function(s)
		Workspace.Gravity = s.old or 196
	end,
	onOption = function(s, n, v)
		if n == "Gravity" then Workspace.Gravity = v end
	end,
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

---------------------------------------------------------------------
-- FEATURES — VISUAL
---------------------------------------------------------------------
feature{
	tab = "Visual", name = "Fullbright",
	desc = "Brighten the entire map",
	enable = function(s)
		s.old = {
			Brightness = Lighting.Brightness,
			Ambient = Lighting.Ambient,
			OutdoorAmbient = Lighting.OutdoorAmbient,
			ClockTime = Lighting.ClockTime,
			FogEnd = Lighting.FogEnd,
		}
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
	disable = function(s) local c = getCam(); if c then c.FieldOfView = 70 end end,
	onOption = function(s, n, v)
		if n == "FOV" then local c = getCam(); if c then c.FieldOfView = v end end
	end,
}

feature{
	tab = "Visual", name = "Time of Day",
	desc = "Set the clock time",
	options = { { type = "slider", name = "Hour", min = 0, max = 24, value = 14 } },
	enable = function(s)
		s.old = Lighting.ClockTime
		Lighting.ClockTime = s.Hour
	end,
	disable = function(s) Lighting.ClockTime = s.old or 14 end,
	onOption = function(s, n, v)
		if n == "Hour" then Lighting.ClockTime = v end
	end,
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
		Lighting.FogStart = s.Start
		Lighting.FogEnd = s.End
	end,
	disable = function(s)
		if not s.old then return end
		Lighting.FogStart = s.old[1]
		Lighting.FogEnd = s.old[2]
	end,
	onOption = function(s, n, v)
		if n == "Start" then Lighting.FogStart = v
		elseif n == "End" then Lighting.FogEnd = v end
	end,
}

feature{
	tab = "Visual", name = "Camera Zoom",
	desc = "Max zoom-out distance",
	options = { { type = "slider", name = "Distance", min = 0, max = 500, value = 128 } },
	enable = function(s)
		s.old = player.CameraMaxZoomDistance
		player.CameraMaxZoomDistance = s.Distance
	end,
	disable = function(s) player.CameraMaxZoomDistance = s.old or 128 end,
	onOption = function(s, n, v)
		if n == "Distance" then player.CameraMaxZoomDistance = v end
	end,
}

feature{
	tab = "Visual", name = "Brightness",
	desc = "Lighting brightness",
	options = { { type = "slider", name = "Level", min = 0, max = 10, value = 2 } },
	enable = function(s)
		s.old = Lighting.Brightness
		Lighting.Brightness = s.Level
	end,
	disable = function(s) Lighting.Brightness = s.old or 2 end,
	onOption = function(s, n, v)
		if n == "Level" then Lighting.Brightness = v end
	end,
}

feature{
	tab = "Visual", name = "Ambient Light",
	desc = "Indoor ambient brightness",
	options = { { type = "slider", name = "Level", min = 0, max = 255, value = 70 } },
	enable = function(s)
		s.old = Lighting.Ambient
		Lighting.Ambient = Color3.fromRGB(s.Level, s.Level, s.Level)
	end,
	disable = function(s) Lighting.Ambient = s.old or Color3.fromRGB(70, 70, 70) end,
	onOption = function(s, n, v)
		if n == "Level" then Lighting.Ambient = Color3.fromRGB(v, v, v) end
	end,
}

feature{
	tab = "Visual", name = "Exposure",
	desc = "Exposure compensation",
	options = { { type = "slider", name = "Value", min = -3, max = 3, value = 0 } },
	enable = function(s)
		s.old = Lighting.ExposureCompensation
		Lighting.ExposureCompensation = s.Value
	end,
	disable = function(s) Lighting.ExposureCompensation = s.old or 0 end,
	onOption = function(s, n, v)
		if n == "Value" then Lighting.ExposureCompensation = v end
	end,
}

feature{
	tab = "Visual", name = "Remove Sky",
	desc = "Delete Sky objects from Lighting",
	enable = function(s)
		s.removed = {}
		for _, d in ipairs(Lighting:GetChildren()) do
			if d:IsA("Sky") then
				s.removed[d] = d.Parent
				d.Parent = nil
			end
		end
	end,
	disable = function(s)
		for d, p in pairs(s.removed or {}) do
			if d then d.Parent = p end
		end
		s.removed = nil
	end,
}

feature{
	tab = "Visual", name = "Remove Sun Rays",
	desc = "Delete SunRaysEffect instances",
	enable = function(s)
		s.removed = {}
		for _, d in ipairs(Lighting:GetChildren()) do
			if d:IsA("SunRaysEffect") then
				s.removed[d] = d.Parent
				d.Parent = nil
			end
		end
	end,
	disable = function(s)
		for d, p in pairs(s.removed or {}) do
			if d then d.Parent = p end
		end
		s.removed = nil
	end,
}

---------------------------------------------------------------------
-- FEATURES — WORLD
---------------------------------------------------------------------
feature{
	tab = "World", name = "Remove Blur",
	desc = "Delete BlurEffect instances",
	enable = function(s)
		s.removed = {}
		for _, d in ipairs(Lighting:GetChildren()) do
			if d:IsA("BlurEffect") then
				s.removed[d] = d.Parent
				d.Parent = nil
			end
		end
	end,
	disable = function(s)
		for d, p in pairs(s.removed or {}) do
			if d then d.Parent = p end
		end
		s.removed = nil
	end,
}

feature{
	tab = "World", name = "Disable Shadows",
	desc = "Turn off global shadows",
	enable = function(s)
		s.old = Lighting.GlobalShadows
		Lighting.GlobalShadows = false
	end,
	disable = function(s)
		Lighting.GlobalShadows = s.old ~= false
	end,
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
				s.removed[d] = d.Parent
				d.Parent = nil
			end
		end
	end,
	disable = function(s)
		for d, p in pairs(s.removed or {}) do
			if d then d.Parent = p end
		end
		s.removed = nil
	end,
}

---------------------------------------------------------------------
-- FEATURES — MISC
---------------------------------------------------------------------
feature{
	tab = "Misc", name = "Anti AFK",
	desc = "Stop Roblox from idling you out",
	enable = function(s)
		s.conn = player.Idled:Connect(function()
			local vu = game:GetService("VirtualUser")
			vu:CaptureController()
			vu:ClickButton2(Vector2.new())
		end)
	end,
	disable = function(s)
		if s.conn then s.conn:Disconnect(); s.conn = nil end
	end,
}

feature{
	tab = "Misc", name = "Hide GUI",
	desc = "Hide the window (Right Shift brings it back)",
	enable  = function() if UI.gui then UI.gui.Enabled = false end end,
	disable = function() if UI.gui then UI.gui.Enabled = true end end,
}

feature{
	tab = "Misc", name = "Performance Overlay",
	desc = "Show FPS and ping in the corner",
	enable = function(s)
		local sg = Instance.new("ScreenGui")
		sg.Name = "PrestigePerf"
		sg.ResetOnSpawn = false
		sg.IgnoreGuiInset = true
		sg.Parent = player:WaitForChild("PlayerGui")

		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.Position = UDim2.new(0, 12, 0, 8)
		lbl.Size = UDim2.fromOffset(280, 20)
		lbl.Font = Enum.Font.Code
		lbl.TextSize = 14
		lbl.TextColor3 = C.accent
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Text = ""
		lbl.Parent = sg

		s.gui    = sg
		s.frames = 0
		s.acc    = 0
		s.fps    = 0

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
			lbl.Text = string.format("FPS %d   PING %s ms", s.fps, ok and ping or "?")
		end)
	end,
	disable = function(s)
		if s.conn then s.conn:Disconnect(); s.conn = nil end
		if s.gui then s.gui:Destroy(); s.gui = nil end
	end,
}

feature{
	tab = "Misc", name = "Coordinates",
	desc = "Show your position on screen",
	enable = function(s)
		local sg = Instance.new("ScreenGui")
		sg.Name = "PrestigeCoords"
		sg.ResetOnSpawn = false
		sg.IgnoreGuiInset = true
		sg.Parent = player:WaitForChild("PlayerGui")

		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.Position = UDim2.new(0, 12, 0, 28)
		lbl.Size = UDim2.fromOffset(280, 20)
		lbl.Font = Enum.Font.Code
		lbl.TextSize = 14
		lbl.TextColor3 = C.accent
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Text = ""
		lbl.Parent = sg

		s.gui = sg
		s.conn = RunService.RenderStepped:Connect(function()
			local r = getRoot()
			if r then
				local p = r.Position
				lbl.Text = string.format("X %.0f   Y %.0f   Z %.0f", p.X, p.Y, p.Z)
			else
				lbl.Text = "X -   Y -   Z -"
			end
		end)
	end,
	disable = function(s)
		if s.conn then s.conn:Disconnect(); s.conn = nil end
		if s.gui then s.gui:Destroy(); s.gui = nil end
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
			StarterGui:SetCore("SendNotification", {
				Title = "Prestige", Text = "JobId copied to clipboard", Duration = 3,
			})
		else
			StarterGui:SetCore("SendNotification", {
				Title = "Prestige", Text = "JobId: " .. game.JobId, Duration = 6,
			})
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
	desc = "Fire a test notification",
	action = true,
	run = function()
		StarterGui:SetCore("SendNotification", {
			Title = "Prestige", Text = "Hello from Prestige Alpha!", Duration = 3,
		})
	end,
}

---------------------------------------------------------------------
-- FEATURES — SETTINGS
---------------------------------------------------------------------
feature{
	tab = "Settings", name = "Window Opacity",
	desc = "How see-through the window is",
	options = { { type = "slider", name = "Transparency", min = 0, max = 100, value = 4 } },
	enable = function(s)
		if UI.main then UI.main.BackgroundTransparency = s.Transparency / 100 end
	end,
	disable = function()
		if UI.main then UI.main.BackgroundTransparency = 0.04 end
	end,
	onOption = function(s, n, v)
		if n == "Transparency" and UI.main then
			UI.main.BackgroundTransparency = v / 100
		end
	end,
}

---------------------------------------------------------------------
-- FEATURES — CONFIGS
---------------------------------------------------------------------
local function collectConfig()
	local out = {}
	for _, f in ipairs(Features) do
		local entry = { enabled = f.enabled, options = {} }
		for _, o in ipairs(f.options) do
			entry.options[o.name] = o.value
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
			if e.options and e.options[o.name] ~= nil then
				o.value = e.options[o.name]
				f.state[o.name] = e.options[o.name]
			end
		end
		if e.enabled ~= nil and e.enabled ~= f.enabled then
			setEnabled(f, e.enabled)
		elseif f.enabled and f.onOption then
			for _, o in ipairs(f.options) do
				pcall(f.onOption, f.state, o.name, o.value, o)
			end
		end
	end
end

feature{
	tab = "Configs", name = "Save Config",
	desc = "Write your current setup to prestige_config.json",
	action = true,
	run = function()
		if not writefile then
			StarterGui:SetCore("SendNotification", {
				Title = "Prestige", Text = "writefile is not available here", Duration = 4,
			})
			return
		end
		writefile("prestige_config.json", HttpService:JSONEncode(collectConfig()))
		StarterGui:SetCore("SendNotification", {
			Title = "Prestige", Text = "Config saved", Duration = 3,
		})
	end,
}

feature{
	tab = "Configs", name = "Load Config",
	desc = "Read prestige_config.json and apply it",
	action = true,
	run = function()
		if not (isfile and readfile) then
			StarterGui:SetCore("SendNotification", {
				Title = "Prestige", Text = "readfile is not available here", Duration = 4,
			})
			return
		end
		if not isfile("prestige_config.json") then
			StarterGui:SetCore("SendNotification", {
				Title = "Prestige", Text = "No saved config found", Duration = 4,
			})
			return
		end
		local ok, cfg = pcall(function()
			return HttpService:JSONDecode(readfile("prestige_config.json"))
		end)
		if not ok then
			StarterGui:SetCore("SendNotification", {
				Title = "Prestige", Text = "Config file is corrupt", Duration = 4,
			})
			return
		end
		applyConfig(cfg)
		if UI.rebuild then UI.rebuild() end
		StarterGui:SetCore("SendNotification", {
			Title = "Prestige", Text = "Config loaded", Duration = 3,
		})
	end,
}

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------
local connections = {}
local function track(conn)
	table.insert(connections, conn)
	return conn
end

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
		BackgroundColor3 = C.offBg,
		AutoButtonColor = false,
		Text = "",
	}, parent)
	round(track, h / 2)
	local trackStroke = stroke(track, C.stroke, 1)
	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
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
	render(false)

	track.MouseButton1Click:Connect(function()
		state = not state
		render(true)
		if onChange then onChange(state) end
	end)
	return track
end

---------------------------------------------------------------------
-- WINDOW
---------------------------------------------------------------------
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
create("UIGradient", {
	Color = ColorSequence.new(C.bg, C.bg2),
	Rotation = 60,
}, main)

local dragStrip = create("Frame", {
	Size = UDim2.new(1, 0, 0, 56),
	BackgroundTransparency = 1,
}, main)

---------------------------------------------------------------------
-- WINDOW BUTTONS
---------------------------------------------------------------------
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
	gui:Destroy()
end)

hideBtn.MouseButton1Click:Connect(function()
	main.Visible = false
end)

track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == TOGGLE_KEY then
		gui.Enabled = true
		main.Visible = not main.Visible
	end
end))

---------------------------------------------------------------------
-- SIDEBAR
---------------------------------------------------------------------
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
	TextSize = 9,
	TextColor3 = C.muted,
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
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, sideBody)
	label(f, {
		Position = UDim2.fromOffset(18, 4),
		Size = UDim2.new(1, -18, 1, -4),
		Font = Enum.Font.GothamMedium,
		TextSize = 10,
		TextColor3 = C.muted,
		Text = text,
	})
end

local function sectionContainer(order)
	local f = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, sideBody)
	create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, f)
	create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, f)
	return f
end

sectionHeader("MODULES", 1)
local modulesTabs = sectionContainer(2)
sectionHeader("GENERAL", 3)
local generalTabs = sectionContainer(4)

---------------------------------------------------------------------
-- CONTENT AREA
---------------------------------------------------------------------
local content = create("Frame", {
	Position = UDim2.fromOffset(232, 0),
	Size = UDim2.new(1, -256, 1, 0),
	BackgroundTransparency = 1,
}, main)

local pageTitle = label(content, {
	Position = UDim2.fromOffset(0, 20),
	Size = UDim2.new(0.6, 0, 0, 30),
	Font = Enum.Font.GothamBold,
	TextSize = 24,
	RichText = true,
	Text = "",
})
local counter = label(content, {
	Position = UDim2.fromOffset(0, 52),
	Size = UDim2.new(0.6, 0, 0, 14),
	TextSize = 11,
	TextColor3 = C.muted,
	Text = "",
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
	TextSize = 16,
	TextColor3 = C.muted,
	TextXAlignment = Enum.TextXAlignment.Center,
	Text = "⌕",
})
local search = create("TextBox", {
	Position = UDim2.fromOffset(34, 0),
	Size = UDim2.new(1, -44, 1, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextColor3 = C.text,
	PlaceholderText = "Search modules",
	PlaceholderColor3 = C.muted,
	TextXAlignment = Enum.TextXAlignment.Left,
	ClearTextOnFocus = false,
	Text = "",
}, searchBox)

local chip = create("TextLabel", {
	Position = UDim2.fromOffset(0, 82),
	Size = UDim2.fromOffset(#CHIP_TEXT * 8 + 28, 26),
	BackgroundColor3 = C.row,
	Font = Enum.Font.GothamMedium,
	TextSize = 11,
	TextColor3 = C.text,
	Text = CHIP_TEXT,
}, content)
round(chip, 8)
stroke(chip, C.stroke, 1)

local function viewButton(xFromRight, glyph, active)
	local b = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -xFromRight, 0, 82),
		Size = UDim2.fromOffset(28, 26),
		BackgroundColor3 = C.row,
		BackgroundTransparency = active and 0 or 1,
		AutoButtonColor = false,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = active and C.text or C.muted,
		Text = glyph,
	}, content)
	round(b, 7)
	return b
end
viewButton(0, "▦", false)
viewButton(34, "☰", true)

---------------------------------------------------------------------
-- OPTION WIDGETS
---------------------------------------------------------------------
local function createSlider(parent, f, opt, order)
	local row = create("Frame", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, parent)
	label(row, { Size = UDim2.new(0.4, 0, 1, 0), TextSize = 12, Text = opt.name })
	local valueLabel = label(row, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(38, 28),
		TextSize = 11,
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = tostring(opt.value),
	})
	local trackBar = create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -48, 0.5, 0),
		Size = UDim2.fromOffset(170, 6),
		BackgroundColor3 = C.offBg,
	}, row)
	round(trackBar, 3)
	stroke(trackBar, C.stroke, 1)

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
		BackgroundTransparency = 1,
		Text = "",
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
				moveConn:Disconnect()
				endConn:Disconnect()
			end
		end)
	end)
end

local function createToggleOption(parent, f, opt, order)
	local row = create("Frame", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, parent)
	label(row, { Size = UDim2.new(0.5, 0, 1, 0), TextSize = 12, Text = opt.name })
	createSwitch(row, UDim2.new(1, 0, 0.5, 0), opt.value, function(on)
		setOption(f, opt, on)
	end, 36, 18)
end

local function createModeOption(parent, f, opt, order)
	local row = create("Frame", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, parent)
	label(row, { Size = UDim2.new(0.5, 0, 1, 0), TextSize = 12, Text = opt.name })
	local btn = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(120, 24),
		BackgroundColor3 = C.offBg,
		AutoButtonColor = false,
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = C.text,
		Text = opt.values[opt.index] .. "  ▾",
	}, row)
	round(btn, 8)
	stroke(btn, C.stroke, 1)
	btn.MouseButton1Click:Connect(function()
		opt.index = opt.index % #opt.values + 1
		btn.Text = opt.values[opt.index] .. "  ▾"
		setOption(f, opt, opt.index)
	end)
end

---------------------------------------------------------------------
-- MODULE LIST
---------------------------------------------------------------------
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
	round(row, 12)
	stroke(row, C.stroke, 1)

	label(row, {
		Position = UDim2.fromOffset(18, 11),
		Size = UDim2.new(1, -150, 0, 18),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		Text = f.name,
	})
	label(row, {
		Position = UDim2.fromOffset(18, 31),
		Size = UDim2.new(1, -150, 0, 14),
		TextSize = 10,
		TextColor3 = C.muted,
		Text = f.desc or "",
	})

	if hasOpts then
		local arrow = create("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -72, 0.5, 0),
			Size = UDim2.fromOffset(34, 34),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Font = Enum.Font.GothamBold,
			TextSize = 20,
			TextColor3 = C.muted,
			Text = "›",
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
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "Run",
		}, row)
		round(runBtn, 9)
		runBtn.MouseButton1Click:Connect(function()
			if f.run then
				local ok, err = pcall(f.run, f.state)
				if not ok then warn("[Prestige] " .. f.name .. ": " .. tostring(err)) end
			end
		end)
	else
		createSwitch(row, UDim2.new(1, -18, 0.5, 0), f.enabled, function(on)
			setEnabled(f, on)
			updateCounter()
		end)
	end

	if hasOpts then
		local panel = create("Frame", {
			Position = UDim2.fromOffset(1, collapsedH + 6),
			Size = UDim2.new(1, -2, 0, panelH),
			BackgroundColor3 = C.row,
			BackgroundTransparency = 0.15,
		}, wrapper)
		round(panel, 12)
		stroke(panel, C.stroke, 1)
		create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, panel)
		create("UIPadding", {
			PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18),
		}, panel)

		for i, opt in ipairs(opts) do
			if opt.type == "slider" then
				createSlider(panel, f, opt, i)
			elseif opt.type == "toggle" then
				createToggleOption(panel, f, opt, i)
			elseif opt.type == "mode" then
				createModeOption(panel, f, opt, i)
			end
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

---------------------------------------------------------------------
-- TABS
---------------------------------------------------------------------
local tabDefs = {
	{ section = "MODULES", name = "Movement", icon = "◆" },
	{ section = "MODULES", name = "Visual",   icon = "◆" },
	{ section = "MODULES", name = "World",    icon = "◆" },
	{ section = "MODULES", name = "Misc",     icon = "◆" },
	{ section = "GENERAL", name = "Settings", icon = "●" },
	{ section = "GENERAL", name = "Configs",  icon = "●" },
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
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = orderCount[tab.section],
	}, parent)
	round(b, 9)
	tab.button = b
	tab.stroke = stroke(b, C.accent, 1)
	tab.stroke.Transparency = 1

	tab.iconLabel = label(b, {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.fromOffset(18, 32),
		TextSize = 11,
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = tab.icon,
	})
	tab.nameLabel = label(b, {
		Position = UDim2.fromOffset(36, 0),
		Size = UDim2.new(1, -80, 1, 0),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = C.muted,
		Text = tab.name,
	})
	label(b, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 0),
		Size = UDim2.fromOffset(30, 32),
		TextSize = 10,
		TextColor3 = C.muted,
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

selectTab(tabDefs[1])

---------------------------------------------------------------------
-- RESPAWN HANDLING
---------------------------------------------------------------------
player.CharacterAdded:Connect(function()
	task.wait(0.6)
	for _, f in ipairs(Features) do
		if f.enabled then
			if f.disable then pcall(f.disable, f.state) end
			if f.enable  then pcall(f.enable,  f.state) end
		end
	end
end)

---------------------------------------------------------------------
-- DRAGGING
---------------------------------------------------------------------
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