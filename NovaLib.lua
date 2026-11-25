--[[
	═══════════════════════════════════════════════════════════════
	 NOVA UI LIBRARY  v1.1
	 Touch-first UI library for Roblox (iOS / ColorOS look)
	 Docs: see README.md   ·   License: MIT
	═══════════════════════════════════════════════════════════════

	 LOAD
	     local Nova = loadstring(game:HttpGet("https://raw.githubusercontent.com/USER/NovaUI/main/NovaLib.lua"))()

	 SHORTCUTS  (the flag of every shortcut is its name, so configs save automatically)
	     local ui  = Nova:CreateWindow({ Title = "My Hub" })
	     local tab = ui:Tab("Main")
	     tab:Section("Player")
	     tab:Toggle("God mode", false, function(on) end)
	     tab:Slider("Speed", 16, 120, 16, function(v) end)
	     tab:Dropdown("Team", { "Red", "Blue" }, "Red", function(v) end)
	     tab:Button("Reset", function() end)
	     ui:Notify("Hello", "Loaded", 3, "success")

	 LONG FORM    tab:AddToggle({ Name = "God mode", Default = false, Flag = "god", Quick = true, Callback = fn })
	 RAYFIELD     tab:CreateToggle({ Name = "God mode", CurrentValue = false, Flag = "god", Callback = fn })
	              (CreateWindow{Name, ConfigurationSaving}, CreateTab, CreateSection, CreateSlider{Range,Increment},
	               CreateDropdown{CurrentOption,MultipleOptions}, Window:LoadConfiguration() ... all work)

	 Shortcut list (tab: or section:)
	     Toggle(name, default, cb)        Checkbox(name, default, cb)       Button(name, cb, danger)
	     Slider(name, min, max, default, cb, step, suffix)                  Stepper(name, min, max, default, cb)
	     Dropdown(name, options, default, cb)   Multi(name, options, defaults, cb)
	     Segmented(name, options, default, cb)  Radio(options, default, cb)
	     Input(name, placeholder, cb)     Keybind(name, key, cb, mode)      Color(name, color, cb)
	     Progress(name)   Label(text)   Paragraph(title, content)   Value(name, value)   Divider()

	 Every component returns a handle: h:Get() h:Set(v) h:SetVisible(b) h:Destroy()  (h.Set and h:Set both work)

	 Window options (all optional)
	     Title / Name, Style ("iOS"|"ColorOS"), Mode ("Dark"|"Light"), Accent (Color3),
	     ToggleKey (Enum.KeyCode | false), ShowFPS, AutoOpen, AutoLoad, Protect (gethui),
	     ConfigFolder, ConfigurationSaving = { Enabled, FolderName, FileName },
	     Quick = { rows = 7, travel = 220, ... }, QuickDefault = { "God mode" }, QuickIcons = { ["God mode"] = "rbxassetid://1" }

	 Window methods
	     :Tab(name) :SelectTab(x) :Notify(title, body, seconds, type) :Open :Close :Minimize :Toggle :Destroy
	     :SaveConfig(n) :LoadConfig(n) :DeleteConfig(n) :ListConfigs() :LoadConfiguration() :SetAutoConfig(n)
	     :SetStyle :SetMode :SetAccent :SetWindowSize(pct) :SetDPI(pct) :SetTitle :OnDestroy(fn)
	     .Flags (read/write by flag)   .Settings (add your own sections to the Settings page)
]]

local Nova = { Version = "1.1.0", _mem = {} }

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

function Nova.CreateWindow(a, b)
	local opts = (a == Nova) and b or a
	opts = opts or {}
	-- Rayfield-style option names are accepted too
	if opts.Name and not opts.Title then opts.Title = opts.Name end
	if opts.Theme == "Light" and not opts.Mode then opts.Mode = "Light" end
	local function keyFrom(v)
		if type(v) == "string" then
			local ok, k = pcall(function() return Enum.KeyCode[v] end)
			return ok and k or nil
		end
		return v
	end
	if opts.ToggleUIKeybind ~= nil and opts.ToggleKey == nil then opts.ToggleKey = keyFrom(opts.ToggleUIKeybind) end
	if type(opts.ToggleKey) == "string" then opts.ToggleKey = keyFrom(opts.ToggleKey) end
	local cs = opts.ConfigurationSaving
	if type(cs) == "table" and cs.Enabled then
		opts.ConfigFolder = opts.ConfigFolder or cs.FolderName
		opts._autoName = cs.FileName or "default"
	end
	if Nova.Active then pcall(function() Nova.Active:Destroy() end) end

	local lp = Players.LocalPlayer
	local pg = lp:WaitForChild("PlayerGui")
	local cam = Workspace.CurrentCamera
	local title = tostring(opts.Title or "Nova")

	local guiParent = pg
	if opts.Protect and type(gethui) == "function" then
		local ok, h = pcall(gethui)
		if ok and h then guiParent = h end
	end
	for _, p in ipairs({ pg, guiParent }) do
		local old = p:FindFirstChild("NovaUI")
		if old then old:Destroy() end
	end

	local conns = {}
	local function C(sig, fn)
		local c = sig:Connect(fn)
		conns[#conns + 1] = c
		return c
	end

	local QuickIcons = {}
	if type(opts.QuickIcons) == "table" then
		for k, v in pairs(opts.QuickIcons) do QuickIcons[k] = v end
	end

	local Window = { Title = title, QuickIcons = QuickIcons }
	local QA = { order = {}, last = nil }
	local byLabel = {}
	local QSel = { m = nil }
	local listening, consumedKey
	local toggleKey = Enum.KeyCode.RightShift
	if opts.ToggleKey ~= nil then toggleKey = opts.ToggleKey or nil end

	----------------------------------------------------------------------
	-- THEMES
	----------------------------------------------------------------------
	local RGB = Color3.fromRGB
	local Palettes = {
		iOS = {
			Dark = {
				bg = RGB(28, 28, 30), card = RGB(44, 44, 46), card2 = RGB(58, 58, 60),
				text = RGB(255, 255, 255), sub = RGB(152, 152, 157), line = RGB(68, 68, 72),
				accent = RGB(10, 132, 255), on = RGB(48, 209, 88), off = RGB(66, 66, 70),
				knob = RGB(255, 255, 255), seg = RGB(99, 99, 102), danger = RGB(255, 69, 58),
			},
			Light = {
				bg = RGB(242, 242, 247), card = RGB(255, 255, 255), card2 = RGB(233, 233, 238),
				text = RGB(0, 0, 0), sub = RGB(142, 142, 147), line = RGB(222, 222, 226),
				accent = RGB(0, 122, 255), on = RGB(52, 199, 89), off = RGB(229, 229, 234),
				knob = RGB(255, 255, 255), seg = RGB(255, 255, 255), danger = RGB(255, 59, 48),
			},
		},
		ColorOS = {
			Dark = {
				bg = RGB(20, 20, 22), card = RGB(36, 36, 40), card2 = RGB(52, 52, 58),
				text = RGB(240, 240, 245), sub = RGB(150, 150, 158), line = RGB(56, 56, 62),
				accent = RGB(0, 198, 142), on = RGB(0, 198, 142), off = RGB(70, 70, 78),
				knob = RGB(255, 255, 255), seg = RGB(76, 76, 86), danger = RGB(255, 84, 84),
			},
			Light = {
				bg = RGB(244, 245, 247), card = RGB(255, 255, 255), card2 = RGB(236, 237, 240),
				text = RGB(20, 20, 24), sub = RGB(130, 134, 142), line = RGB(232, 233, 236),
				accent = RGB(0, 190, 135), on = RGB(0, 190, 135), off = RGB(214, 216, 222),
				knob = RGB(255, 255, 255), seg = RGB(255, 255, 255), danger = RGB(240, 70, 70),
			},
		},
	}
	local Shapes = {
		iOS = { rWin = UDim.new(0, 22), rCard = UDim.new(0, 12), rCtl = UDim.new(0, 8) },
		ColorOS = { rWin = UDim.new(0, 30), rCard = UDim.new(0, 20), rCtl = UDim.new(0, 14) },
	}
	local cfg = { style = opts.Style or "iOS", mode = opts.Mode or "Dark", accent = opts.Accent }
	if not Palettes[cfg.style] then cfg.style = "iOS" end
	if not (Palettes[cfg.style] and Palettes[cfg.style][cfg.mode]) then cfg.mode = "Dark" end
	local Th = {}
	local function buildTheme()
		Th = {}
		for k, v in pairs(Palettes[cfg.style][cfg.mode]) do Th[k] = v end
		for k, v in pairs(Shapes[cfg.style]) do Th[k] = v end
		if cfg.accent then Th.accent = cfg.accent end
	end
	buildTheme()

	----------------------------------------------------------------------
	-- QUICK ACCESS CONFIG (defaults; override with opts.Quick, edit live in Settings)
	----------------------------------------------------------------------
	local QDef = {
		enabled = true,
		zoneW = 48, zoneH = 220, zonePct = 50, showLine = true,
		travel = 180, direction = "Down", startFrom = "First",
		cancelOn = true, cancelDist = 100,
		width = 230, rowH = 42, rows = 5, textSize = 14, radius = 0,
		dim = 45, boxAlpha = 6, wheel = true, showState = true, showCount = true, showHint = true,
		pos = "Center", offY = 0, speed = 1,
		openEdge = "Right", closeSwipe = "Both",
	}
	if type(opts.Quick) == "table" then
		for k, v in pairs(opts.Quick) do
			if QDef[k] ~= nil then QDef[k] = v end
		end
	end
	local QS = {}
	for k, v in pairs(QDef) do QS[k] = v end

	----------------------------------------------------------------------
	-- HELPERS
	----------------------------------------------------------------------
	local gui

	local function tw(o, t, props, style, dir)
		local tween = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
		tween:Play()
		return tween
	end

	local function new(class, props)
		local o = Instance.new(class)
		local parent
		for k, v in pairs(props) do
			if k == "Parent" then parent = v else o[k] = v end
		end
		o.Parent = parent
		return o
	end

	local reg = {}
	local function bind(obj, prop, key)
		if typeof(key) ~= "string" and typeof(key) ~= "function" then
			obj[prop] = key
			return function() end
		end
		local function get()
			if type(key) == "function" then return key() end
			return Th[key]
		end
		reg[#reg + 1] = { obj = obj, prop = prop, get = get }
		obj[prop] = get()
		return function(dur)
			if dur and dur > 0 then tw(obj, dur, { [prop] = get() }) else obj[prop] = get() end
		end
	end

	local function applyTheme(animate)
		for i = #reg, 1, -1 do
			local e = reg[i]
			if not e.obj:IsDescendantOf(gui) then
				table.remove(reg, i)
			elseif animate then
				tw(e.obj, 0.35, { [e.prop] = e.get() })
			else
				e.obj[e.prop] = e.get()
			end
		end
	end

	local function font(w) return Font.new("rbxasset://fonts/families/GothamSSm.json", w or Enum.FontWeight.Medium) end
	local function isPress(i) return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch end
	local function V2(i) return Vector2.new(i.Position.X, i.Position.Y) end
	local function posU(p) return UDim2.fromOffset(p.X, p.Y) end

	----------------------------------------------------------------------
	-- >>> TOUCH SYSTEM (one finger owns a gesture, others are ignored)
	----------------------------------------------------------------------
	local lockOwner = nil
	local function lockFree()
		if lockOwner and (lockOwner.UserInputState == Enum.UserInputState.End or lockOwner.UserInputState == Enum.UserInputState.Cancel) then
			lockOwner = nil
		end
		return lockOwner == nil
	end

	local function capture(input, onMove, onEnd)
		if not lockFree() then return nil end
		lockOwner = input
		local list, done, h = {}, false, {}
		local function isMine(i)
			return i == input or (i.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)
		end
		function h.unlock()
			if lockOwner == input then lockOwner = nil end
		end
		local function finish()
			if done then return end
			done = true
			for _, c in ipairs(list) do c:Disconnect() end
			h.unlock()
			if onEnd then onEnd() end
		end
		list[1] = UIS.InputChanged:Connect(function(i)
			if onMove and (i == input or (i.UserInputType == Enum.UserInputType.MouseMovement and input.UserInputType == Enum.UserInputType.MouseButton1)) then
				onMove(V2(i))
			end
		end)
		list[2] = UIS.InputEnded:Connect(function(i) if isMine(i) then finish() end end)
		return h
	end

	-- tap: fires only if the finger did not move (so scrolling never triggers buttons)
	local function tap(btn, fn, down, up)
		btn.InputBegan:Connect(function(i)
			if not isPress(i) or not lockFree() then return end
			local start, moved, shown, finished = V2(i), false, false, false
			local timer = task.delay(0.06, function()
				if not finished and not moved then
					shown = true
					if down then down() end
				end
			end)
			local cap
			cap = capture(i, function(p)
				if not moved and (p - start).Magnitude > 9 then
					moved = true
					if cap then cap.unlock() end
					if shown then
						shown = false
						if up then up() end
					end
				end
			end, function()
				finished = true
				pcall(task.cancel, timer)
				if shown then
					if up then up() end
				elseif not moved and down and up then
					down()
					task.delay(0.08, up)
				end
				if not moved and fn then fn() end
			end)
		end)
	end

	-- hDrag: horizontal RELATIVE drag. Vertical intent = let the menu scroll.
	local function hDrag(hit, scrollFrame, onBegin, onDrag, onEnd)
		hit.InputBegan:Connect(function(i)
			if not isPress(i) or not lockFree() then return end
			local isMouse = i.UserInputType == Enum.UserInputType.MouseButton1
			local start, mode, ox = V2(i), nil, 0
			local cap
			cap = capture(i, function(p)
				if mode == nil then
					local d = p - start
					if d.Magnitude < (isMouse and 2 or 6) then return end
					if isMouse or math.abs(d.X) >= math.abs(d.Y) * 0.9 then
						mode, ox = "drag", p.X
						scrollFrame.ScrollingEnabled = false
						onBegin()
					else
						mode = "scroll"
						if cap then cap.unlock() end
					end
				end
				if mode == "drag" then onDrag(p.X - ox) end
			end, function()
				if mode == "drag" then
					scrollFrame.ScrollingEnabled = true
					onEnd()
				end
			end)
		end)
	end

	local function corner(p, key)
		local c = new("UICorner", { Parent = p })
		if key then bind(c, "CornerRadius", key) else c.CornerRadius = UDim.new(1, 0) end
		return c
	end

	local function text(parent, str, size, weight, key, extra)
		local l = new("TextLabel", {
			BackgroundTransparency = 1, Text = str, TextSize = size, FontFace = font(weight),
			TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromScale(1, 1), Parent = parent,
		})
		bind(l, "TextColor3", key)
		if extra then for k, v in pairs(extra) do l[k] = v end end
		return l
	end

	----------------------------------------------------------------------
	-- ROOT GUI + WINDOW
	----------------------------------------------------------------------
	gui = new("ScreenGui", {
		Name = "NovaUI", ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 1000,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets, Parent = guiParent,
	})

	local function vp()
		local s = gui.AbsoluteSize
		if s.X < 50 then s = cam.ViewportSize end
		return s
	end

	local win = new("CanvasGroup", {
		Name = "Window", Size = UDim2.fromOffset(300, 300), BackgroundTransparency = 0.04,
		GroupTransparency = 1, Visible = false, Active = true, Parent = gui,
	})
	bind(win, "BackgroundColor3", "bg")
	corner(win, "rWin")
	local winStroke = new("UIStroke", { Thickness = 1, Transparency = 0.3, Parent = win })
	bind(winStroke, "Color", "line")
	local winScale = new("UIScale", { Parent = win })

	local userScale = 1
	local function layoutSize()
		local v = vp()
		win.Size = UDim2.fromOffset(math.clamp(v.X * 0.36, 240, 320), math.clamp(v.Y * 0.7, 210, 380))
	end
	local function winVis() return Vector2.new(win.Size.X.Offset, win.Size.Y.Offset) * userScale end
	local function clampBox(p, s, rm, lm)
		local v = vp()
		rm, lm = rm or 6, lm or 6
		return Vector2.new(math.clamp(p.X, lm, math.max(lm, v.X - s.X - rm)), math.clamp(p.Y, 6, math.max(6, v.Y - s.Y - 6)))
	end
	-- the window keeps the right edge strip free so the Quick Access gesture always works
	local function clampWin(p)
		return clampBox(p, winVis(), QS.enabled and (QS.zoneW + 8) or 6, (QS.openEdge ~= "Right") and (QS.zoneW + 8) or 6)
	end
	local PILL = Vector2.new(120, 34)
	local function pillVis() return PILL * userScale end
	layoutSize()
	local winPos = clampWin(Vector2.new(9e4, 62))
	local pillPos = clampBox(Vector2.new(9e4, 66), pillVis())

	local state, token, swiping = "hidden", 0, false
	local openWindow, closeWindow -- forward
	local titleL

	-- header
	local header = new("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, Active = true, Parent = win })
	local grab = new("Frame", {
		Size = UDim2.fromOffset(36, 4), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6),
		BorderSizePixel = 0, BackgroundTransparency = 0.5, Parent = header,
	})
	bind(grab, "BackgroundColor3", "sub")
	corner(grab)
	titleL = text(header, title, 17, Enum.FontWeight.Bold, "text", { Position = UDim2.fromOffset(14, 14), Size = UDim2.new(1, -130, 0, 26) })

	local function circleBtn(glyph, fromRight, cb)
		local b = new("TextButton", {
			Size = UDim2.fromOffset(30, 30), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -fromRight, 0, 12),
			Text = glyph, TextSize = 18, FontFace = font(Enum.FontWeight.Bold), AutoButtonColor = false, BorderSizePixel = 0, Parent = header,
		})
		bind(b, "BackgroundColor3", "card2")
		bind(b, "TextColor3", "sub")
		corner(b)
		local sc = new("UIScale", { Parent = b })
		tap(b, cb, function() tw(sc, 0.1, { Scale = 0.86 }) end, function() tw(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back) end)
	end
	circleBtn("×", 10, function() closeWindow("hidden") end)
	circleBtn("–", 46, function() closeWindow("mini") end)

	----------------------------------------------------------------------
	-- COMPONENT LIBRARY
	----------------------------------------------------------------------
	local registry = {} -- items that Quick Access can use
	local function unregister(e)
		local i = table.find(registry, e)
		if i then table.remove(registry, i) end
		if byLabel[e.label] == e then byLabel[e.label] = nil end
		local j = table.find(QA.order, e.label)
		if j then table.remove(QA.order, j) end
		if QA.onRegistry then QA.onRegistry() end
	end
	local function register(sec, name, kind, run, getState, quick, icon)
		if sec.page.noQA or quick == false then return nil end
		local e = { name = name, page = sec.page.name, kind = kind, run = run, state = getState, icon = icon }
		local label = name
		if byLabel[label] then label = name .. " · " .. sec.page.name end
		local k = 2
		while byLabel[label] do
			label = name .. " · " .. sec.page.name .. " " .. k
			k += 1
		end
		e.label = label
		byLabel[label] = e
		registry[#registry + 1] = e
		local pre = type(opts.QuickDefault) == "table" and table.find(opts.QuickDefault, name)
		if (quick == true or pre) and not table.find(QA.order, label) then QA.order[#QA.order + 1] = label end
		if QA.onRegistry then QA.onRegistry() end
		return e
	end

	local function makeSegmented(parent, opts, default, onSel, size, pos, tsize)
		local n, sel = #opts, default or 1
		local c = new("Frame", { Size = size, Position = pos, BorderSizePixel = 0, Parent = parent })
		bind(c, "BackgroundColor3", "card2")
		corner(c, "rCtl")
		local ind = new("Frame", {
			Size = UDim2.new(1 / n, -4, 1, -4), Position = UDim2.new((sel - 1) / n, 2, 0, 2), BorderSizePixel = 0, Parent = c,
		})
		bind(ind, "BackgroundColor3", "seg")
		corner(ind, "rCtl")
		local ups, obj = {}, {}
		for i, name in ipairs(opts) do
			local b = new("TextButton", {
				Size = UDim2.new(1 / n, 0, 1, 0), Position = UDim2.new((i - 1) / n, 0, 0, 0), BackgroundTransparency = 1,
				Text = name, TextSize = tsize or 13, FontFace = font(Enum.FontWeight.SemiBold), AutoButtonColor = false, Parent = c,
			})
			ups[i] = bind(b, "TextColor3", function() return sel == i and Th.text or Th.sub end)
			tap(b, function() obj.Set(i) end)
		end
		function obj.Set(i, silent)
			sel = i
			tw(ind, 0.35, { Position = UDim2.new((i - 1) / n, 2, 0, 2) })
			for _, u in ipairs(ups) do u(0.2) end
			if not silent and onSel then onSel(i, opts[i]) end
		end
		obj.Frame = c
		return obj
	end

	-- pages
	local pages, curPage = {}, 1
	local pageHost = new("Frame", {
		Position = UDim2.fromOffset(0, 88), Size = UDim2.new(1, 0, 1, -88), BackgroundTransparency = 1, ClipsDescendants = true, Parent = win,
	})

	-- DPI: every scrolling content area gets a UIScale and a counter-scaled size,
	-- so the window frame stays the same but everything inside grows / shrinks.
	local dpiList = {}
	local dpiNV = Instance.new("NumberValue")
	dpiNV.Value = 1
	local function dpiApply(e, v)
		e.us.Scale = v
		e.sf.Size = UDim2.fromScale(1 / v, 1 / v)
	end
	local function dpiAttach(sf)
		local e = { sf = sf, us = new("UIScale", { Parent = sf }) }
		dpiApply(e, dpiNV.Value)
		dpiList[#dpiList + 1] = e
	end
	dpiNV.Changed:Connect(function(v)
		for _, e in ipairs(dpiList) do dpiApply(e, v) end
	end)
	local function dpiTo(v) tw(dpiNV, 0.35, { Value = v }) end

	local function Page(name)
		local root = new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = pageHost })
		local sf = new("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
			AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y,
			ElasticBehavior = Enum.ElasticBehavior.Always, Parent = root,
		})
		bind(sf, "ScrollBarImageColor3", "sub")
		new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 18), Parent = sf })
		new("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sf })
		dpiAttach(sf)
		local p = { root = root, scroll = sf, order = 0, name = name }
		pages[#pages + 1] = p
		return p
	end

	local function showPage(i, instant)
		if i == curPage and not instant then return end
		if instant then
			for k, p in ipairs(pages) do p.root.Visible = (k == i) end
			curPage = i
			return
		end
		local dir = i > curPage and 1 or -1
		local o, n = pages[curPage], pages[i]
		n.root.Position = UDim2.fromScale(0.18 * dir, 0)
		n.root.GroupTransparency = 1
		n.root.Visible = true
		tw(n.root, 0.42, { Position = UDim2.fromScale(0, 0), GroupTransparency = 0 })
		tw(o.root, 0.3, { Position = UDim2.fromScale(-0.18 * dir, 0), GroupTransparency = 1 })
		curPage = i
		task.delay(0.34, function()
			for k, p in ipairs(pages) do if k ~= curPage then p.root.Visible = false end end
		end)
	end

	local function Section(page, title)
		page.order += 1
		local wrap = new("Frame", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = page.order, Parent = page.scroll,
		})
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = wrap })
		local h
		if title then
			h = new("TextLabel", {
				BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), Text = string.upper(title), TextSize = 11,
				FontFace = font(Enum.FontWeight.SemiBold), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 0, Parent = wrap,
			})
			bind(h, "TextColor3", "sub")
			new("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = h })
		end
		local card = new("Frame", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ClipsDescendants = true, BorderSizePixel = 0, LayoutOrder = 1, Parent = wrap,
		})
		bind(card, "BackgroundColor3", "card")
		corner(card, "rCard")
		new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })
		return { card = card, n = 0, page = page, wrap = wrap, header = h }
	end

	local function Row(sec, h)
		sec.n += 1
		local r = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, h or 44), LayoutOrder = sec.n, Parent = sec.card })
		if sec.n > 1 then
			local l = new("Frame", { Size = UDim2.new(1, -28, 0, 1), Position = UDim2.fromOffset(14, 0), BorderSizePixel = 0, Parent = r })
			bind(l, "BackgroundColor3", "line")
		end
		return r
	end

	local function hlFrame(r)
		local h = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = r })
		bind(h, "BackgroundColor3", "text")
		return h
	end

	local function overlay(r)
		return new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = r })
	end

	local function rowLabel(r, name)
		return text(r, name, 14, Enum.FontWeight.Medium, "text", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -90, 1, 0) })
	end

	local function hlFX(hl)
		return function() tw(hl, 0.08, { BackgroundTransparency = 0.9 }) end, function() tw(hl, 0.3, { BackgroundTransparency = 1 }) end
	end

	----------------------------------------------------------------------
	-- COMPONENTS  (each one takes an options table and returns a handle)
	----------------------------------------------------------------------
	local flags = {}
	local function regFlag(name, kind, get, set)
		flags[name] = { kind = kind, get = get, set = set }
	end

	-- common handle methods + flag registration
	local function finish(r, obj, o, kind, entry)
		obj.Row = r
		function obj.SetVisible(v) r.Visible = v and true or false end
		function obj.Destroy()
			if obj._cleanup then obj._cleanup() end
			if entry then unregister(entry) end
			if o.Flag and flags[o.Flag] then flags[o.Flag] = nil end
			r:Destroy()
		end
		if o.Flag then regFlag(o.Flag, kind, obj.Get, function(v) obj.Set(v) end) end
		return obj
	end

	-- Toggle -------------------------------------------------------------
	local function Toggle(sec, o)
		local name, cb = o.Name or "Toggle", o.Callback
		local r = Row(sec)
		local hl = hlFrame(r)
		local lab = rowLabel(r, name)
		local track = new("Frame", {
			Size = UDim2.fromOffset(46, 26), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), BorderSizePixel = 0, Parent = r,
		})
		corner(track)
		local knob = new("Frame", { Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(0, 0.5), BorderSizePixel = 0, Parent = track })
		corner(knob)
		bind(knob, "BackgroundColor3", "knob")
		local state, pressed = o.Default and true or false, false
		local upd = bind(track, "BackgroundColor3", function() return state and Th.on or Th.off end)
		local function place(dur)
			local w = pressed and 28 or 22
			local goal = { Size = UDim2.fromOffset(w, 22), Position = UDim2.new(0, state and (46 - w - 2) or 2, 0.5, 0) }
			if dur == 0 then
				for k, v in pairs(goal) do knob[k] = v end
			else
				tw(knob, dur or 0.28, goal)
			end
		end
		place(0)
		local obj = {}
		function obj.Set(v, silent)
			state = v and true or false
			upd(0.25)
			place()
			if not silent and cb then cb(state) end
		end
		function obj.Get() return state end
		function obj.SetName(n) lab.Text = n end
		local hd, hu = hlFX(hl)
		tap(overlay(r), function() obj.Set(not state) end,
			function() pressed = true; place(0.12); hd() end,
			function() pressed = false; place(0.2); hu() end)
		local entry = register(sec, name, "toggle", function() obj.Set(not obj.Get()) end, obj.Get, o.Quick, o.Icon)
		return finish(r, obj, o, "toggle", entry)
	end

	-- Checkbox -----------------------------------------------------------
	local function Checkbox(sec, o)
		local name, cb = o.Name or "Checkbox", o.Callback
		local r = Row(sec)
		local hl = hlFrame(r)
		local lab = rowLabel(r, name)
		local state = o.Default and true or false
		local box = new("Frame", {
			Size = UDim2.fromOffset(24, 24), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), BorderSizePixel = 0, Parent = r,
		})
		corner(box)
		local upd = bind(box, "BackgroundColor3", function() return state and Th.accent or Th.card2 end)
		local bs = new("UIStroke", { Thickness = 1.5, Parent = box })
		bind(bs, "Color", function() return state and Th.accent or Th.sub end)
		local mark = text(box, "✓", 15, Enum.FontWeight.Bold, Color3.new(1, 1, 1), { TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = state and 0 or 1 })
		local obj = {}
		function obj.Set(v, silent)
			state = v and true or false
			upd(0.2)
			tw(bs, 0.2, { Color = state and Th.accent or Th.sub })
			tw(mark, 0.2, { TextTransparency = state and 0 or 1 })
			if not silent and cb then cb(state) end
		end
		function obj.Get() return state end
		function obj.SetName(n) lab.Text = n end
		local hd, hu = hlFX(hl)
		tap(overlay(r), function() obj.Set(not state) end, hd, hu)
		local entry = register(sec, name, "toggle", function() obj.Set(not obj.Get()) end, obj.Get, o.Quick, o.Icon)
		return finish(r, obj, o, "toggle", entry)
	end

	-- Button -------------------------------------------------------------
	local function Button(sec, o)
		local name, cb, danger = o.Name or "Button", o.Callback, o.Danger
		local r = Row(sec)
		local hl = hlFrame(r)
		local lbl = text(r, name, 14, Enum.FontWeight.SemiBold, danger and "danger" or "accent", { TextXAlignment = Enum.TextXAlignment.Center })
		local hd, hu = hlFX(hl)
		local function fire() if cb then cb() end end
		tap(overlay(r), fire, hd, hu)
		local obj = { Fire = fire }
		function obj.SetName(n) lbl.Text = n end
		function obj.Get() return nil end
		function obj.Set() end
		local entry
		if (not danger) or o.Quick == true then
			entry = register(sec, name, "button", fire, nil, o.Quick, o.Icon)
		end
		return finish(r, obj, o, "button", entry)
	end

	-- Slider (relative drag, scroll friendly, multi-touch safe) -----------
	local function Slider(sec, o)
		local name, min, max = o.Name or "Slider", o.Min or 0, o.Max or 100
		local step, suffix, cb, commitOnly = o.Step or 1, o.Suffix or "", o.Callback, o.CommitOnly
		local dec, s = 0, step
		while math.abs(s - math.floor(s + 0.5)) > 1e-6 and dec < 4 do s *= 10; dec += 1 end
		local fmt = "%." .. dec .. "f"
		local r = Row(sec, 60)
		local nameL = text(r, name, 14, Enum.FontWeight.Medium, "text", { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(0.6, 0, 0, 20) })
		local val = text(r, "", 13, Enum.FontWeight.Medium, "sub", { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 20), TextXAlignment = Enum.TextXAlignment.Right })
		local track = new("Frame", {
			Size = UDim2.new(1, -28, 0, 6), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(14, 42), BorderSizePixel = 0, Parent = r,
		})
		bind(track, "BackgroundColor3", "off")
		corner(track)
		local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, Parent = track })
		bind(fill, "BackgroundColor3", "accent")
		corner(fill)
		local knob = new("Frame", {
			Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BorderSizePixel = 0, Parent = track,
		})
		bind(knob, "BackgroundColor3", "knob")
		corner(knob)
		new("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0), Transparency = 0.85, Parent = knob })
		local value = math.clamp(o.Default or min, min, max)
		local raw, startRaw = value, value
		local function snap(x)
			local v = min + math.floor((x - min) / step + 0.5) * step
			return tonumber(string.format(fmt, math.clamp(v, min, max)))
		end
		local function render(v, dur)
			local a = (v - min) / math.max(max - min, 1e-9)
			tw(fill, dur, { Size = UDim2.fromScale(a, 1) })
			tw(knob, dur, { Position = UDim2.fromScale(a, 0.5) })
			val.Text = string.format(fmt, v) .. suffix
		end
		render(value, 0)
		local obj = {}
		function obj.Get() return value end
		function obj.Set(v, silent)
			value = snap(tonumber(v) or value)
			raw = value
			render(value, 0.25)
			if not silent and cb then cb(value) end
		end
		function obj.SetName(n) nameL.Text = n end
		local hit = new("TextButton", {
			Size = UDim2.new(1, -8, 0, 36), Position = UDim2.fromOffset(4, 24), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = r,
		})
		hDrag(hit, sec.page.scroll, function()
			startRaw = raw
			tw(knob, 0.12, { Size = UDim2.fromOffset(27, 27) })
		end, function(dx)
			raw = math.clamp(startRaw + dx / math.max(track.AbsoluteSize.X, 1) * (max - min), min, max)
			local v = snap(raw)
			if v ~= value then
				value = v
				render(v, 0.06)
				if cb and not commitOnly then cb(v) end
			end
		end, function()
			tw(knob, 0.25, { Size = UDim2.fromOffset(22, 22) }, Enum.EasingStyle.Back)
			if cb and commitOnly then cb(value) end
		end)
		return finish(r, obj, o, "number")
	end

	-- Stepper ------------------------------------------------------------
	local function Stepper(sec, o)
		local name, min, max, step, cb = o.Name or "Stepper", o.Min or 0, o.Max or 100, o.Step or 1, o.Callback
		local r = Row(sec)
		local lab = rowLabel(r, name)
		local box = new("Frame", {
			Size = UDim2.fromOffset(104, 30), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), BorderSizePixel = 0, Parent = r,
		})
		bind(box, "BackgroundColor3", "card2")
		corner(box, "rCtl")
		local value = math.clamp(o.Default or min, min, max)
		local lbl = text(box, tostring(value), 14, Enum.FontWeight.SemiBold, "text", { TextXAlignment = Enum.TextXAlignment.Center })
		local function setValue(nv, silent)
			nv = math.clamp(nv, min, max)
			if nv ~= value then
				value = nv
				lbl.Text = tostring(value)
				if not silent and cb then cb(value) end
			end
		end
		for k, g in ipairs({ "-", "+" }) do
			local b = new("TextButton", {
				Size = UDim2.fromOffset(34, 30), Position = UDim2.fromOffset(k == 1 and 0 or 70, 0), BackgroundTransparency = 1,
				Text = g, TextSize = 20, FontFace = font(Enum.FontWeight.Bold), AutoButtonColor = false, Parent = box,
			})
			bind(b, "TextColor3", "accent")
			local sc = new("UIScale", { Parent = b })
			b.InputBegan:Connect(function(i)
				if not isPress(i) or not lockFree() then return end
				local held, start = true, V2(i)
				setValue(value + (k == 1 and -1 or 1) * step)
				tw(sc, 0.1, { Scale = 0.8 })
				task.spawn(function()
					task.wait(0.4)
					while held do
						setValue(value + (k == 1 and -1 or 1) * step)
						task.wait(0.07)
					end
				end)
				capture(i, function(p)
					if (p - start).Magnitude > 14 then held = false end
				end, function()
					held = false
					tw(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
				end)
			end)
		end
		local obj = {}
		function obj.Get() return value end
		function obj.Set(v, silent) setValue(tonumber(v) or value, silent) end
		function obj.SetName(n) lab.Text = n end
		return finish(r, obj, o, "number")
	end

	-- Dropdown (single / multi, options can change at runtime) -----------
	local function Dropdown(sec, o)
		local name, cb, multi = o.Name or "Dropdown", o.Callback, o.Multi
		local options = {}
		for _, x in ipairs(o.Options or {}) do options[#options + 1] = tostring(x) end
		local r = Row(sec)
		r.ClipsDescendants = true
		local hl = hlFrame(r)
		hl.Size = UDim2.new(1, 0, 0, 44)
		local nameL = text(r, name, 14, Enum.FontWeight.Medium, "text", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0.5, -14, 0, 44) })
		local valL = text(r, "", 13, Enum.FontWeight.Medium, "sub", {
			Position = UDim2.new(0.4, 0, 0, 0), Size = UDim2.new(0.6, -40, 0, 44), TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local chev = text(r, "›", 24, Enum.FontWeight.Medium, "sub", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -22, 0, 22), Size = UDim2.fromOffset(24, 24), TextXAlignment = Enum.TextXAlignment.Center,
		})
		local chosen, checks, optBtns = {}, {}, {}
		if multi then
			for _, d in ipairs(o.Default or {}) do chosen[tostring(d)] = true end
		elseif o.Default ~= nil then
			chosen[tostring(o.Default)] = true
		elseif options[1] ~= nil and o.AllowNone ~= true then
			chosen[options[1]] = true
		end
		local function selectedList()
			local l = {}
			for _, x in ipairs(options) do if chosen[x] then l[#l + 1] = x end end
			return l
		end
		local function summary()
			local l = selectedList()
			if multi then
				if #l == 0 then return "None" elseif #l <= 2 then return table.concat(l, ", ") end
				return #l .. " selected"
			end
			return l[1] or "None"
		end
		local open = false
		local function height() return 44 + (open and #options * 38 or 0) end
		local function refresh()
			valL.Text = summary()
			for opt, chk in pairs(checks) do tw(chk, 0.2, { TextTransparency = chosen[opt] and 0 or 1 }) end
		end
		local function setOpen(v)
			open = v
			tw(r, 0.38, { Size = UDim2.new(1, 0, 0, height()) })
			tw(chev, 0.3, { Rotation = v and 90 or 0 })
		end
		local function fire()
			if not cb then return end
			if multi then cb(selectedList()) else cb(selectedList()[1]) end
		end
		local function build()
			for _, b in ipairs(optBtns) do b:Destroy() end
			optBtns, checks = {}, {}
			for k, opt in ipairs(options) do
				local ob = new("TextButton", {
					Size = UDim2.new(1, 0, 0, 38), Position = UDim2.fromOffset(0, 44 + (k - 1) * 38), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = r,
				})
				optBtns[#optBtns + 1] = ob
				local ln = new("Frame", { Size = UDim2.new(1, -28, 0, 1), Position = UDim2.fromOffset(14, 0), BorderSizePixel = 0, Parent = ob })
				bind(ln, "BackgroundColor3", "line")
				text(ob, opt, 13, Enum.FontWeight.Medium, "text", { Position = UDim2.fromOffset(24, 0), Size = UDim2.new(1, -60, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
				checks[opt] = text(ob, "✓", 16, Enum.FontWeight.Bold, "accent", {
					AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(20, 20),
					TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = chosen[opt] and 0 or 1,
				})
				tap(ob, function()
					if multi then
						chosen[opt] = not chosen[opt] or nil
						refresh()
						fire()
					else
						chosen = { [opt] = true }
						refresh()
						fire()
						task.delay(0.15, function() setOpen(false) end)
					end
				end)
			end
			if open then r.Size = UDim2.new(1, 0, 0, height()) end
			valL.Text = summary()
		end
		build()
		valL.Text = summary()
		local hd, hu = hlFX(hl)
		local head = new("TextButton", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = r })
		tap(head, function() setOpen(not open) end, hd, hu)
		local obj = {}
		function obj.Get()
			if multi then return selectedList() end
			return selectedList()[1]
		end
		function obj.Set(v, silent)
			chosen = {}
			if multi then
				for _, d in ipairs(type(v) == "table" and v or {}) do chosen[tostring(d)] = true end
			elseif v ~= nil then
				chosen[tostring(v)] = true
			end
			refresh()
			if not silent then fire() end
		end
		function obj.SetOptions(list, silent)
			options = {}
			for _, x in ipairs(list or {}) do options[#options + 1] = tostring(x) end
			local keep = {}
			for _, x in ipairs(options) do if chosen[x] then keep[x] = true end end
			chosen = keep
			build()
			if not silent then fire() end
		end
		function obj.GetOptions() return table.clone(options) end
		function obj.SetName(n) nameL.Text = n end
		function obj.Open(v) setOpen(v and true or false) end
		return finish(r, obj, o, multi and "list" or "choice")
	end

	-- Segmented ----------------------------------------------------------
	local function Segmented(sec, o)
		local opts, cb = o.Options or {}, o.Callback
		local r = Row(sec, o.Name and 66 or 44)
		local cur = type(o.Default) == "number" and o.Default or table.find(opts, o.Default) or 1
		local seg
		local function onSel(i, n)
			cur = i
			if cb then cb(n) end
		end
		if o.Name then
			text(r, o.Name, 14, Enum.FontWeight.Medium, "text", { Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 20) })
			seg = makeSegmented(r, opts, cur, onSel, UDim2.new(1, -28, 0, 28), UDim2.fromOffset(14, 32), 12)
		else
			seg = makeSegmented(r, opts, cur, onSel, UDim2.new(1, -28, 0, 30), UDim2.fromOffset(14, 7), 13)
		end
		local obj = {}
		function obj.Get() return opts[cur] end
		function obj.Set(v, silent)
			local idx = type(v) == "number" and v or table.find(opts, v)
			if not idx then return end
			cur = idx
			seg.Set(idx, silent)
		end
		return finish(r, obj, o, "choice")
	end

	-- Input (label left, field right, lifts the window above the keyboard) --
	local function Input(sec, o)
		local name, cb = o.Name or "Input", o.Callback
		local r = Row(sec)
		local lab = text(r, name, 14, Enum.FontWeight.Medium, "text", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0.4, -14, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
		local tb = new("TextBox", {
			Size = UDim2.new(0.6, -28, 0, 30), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), BorderSizePixel = 0,
			Text = o.Default and tostring(o.Default) or "", PlaceholderText = o.Placeholder or "Type…", TextSize = 13, FontFace = font(Enum.FontWeight.Medium),
			ClearTextOnFocus = o.ClearOnFocus and true or false, TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Center,
			ClipsDescendants = true, Parent = r,
		})
		bind(tb, "BackgroundColor3", "card2")
		bind(tb, "TextColor3", "text")
		bind(tb, "PlaceholderColor3", "sub")
		corner(tb, "rCtl")
		new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = tb })
		local st = new("UIStroke", { Thickness = 1.5, Transparency = 1, Parent = tb })
		bind(st, "Color", "accent")
		local lifted
		tb.Focused:Connect(function()
			tw(st, 0.2, { Transparency = 0 })
			if UIS.TouchEnabled and state == "open" then
				lifted = winPos
				winPos = clampWin(Vector2.new(winPos.X, 6))
				tw(win, 0.3, { Position = posU(winPos) })
			end
		end)
		tb.FocusLost:Connect(function(enter)
			tw(st, 0.25, { Transparency = 1 })
			if lifted then
				winPos = clampWin(lifted)
				lifted = nil
				if state == "open" then tw(win, 0.3, { Position = posU(winPos) }) end
			end
			if cb then cb(tb.Text, enter) end
		end)
		local busy = false
		tb:GetPropertyChangedSignal("Text"):Connect(function()
			if busy then return end
			local t = tb.Text
			local nt = t
			if o.Numeric then nt = (nt:gsub("[^%d%.%-]", "")) end
			if o.MaxLength and #nt > o.MaxLength then nt = nt:sub(1, o.MaxLength) end
			if nt ~= t then
				busy = true
				tb.Text = nt
				busy = false
			end
			if o.OnChange then o.OnChange(tb.Text) end
		end)
		local obj = { Box = tb }
		function obj.Get() return tb.Text end
		function obj.GetNumber() return tonumber(tb.Text) end
		function obj.Set(t, silent)
			tb.Text = tostring(t == nil and "" or t)
			if not silent and cb then cb(tb.Text, false) end
		end
		function obj.Focus() tb:CaptureFocus() end
		function obj.SetName(n) lab.Text = n end
		return finish(r, obj, o, "text")
	end

	-- Progress -----------------------------------------------------------
	local function Progress(sec, o)
		local name = o.Name or "Progress"
		local r = Row(sec, 58)
		local nameL = text(r, name, 14, Enum.FontWeight.Medium, "text", { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(0.6, 0, 0, 20) })
		local pct = text(r, "0%", 13, Enum.FontWeight.Medium, "sub", { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 20), TextXAlignment = Enum.TextXAlignment.Right })
		local bar = new("Frame", { Size = UDim2.new(1, -28, 0, 8), Position = UDim2.fromOffset(14, 38), BorderSizePixel = 0, Parent = r })
		bind(bar, "BackgroundColor3", "off")
		corner(bar)
		local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, Parent = bar })
		bind(fill, "BackgroundColor3", "accent")
		corner(fill)
		local nv = Instance.new("NumberValue")
		nv.Changed:Connect(function(v)
			fill.Size = UDim2.fromScale(v, 1)
			pct.Text = math.floor(v * 100 + 0.5) .. "%"
		end)
		local obj = {}
		function obj.Set(a, dur, style)
			tw(nv, dur or 0.4, { Value = math.clamp(a, 0, 1) }, style or Enum.EasingStyle.Quint)
		end
		function obj.Get() return nv.Value end
		function obj.SetName(n) nameL.Text = n end
		if o.Default then obj.Set(o.Default, 0) end
		return finish(r, obj, o, "progress")
	end

	-- ColorPicker --------------------------------------------------------
	local function ColorPicker(sec, o)
		local name, cb = o.Name or "Color", o.Callback
		local default = o.Default or Color3.new(1, 1, 1)
		local r = Row(sec)
		r.ClipsDescendants = true
		local hl = hlFrame(r)
		hl.Size = UDim2.new(1, 0, 0, 44)
		local lab = rowLabel(r, name)
		local h, s, v = default:ToHSV()
		local swatch = new("Frame", {
			Size = UDim2.fromOffset(26, 26), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -44, 0, 22), BorderSizePixel = 0, BackgroundColor3 = default, Parent = r,
		})
		corner(swatch)
		new("UIStroke", { Thickness = 1, Transparency = 0.7, Color = Color3.new(0.5, 0.5, 0.5), Parent = swatch })
		local chev = text(r, "›", 24, Enum.FontWeight.Medium, "sub", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -22, 0, 22), Size = UDim2.fromOffset(24, 24), TextXAlignment = Enum.TextXAlignment.Center,
		})
		local sGrad, vGrad
		local thumbs = {}
		local function refresh(fire)
			local c = Color3.fromHSV(h, s, v)
			swatch.BackgroundColor3 = c
			sGrad.Color = ColorSequence.new(Color3.fromHSV(h, 0, v), Color3.fromHSV(h, 1, v))
			vGrad.Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.fromHSV(h, s, 1))
			for _, t in ipairs(thumbs) do t.thumb.Position = UDim2.fromScale(t.get(), 0.5) end
			if fire and cb then cb(c) end
		end
		local function bar(y, getA, setA)
			local b = new("Frame", { Size = UDim2.new(1, -28, 0, 14), Position = UDim2.fromOffset(14, y), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), Parent = r })
			corner(b)
			local g = new("UIGradient", { Parent = b })
			local thumb = new("Frame", {
				Size = UDim2.fromOffset(20, 20), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(getA(), 0.5),
				BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), Parent = b,
			})
			corner(thumb)
			new("UIStroke", { Thickness = 1, Transparency = 0.7, Color = Color3.new(0, 0, 0), Parent = thumb })
			thumbs[#thumbs + 1] = { thumb = thumb, get = getA }
			local hit = new("TextButton", {
				Size = UDim2.new(1, 0, 0, 32), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = b,
			})
			local a0 = 0
			hDrag(hit, sec.page.scroll, function() a0 = getA() end, function(dx)
				setA(math.clamp(a0 + dx / math.max(b.AbsoluteSize.X, 1), 0, 1))
				refresh(true)
			end, function() end)
			return g
		end
		local hg = bar(54, function() return h end, function(a) h = math.min(a, 0.999) end)
		hg.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, RGB(255, 0, 0)), ColorSequenceKeypoint.new(1 / 6, RGB(255, 255, 0)),
			ColorSequenceKeypoint.new(2 / 6, RGB(0, 255, 0)), ColorSequenceKeypoint.new(3 / 6, RGB(0, 255, 255)),
			ColorSequenceKeypoint.new(4 / 6, RGB(0, 0, 255)), ColorSequenceKeypoint.new(5 / 6, RGB(255, 0, 255)),
			ColorSequenceKeypoint.new(1, RGB(255, 0, 0)),
		})
		sGrad = bar(90, function() return s end, function(a) s = a end)
		vGrad = bar(126, function() return v end, function(a) v = a end)
		refresh(false)
		local open = false
		local head = new("TextButton", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = r })
		local hd, hu = hlFX(hl)
		tap(head, function()
			open = not open
			tw(r, 0.38, { Size = UDim2.new(1, 0, 0, open and 154 or 44) })
			tw(chev, 0.3, { Rotation = open and 90 or 0 })
		end, hd, hu)
		local obj = {}
		function obj.Get() return Color3.fromHSV(h, s, v) end
		function obj.Set(c, silent)
			if typeof(c) == "string" then
				local ok, col = pcall(Color3.fromHex, c)
				if not ok then return end
				c = col
			end
			if typeof(c) ~= "Color3" then return end
			h, s, v = c:ToHSV()
			h = math.min(h, 0.999)
			refresh(not silent)
		end
		function obj.SetName(n) lab.Text = n end
		return finish(r, obj, o, "color")
	end

	-- Labels / paragraph / value -----------------------------------------
	local function Label(sec, o)
		local r = Row(sec, 0)
		r.Size = UDim2.new(1, 0, 0, 0)
		r.AutomaticSize = Enum.AutomaticSize.Y
		local l = text(r, o.Text or "", 12, Enum.FontWeight.Regular, o.Color or "sub", {
			Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true,
		})
		new("UIPadding", { PaddingTop = UDim.new(0, 11), PaddingBottom = UDim.new(0, 11), Parent = l })
		local obj = {}
		function obj.Get() return l.Text end
		function obj.Set(t) l.Text = tostring(t) end
		obj.SetText = obj.Set
		return finish(r, obj, o, "label")
	end

	local function Paragraph(sec, o)
		local r = Row(sec, 0)
		r.Size = UDim2.new(1, 0, 0, 0)
		r.AutomaticSize = Enum.AutomaticSize.Y
		local col = new("Frame", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = r,
		})
		new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = col })
		new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), Parent = col })
		local t1 = text(col, o.Title or "", 14, Enum.FontWeight.SemiBold, "text", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, LayoutOrder = 1 })
		local t2 = text(col, o.Content or "", 12, Enum.FontWeight.Regular, "sub", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, LayoutOrder = 2 })
		local obj = {}
		function obj.Get() return t2.Text end
		function obj.Set(t) t2.Text = tostring(t) end
		function obj.SetTitle(t) t1.Text = tostring(t) end
		return finish(r, obj, o, "label")
	end

	local function Value(sec, o)
		local r = Row(sec)
		local lab = rowLabel(r, o.Name or "Value")
		local l = text(r, tostring(o.Value or ""), 13, Enum.FontWeight.Medium, "sub", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0), TextXAlignment = Enum.TextXAlignment.Right })
		local obj = {}
		function obj.Get() return l.Text end
		function obj.Set(t) l.Text = tostring(t) end
		function obj.SetName(n) lab.Text = n end
		return finish(r, obj, o, "label")
	end

	local function Divider(sec, o)
		local r = Row(sec, 10)
		local obj = {}
		function obj.Get() return nil end
		function obj.Set() end
		return finish(r, obj, o or {}, "divider")
	end

	-- Keybind (Press / Toggle / Hold / None) -----------------------------
	local keybinds = {}
	local function keyOf(v)
		if typeof(v) == "EnumItem" then return v end
		if type(v) == "string" and v ~= "" and v ~= "None" then
			local ok, k = pcall(function() return Enum.KeyCode[v] end)
			if ok then return k end
		end
		return nil
	end

	local function Keybind(sec, o)
		local name, mode, cb, changed = o.Name or "Keybind", o.Mode or "Press", o.Callback, o.Changed
		local r = Row(sec)
		local hl = hlFrame(r)
		local lab = rowLabel(r, name)
		local btn = new("TextButton", {
			Size = UDim2.fromOffset(92, 28), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Text = "",
			AutoButtonColor = false, BorderSizePixel = 0, Parent = r,
		})
		bind(btn, "BackgroundColor3", "card2")
		corner(btn, "rCtl")
		local kl = text(btn, "None", 12, Enum.FontWeight.SemiBold, "sub", { TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd })
		local st = new("UIStroke", { Thickness = 1.5, Transparency = 1, Parent = btn })
		bind(st, "Color", "accent")
		local ks = new("UIScale", { Parent = btn })
		local key = keyOf(o.Default)
		local entry = { key = key }
		local active = false
		local function show(listen)
			kl.Text = listen and "…" or (key and key.Name or "None")
			tw(st, 0.2, { Transparency = listen and 0 or 1 })
		end
		local function assign(k, silent)
			key = k
			entry.key = k
			show(false)
			if not silent and changed then changed(k) end
		end
		entry.assign = function(k) assign(k) end
		entry.cancel = function() show(false) end
		entry.press = function()
			if mode == "Toggle" then
				active = not active
				if cb then cb(active) end
			elseif mode == "Hold" then
				active = true
				if cb then cb(true) end
			elseif mode == "Press" then
				if cb then cb(key and key.Name or nil) end
			end
		end
		entry.release = function()
			if mode == "Hold" and active then
				active = false
				if cb then cb(false) end
			end
		end
		entry.mode = mode
		keybinds[#keybinds + 1] = entry
		show(false)
		local hd, hu = hlFX(hl)
		tap(btn, function()
			if listening and listening ~= entry then listening.cancel() end
			listening = entry
			show(true)
		end, function() hd(); tw(ks, 0.1, { Scale = 0.92 }) end, function() hu(); tw(ks, 0.3, { Scale = 1 }, Enum.EasingStyle.Back) end)
		local obj = {}
		function obj.Get() return key and key.Name or "" end
		function obj.Set(v, silent) assign(keyOf(v), silent) end
		function obj.GetState() return active end
		function obj.SetName(n) lab.Text = n end
		obj._cleanup = function()
			local i = table.find(keybinds, entry)
			if i then table.remove(keybinds, i) end
			if listening == entry then listening = nil end
		end
		return finish(r, obj, o, "keybind")
	end

	C(UIS.InputBegan, function(i, gp)
		if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if listening then
			local e = listening
			listening = nil
			consumedKey = i
			local k = i.KeyCode
			if k == Enum.KeyCode.Escape then
				e.cancel()
			elseif k == Enum.KeyCode.Backspace or k == Enum.KeyCode.Delete then
				e.assign(nil)
			else
				e.assign(k)
			end
			return
		end
		if gp or UIS:GetFocusedTextBox() then return end
		for _, e in ipairs(keybinds) do
			if e.key == i.KeyCode then
				if e.mode ~= "None" then consumedKey = i end
				e.press()
			end
		end
	end)
	C(UIS.InputEnded, function(i)
		if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
		for _, e in ipairs(keybinds) do
			if e.key == i.KeyCode then e.release() end
		end
	end)

	----------------------------------------------------------------------
	-- NOTIFICATIONS (iOS-style banners, newest on top, they stack)
	----------------------------------------------------------------------
	local notifs = {}
	local NOTIF_H, NOTIF_GAP = 58, 8

	local function relayoutNotifs()
		local y = 10
		for _, n in ipairs(notifs) do
			if not n.dying then tw(n.f, 0.45, { Position = UDim2.new(0.5, 0, 0, y) }, Enum.EasingStyle.Back) end
			y += (NOTIF_H + NOTIF_GAP) * userScale
		end
	end

	local function dismissNotif(n)
		if n.dying then return end
		n.dying = true
		local i = table.find(notifs, n)
		if i then table.remove(notifs, i) end
		tw(n.f, 0.4, { Position = UDim2.new(0.5, 0, 0, -140) })
		tw(n.f, 0.3, { GroupTransparency = 1 })
		task.delay(0.45, function() n.f:Destroy() end)
		relayoutNotifs()
	end

	local NOTIF_KINDS = {
		success = { glyph = "✓", color = function() return Th.on end },
		error = { glyph = "✕", color = function() return Th.danger end },
		warn = { glyph = "!", color = function() return RGB(255, 159, 10) end },
		info = { glyph = "i", color = function() return Th.accent end },
	}

	local function Notify(title, body, dur, kind)
		while #notifs >= 4 do dismissNotif(notifs[#notifs]) end
		local f = new("CanvasGroup", {
			Size = UDim2.fromOffset(math.min(300, (vp().X - 24) / userScale), NOTIF_H), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -140),
			BackgroundTransparency = 0.05, GroupTransparency = 1, ZIndex = 100, Parent = gui,
		})
		new("UIScale", { Scale = userScale, Parent = f })
		bind(f, "BackgroundColor3", "card")
		corner(f, "rCard")
		local fs = new("UIStroke", { Thickness = 1, Transparency = 0.4, Parent = f })
		bind(fs, "Color", "line")
		local k = NOTIF_KINDS[kind or ""]
		local icon = new("Frame", { Size = UDim2.fromOffset(32, 32), Position = UDim2.fromOffset(12, 13), BorderSizePixel = 0, Parent = f })
		if k then bind(icon, "BackgroundColor3", k.color) else bind(icon, "BackgroundColor3", "accent") end
		corner(icon, "rCtl")
		local glyph = k and k.glyph or string.upper(string.sub(Window.Title or "N", 1, 1))
		text(icon, glyph, 16, Enum.FontWeight.Bold, Color3.new(1, 1, 1), { TextXAlignment = Enum.TextXAlignment.Center })
		text(f, title or "", 13, Enum.FontWeight.Bold, "text", { Position = UDim2.fromOffset(54, 9), Size = UDim2.new(1, -66, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
		text(f, body or "", 12, Enum.FontWeight.Regular, "sub", { Position = UDim2.fromOffset(54, 29), Size = UDim2.new(1, -66, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
		local n = { f = f }
		table.insert(notifs, 1, n)
		relayoutNotifs()
		tw(f, 0.25, { GroupTransparency = 0 })
		task.delay(dur or 2.6, function() dismissNotif(n) end)
		return n
	end

	----------------------------------------------------------------------
	-- CONFIG MANAGER (flags -> JSON; files when the executor has them, memory otherwise)
	----------------------------------------------------------------------
	local folder = opts.ConfigFolder or ("NovaUI/" .. (title:gsub("[^%w_%-]", "_")))
	local hasFS = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
	local mem = Nova._mem

	local function encV(v)
		if typeof(v) == "Color3" then return { __color = v:ToHex() } end
		return v
	end
	local function decV(v)
		if type(v) == "table" and v.__color then
			local ok, c = pcall(Color3.fromHex, v.__color)
			if ok then return c end
		end
		return v
	end
	local function ensureFolder()
		if not hasFS or type(isfolder) ~= "function" or type(makefolder) ~= "function" then return end
		local path = ""
		for seg in string.gmatch(folder, "[^/]+") do
			path = path == "" and seg or (path .. "/" .. seg)
			if not isfolder(path) then pcall(makefolder, path) end
		end
	end
	local function cfgPath(n) return folder .. "/" .. n .. ".json" end
	local function cleanName(n)
		n = tostring(n or ""):gsub("[^%w_%- ]", ""):gsub("^%s+", ""):gsub("%s+$", "")
		return n
	end

	local function cfgSnapshot()
		local data = {}
		for k, f in pairs(flags) do
			local ok, v = pcall(f.get)
			if ok and v ~= nil then data[k] = encV(v) end
		end
		return HttpService:JSONEncode(data)
	end

	local function cfgSave(name)
		name = cleanName(name)
		if name == "" then return false, "empty name" end
		local okJ, json = pcall(cfgSnapshot)
		if not okJ then return false, "encode failed" end
		if hasFS then
			ensureFolder()
			local ok, err = pcall(writefile, cfgPath(name), json)
			return ok, err
		end
		mem[folder .. "/" .. name] = json
		return true
	end

	local function cfgLoad(name)
		name = cleanName(name)
		if name == "" then return false, "empty name" end
		local json
		if hasFS then
			if not isfile(cfgPath(name)) then return false, "not found" end
			local ok, res = pcall(readfile, cfgPath(name))
			if not ok then return false, "read failed" end
			json = res
		else
			json = mem[folder .. "/" .. name]
			if not json then return false, "not found" end
		end
		local ok, data = pcall(function() return HttpService:JSONDecode(json) end)
		if not ok or type(data) ~= "table" then return false, "bad file" end
		local keys = {}
		for k in pairs(data) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b)
			local ia, ib = a:sub(1, 1) == "_", b:sub(1, 1) == "_"
			if ia ~= ib then return ia end
			return a < b
		end)
		for _, k in ipairs(keys) do
			local f = flags[k]
			if f then pcall(f.set, decV(data[k])) end
		end
		return true
	end

	local function cfgList()
		local list = {}
		if hasFS and type(listfiles) == "function" then
			ensureFolder()
			local ok, files = pcall(listfiles, folder)
			if ok then
				for _, p in ipairs(files) do
					local n = tostring(p):match("([^/\\]+)%.json$")
					if n then list[#list + 1] = n end
				end
			end
		else
			local prefix = folder .. "/"
			for k in pairs(mem) do
				if k:sub(1, #prefix) == prefix and k ~= prefix .. "_auto" then list[#list + 1] = k:sub(#prefix + 1) end
			end
		end
		table.sort(list)
		return list
	end

	local function cfgDelete(name)
		name = cleanName(name)
		if hasFS and type(delfile) == "function" then
			if isfile(cfgPath(name)) then return pcall(delfile, cfgPath(name)) end
			return false, "not found"
		end
		mem[folder .. "/" .. name] = nil
		return true
	end

	local function cfgSetAuto(name)
		name = name and cleanName(name) or ""
		if hasFS then
			ensureFolder()
			pcall(writefile, folder .. "/_auto.txt", name)
		else
			mem[folder .. "/_auto"] = name
		end
	end
	local function cfgGetAuto()
		local n
		if hasFS then
			if isfile(folder .. "/_auto.txt") then
				local ok, res = pcall(readfile, folder .. "/_auto.txt")
				if ok then n = res end
			end
		else
			n = mem[folder .. "/_auto"]
		end
		if n and n ~= "" then return n end
		return nil
	end

	----------------------------------------------------------------------
	-- MINI PILL (bubble) + EDGE HINT
	----------------------------------------------------------------------
	local showFps = true
	local pill = new("CanvasGroup", {
		Size = UDim2.fromOffset(PILL.X, PILL.Y), BackgroundTransparency = 0.05, GroupTransparency = 1, Visible = false, Active = true, Parent = gui,
	})
	bind(pill, "BackgroundColor3", "bg")
	corner(pill)
	local pst = new("UIStroke", { Thickness = 1, Transparency = 0.3, Parent = pill })
	bind(pst, "Color", "line")
	local pillScale = new("UIScale", { Parent = pill })
	local dot = new("Frame", { Size = UDim2.fromOffset(8, 8), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), BorderSizePixel = 0, Parent = pill })
	bind(dot, "BackgroundColor3", "on")
	corner(dot)
	local pillText = text(pill, title, 13, Enum.FontWeight.SemiBold, "text", { Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -38, 1, 0) })
	local pillBtn = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = pill })

	local hint = new("Frame", {
		Size = UDim2.fromOffset(4, 46), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -2, 0.5, 0), BorderSizePixel = 0, BackgroundTransparency = 1, Parent = gui,
	})
	bind(hint, "BackgroundColor3", "sub")
	corner(hint)
	local hintL = new("Frame", {
		Size = UDim2.fromOffset(4, 46), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), BorderSizePixel = 0, BackgroundTransparency = 1, Parent = gui,
	})
	bind(hintL, "BackgroundColor3", "sub")
	corner(hintL)
	local function updateHint()
		hint.Position = UDim2.new(1, -2, QS.zonePct / 100, 0)
		tw(hint, 0.3, { BackgroundTransparency = (QS.enabled and QS.showLine) and 0.45 or 1 })
		tw(hintL, 0.3, { BackgroundTransparency = (QS.openEdge ~= "Right" and QS.showLine) and 0.45 or 1 })
	end
	updateHint()

	local pillTok = 0
	local function showPill()
		pillTok += 1
		pillPos = clampBox(pillPos, pillVis())
		pill.Position = posU(pillPos)
		pill.Visible = true
		pillScale.Scale = 0.6 * userScale
		tw(pill, 0.3, { GroupTransparency = 0 })
		tw(pillScale, 0.5, { Scale = userScale }, Enum.EasingStyle.Back)
	end
	local function hidePill()
		pillTok += 1
		local t = pillTok
		tw(pill, 0.25, { GroupTransparency = 1 })
		tw(pillScale, 0.25, { Scale = 0.7 * userScale })
		task.delay(0.3, function() if pillTok == t then pill.Visible = false end end)
	end

	----------------------------------------------------------------------
	-- WINDOW STATE MACHINE  (open / mini / hidden)
	----------------------------------------------------------------------
	local lastSide = "right"
	local function sideX(side)
		if side == "left" then return -winVis().X - 16 end
		return vp().X + 16
	end
	local function hiddenPos(side) return Vector2.new(sideX(side or lastSide), winPos.Y) end

	openWindow = function(side)
		if state == "open" then return end
		if side then lastSide = side end
		local prev = state
		token += 1
		state = "open"
		layoutSize()
		winPos = clampWin(winPos)
		win.Visible = true
		local sp, ss
		if prev == "mini" then sp, ss = pillPos, userScale * 0.25 else sp, ss = hiddenPos(), userScale * 0.96 end
		win.Position = posU(sp)
		win.GroupTransparency = 1
		winScale.Scale = ss
		tw(win, 0.5, { Position = posU(winPos) })
		tw(win, 0.3, { GroupTransparency = 0 })
		tw(winScale, 0.5, { Scale = userScale }, Enum.EasingStyle.Back)
		hidePill()
	end

	closeWindow = function(to, side)
		if state ~= "open" then return end
		if side then lastSide = side end
		token += 1
		local t = token
		state = to
		if to == "mini" then
			pillPos = clampBox(pillPos, pillVis())
			tw(win, 0.38, { Position = posU(pillPos), GroupTransparency = 1 })
			tw(winScale, 0.38, { Scale = userScale * 0.2 })
			showPill()
		else
			tw(win, 0.38, { Position = posU(hiddenPos()), GroupTransparency = 1 })
			hidePill()
		end
		task.delay(0.42, function()
			if token == t then win.Visible = false; winScale.Scale = userScale end
		end)
	end

	-- header drag + fling-to-hide
	header.InputBegan:Connect(function(i)
		if not isPress(i) or state ~= "open" or not lockFree() then return end
		local start, sp, hist = V2(i), winPos, {}
		capture(i, function(p)
			winPos = clampWin(sp + (p - start))
			win.Position = posU(winPos)
			hist[#hist + 1] = { os.clock(), p.X }
			if #hist > 8 then table.remove(hist, 1) end
		end, function()
			local n = #hist
			if n >= 2 then
				local a, b = hist[1], hist[n]
				local dt = b[1] - a[1]
				local vx = (b[2] - a[2]) / math.max(dt, 0.001)
				if os.clock() - b[1] < 0.1 and dt > 0.01 and math.abs(vx) > 1100 then
					local dir = vx > 0 and "right" or "left"
					if QS.closeSwipe == "Both" or string.lower(QS.closeSwipe) == dir then closeWindow("hidden", dir) end
				end
			end
		end)
	end)

	-- pill drag / tap
	pillBtn.InputBegan:Connect(function(i)
		if not isPress(i) or not lockFree() then return end
		local start, sp, moved = V2(i), pillPos, false
		tw(pillScale, 0.1, { Scale = 0.94 * userScale })
		capture(i, function(p)
			local d = p - start
			if d.Magnitude > 7 then moved = true end
			if moved then
				pillPos = clampBox(sp + d, pillVis())
				pill.Position = posU(pillPos)
			end
		end, function()
			tw(pillScale, 0.3, { Scale = userScale }, Enum.EasingStyle.Back)
			if not moved then openWindow() end
		end)
	end)

	-- FPS on the pill
	do
		local acc, frames = 0, 0
		C(RunService.Heartbeat, function(dt)
			acc += dt
			frames += 1
			if acc >= 0.5 then
				pillText.Text = showFps and (title .. " · " .. math.floor(frames / acc + 0.5) .. " FPS") or title
				acc, frames = 0, 0
			end
		end)
	end

	----------------------------------------------------------------------
	-- >>> QUICK ACCESS PICKER (edge drag -> centered box, release to run)
	----------------------------------------------------------------------

	local function qsList()
		local list = {}
		for _, lbl in ipairs(QA.order) do
			if byLabel[lbl] then list[#list + 1] = byLabel[lbl] end
		end
		return list
	end

	local function qsCounter(m)
		if m.cancel then
			m.counter.Text = "Cancel"
			m.counter.TextColor3 = Th.danger
		else
			m.counter.Text = m.idx .. "/" .. m.n
			m.counter.TextColor3 = Th.sub
		end
	end

	local function qsStep(dt)
		local m = QSel.m
		if not m then return end
		local sp = QS.speed
		m.pos += (m.target - m.pos) * (1 - math.exp(-dt * 14 * sp))
		m.cancelAmt += ((m.cancel and 1 or 0) - m.cancelAmt) * (1 - math.exp(-dt * 12 * sp))
		m.pulse *= math.exp(-dt * 9)
		m.hl.BackgroundColor3 = (QS.hl or Th.accent):Lerp(Th.danger, m.cancelAmt)
		m.hlScale.Scale = 1 + m.pulse
		local half = m.rows / 2
		local white = Color3.new(1, 1, 1)
		for k, it in ipairs(m.items) do
			local d = k - m.pos
			local ad = math.abs(d)
			if ad > half + 1 then
				it.f.Visible = false
			else
				it.f.Visible = true
				it.f.Position = UDim2.new(0, 10, 0, m.LH / 2 + d * m.rowH)
				local selAmt = math.clamp(1 - ad, 0, 1)
				local scale, alpha = 1, 1
				if QS.wheel then
					scale = math.max(1 - 0.07 * ad, 0.6)
					alpha = 1 - math.clamp(ad / (half + 0.6), 0, 1) ^ 2.2
				else
					alpha = 1 - math.clamp(ad - (half - 0.3), 0, 1)
				end
				it.sc.Scale = scale
				local tr = 1 - alpha
				it.name.TextColor3 = Th.text:Lerp(white, selAmt)
				it.name.TextTransparency = tr
				if it.setIcon then it.setIcon(alpha) end
				if QS.showState then
					if it.e.state then
						local on = it.e.state()
						it.stateL.Text = on and "On" or "Off"
						if it.dot then
							it.dot.BackgroundColor3 = on and Th.on or Th.off
							it.dot.BackgroundTransparency = tr
						end
					else
						it.stateL.Text = "Run"
					end
					it.stateL.TextColor3 = Th.sub:Lerp(white, selAmt)
					it.stateL.TextTransparency = tr
				end
			end
		end
	end

	local qsClose

	local function qsOpen(p)
		if QSel.m then return nil end
		local list = qsList()
		local n = #list
		if n == 0 then
			Notify("Quick Access", "Add choices in Settings → Quick Access first")
			return nil
		end
		local v = vp()
		local sp = QS.speed
		local ds = userScale
		local rowH = QS.rowH
		local rows = QS.rows
		if rows % 2 == 0 then rows += 1 end
		rows = math.min(rows, (n % 2 == 1) and n or (n + 1))
		local HEAD, FOOT = 34, QS.showHint and 26 or 8
		while rows > 3 and (HEAD + rows * rowH + FOOT + 10) * ds > v.Y - 24 do rows -= 2 end
		local LH = rows * rowH
		local W = math.min(QS.width, (v.X - 24) / ds)
		local H = HEAD + LH + FOOT + 10
		local cx = v.X / 2
		if QS.pos == "Right" then cx = v.X - W * ds / 2 - 70 elseif QS.pos == "Left" then cx = W * ds / 2 + 70 end
		cx = math.clamp(cx, W * ds / 2 + 8, v.X - W * ds / 2 - 8)
		local cy = math.clamp(v.Y / 2 + QS.offY, H * ds / 2 + 8, v.Y - H * ds / 2 - 8)

		local dim = new("Frame", {
			Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 28, Parent = gui,
		})
		tw(dim, 0.3 / sp, { BackgroundTransparency = 1 - QS.dim / 100 })

		local box = new("CanvasGroup", {
			Size = UDim2.fromOffset(W, H), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, v.Y + H * ds / 2 + 30),
			BackgroundTransparency = QS.boxAlpha / 100, GroupTransparency = 1, ZIndex = 30, Parent = gui,
		})
		bind(box, "BackgroundColor3", "bg")
		if QS.radius > 0 then
			new("UICorner", { CornerRadius = UDim.new(0, QS.radius), Parent = box })
		else
			corner(box, "rWin")
		end
		local bst = new("UIStroke", { Thickness = 1, Transparency = 0.3, Parent = box })
		bind(bst, "Color", "line")
		local boxScale = new("UIScale", { Scale = 0.92 * ds, Parent = box })

		text(box, "QUICK ACCESS", 11, Enum.FontWeight.SemiBold, "sub", { Position = UDim2.fromOffset(16, 10), Size = UDim2.new(0.6, 0, 0, 16) })
		local counter = text(box, "", 12, Enum.FontWeight.SemiBold, "sub", {
			Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, -16, 0, 16), TextXAlignment = Enum.TextXAlignment.Right, Visible = QS.showCount,
		})
		local listF = new("Frame", { Position = UDim2.fromOffset(0, HEAD), Size = UDim2.new(1, 0, 0, LH), BackgroundTransparency = 1, ClipsDescendants = true, Parent = box })
		local hl = new("Frame", {
			Size = UDim2.new(1, -20, 0, rowH - 6), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0, LH / 2), BorderSizePixel = 0, Parent = listF,
		})
		corner(hl, "rCtl")
		local hlScale = new("UIScale", { Parent = hl })
		local hintText = QS.cancelOn and "Release to select  ·  swipe left to cancel" or "Release to select"
		local hintL = text(box, hintText, 11, Enum.FontWeight.Medium, "sub", {
			Position = UDim2.fromOffset(0, HEAD + LH + 2), Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, Visible = QS.showHint,
		})

		local items = {}
		for k, e in ipairs(list) do
			local f = new("Frame", {
				Size = UDim2.new(1, -20, 0, rowH), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0, LH / 2), BackgroundTransparency = 1, Visible = false, Parent = listF,
			})
			local it = { f = f, e = e, sc = new("UIScale", { Parent = f }) }
			local textX = 16
			local ic = QuickIcons[e.name] or e.icon
			if ic ~= nil then ic = tostring(ic) end
			if ic then
				textX = 44
				if string.find(ic, "rbxasset") then
					local img = new("ImageLabel", {
						BackgroundTransparency = 1, Image = ic, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.fromOffset(22, 22), Parent = f,
					})
					it.setIcon = function(a) img.ImageTransparency = 1 - a end
				else
					local t = new("TextLabel", {
						BackgroundTransparency = 1, Text = ic, TextSize = 18, FontFace = font(), AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.fromOffset(24, 24), Parent = f,
					})
					bind(t, "TextColor3", "text")
					it.setIcon = function(a) t.TextTransparency = 1 - a end
				end
			elseif e.state and QS.showState then
				textX = 32
				it.dot = new("Frame", { Size = UDim2.fromOffset(8, 8), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 0), BorderSizePixel = 0, Parent = f })
				corner(it.dot)
			end
			it.name = new("TextLabel", {
				BackgroundTransparency = 1, Text = e.name, TextSize = QS.textSize, FontFace = font(Enum.FontWeight.SemiBold),
				TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(textX, 0), Size = UDim2.new(1, -(textX + 70), 1, 0), Parent = f,
			})
			it.stateL = new("TextLabel", {
				BackgroundTransparency = 1, Text = "", TextSize = math.max(QS.textSize - 2, 10), FontFace = font(Enum.FontWeight.Medium),
				TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 0),
				Size = UDim2.fromOffset(60, rowH), Parent = f,
			})
			items[k] = it
		end

		-- start index + adaptive sensitivity (finger never has to leave the screen)
		local si = 1
		if QS.startFrom == "Last used" and QA.last then si = math.clamp(QA.last, 1, n)
		elseif QS.startFrom == "Middle" then si = math.ceil(n / 2) end
		local dirS = QS.direction == "Down" and 1 or -1
		local stepsFwd = (dirS == 1) and (n - si) or (si - 1)
		local stepsBack = (dirS == 1) and (si - 1) or (n - si)
		local screenH = cam.ViewportSize.Y
		local px = math.min(QS.travel, screenH * 0.7) / math.max(n - 1, 1)
		local availF = (dirS == 1) and (screenH - 24 - p.Y) or (p.Y - 24)
		local availB = (dirS == 1) and (p.Y - 24) or (screenH - 24 - p.Y)
		if stepsFwd > 0 then px = math.min(px, math.max(availF, 30) / stepsFwd) end
		if stepsBack > 0 then px = math.min(px, math.max(availB, 30) / stepsBack) end
		px = math.max(px, 2)

		local m = {
			list = list, n = n, rows = rows, rowH = rowH, LH = LH, H = H, cx = cx, box = box, dim = dim, boxScale = boxScale,
			hl = hl, hlScale = hlScale, counter = counter, hintL = hintL, hintText = hintText, items = items,
			idx = si, target = si, pos = si, startIdx = si, startY = p.Y, startX = p.X, px = px, dirS = dirS,
			pulse = 0, cancel = false, cancelAmt = 0, closing = false,
		}
		QSel.m = m
		qsCounter(m)
		m.pulse = 0.05
		m.conn = RunService.RenderStepped:Connect(qsStep)
		qsStep(1 / 60)

		tw(box, 0.55 / sp, { Position = UDim2.fromOffset(cx, cy) }, Enum.EasingStyle.Back)
		tw(box, 0.25 / sp, { GroupTransparency = 0 })
		tw(boxScale, 0.5 / sp, { Scale = ds }, Enum.EasingStyle.Back)
		tw(hint, 0.2, { Size = UDim2.fromOffset(6, 120), BackgroundTransparency = 0.05, BackgroundColor3 = Th.accent })
		return m
	end

	local function qsMove(p)
		local m = QSel.m
		if not m or m.closing then return end
		local raw = m.startIdx + ((p.Y - m.startY) * m.dirS) / m.px
		local idx = math.clamp(math.floor(raw + 0.5), 1, m.n)
		if idx ~= m.idx then
			m.idx = idx
			m.pulse = 0.05
			qsCounter(m)
		end
		local tgt = idx
		if raw < 1 then tgt = 1 + math.max(raw - 1, -3) * 0.1
		elseif raw > m.n then tgt = m.n + math.min(raw - m.n, 3) * 0.1 end
		m.target = tgt
		local cancel = QS.cancelOn and (m.startX - p.X) > QS.cancelDist
		if cancel ~= m.cancel then
			m.cancel = cancel
			m.hintL.Text = cancel and "Release to cancel" or m.hintText
			qsCounter(m)
		end
	end

	qsClose = function(ran)
		local m = QSel.m
		if not m or m.closing then return end
		m.closing = true
		local sp = QS.speed
		task.delay(ran and 0.16 or 0, function()
			if QSel.m ~= m then return end
			tw(m.box, 0.38 / sp, { Position = UDim2.fromOffset(m.cx, vp().Y + m.H * userScale / 2 + 30) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
			tw(m.box, 0.28 / sp, { GroupTransparency = 1 })
			tw(m.boxScale, 0.35 / sp, { Scale = 0.94 * userScale })
			tw(m.dim, 0.3 / sp, { BackgroundTransparency = 1 })
			tw(hint, 0.3, { Size = UDim2.fromOffset(4, 46), BackgroundColor3 = Th.sub })
			updateHint()
			task.delay(0.42 / sp, function()
				if m.conn then m.conn:Disconnect() end
				m.box:Destroy()
				m.dim:Destroy()
				if QSel.m == m then QSel.m = nil end
			end)
		end)
	end

	local function qsRelease()
		local m = QSel.m
		if not m or m.closing then return end
		if m.cancel then
			qsClose(false)
			return
		end
		local e = m.list[m.idx]
		QA.last = m.idx
		m.pulse = 0.14
		task.spawn(e.run)
		qsClose(true)
	end

	local function qsPreview()
		if QSel.m then return end
		local v = cam.ViewportSize
		local m = qsOpen(Vector2.new(v.X - 20, v.Y / 2))
		if not m then return end
		task.spawn(function()
			task.wait(0.7 / QS.speed)
			for k = 1, m.n do
				if QSel.m ~= m or m.closing then return end
				m.idx, m.target, m.pulse = k, k, 0.05
				qsCounter(m)
				task.wait(0.42 / QS.speed)
			end
			task.wait(0.3)
			qsClose(false)
		end)
	end

	-- >>> EDGE GESTURES: swipe inward = open window (right/left edge), vertical drag on the edge line = Quick Access
	C(UIS.InputBegan, function(i, gp)
		if i.UserInputType == Enum.UserInputType.Keyboard then
			if toggleKey and i.KeyCode == toggleKey and consumedKey ~= i and not listening and not UIS:GetFocusedTextBox() then
				if state == "open" then closeWindow("mini") else openWindow() end
			end
			return
		end
		if gp or not isPress(i) or swiping or QSel.m or not lockFree() then return end
		local sz = vp()
		local axl = gui.AbsolutePosition.X
		local zoneCY = gui.AbsolutePosition.Y + sz.Y * QS.zonePct / 100
		local fromRight = (axl + sz.X) - i.Position.X <= QS.zoneW
		local fromLeft = i.Position.X - axl <= QS.zoneW
		if not fromRight and not fromLeft then return end
		local side = fromRight and "right" or "left"
		local inZone = fromRight and QS.enabled and math.abs(i.Position.Y - zoneCY) <= QS.zoneH / 2
		local sideOk = (side == "right" and QS.openEdge ~= "Left") or (side == "left" and QS.openEdge ~= "Right")
		local canWindow = state ~= "open" and sideOk
		if not inZone and not canWindow then return end
		local start, mode, prog = V2(i), nil, 0
		local width = win.Size.X.Offset * userScale
		local sgn = (side == "right") and -1 or 1
		capture(i, function(p)
			local d = p - start
			local along = d.X * sgn
			if mode == nil then
				if d.Magnitude < 8 then return end
				if along > math.abs(d.Y) and canWindow then
					mode = "window"
					swiping = true
					token += 1
					lastSide = side
					layoutSize()
					winPos = clampWin(winPos)
					win.Visible = true
					win.GroupTransparency = 1
					winScale.Scale = userScale
				elseif inZone and math.abs(d.Y) >= along then
					mode = qsOpen(p) and "quick" or "none"
				else
					mode = "none"
				end
			end
			if mode == "window" then
				prog = math.clamp(along / (width * 0.9), 0, 1)
				local e = 1 - (1 - prog) ^ 2
				local hx = sideX(side)
				win.Position = posU(Vector2.new(hx + (winPos.X - hx) * e, winPos.Y))
				win.GroupTransparency = 1 - prog
			elseif mode == "quick" then
				qsMove(p)
			end
		end, function()
			if mode == "quick" then
				qsRelease()
				return
			end
			swiping = false
			if mode ~= "window" then return end
			token += 1
			local t = token
			if prog > 0.3 then
				state = "open"
				tw(win, 0.4, { Position = posU(winPos), GroupTransparency = 0 })
				hidePill()
			else
				tw(win, 0.3, { Position = posU(hiddenPos(side)), GroupTransparency = 1 })
				task.delay(0.35, function() if token == t and state ~= "open" then win.Visible = false end end)
			end
		end)
	end)

	-- keep everything on screen if the viewport changes
	C(gui:GetPropertyChangedSignal("AbsoluteSize"), function()
		layoutSize()
		winPos = clampWin(winPos)
		pillPos = clampBox(pillPos, pillVis())
		updateHint()
		if state == "open" then win.Position = posU(winPos) end
		if state == "mini" then pill.Position = posU(pillPos) end
	end)

	----------------------------------------------------------------------
	-- >>> HEADER MENU (⋯) + GESTURES & QUICK ACCESS PAGE
	----------------------------------------------------------------------
	local openSub, closeSub
	local sketchAPI

	-- three-dots button
	local dotsBtn = new("TextButton", {
		Size = UDim2.fromOffset(30, 30), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -82, 0, 12),
		Text = "", AutoButtonColor = false, BorderSizePixel = 0, Parent = header,
	})
	bind(dotsBtn, "BackgroundColor3", "card2")
	corner(dotsBtn)
	for k = 0, 2 do
		local d = new("Frame", { Size = UDim2.fromOffset(4, 4), Position = UDim2.fromOffset(7 + k * 6, 13), BorderSizePixel = 0, Parent = dotsBtn })
		bind(d, "BackgroundColor3", "sub")
		corner(d)
	end
	local dotsScale = new("UIScale", { Parent = dotsBtn })

	-- popover with the word "Settings"
	local catcher = new("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 40, Parent = win,
	})
	local pop = new("CanvasGroup", {
		Size = UDim2.fromOffset(150, 46), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 50),
		BackgroundTransparency = 0, GroupTransparency = 1, Visible = false, ZIndex = 41, Parent = win,
	})
	bind(pop, "BackgroundColor3", "card")
	corner(pop, "rCard")
	local popStroke = new("UIStroke", { Thickness = 1, Transparency = 0.3, Parent = pop })
	bind(popStroke, "Color", "line")
	local popScale = new("UIScale", { Scale = 0.85, Parent = pop })
	local popHl = hlFrame(pop)
	text(pop, "Settings", 14, Enum.FontWeight.Medium, "text", { Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -32, 1, 0) })
	local popItem = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = pop })

	local popOpen = false
	local function setPop(o)
		popOpen = o
		if o then
			catcher.Visible = true
			pop.Visible = true
			tw(pop, 0.2, { GroupTransparency = 0 })
			tw(popScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		else
			catcher.Visible = false
			tw(pop, 0.18, { GroupTransparency = 1 })
			tw(popScale, 0.2, { Scale = 0.88 })
			task.delay(0.2, function() if not popOpen then pop.Visible = false end end)
		end
	end
	tap(dotsBtn, function() setPop(not popOpen) end,
		function() tw(dotsScale, 0.1, { Scale = 0.88 }) end,
		function() tw(dotsScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back) end)
	tap(catcher, function() setPop(false) end)
	do
		local hd, hu = hlFX(popHl)
		tap(popItem, function() setPop(false); openSub() end, hd, hu)
	end

	-- Radio list (device-settings style)
	local function Radio(sec, opts, default, cb)
		local selected = default
		local obj, ups = {}, {}
		for _, o in ipairs(opts) do
			local r = Row(sec, 0)
			r.AutomaticSize = Enum.AutomaticSize.Y
			local hl = hlFrame(r)
			local col = new("Frame", {
				BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -66, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = r,
			})
			new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = col })
			new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), Parent = col })
			text(col, o.title, 14, Enum.FontWeight.Medium, "text", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, LayoutOrder = 1 })
			if o.desc then
				text(col, o.desc, 12, Enum.FontWeight.Regular, "sub", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, LayoutOrder = 2 })
			end
			local ring = new("Frame", { Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), BorderSizePixel = 0, Parent = r })
			corner(ring)
			local rs = new("UIStroke", { Thickness = 1.5, Parent = ring })
			local inner = new("Frame", { Size = UDim2.fromOffset(0, 0), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BorderSizePixel = 0, Parent = ring })
			corner(inner)
			bind(inner, "BackgroundColor3", "card")
			local u1 = bind(ring, "BackgroundColor3", function() return selected == o.key and Th.on or Th.card end)
			local u2 = bind(rs, "Color", function() return selected == o.key and Th.on or Th.sub end)
			inner.Size = (selected == o.key) and UDim2.fromOffset(10, 10) or UDim2.fromOffset(0, 0)
			ups[#ups + 1] = function()
				u1(0.25)
				u2(0.25)
				tw(inner, 0.25, { Size = (selected == o.key) and UDim2.fromOffset(10, 10) or UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back)
			end
			local hd, hu = hlFX(hl)
			tap(overlay(r), function() obj.Set(o.key) end, hd, hu)
		end
		function obj.Set(key, silent)
			selected = key
			for _, u in ipairs(ups) do u() end
			if not silent and cb then cb(key) end
		end
		function obj.Get() return selected end
		return obj
	end

	-- sub page (slides over the tabs)
	local sub = new("CanvasGroup", {
		Position = UDim2.new(0.35, 0, 0, 46), Size = UDim2.new(1, 0, 1, -46), BackgroundTransparency = 0,
		GroupTransparency = 1, Visible = false, Active = true, ZIndex = 20, Parent = win,
	})
	bind(sub, "BackgroundColor3", "bg")
	local backBtn = new("TextButton", {
		Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(12, 5), Text = "←", TextSize = 18, FontFace = font(Enum.FontWeight.Bold),
		AutoButtonColor = false, BorderSizePixel = 0, Parent = sub,
	})
	bind(backBtn, "BackgroundColor3", "card")
	bind(backBtn, "TextColor3", "text")
	corner(backBtn)
	local backScale = new("UIScale", { Parent = backBtn })
	text(sub, "Settings", 15, Enum.FontWeight.Bold, "text", {
		Position = UDim2.fromOffset(56, 0), Size = UDim2.new(1, -68, 0, 44), TextTruncate = Enum.TextTruncate.AtEnd,
	})
	tap(backBtn, function() closeSub() end,
		function() tw(backScale, 0.1, { Scale = 0.88 }) end,
		function() tw(backScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back) end)

	local function SubPage()
		local holder = new("Frame", {
			Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 1, -46), BackgroundTransparency = 1, ClipsDescendants = true, Parent = sub,
		})
		local sf = new("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
			AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y,
			ElasticBehavior = Enum.ElasticBehavior.Always, Parent = holder,
		})
		dpiAttach(sf)
		bind(sf, "ScrollBarImageColor3", "sub")
		new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 18), Parent = sf })
		new("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sf })
		return { scroll = sf, order = 0, name = "Settings", noQA = true }
	end

	-- animated phone sketches (like the device settings illustrations)
	local function buildSketches(page)
		local holder = new("Frame", { Size = UDim2.new(1, 0, 0, 190), BackgroundTransparency = 1, LayoutOrder = 0, Parent = page.scroll })
		local function cornerPx(p, r) return new("UICorner", { CornerRadius = UDim.new(0, r), Parent = p }) end

		local function phoneCell(xs, label)
			local cell = new("Frame", { Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.fromScale(xs, 0), BackgroundTransparency = 1, Parent = holder })
			local outline = new("Frame", {
				Size = UDim2.fromOffset(88, 152), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), BackgroundTransparency = 1, Parent = cell,
			})
			cornerPx(outline, 16)
			local ost = new("UIStroke", { Thickness = 2.5, Parent = outline })
			bind(ost, "Color", "sub")
			local phone = new("Frame", {
				Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), BackgroundTransparency = 1, ClipsDescendants = true, Parent = outline,
			})
			cornerPx(phone, 13)
			local ys, hs = { 6, 30, 54, 78, 126 }, { 20, 20, 20, 44, 20 }
			for i = 1, 5 do
				local c = new("Frame", { Size = UDim2.new(1, -12, 0, hs[i]), Position = UDim2.fromOffset(6, ys[i]), BorderSizePixel = 0, Parent = phone })
				bind(c, "BackgroundColor3", "card2")
				cornerPx(c, 6)
				if i ~= 4 then
					local dp = new("Frame", { Size = UDim2.fromOffset(8, 8), Position = UDim2.fromOffset(5, 6), BorderSizePixel = 0, Parent = c })
					bind(dp, "BackgroundColor3", "line")
					corner(dp)
					for k = 1, 2 do
						local ln = new("Frame", {
							Size = UDim2.new(k == 1 and 0.45 or 0.6, 0, 0, 2), Position = UDim2.fromOffset(18, 5 + (k - 1) * 6), BorderSizePixel = 0, Parent = c,
						})
						bind(ln, "BackgroundColor3", "line")
					end
				end
			end
			text(cell, label, 12, Enum.FontWeight.Medium, "text", { Position = UDim2.fromOffset(0, 160), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center })
			return phone
		end

		local gPhone = phoneCell(0, "Gesture")
		local qPhone = phoneCell(0.5, "Quick Access")

		local function makeFinger(phone)
			local f = new("Frame", {
				Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 10, Parent = phone,
			})
			bind(f, "BackgroundColor3", "accent")
			corner(f)
			local fs = new("UIStroke", { Thickness = 2, Transparency = 1, Color = Color3.new(1, 1, 1), Parent = f })
			return f, fs
		end
		local function fingerShow(f, fs, on)
			tw(f, 0.22, { BackgroundTransparency = on and 0.2 or 1 })
			tw(fs, 0.22, { Transparency = on and 0.1 or 1 })
		end
		local function edgeMark(phone, right)
			local m = new("Frame", {
				Size = UDim2.fromOffset(3, 22), AnchorPoint = Vector2.new(right and 1 or 0, 0.5), Position = UDim2.new(right and 1 or 0, right and -1 or 1, 0.5, 0),
				BorderSizePixel = 0, BackgroundTransparency = 0.3, ZIndex = 4, Parent = phone,
			})
			bind(m, "BackgroundColor3", "sub")
			corner(m)
			return m
		end

		-- gesture phone: menu slides in/out from the edges
		local panel = new("Frame", {
			Size = UDim2.fromScale(0.62, 0.72), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(1.1, 0.5), BorderSizePixel = 0, ZIndex = 6, Parent = gPhone,
		})
		bind(panel, "BackgroundColor3", "bg")
		cornerPx(panel, 8)
		local pst = new("UIStroke", { Thickness = 1.5, Parent = panel })
		bind(pst, "Color", "accent")
		local pbar = new("Frame", { Size = UDim2.new(0.4, 0, 0, 4), Position = UDim2.fromOffset(8, 8), BorderSizePixel = 0, Parent = panel })
		bind(pbar, "BackgroundColor3", "accent")
		corner(pbar)
		for k = 1, 3 do
			local ln = new("Frame", { Size = UDim2.new(1, -16, 0, 12), Position = UDim2.fromOffset(8, 22 + (k - 1) * 18), BorderSizePixel = 0, Parent = panel })
			bind(ln, "BackgroundColor3", "card2")
			cornerPx(ln, 4)
		end
		local gEdgeR, gEdgeL = edgeMark(gPhone, true), edgeMark(gPhone, false)
		local gFinger, gFs = makeFinger(gPhone)

		-- quick phone: picker rises from the bottom while the finger drags down the edge
		local qEdge = edgeMark(qPhone, true)
		local qBox = new("Frame", {
			Size = UDim2.new(0.74, 0, 0, 78), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 1.5), BorderSizePixel = 0, ZIndex = 6, Parent = qPhone,
		})
		bind(qBox, "BackgroundColor3", "bg")
		cornerPx(qBox, 8)
		local qst = new("UIStroke", { Thickness = 1.5, Parent = qBox })
		bind(qst, "Color", "accent")
		local qt = new("Frame", { Size = UDim2.new(0.3, 0, 0, 3), Position = UDim2.fromOffset(8, 8), BorderSizePixel = 0, Parent = qBox })
		bind(qt, "BackgroundColor3", "sub")
		corner(qt)
		local qHl = new("Frame", { Size = UDim2.new(1, -12, 0, 16), Position = UDim2.fromOffset(6, 20), BorderSizePixel = 0, Parent = qBox })
		bind(qHl, "BackgroundColor3", "accent")
		cornerPx(qHl, 5)
		for k = 1, 3 do
			local b = new("Frame", { Size = UDim2.new(0.5, 0, 0, 3), Position = UDim2.fromOffset(14, 26 + (k - 1) * 20), BorderSizePixel = 0, ZIndex = 7, Parent = qBox })
			bind(b, "BackgroundColor3", "sub")
			corner(b)
		end
		local qFinger, qFs = makeFinger(qPhone)

		local gen, running = 0, false
		local function alive(my) return running and gen == my and holder:IsDescendantOf(gui) end
		local function sleep(my, t)
			task.wait(t)
			return alive(my)
		end

		local function gestureLoop(my)
			local n = 0
			while alive(my) do
				local sides = (QS.openEdge == "Both") and { "right", "left" } or { string.lower(QS.openEdge) }
				n = n % #sides + 1
				local isR = sides[n] == "right"
				gEdgeR.BackgroundTransparency = (QS.openEdge ~= "Left") and 0.3 or 1
				gEdgeL.BackgroundTransparency = (QS.openEdge ~= "Right") and 0.3 or 1
				local offX, inX = isR and 1.1 or -0.72, isR and 0.34 or 0.04
				local edgeX, midX = isR and 0.93 or 0.07, isR and 0.6 or 0.4
				panel.Position = UDim2.fromScale(offX, 0.5)
				gFinger.Position = UDim2.fromScale(edgeX, 0.5)
				fingerShow(gFinger, gFs, true)
				if not sleep(my, 0.35) then return end
				tw(gFinger, 0.8, { Position = UDim2.fromScale(midX, 0.5) })
				tw(panel, 0.8, { Position = UDim2.fromScale(inX, 0.5) })
				if not sleep(my, 0.9) then return end
				fingerShow(gFinger, gFs, false)
				if not sleep(my, 1.0) then return end
				fingerShow(gFinger, gFs, true)
				if not sleep(my, 0.3) then return end
				tw(gFinger, 0.7, { Position = UDim2.fromScale(edgeX, 0.5) })
				tw(panel, 0.7, { Position = UDim2.fromScale(offX, 0.5) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
				if not sleep(my, 0.75) then return end
				fingerShow(gFinger, gFs, false)
				if not sleep(my, 0.6) then return end
			end
		end

		local function quickLoop(my)
			while alive(my) do
				qBox.Position = UDim2.fromScale(0.5, 1.5)
				qHl.Position = UDim2.fromOffset(6, 20)
				qFinger.Position = UDim2.fromScale(0.92, 0.3)
				fingerShow(qFinger, qFs, true)
				if not sleep(my, 0.4) then return end
				tw(qBox, 0.65, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back)
				tw(qFinger, 1.5, { Position = UDim2.fromScale(0.92, 0.66) }, Enum.EasingStyle.Sine)
				if not sleep(my, 0.8) then return end
				tw(qHl, 0.28, { Position = UDim2.fromOffset(6, 40) })
				if not sleep(my, 0.45) then return end
				tw(qHl, 0.28, { Position = UDim2.fromOffset(6, 60) })
				if not sleep(my, 0.7) then return end
				fingerShow(qFinger, qFs, false)
				tw(qHl, 0.12, { Size = UDim2.new(1, -8, 0, 18) })
				if not sleep(my, 0.14) then return end
				tw(qHl, 0.2, { Size = UDim2.new(1, -12, 0, 16) })
				if not sleep(my, 0.3) then return end
				tw(qBox, 0.45, { Position = UDim2.fromScale(0.5, 1.5) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
				if not sleep(my, 1.1) then return end
			end
		end

		local api = {}
		function api.start()
			if running then return end
			running = true
			gen += 1
			local my = gen
			task.spawn(gestureLoop, my)
			task.spawn(quickLoop, my)
		end
		function api.stop() running = false end
		return api
	end

	openSub = function()
		if sub.Visible and sub.GroupTransparency < 0.5 then return end
		sub.Visible = true
		sub.Position = UDim2.new(0.35, 0, 0, 46)
		sub.GroupTransparency = 1
		tw(sub, 0.45, { Position = UDim2.new(0, 0, 0, 46) })
		tw(sub, 0.3, { GroupTransparency = 0 })
		if sketchAPI then sketchAPI.start() end
	end
	closeSub = function()
		if sketchAPI then sketchAPI.stop() end
		tw(sub, 0.38, { Position = UDim2.new(0.35, 0, 0, 46) })
		tw(sub, 0.28, { GroupTransparency = 1 })
		task.delay(0.4, function()
			if sub.GroupTransparency > 0.9 then sub.Visible = false end
		end)
	end


	local Q = SubPage()
	sketchAPI = buildSketches(Q)

	----------------------------------------------------------------------
	-- BUILT-IN SETTINGS PAGE  (⋯ -> Settings)
	----------------------------------------------------------------------
	do
		local ctrl, afters = {}, {}
		showFps = opts.ShowFPS ~= false

		local function labelList()
			local l = {}
			for _, e in ipairs(registry) do l[#l + 1] = e.label end
			return l
		end

		do
			-- appearance --------------------------------------------------------
			local a = Section(Q, "Appearance")
			Segmented(a, { Options = { "iOS", "ColorOS" }, Default = cfg.style, Flag = "_nova.style",
				Callback = function(n) cfg.style = n; buildTheme(); applyTheme(true) end })
			Segmented(a, { Options = { "Dark", "Light" }, Default = cfg.mode, Flag = "_nova.mode",
				Callback = function(n) cfg.mode = n; buildTheme(); applyTheme(true) end })
			local accentPicker = ColorPicker(a, { Name = "Accent color", Default = Th.accent,
				Callback = function(col) cfg.accent = col; buildTheme(); applyTheme(false) end })
			regFlag("_nova.accent", "color", function() return cfg.accent end, function(c) accentPicker.Set(c) end)
			Slider(a, { Name = "Transparency", Min = 0, Max = 40, Default = 4, Step = 1, Suffix = "%", Flag = "_nova.transparency",
				Callback = function(v) win.BackgroundTransparency = v / 100 end })

			-- size --------------------------------------------------------------
			local sz = Section(Q, "Size")
			Slider(sz, { Name = "Window size", Min = 60, Max = 150, Default = 100, Step = 5, Suffix = "%", CommitOnly = true, Flag = "_nova.windowSize",
				Callback = function(v)
					userScale = v / 100
					winScale.Scale = userScale
					pillScale.Scale = userScale
					winPos = clampWin(winPos)
					pillPos = clampBox(pillPos, pillVis())
					if state == "open" then tw(win, 0.35, { Position = posU(winPos) }) end
					if state == "mini" then tw(pill, 0.35, { Position = posU(pillPos) }) end
					Notify("Window size", v .. "%", 1.4)
				end })
			Slider(sz, { Name = "DPI", Min = 60, Max = 150, Default = 100, Step = 5, Suffix = "%", CommitOnly = true, Flag = "_nova.dpi",
				Callback = function(v)
					dpiTo(v / 100)
					Notify("DPI", v .. "%", 1.4)
				end })
			Label(sz, { Text = "Window size scales the whole menu. DPI scales only what is inside it (text, rows, controls) while the window frame stays put." })

			-- window ------------------------------------------------------------
			local w = Section(Q, "Window")
			Toggle(w, { Name = "Show FPS on bubble", Default = showFps, Flag = "_nova.fps", Callback = function(v) showFps = v end })
			Keybind(w, { Name = "Menu key", Mode = "None", Default = toggleKey, Flag = "_nova.menuKey",
				Changed = function(k) toggleKey = k end })
			Button(w, { Name = "Reset position", Callback = function()
				winPos = clampWin(Vector2.new(9e4, 62))
				pillPos = clampBox(pillPos, pillVis())
				tw(win, 0.5, { Position = posU(winPos) })
			end })

			-- configuration -----------------------------------------------------
			local cs = Section(Q, "Configuration")
			local cName = Input(cs, { Name = "Name", Placeholder = "my-config" })
			local cList = Dropdown(cs, { Name = "Saved configs", Options = cfgList(), AllowNone = true })
			local function target()
				local n = cleanName(cName.Get())
				if n == "" then n = cleanName(cList.Get() or "") end
				return n
			end
			local function refreshCfgs() cList.SetOptions(cfgList(), true) end
			Button(cs, { Name = "Save config", Callback = function()
				local n = target()
				if n == "" then n = "default" end
				local ok, err = cfgSave(n)
				if ok then
					refreshCfgs()
					cList.Set(n, true)
					Notify("Config saved", n .. (hasFS and "" or "  (memory only)"), 1.8, "success")
				else
					Notify("Save failed", tostring(err), 2.2, "error")
				end
			end })
			Button(cs, { Name = "Load config", Callback = function()
				local n = target()
				if n == "" then Notify("Load config", "Pick or type a name first", 1.8, "warn") return end
				local ok, err = cfgLoad(n)
				if ok then Notify("Config loaded", n, 1.8, "success") else Notify("Load failed", tostring(err), 2.2, "error") end
			end })
			Button(cs, { Name = "Use as auto-load", Callback = function()
				local n = target()
				if n == "" then Notify("Auto-load", "Pick or type a name first", 1.8, "warn") return end
				cfgSetAuto(n)
				Notify("Auto-load", n .. " loads on start", 1.8, "success")
			end })
			Button(cs, { Name = "Clear auto-load", Callback = function()
				cfgSetAuto(nil)
				Notify("Auto-load", "Cleared", 1.4)
			end })
			Button(cs, { Name = "Delete config", Danger = true, Callback = function()
				local n = target()
				if n == "" then return end
				local ok = cfgDelete(n)
				refreshCfgs()
				cList.Set(nil, true)
				Notify(ok and "Config deleted" or "Delete failed", n, 1.8, ok and "success" or "error")
			end })
			Label(cs, { Text = hasFS and ("Saved in workspace/" .. folder) or "This executor has no file access, configs live in memory until you leave." })
		end

	-- >>> gestures & Quick Access --------------------------------------------
	do
		local function refreshLayout()
			winPos = clampWin(winPos)
			if state == "open" then tw(win, 0.35, { Position = posU(winPos) }) end
			updateHint()
		end
		local function S(sec, label, key, min, max, step, suffix, after)
			local o = Slider(sec, { Name = label, Min = min, Max = max, Default = QS[key], Step = step, Suffix = suffix, Flag = "_q." .. key,
				Callback = function(v)
					QS[key] = v
					if after then after(v) end
				end })
			ctrl[#ctrl + 1] = function() QS[key] = QDef[key]; o.Set(QDef[key], true) end
			if after then afters[#afters + 1] = after end
		end
		local function T(sec, label, key, after)
			local o = Toggle(sec, { Name = label, Default = QS[key], Flag = "_q." .. key,
				Callback = function(v)
					QS[key] = v
					if after then after(v) end
				end })
			ctrl[#ctrl + 1] = function() QS[key] = QDef[key]; o.Set(QDef[key], true) end
			if after then afters[#afters + 1] = after end
		end
		local function G(sec, label, list, key)
			local o = Segmented(sec, { Name = label, Options = list, Default = QS[key], Flag = "_q." .. key,
				Callback = function(n) QS[key] = n end })
			ctrl[#ctrl + 1] = function() QS[key] = QDef[key]; o.Set(QDef[key], true) end
		end
		local function R(sec, key, list, after)
			local o = Radio(sec, list, QS[key], function(k)
				QS[key] = k
				if after then after(k) end
			end)
			regFlag("_q." .. key, "choice", o.Get, function(v) o.Set(v) end)
			ctrl[#ctrl + 1] = function() QS[key] = QDef[key]; o.Set(QDef[key], true) end
			if after then afters[#afters + 1] = after end
		end

		-- menu gestures
		local m1 = Section(Q, "Open the menu from")
		R(m1, "openEdge", {
			{ key = "Right", title = "Right edge", desc = "Swipe from the right edge toward the center." },
			{ key = "Left", title = "Left edge", desc = "Swipe from the left edge toward the center." },
			{ key = "Both", title = "Both edges", desc = "Works from either side of the screen." },
		}, refreshLayout)
		local m2 = Section(Q, "Close the menu by swiping")
		R(m2, "closeSwipe", {
			{ key = "Both", title = "Either direction", desc = "Flick the window header to the left or to the right." },
			{ key = "Right", title = "Right only", desc = "Flick the window header to the right." },
			{ key = "Left", title = "Left only", desc = "Flick the window header to the left." },
		})

		-- choices + order
		local dd, orderSec, rebuildOrder
		local c = Section(Q, "Quick Access choices")
		dd = Dropdown(c, { Name = "Buttons", Options = labelList(), Multi = true, Default = QA.order, Callback = function(list)
			local set = {}
			for _, l in ipairs(list) do set[l] = true end
			local new = {}
			for _, l in ipairs(QA.order) do
				if set[l] then new[#new + 1] = l; set[l] = nil end
			end
			for _, l in ipairs(list) do
				if set[l] then new[#new + 1] = l end
			end
			QA.order = new
			rebuildOrder()
		end })
		Label(c, { Text = "Every toggle / button you add shows up here. Pick the ones that appear in the picker, then arrange their order below." })
		regFlag("_q.order", "list", function() return table.clone(QA.order) end, function(v)
			local new = {}
			for _, l in ipairs(type(v) == "table" and v or {}) do
				if byLabel[l] then new[#new + 1] = l end
			end
			QA.order = new
			dd.Set(QA.order, true)
			rebuildOrder()
		end)

		orderSec = Section(Q, "Quick Access order")
		rebuildOrder = function()
			for _, ch in ipairs(orderSec.card:GetChildren()) do
				if ch:IsA("Frame") then ch:Destroy() end
			end
			orderSec.n = 0
			if #QA.order == 0 then
				Label(orderSec, { Text = "No choices yet. Pick some above." })
				return
			end
			for idx, lbl in ipairs(QA.order) do
				local r = Row(orderSec)
				text(r, idx .. ".  " .. lbl, 13, Enum.FontWeight.Medium, "text", {
					Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -140, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd,
				})
				local function mini(glyph, fromRight, fn, key)
					local b = new("TextButton", {
						Size = UDim2.fromOffset(32, 30), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -fromRight, 0.5, 0),
						Text = glyph, TextSize = 13, FontFace = font(Enum.FontWeight.Bold), AutoButtonColor = false, BorderSizePixel = 0, Parent = r,
					})
					bind(b, "BackgroundColor3", "card2")
					bind(b, "TextColor3", key or "accent")
					corner(b, "rCtl")
					local sc = new("UIScale", { Parent = b })
					tap(b, fn, function() tw(sc, 0.08, { Scale = 0.86 }) end, function() tw(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back) end)
				end
				mini("✕", 10, function()
					table.remove(QA.order, idx)
					dd.Set(QA.order, true)
					rebuildOrder()
				end, "danger")
				mini("▼", 48, function()
					if idx < #QA.order then
						QA.order[idx], QA.order[idx + 1] = QA.order[idx + 1], QA.order[idx]
						rebuildOrder()
					end
				end)
				mini("▲", 86, function()
					if idx > 1 then
						QA.order[idx], QA.order[idx - 1] = QA.order[idx - 1], QA.order[idx]
						rebuildOrder()
					end
				end)
			end
		end
		rebuildOrder()

		-- the registry changed (a component was added / removed)
		local pending = false
		QA.onRegistry = function()
			if pending then return end
			pending = true
			task.defer(function()
				pending = false
				if not gui.Parent then return end
				dd.SetOptions(labelList(), true)
				dd.Set(QA.order, true)
				rebuildOrder()
			end)
		end

		-- quick access gesture
		local g = Section(Q, "Quick Access gesture")
		T(g, "Enabled", "enabled", refreshLayout)
		S(g, "Edge width", "zoneW", 24, 90, 2, " px", refreshLayout)
		S(g, "Zone height", "zoneH", 80, 500, 10, " px")
		S(g, "Zone position", "zonePct", 10, 90, 1, "%", refreshLayout)
		T(g, "Show edge line", "showLine", updateHint)
		S(g, "Finger travel", "travel", 80, 400, 10, " px")
		G(g, "Drag direction", { "Down", "Up" }, "direction")
		G(g, "Start from", { "First", "Last used", "Middle" }, "startFrom")
		T(g, "Swipe left to cancel", "cancelOn")
		S(g, "Cancel distance", "cancelDist", 50, 200, 5, " px")
		Label(g, { Text = "The same finger travel always covers the whole list, so more choices means more sensitive dragging." })

		-- picker appearance
		local a = Section(Q, "Picker appearance")
		G(a, "Position", { "Center", "Right", "Left" }, "pos")
		S(a, "Vertical offset", "offY", -150, 150, 5, " px")
		S(a, "Width", "width", 160, 320, 5, " px")
		S(a, "Row height", "rowH", 30, 60, 2, " px")
		S(a, "Visible rows", "rows", 3, 9, 2, "")
		S(a, "Text size", "textSize", 11, 18, 1, "")
		S(a, "Corner radius", "radius", 0, 36, 1, "")
		S(a, "Background dim", "dim", 0, 80, 5, "%")
		S(a, "Box transparency", "boxAlpha", 0, 50, 1, "%")
		T(a, "Wheel effect", "wheel")
		T(a, "Show On/Off state", "showState")
		T(a, "Show counter", "showCount")
		T(a, "Show hint text", "showHint")
		local hlPicker = ColorPicker(a, { Name = "Highlight color", Default = Th.accent, Callback = function(col) QS.hl = col end })
		regFlag("_q.hl", "color", function() return QS.hl end, function(col) hlPicker.Set(col) end)
		Label(a, { Text = "Corner radius 0 follows the current theme." })

		-- animation
		local n = Section(Q, "Animation")
		local spd = Slider(n, { Name = "Speed", Min = 50, Max = 200, Default = QS.speed * 100, Step = 10, Suffix = "%", Flag = "_q.speed",
			Callback = function(v) QS.speed = v / 100 end })
		ctrl[#ctrl + 1] = function() QS.speed = QDef.speed; spd.Set(QDef.speed * 100, true) end

		-- tools
		local t = Section(Q, "Tools")
		Button(t, { Name = "Preview picker", Callback = qsPreview })
		Button(t, { Name = "Reset gestures & Quick Access", Danger = true, Callback = function()
			for _, f in ipairs(ctrl) do f() end
			QS.hl = nil
			for _, f in ipairs(afters) do f() end
			Notify("Quick Access", "Settings reset")
		end })

		local ab = Section(Q, "About")
		Label(ab, { Text = title .. "  ·  Nova UI Library v" .. Nova.Version })
		Button(ab, { Name = "Unload UI", Danger = true, Callback = function()
			Notify(title, "Unloading…", 0.8)
			task.delay(0.9, function() Window:Destroy() end)
		end })
	end
	end -- settings

	----------------------------------------------------------------------
	-- TAB BAR (equal slots, scrolls horizontally when there are many tabs)
	----------------------------------------------------------------------
	local tabList = {}
	local tabBar = { frame = nil, select = function() end }
	local rebuildTabBar
	rebuildTabBar = function()
		if tabBar.frame then tabBar.frame:Destroy() end
		local n = #tabList
		if n == 0 then return end
		local c = new("Frame", {
			Size = UDim2.new(1, -24, 0, 32), Position = UDim2.fromOffset(12, 48), BorderSizePixel = 0, ClipsDescendants = true, Parent = win,
		})
		bind(c, "BackgroundColor3", "card2")
		corner(c, "rCtl")
		tabBar.frame = c
		local sf = new("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0,
			ScrollingDirection = Enum.ScrollingDirection.X, CanvasSize = UDim2.new(), Parent = c,
		})
		local avail = math.max(win.Size.X.Offset - 24, 100)
		local MINW = 78
		local scroll = n * MINW > avail
		local function slotPos(i) return scroll and UDim2.fromOffset((i - 1) * MINW, 0) or UDim2.new((i - 1) / n, 0, 0, 0) end
		local function slotSize() return scroll and UDim2.new(0, MINW, 1, 0) or UDim2.new(1 / n, 0, 1, 0) end
		if scroll then sf.CanvasSize = UDim2.fromOffset(n * MINW, 0) end
		local ind = new("Frame", { BorderSizePixel = 0, ZIndex = 1, Parent = sf })
		bind(ind, "BackgroundColor3", "seg")
		corner(ind, "rCtl")
		local sel = curPage
		local function indPos(i)
			return scroll and UDim2.fromOffset((i - 1) * MINW + 2, 2) or UDim2.new((i - 1) / n, 2, 0, 2)
		end
		ind.Size = scroll and UDim2.new(0, MINW - 4, 1, -4) or UDim2.new(1 / n, -4, 1, -4)
		ind.Position = indPos(sel)
		local ups = {}
		for i, t in ipairs(tabList) do
			local b = new("TextButton", {
				Size = slotSize(), Position = slotPos(i), BackgroundTransparency = 1, Text = t.name, TextSize = n > 4 and 12 or 13,
				FontFace = font(Enum.FontWeight.SemiBold), AutoButtonColor = false, ZIndex = 2, Parent = sf,
			})
			ups[i] = bind(b, "TextColor3", function() return sel == i and Th.text or Th.sub end)
			tap(b, function() tabBar.select(i) end)
		end
		tabBar.select = function(i, instant)
			sel = i
			tw(ind, instant and 0 or 0.35, { Position = indPos(i) })
			for _, u in ipairs(ups) do u(instant and 0 or 0.2) end
			if scroll then
				local maxC = math.max(0, n * MINW - avail)
				tw(sf, instant and 0 or 0.35, { CanvasPosition = Vector2.new(math.clamp((i - 0.5) * MINW - avail / 2, 0, maxC), 0) })
			end
			showPage(i, instant)
		end
	end
	do
		local last = win.Size
		local pend = false
		win:GetPropertyChangedSignal("Size"):Connect(function()
			if win.Size == last or pend then return end
			last = win.Size
			pend = true
			task.defer(function()
				pend = false
				rebuildTabBar()
			end)
		end)
	end

	----------------------------------------------------------------------
	-- PUBLIC API
	--   long form : sec:AddToggle({ Name = ..., Default = ..., Flag = ..., Callback = ... })
	--   shortcuts : tab:Toggle("Name", default, callback)         (flag = name, automatic)
	--   Rayfield  : tab:CreateToggle({ Name = ..., CurrentValue = ..., Callback = ... })
	----------------------------------------------------------------------
	local SecMT, TabMT = {}, {}
	SecMT.__index = SecMT
	TabMT.__index = TabMT

	do
		local function opt(o)
			if type(o) == "string" then return { Name = o } end
			return o or {}
		end

		-- handles work with both  h.Set(v)  and  h:Set(v)  and expose Rayfield's .CurrentValue
		local function dualize(obj)
			if type(obj) ~= "table" then return obj end
			for k, f in pairs(obj) do
				if type(f) == "function" and string.sub(k, 1, 1) ~= "_" then
					obj[k] = function(a, ...)
						if a == obj then return f(...) end
						return f(a, ...)
					end
				end
			end
			return setmetatable(obj, {
				__index = function(_, k)
					if k == "CurrentValue" or k == "CurrentOption" or k == "CurrentKeybind" or k == "Value" then
						local ok, v = pcall(obj.Get)
						if ok then return v end
					end
					return nil
				end,
			})
		end

		-- Rayfield option names -> Nova option names
		local function rf(kind, o)
			if type(o) ~= "table" then o = { Name = tostring(o) } end
			local n = {}
			for k, v in pairs(o) do n[k] = v end
			if kind == "Toggle" or kind == "Checkbox" then
				if n.CurrentValue ~= nil then n.Default = n.CurrentValue end
			elseif kind == "Slider" then
				if n.Range then n.Min, n.Max = n.Range[1], n.Range[2] end
				n.Step = n.Increment or n.Step
				if n.CurrentValue ~= nil then n.Default = n.CurrentValue end
			elseif kind == "Dropdown" then
				local cur = n.CurrentOption
				if type(cur) == "table" then n.Default = n.MultipleOptions and cur or cur[1] elseif cur ~= nil then n.Default = cur end
				n.Multi = n.MultipleOptions
				local cb = n.Callback
				if cb then n.Callback = function(v) cb(type(v) == "table" and v or { v }) end end
			elseif kind == "Input" then
				n.Placeholder = n.PlaceholderText or n.Placeholder
				if n.CurrentValue ~= nil then n.Default = n.CurrentValue end
				n.ClearOnFocus = n.RemoveTextAfterFocusLost
			elseif kind == "Keybind" then
				n.Default = n.CurrentKeybind or n.Default
				n.Mode = n.HoldToInteract and "Hold" or n.Mode
			elseif kind == "ColorPicker" then
				n.Default = n.Color or n.Default
			end
			return n
		end

		local function makeRadio(sec, o)
			o = opt(o)
			local list = {}
			for _, x in ipairs(o.Options or {}) do
				if type(x) == "table" then
					list[#list + 1] = { key = x.Key or x.Title, title = x.Title or tostring(x.Key), desc = x.Desc }
				else
					list[#list + 1] = { key = tostring(x), title = tostring(x) }
				end
			end
			local default = o.Default
			if default == nil and list[1] then default = list[1].key end
			local obj = Radio(sec, list, default, o.Callback)
			if o.Flag then regFlag(o.Flag, "choice", obj.Get, function(v) obj.Set(v) end) end
			return obj
		end

		local function makeLabel(sec, o)
			if type(o) == "string" then o = { Text = o } end
			return Label(sec, o or {})
		end

		-- the tab's implicit section (used when you add components straight onto a tab)
		local function curSec(tab)
			if not tab._cur then
				tab._cur = setmetatable(Section(tab._page, nil), SecMT)
			end
			return tab._cur
		end

		local KINDS = {
			Toggle = Toggle, Checkbox = Checkbox, Button = Button, Slider = Slider, Stepper = Stepper, Dropdown = Dropdown,
			Segmented = Segmented, Input = Input, Progress = Progress, ColorPicker = ColorPicker, Keybind = Keybind,
			Paragraph = Paragraph, Value = Value, Divider = Divider,
		}
		for kind, fn in pairs(KINDS) do
			local function add(sec, o) return dualize(fn(sec, opt(o))) end
			local function create(sec, o) return dualize(fn(sec, rf(kind, o))) end
			SecMT["Add" .. kind] = function(self, o) return add(self, o) end
			SecMT["Create" .. kind] = function(self, o) return create(self, o) end
			TabMT["Add" .. kind] = function(self, o) return add(curSec(self), o) end
			TabMT["Create" .. kind] = function(self, o) return create(curSec(self), o) end
		end
		SecMT.AddRadio = function(self, o) return dualize(makeRadio(self, o)) end
		SecMT.CreateRadio = SecMT.AddRadio
		TabMT.AddRadio = function(self, o) return dualize(makeRadio(curSec(self), o)) end
		TabMT.CreateRadio = TabMT.AddRadio
		SecMT.AddLabel = function(self, o) return dualize(makeLabel(self, o)) end
		SecMT.CreateLabel = SecMT.AddLabel
		TabMT.AddLabel = function(self, o) return dualize(makeLabel(curSec(self), o)) end
		TabMT.CreateLabel = TabMT.AddLabel

		-- positional shortcuts: flag defaults to the component name, so config saving "just works"
		local function isInt(x) return type(x) == "number" and x % 1 == 0 end
		local SHORT = {
			Toggle = function(s, name, def, cb) return Toggle(s, { Name = name, Default = def, Callback = cb, Flag = name }) end,
			Checkbox = function(s, name, def, cb) return Checkbox(s, { Name = name, Default = def, Callback = cb, Flag = name }) end,
			Button = function(s, name, cb, danger) return Button(s, { Name = name, Callback = cb, Danger = danger }) end,
			Slider = function(s, name, min, max, def, cb, step, suffix)
				min, max = min or 0, max or 100
				def = def or min
				if not step then step = (isInt(min) and isInt(max) and isInt(def)) and 1 or math.max((max - min) / 100, 0.01) end
				return Slider(s, { Name = name, Min = min, Max = max, Default = def, Step = step, Suffix = suffix, Callback = cb, Flag = name })
			end,
			Stepper = function(s, name, min, max, def, cb) return Stepper(s, { Name = name, Min = min, Max = max, Default = def, Callback = cb, Flag = name }) end,
			Dropdown = function(s, name, options, def, cb) return Dropdown(s, { Name = name, Options = options, Default = def, Callback = cb, Flag = name }) end,
			Multi = function(s, name, options, defs, cb) return Dropdown(s, { Name = name, Options = options, Default = defs, Multi = true, Callback = cb, Flag = name }) end,
			Segmented = function(s, name, options, def, cb) return Segmented(s, { Name = name, Options = options, Default = def, Callback = cb, Flag = name }) end,
			Radio = function(s, options, def, cb) return makeRadio(s, { Options = options, Default = def, Callback = cb }) end,
			Input = function(s, name, placeholder, cb) return Input(s, { Name = name, Placeholder = placeholder, Callback = cb, Flag = name }) end,
			Keybind = function(s, name, key, cb, mode) return Keybind(s, { Name = name, Default = key, Callback = cb, Mode = mode, Flag = name }) end,
			Color = function(s, name, color, cb) return ColorPicker(s, { Name = name, Default = color, Callback = cb, Flag = name }) end,
			Progress = function(s, name) return Progress(s, { Name = name }) end,
			Label = function(s, text) return makeLabel(s, text) end,
			Paragraph = function(s, titleText, content) return Paragraph(s, { Title = titleText, Content = content }) end,
			Value = function(s, name, v) return Value(s, { Name = name, Value = v }) end,
			Divider = function(s) return Divider(s, {}) end,
		}
		for name, fn in pairs(SHORT) do
			SecMT[name] = function(self, ...) return dualize(fn(self, ...)) end
			TabMT[name] = function(self, ...) return dualize(fn(curSec(self), ...)) end
		end

	end -- shortcut builders

	function SecMT:SetTitle(t)
		if self.header then self.header.Text = string.upper(t) end
	end
	function SecMT:SetVisible(v) self.wrap.Visible = v and true or false end
	function SecMT:Destroy() self.wrap:Destroy() end

	-- sections: tab:AddSection("Title") / tab:Section("Title") / tab:CreateSection("Title")
	function TabMT:AddSection(titleText)
		local s = setmetatable(Section(self._page, titleText), SecMT)
		s.tab = self
		self._cur = s
		return s
	end
	TabMT.Section = TabMT.AddSection
	TabMT.CreateSection = TabMT.AddSection
	function TabMT:Select()
		if self._index then tabBar.select(self._index) end
	end

	----------------------------------------------------------------------
	-- WINDOW
	----------------------------------------------------------------------
	function Window:AddTab(name)
		name = tostring(name or ("Tab " .. (#tabList + 1)))
		local page = Page(name)
		local tab = setmetatable({ Name = name, _page = page }, TabMT)
		tab._index = #pages
		tabList[#tabList + 1] = { name = name, tab = tab }
		rebuildTabBar()
		if #pages == 1 then tabBar.select(1, true) else tabBar.select(curPage, true) end
		return tab
	end
	Window.Tab = Window.AddTab
	Window.CreateTab = Window.AddTab -- Rayfield: Window:CreateTab("Name", icon)

	function Window:SelectTab(x)
		local i = type(x) == "number" and x or nil
		if not i then
			for k, t in ipairs(tabList) do if t.name == x then i = k end end
		end
		if i and tabList[i] then tabBar.select(i) end
	end

	function Window:Notify(o, body, dur, kind)
		if type(o) == "table" then
			return Notify(o.Title or title, o.Body or o.Content or "", o.Duration, o.Type)
		end
		return Notify(o or title, body, dur, kind)
	end
	function Window:Open() openWindow() end
	function Window:Close() closeWindow("hidden") end
	function Window:Minimize() closeWindow("mini") end
	function Window:Toggle()
		if state == "open" then closeWindow("mini") else openWindow() end
	end
	function Window:SetVisibility(v)
		if v then openWindow() else closeWindow("hidden") end
	end
	function Window:SetTitle(t)
		title = tostring(t)
		Window.Title = title
		titleL.Text = title
		pillText.Text = title
	end

	-- config
	local autoName = opts._autoName
	local loadedOnce, autosaving = false, false
	function Window:SaveConfig(n) return cfgSave(n) end
	function Window:LoadConfig(n) return cfgLoad(n) end
	function Window:DeleteConfig(n) return cfgDelete(n) end
	function Window:ListConfigs() return cfgList() end
	function Window:SetAutoConfig(n) cfgSetAuto(n) end
	function Window:LoadAutoConfig()
		local n = cfgGetAuto()
		if n then return cfgLoad(n), n end
		return false
	end
	local function startAutosave()
		if not autoName or autosaving then return end
		autosaving = true
		task.spawn(function()
			local okS, last = pcall(cfgSnapshot)
			if not okS then last = nil end
			while not Window.Destroyed do
				task.wait(3)
				local ok, snap = pcall(cfgSnapshot)
				if ok and snap ~= last then
					last = snap
					cfgSave(autoName)
				end
			end
		end)
	end
	-- Rayfield-style: call once at the end of your script (also runs by itself after 1.5s)
	function Window:LoadConfiguration()
		loadedOnce = true
		if autoName then cfgLoad(autoName) else Window:LoadAutoConfig() end
		startAutosave()
	end

	-- look & size shortcuts
	local function setFlag(name, v)
		local f = flags[name]
		if f then f.set(v) end
	end
	function Window:SetStyle(s) setFlag("_nova.style", s) end
	function Window:SetMode(m) setFlag("_nova.mode", m) end
	function Window:SetAccent(c) setFlag("_nova.accent", c) end
	function Window:SetWindowSize(p) setFlag("_nova.windowSize", p) end
	function Window:SetDPI(p) setFlag("_nova.dpi", p) end

	-- flags proxy: ui.Flags.speed  /  ui.Flags.speed = 50
	Window.Flags = setmetatable({}, {
		__index = function(_, k)
			local f = flags[k]
			if f then
				local ok, v = pcall(f.get)
				if ok then return v end
			end
			return nil
		end,
		__newindex = function(_, k, v)
			local f = flags[k]
			if f then f.set(v) end
		end,
	})
	function Window:GetFlags()
		local t = {}
		for k, f in pairs(flags) do
			local ok, v = pcall(f.get)
			if ok then t[k] = v end
		end
		return t
	end

	-- Settings page: add your own sections after the built-in ones
	Window.Settings = setmetatable({ Name = "Settings", _page = Q }, TabMT)
	Window.Gui = gui

	local destroyHandlers = {}
	function Window:OnDestroy(fn) destroyHandlers[#destroyHandlers + 1] = fn end
	function Window:Destroy()
		if Window.Destroyed then return end
		Window.Destroyed = true
		for _, fn in ipairs(destroyHandlers) do pcall(fn) end
		for _, c in ipairs(conns) do c:Disconnect() end
		if QSel.m and QSel.m.conn then QSel.m.conn:Disconnect() end
		gui:Destroy()
		if Nova.Active == Window then Nova.Active = nil end
	end

	Nova.Active = Window

	if opts.AutoOpen ~= false then
		task.delay(0.25, function()
			if Window.Destroyed then return end
			openWindow()
			if opts.Welcome ~= false then
				task.delay(0.6, function()
					if not Window.Destroyed then Notify(title, opts.WelcomeText or "Loaded — drag on the edge line for Quick Access", 2.6, "info") end
				end)
			end
		end)
	end
	if autoName then
		task.delay(1.5, function()
			if not Window.Destroyed and not loadedOnce then Window:LoadConfiguration() end
		end)
	elseif opts.AutoLoad ~= false then
		task.delay(0.8, function()
			if not Window.Destroyed then pcall(function() Window:LoadAutoConfig() end) end
		end)
	end

	return Window
end

-- library-level shortcuts (forward to the active window)
function Nova.Notify(a, b, c, d, e)
	local w = Nova.Active
	if not w then return end
	if a == Nova then return w:Notify(b, c, d, e) end
	return w:Notify(a, b, c, d)
end
function Nova.LoadConfiguration(a)
	if Nova.Active then Nova.Active:LoadConfiguration() end
end
function Nova.Destroy(a)
	if Nova.Active then Nova.Active:Destroy() end
end

return Nova
