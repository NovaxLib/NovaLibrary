# Nova UI

A touch-first UI library for Roblox with an iOS / ColorOS look, built for phones: edge-swipe to open, a pocket-size bubble, a built-in **Quick Access** picker, DPI + window size controls, config saving and a Rayfield-compatible API.

## Install

```lua
local Nova = loadstring(game:HttpGet("https://raw.githubusercontent.com/USER/NovaUI/main/NovaLib.lua"))()
```

Safer for production (pin a version, with a fallback mirror):

```lua
local function load(urls)
	for _, u in ipairs(urls) do
		local ok, src = pcall(game.HttpGet, game, u)
		if ok and type(src) == "string" and #src > 1000 then
			local fn = loadstring(src)
			if fn then return fn() end
		end
	end
	error("Nova UI: could not download the library")
end
local Nova = load({
	"https://cdn.jsdelivr.net/gh/USER/NovaUI@v1.1.0/NovaLib.lua",
	"https://raw.githubusercontent.com/USER/NovaUI/v1.1.0/NovaLib.lua",
})
```

## 30 seconds

```lua
local ui  = Nova:CreateWindow({ Title = "My Hub" })
local tab = ui:Tab("Main")

tab:Section("Player")
tab:Toggle("God mode", false, function(on) print(on) end)
tab:Slider("Speed", 16, 120, 16, function(v) print(v) end)
tab:Dropdown("Team", { "Red", "Blue" }, "Red", function(v) print(v) end)
tab:Button("Reset", function() print("reset") end)

ui:Notify("Hello", "Loaded", 3, "success")
ui:LoadConfiguration()
```

Every shortcut uses its **name as the flag**, so saving / loading works without extra code.

## Three ways to write the same thing

| Style | Example |
|---|---|
| Shortcut | `tab:Toggle("God mode", false, cb)` |
| Long form | `tab:AddToggle({ Name = "God mode", Default = false, Flag = "god", Quick = true, Callback = cb })` |
| Rayfield | `tab:CreateToggle({ Name = "God mode", CurrentValue = false, Flag = "god", Callback = cb })` |

Handles work with `h.Set(v)` **and** `h:Set(v)`, and expose `.CurrentValue` like Rayfield.

## Shortcuts (on a tab or a section)

| Call | Notes |
|---|---|
| `Toggle(name, default, cb)` | cb(bool) |
| `Checkbox(name, default, cb)` | cb(bool) |
| `Button(name, cb, danger)` | danger = red text |
| `Slider(name, min, max, default, cb, step, suffix)` | step auto-detected |
| `Stepper(name, min, max, default, cb)` | hold to repeat |
| `Dropdown(name, options, default, cb)` | cb(string) |
| `Multi(name, options, defaults, cb)` | cb(list) |
| `Segmented(name, options, default, cb)` | cb(string) |
| `Radio(options, default, cb)` | options may be `{Key, Title, Desc}` |
| `Input(name, placeholder, cb)` | cb(text, enterPressed) |
| `Keybind(name, key, cb, mode)` | mode: `"Press"` `"Toggle"` `"Hold"` |
| `Color(name, color, cb)` | HSV picker |
| `Progress(name)` | `h.Set(0..1, seconds)` |
| `Label(text)` `Paragraph(title, content)` `Value(name, value)` `Divider()` | display only |

Long-form options: `Name, Default, Flag, Callback, Quick, Icon, Min, Max, Step, Suffix, CommitOnly, Options, Multi, Placeholder, Numeric, MaxLength, ClearOnFocus, Mode, Changed, Danger, Text, Title, Content, Value`.

## Window

```lua
Nova:CreateWindow({
	Title = "My Hub",              -- or Name
	Style = "iOS",                 -- "iOS" | "ColorOS"
	Mode = "Dark",                 -- "Dark" | "Light"
	Accent = Color3.fromRGB(10,132,255),
	ToggleKey = Enum.KeyCode.RightShift,  -- false to disable
	ShowFPS = true, AutoOpen = true, Protect = false,
	ConfigFolder = "MyHub",
	ConfigurationSaving = { Enabled = true, FolderName = "MyHub", FileName = "main" }, -- Rayfield style auto save
	Quick = { rows = 7 },           -- Quick Access defaults
	QuickDefault = { "God mode" },  -- pre-selected shortcuts
	QuickIcons = { ["God mode"] = "rbxassetid://123" },
})
```

| Method | |
|---|---|
| `:Tab(name)` / `:CreateTab(name)` | returns a tab |
| `:Notify(title, body, seconds, type)` or `:Notify{Title,Body,Duration,Type}` | type: `success` `error` `warn` `info` |
| `:Open() :Close() :Minimize() :Toggle() :Destroy()` | |
| `:SaveConfig(n) :LoadConfig(n) :DeleteConfig(n) :ListConfigs()` | |
| `:LoadConfiguration()` | load the auto config and start auto-saving |
| `:SetStyle() :SetMode() :SetAccent() :SetWindowSize(pct) :SetDPI(pct)` | |
| `.Flags` | `ui.Flags["God mode"]`, `ui.Flags.speed = 50` |
| `.Settings` | `ui.Settings:Section("My hub")` adds to the built-in Settings page |

## Built in (⋯ → Settings)

Appearance, **Window size** (scales the whole menu), **DPI** (scales only what is inside it), animation speed, menu key, configs (save / load / delete / auto-load), menu open / close gestures, Quick Access gesture and picker look. All of it is saved in your configs.

## Quick Access

Drag vertically on the white line at the screen edge: a centered picker appears, slide your finger to a shortcut and release to run it. Every toggle and button is selectable in Settings; `QuickDefault` or `Quick = true` pre-selects it, `Quick = false` hides it.

## Publish your own copy

1. Create a GitHub repo (e.g. `NovaUI`), upload `NovaLib.lua`, `README.md`, `LICENSE` and `examples/`.
2. Raw link: `https://raw.githubusercontent.com/<you>/NovaUI/main/NovaLib.lua`
3. Make a release tag (`v1.1.0`). CDN link, cached and fast: `https://cdn.jsdelivr.net/gh/<you>/NovaUI@v1.1.0/NovaLib.lua`
4. Replace `USER` in the README and examples with your username.
5. Always tell people to pin a tag instead of `main`: people who load remote code trust you not to change it silently.

## Notes

- One window per script (creating another destroys the first).
- Needs `game:HttpGet` + `loadstring` (executors). Config files need `writefile`; without it configs stay in memory.
- Rayfield's loading screen, key system and icons are accepted and ignored.
