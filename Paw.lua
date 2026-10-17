-- Paw (executor-ready) — modern dark UI; paste & run in your executor
-- After running: press Insert to open/close, or use getgenv().PawUI to access the window object.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Library = {}

-- optional icon loader (if executor allows http)
local Lucide
pcall(function()
	Lucide = loadstring(game:HttpGet("https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/icons.lua"))()
end)

local function ResolveIcon(Icon)
	if type(Icon) == "number" then return "rbxassetid://" .. Icon end
	if type(Icon) == "string" then
		if string.match(Icon, "^rbxassetid://") then return Icon end
		if string.match(Icon, "^%d+$") then return "rbxassetid://" .. Icon end
		local Name = string.lower(Icon)
		if type(Lucide) == "function" then
			local ok, Data = pcall(Lucide, Name)
			if ok and type(Data) == "table" then
				local Id = Data.id or Data.Id or Data[1]
				local Size = Data.imageRectSize or Data.ImageRectSize or Data[2]
				local Offset = Data.imageRectOffset or Data.imageRectPosition or Data.ImageRectOffset or Data[3]
				if Id then return "rbxassetid://" .. tostring(Id), Offset, Size end
			end
		elseif type(Lucide) == "table" then
			for _, Set in { Lucide["48px"], Lucide["256px"], Lucide } do
				if type(Set) == "table" then
					local Data = Set[Name]
					if type(Data) == "table" and Data[1] then
						return "rbxassetid://" .. tostring(Data[1]), Data[3], Data[2]
					end
				end
			end
		end
	end
	return "rbxassetid://0"
end

local function ToVector2(Value)
	if typeof(Value) == "Vector2" then return Value end
	if type(Value) == "table" then return Vector2.new(Value[1] or Value.X or 0, Value[2] or Value.Y or 0) end
	return Vector2.new(0, 0)
end

local function ApplyIcon(Object, Icon)
	if not Icon then return end
	local Image, Offset, Size = ResolveIcon(Icon)
	Object.Image = Image
	if Offset then Object.ImageRectOffset = ToVector2(Offset) end
	if Size then Object.ImageRectSize = ToVector2(Size) end
end

-- Modern dark theme palette (executor-ready)
local C = {
	Box = Color3.fromRGB(20, 20, 22),
	Line = Color3.fromRGB(70, 70, 75),
	Off = Color3.fromRGB(140, 140, 145),
	On = Color3.fromRGB(235, 235, 238),
	BoxStroke = Color3.fromRGB(38, 38, 40),
}
local DIM = Color3.fromRGB(110, 110, 115)
local FONT = Enum.Font.GothamMedium
local WHITE = Color3.new(1, 1, 1)
local MB1, TOUCH = Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch
local DESIGN_W, DESIGN_H = 973, 840

local function New(Class, Props, Parent)
	local o = Instance.new(Class)
	for k, v in pairs(Props) do o[k] = v end
	o.Parent = Parent
	return o
end
local function Corner(o, r) return New("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
local function Stroke(o, col, t, tr)
	return New("UIStroke", { Color = col, Thickness = t or 1, Transparency = tr or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function Grad(o, c0, c1, rot, mid)
	local seq = mid and ColorSequence.new({ ColorSequenceKeypoint.new(0, c0), ColorSequenceKeypoint.new(0.5, mid),
		ColorSequenceKeypoint.new(1, c1) }) or ColorSequence.new(c0, c1)
	return New("UIGradient", { Color = seq, Rotation = rot or 0 }, o)
end
local function Text(parent, txt, x, cy, w, size, col, align)
	return New("TextLabel", {
		BackgroundTransparency = 1, Text = txt, Font = FONT, TextSize = size or 22,
		TextColor3 = col or C.Off, TextXAlignment = align or Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(x, cy), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(w or 300, 30),
	}, parent)
end
local function Icon(parent, name, cx, cy, size, col)
	local i = New("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(size, size), ImageColor3 = col or C.Off }, parent)
	ApplyIcon(i, name)
	return i
end
local function Line(parent, x, y, w)
	return New("Frame", { BackgroundColor3 = C.Line, BackgroundTransparency = 0.35, BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 1) }, parent)
end

local Accent = Color3.fromRGB(180, 180, 186)
local Hooks = {}
local function AccentSeq() return ColorSequence.new(Accent:Lerp(WHITE, 0.35), Accent) end
local function OnAccent(obj, fn) table.insert(Hooks, { obj, fn }); fn() end
local function SetAccent(c)
	Accent = c
	for i = #Hooks, 1, -1 do
		local h = Hooks[i]
		if h[1].Parent == nil then table.remove(Hooks, i) else h[2]() end
	end
end

local Root, Scale, Popup, Blocker, Drop, DropBlocker, Listening, ActiveDrag, Notifier, WmOpts
local MenuKey = Enum.KeyCode.Insert
local Folder, AutoFile = "Paw", "Paw/autoload.txt"
local AllScrollers = {}
local Config, Callbacks, Registry, Refreshers = {}, {}, {}, {}
local Presets = {
	Color3.fromRGB(210, 210, 215), Color3.fromRGB(190, 190, 195), Color3.fromRGB(170, 170, 175),
	Color3.fromRGB(150, 150, 155), Color3.fromRGB(130, 130, 135), Color3.fromRGB(110, 110, 115),
	Color3.fromRGB(90, 90, 95),
}
local EaseList = { "Linear", "Sine", "Quad", "Cubic", "Quart", "Quint", "Exponential", "Back", "Bounce", "Elastic" }
local TypeMap = { Slider = "slider", Dropdown = "dropdown", MultiDropdown = "multi", SearchDropdown = "search",
	Keybind = "keybind", ColorPicker = "color", Toggle = "toggle", Input = "input", Button = "button", Label = "label" }

local function Cfg(key)
	if not Config[key] then Config[key] = { enabled = false, options = {}, cbs = {} } end
	return Config[key]
end
local function Call(key, ...)
	local cb = Callbacks[key]
	if cb then task.spawn(cb, ...) end
end
local function Refresh(obj, fn) table.insert(Refreshers, { obj, fn }) end
local function RefreshAll()
	for i = #Refreshers, 1, -1 do
		local r = Refreshers[i]
		if r[1].Parent == nil then table.remove(Refreshers, i) else pcall(r[2]) end
	end
end
local function Register(key, obj, fn)
	Registry[key] = Registry[key] or {}
	table.insert(Registry[key], { obj, fn })
end
local function SetEnabled(key, v)
	Cfg(key).enabled = v
	local r = Registry[key]
	if r then
		for i = #r, 1, -1 do
			if r[i][1].Parent == nil then table.remove(r, i) else r[i][2](v) end
		end
	end
	Call(key, v)
end

local function Tw(t, style, dir)
	local sp = Config["tween speed"]
	sp = sp and tonumber(sp.value) or 100
	local es = style
	if not es then
		local st = Config["easing style"]
		local okE, v = pcall(function() return Enum.EasingStyle[st and st.value or "Quart"] end)
		es = okE and v or Enum.EasingStyle.Quart
	end
	return TweenInfo.new(t / math.max(sp, 10) * 100, es, dir or Enum.EasingDirection.Out)
end

local function Spec(o)
	local t = TypeMap[o.Type]
	local e = { t = t, n = o.Name or (t == "keybind" and "keybind" or nil), min = o.Min, max = o.Max, def = o.Default,
		suf = o.Suffix, step = o.Step, list = o.List, ph = o.Placeholder, col = o.Color }
	if t == "button" then e.cb = o.Callback else e.on = o.Callback end
	return e
end

local function ExtScale() return math.clamp(Scale.Scale * 1.15, 0.5, 0.9) end
local function ViewportSize()
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(1920, 1080)
end
local function SetScrolling(b) for _, s in ipairs(AllScrollers) do s.ScrollingEnabled = b end end
local function KeyName(k) return k and k.Name:lower() or "none" end

local function CloseDrop()
	if Drop then Drop:Destroy(); Drop = nil end
	if DropBlocker then DropBlocker:Destroy(); DropBlocker = nil end
end
local function ClosePopup()
	CloseDrop()
	if Popup then Popup:Destroy(); Popup = nil end
	if Blocker then Blocker:Destroy(); Blocker = nil end
end

local function MakeCheck(parent, label, cx, cy, size, textSize, textX, width, get, set, regKey)
	local box = New("Frame", { BackgroundColor3 = C.Box, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(size, size) }, parent)
	Corner(box, 6)
	local g = New("UIGradient", { Rotation = 45, Enabled = false }, box)
	local chk = Icon(box, "check", size / 2, size / 2, size * 0.72, Color3.fromRGB(35, 22, 36))
	chk.Visible = false
	local lbl = Text(parent, label, textX, cy, width, textSize, C.Off)
	local first = true
	local function apply(v)
		box.BackgroundColor3 = v and WHITE or C.Box
		g.Enabled = v
		g.Color = AccentSeq()
		chk.Visible = v
		local col = v and C.On or C.Off
		if first then lbl.TextColor3 = col
		else TweenService:Create(lbl, Tw(0.15), { TextColor3 = col }):Play() end
	end
	OnAccent(box, function() g.Color = AccentSeq() end)
	if regKey then Register(regKey, box, apply) end
	apply(get())
	first = false
	if not regKey then Refresh(box, function() apply(get()) end) end
	local hit = New("TextButton", { Text = "", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(cx - 4, cy), Size = UDim2.fromOffset(width + (textX - cx), size + 12) }, parent)
	hit.MouseButton1Click:Connect(function()
		set(not get())
		if not regKey then apply(get()) end
	end)
end

local function MakeSlider(parent, x, y, w, e)
	Text(parent, e.n, x, y + 14, w - 160, 21, C.Off)
	local val = Text(parent, "", x + w - 150, y + 14, 150, 21, C.On, Enum.TextXAlignment.Right)
	local track = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.Box, BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, y + 34), Size = UDim2.fromOffset(w, 10) }, parent)
	Corner(track, 5)
	local fill = New("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromScale(0.02, 1) }, track)
	Corner(fill, 5)
	local g = New("UIGradient", {}, fill)
	OnAccent(fill, function() g.Color = AccentSeq() end)
	local knob = New("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.02, 0.5), Size = UDim2.fromOffset(20, 20), ZIndex = 2 }, track)
	Corner(knob, 10)
	local ks = Stroke(knob, Accent, 3, 0)
	OnAccent(knob, function() ks.Color = Accent end)
	local step = e.step or 1
	local TI = Tw(0.12)
	local function show(v, instant)
		local f = math.max((v - e.min) / (e.max - e.min), 0.012)
		if instant then
			fill.Size = UDim2.fromScale(f, 1)
			knob.Position = UDim2.fromScale(f, 0.5)
		else
			TweenService:Create(fill, TI, { Size = UDim2.fromScale(f, 1) }):Play()
			TweenService:Create(knob, TI, { Position = UDim2.fromScale(f, 0.5) }):Play()
		end
		val.Text = tostring(v) .. (e.suf or "")
	end
	local function fromPos(pos)
		local rel = math.clamp((pos.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		local v = math.clamp(math.floor((e.min + rel * (e.max - e.min)) / step + 0.5) * step, e.min, e.max)
		show(v)
		e.set(v)
	end
	local hitArea = New("TextButton", { Text = "", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 20, 0, 30), ZIndex = 3 }, track)
	hitArea.InputBegan:Connect(function(inp)
		if inp.UserInputType == MB1 or inp.UserInputType == TOUCH then
			ActiveDrag = fromPos
			SetScrolling(false)
			fromPos(inp.Position)
		end
	end)
	Refresh(track, function() show(e.get() or e.min, true) end)
	show(e.get() or e.min, true)
end

local function SmallBox(parent, txt, x, cy, w)
	local b = New("TextButton", { Text = txt, Font = FONT, TextSize = 20, TextColor3 = C.On, AutoButtonColor = false,
		BackgroundColor3 = C.Box, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromOffset(x, cy), Size = UDim2.fromOffset(w, 32) }, parent)
	Corner(b, 6)
	Stroke(b, C.BoxStroke, 1, 0.3)
	return b
end

local function DropButton(parent, x, cy, w, getText)
	local b = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.Box, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromOffset(x, cy), Size = UDim2.fromOffset(w, 32) }, parent)
	Corner(b, 6)
	Stroke(b, C.BoxStroke, 1, 0.3)
	local t = New("TextLabel", { BackgroundTransparency = 1, Font = FONT, TextSize = 19, TextColor3 = C.On,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -34, 1, 0) }, b)
	Icon(b, "chevron-down", w - 16, 16, 16, C.Off)
	local function refresh() t.Text = getText() end
	refresh()
	return b, refresh
end

local function AnchorRect(anchor)
	local s = Scale.Scale
	return (anchor.AbsolutePosition - Root.AbsolutePosition) / s, anchor.AbsoluteSize / s
end

local function MakeOverlay(x, y, w, h)
	CloseDrop()
	DropBlocker = New("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 65 }, Root)
	DropBlocker.MouseButton1Click:Connect(CloseDrop)
	Drop = New("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 70,
		Position = UDim2.fromOffset(x, y + 8), Size = UDim2.fromOffset(w, h) }, Root)
	Corner(Drop, 8)
	Grad(Drop, Color3.fromRGB(30, 30, 32), Color3.fromRGB(12, 12, 14), 60)
	Grad(Stroke(Drop, WHITE, 1, 0.1), Color3.fromRGB(50, 50, 52), Color3.fromRGB(28, 28, 30), 45)
	TweenService:Create(Drop, Tw(0.12), { Position = UDim2.fromOffset(x, y) }):Play()
	return Drop
end

local function OpenList(anchor, e, mode, refresh)
	local a, sz = AnchorRect(anchor)
	local w = math.max(sz.X, 190)
	local rowH = 34
	local top = (mode == "search") and 46 or 6
	local listH = math.min(#e.list, 6) * rowH
	local h = top + listH + 6
	local x = math.clamp(a.X + sz.X - w, 10, DESIGN_W - w - 10)
	local y = a.Y + sz.Y + 4
	if y + h > DESIGN_H - 10 then y = math.max(a.Y - h - 4, 10) end
	local D = MakeOverlay(x, y, w, h)

	local box
	if mode == "search" then
		box = New("TextBox", { PlaceholderText = "search...", Text = "", ClearTextOnFocus = false, Font = FONT, TextSize = 19,
			TextColor3 = C.On, PlaceholderColor3 = C.Off, BackgroundColor3 = C.Box, BorderSizePixel = 0,
			TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(w - 16, 30) }, D)
		Corner(box, 6)
		New("UIPadding", { PaddingLeft = UDim.new(0, 10) }, box)
		Icon(box, "search", w - 16 - 18, 15, 16, C.Off)
	end
	local sf = New("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(6, top),
		Size = UDim2.fromOffset(w - 12, listH), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 2, ScrollBarImageColor3 = Color3.fromRGB(130, 130, 140) }, D)
	New("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, sf)

	local function isSel(it)
		if mode == "multi" then return table.find(e.get() or {}, it) ~= nil end
		return e.get() == it
	end
	local rebuild
	rebuild = function()
		local pos = sf.CanvasPosition
		for _, c in ipairs(sf:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
		local f = box and box.Text:lower() or ""
		for i, it in ipairs(e.list) do
			if f == "" or it:lower():find(f, 1, true) then
				local sel = isSel(it)
				local b = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(96, 78, 100),
					BackgroundTransparency = sel and 0.45 or 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = i }, sf)
				Corner(b, 6)
				New("TextLabel", { BackgroundTransparency = 1, Text = it, Font = FONT, TextSize = 19,
					TextColor3 = sel and C.On or C.Off, TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -40, 1, 0) }, b)
				if sel then Icon(b, "check", w - 12 - 20, 16, 16, Accent) end
				b.MouseEnter:Connect(function() if not sel then b.BackgroundTransparency = 0.75 end end)
				b.MouseLeave:Connect(function() if not sel then b.BackgroundTransparency = 1 end end)
				b.MouseButton1Click:Connect(function()
					if mode == "multi" then
						local set = {}
						for _, v in ipairs(e.get() or {}) do set[v] = true end
						set[it] = not set[it] or nil
						local new = {}
						for _, v in ipairs(e.list) do if set[v] then table.insert(new, v) end end
						e.set(new)
						refresh()
						rebuild()
					else
						e.set(it)
						refresh()
						CloseDrop()
					end
				end)
			end
		end
		sf.CanvasPosition = pos
	end
	rebuild()
	if box then box:GetPropertyChangedSignal("Text"):Connect(rebuild) end
end

local function OpenPicker(anchor, title, get, set)
	local a, sz = AnchorRect(anchor)
	local w, h = 300, 362
	local x = math.clamp(a.X + sz.X - w, 10, DESIGN_W - w - 10)
	local y = a.Y + sz.Y + 6
	if y + h > DESIGN_H - 10 then y = math.max(a.Y - h - 6, 10) end
	local D = MakeOverlay(x, y, w, h)
	Text(D, title, 16, 26, 260, 21, Color3.fromRGB(205, 200, 207))

	local hh, ss, vv = (get() or Presets[1]):ToHSV()

	local sv = New("Frame", { BackgroundColor3 = Color3.fromHSV(hh, 1, 1), BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 50), Size = UDim2.fromOffset(268, 170) }, D)
	Corner(sv, 6)
	local wo = New("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, sv)
	Corner(wo, 6)
	New("UIGradient", { Transparency = NumberSequence.new(0, 1) }, wo)
	local bo = New("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, sv)
	Corner(bo, 6)
	New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }, bo)
	local svBtn = New("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, sv)
	local svCur = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(16, 16) }, sv)
	Corner(svCur, 8)
	Stroke(svCur, WHITE, 2, 0)
	local svCur2 = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(18, 18) }, svCur)
	Corner(svCur2, 9)
	Stroke(svCur2, Color3.new(0, 0, 0), 1, 0.4)

	local hue = New("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 232), Size = UDim2.fromOffset(268, 16) }, D)
	Corner(hue, 8)
	New("UIGradient", { Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)), ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
		ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)), ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
		ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)), ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)) }) }, hue)
	local hueBtn = New("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, hue)
	local hueCur = New("Frame", { BackgroundColor3 = WHITE, AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(8, 24), BorderSizePixel = 0 }, hue)
	Corner(hueCur, 4)
	Stroke(hueCur, Color3.new(0, 0, 0), 1, 0.5)

	local hex = New("TextBox", { Text = "", ClearTextOnFocus = false, Font = FONT, TextSize = 19, TextColor3 = C.On,
		BackgroundColor3 = C.Box, BorderSizePixel = 0, Position = UDim2.fromOffset(16, 262), Size = UDim2.fromOffset(116, 34) }, D)
	Corner(hex, 6)
	Stroke(hex, C.BoxStroke, 1, 0.3)
	local prev = New("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0, Position = UDim2.fromOffset(142, 262),
		Size = UDim2.fromOffset(40, 34) }, D)
	Corner(prev, 6)
	Stroke(prev, Color3.fromRGB(90, 80, 92), 1, 0.2)
	local rgb = Text(D, "", 192, 279, 92, 17, C.Off, Enum.TextXAlignment.Right)

	local function update(fire)
		local c = Color3.fromHSV(hh, ss, vv)
		sv.BackgroundColor3 = Color3.fromHSV(hh, 1, 1)
		svCur.Position = UDim2.fromScale(ss, 1 - vv)
		hueCur.Position = UDim2.fromScale(hh, 0.5)
		prev.BackgroundColor3 = c
		hex.Text = "#" .. c:ToHex():upper()
		rgb.Text = math.floor(c.R * 255 + 0.5) .. ", " .. math.floor(c.G * 255 + 0.5) .. ", " .. math.floor(c.B * 255 + 0.5)
		if fire then set(c) end
	end

	svBtn.InputBegan:Connect(function(inp)
		if inp.UserInputType == MB1 or inp.UserInputType == TOUCH then
			local function f(pos)
				ss = math.clamp((pos.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
				vv = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
				update(true)
			end
			ActiveDrag = f
			SetScrolling(false)
			f(inp.Position)
		end
	end)
	hueBtn.InputBegan:Connect(function(inp)
		if inp.UserInputType == MB1 or inp.UserInputType == TOUCH then
			local function f(pos)
				hh = math.clamp((pos.X - hue.AbsolutePosition.X) / hue.AbsoluteSize.X, 0, 0.999)
				update(true)
			end
			ActiveDrag = f
			SetScrolling(false)
			f(inp.Position)
		end
	end)
	hex.FocusLost:Connect(function()
		local okc, c = pcall(Color3.fromHex, hex.Text)
		if okc and c then hh, ss, vv = c:ToHSV(); update(true) else update(false) end
	end)

	Text(D, "presets", 16, 316, 100, 16, C.Off)
	for i, col in ipairs(Presets) do
		local b = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = col, BorderSizePixel = 0,
			Position = UDim2.fromOffset(16 + (i - 1) * 39, 328), Size = UDim2.fromOffset(30, 22) }, D)
		Corner(b, 6)
		Stroke(b, Color3.fromRGB(0, 0, 0), 1, 0.6)
		b.MouseButton1Click:Connect(function() hh, ss, vv = col:ToHSV(); update(true) end)
	end
	update(false)
end

local function WH(e) return e.t == "slider" and 62 or (e.t == "label" and 36 or 44.5) end

local function AddWidget(parent, e, x, y, w)
	local h = WH(e)
	local cy = y + h / 2
	local t = e.t
	local extra
	if t == "enabled" then
		MakeCheck(parent, e.n or "enabled", x, cy, 28, 22, x + 44, w - 44,
			function() return Cfg(e.key).enabled end, function(v) SetEnabled(e.key, v) end, e.key)
	elseif t == "toggle" then
		MakeCheck(parent, e.n, x, cy, 28, 22, x + 44, w - 44, e.get, e.set)
	elseif t == "slider" then
		MakeSlider(parent, x, y, w, e)
	elseif t == "dropdown" or t == "multi" or t == "search" then
		Text(parent, e.n, x, cy, w - 175, 21, C.Off)
		local b, refresh
		local function txt()
			if t == "multi" then
				local v = e.get() or {}
				return #v == 0 and "none" or table.concat(v, ", ")
			end
			return tostring(e.get() or "none")
		end
		b, refresh = DropButton(parent, x + w, cy, 165, txt)
		b.MouseButton1Click:Connect(function() OpenList(b, e, t, refresh) end)
		Refresh(b, refresh)
		if e.onCreate then e.onCreate(b, refresh) end
	elseif t == "keybind" then
		Text(parent, e.n, x, cy, w - 175, 21, C.Off)
		local b = SmallBox(parent, KeyName(e.get()), x + w, cy, 165)
		Refresh(b, function() b.Text = KeyName(e.get()) end)
		b.MouseButton1Click:Connect(function()
			b.Text = "..."
			b.TextColor3 = Accent
			Listening = function(k) e.set(k); b.Text = KeyName(k); b.TextColor3 = C.On end
		end)
	elseif t == "color" then
		Text(parent, e.n, x, cy, w - 100, 21, C.Off)
		local sw = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = e.get() or Presets[1],
			BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromOffset(x + w, cy),
			Size = UDim2.fromOffset(56, 30) }, parent)
		Corner(sw, 6)
		Stroke(sw, Color3.fromRGB(0, 0, 0), 1, 0.55)
		Refresh(sw, function() sw.BackgroundColor3 = e.get() or Presets[1] end)
		sw.MouseButton1Click:Connect(function()
			OpenPicker(sw, e.n, e.get, function(c) e.set(c); sw.Backgroun