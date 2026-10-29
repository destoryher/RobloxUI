# RobloxUI

A UI library for Roblox scripts. Load a single file, declare tabs, cards and controls, and the library takes care of styling, layout, animation and mobile support. It also includes a key gate with a Luarmor adapter.

## Installation

```lua
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/v0.7.1/dist/ui.lua"))()
```

Use a release tag in the URL (`vX.Y.Z`) so your script keeps working when new versions are published.

## Usage

```lua
local Window = Library:CreateWindow({
    Title = "My Script",
    Subtitle = "v1.0",
    ToggleKey = Enum.KeyCode.RightShift,
})

local Main = Window:CreateTab({ Name = "Main", Group = "Farm" })
local Card = Main:CreateCard({ Name = "Automation" })

Card:CreateToggle({
    Name = "Auto farm",
    Callback = function(enabled)
        print(enabled)
    end,
})

Window:Notify({ Title = "Loaded", Type = "Success" })
```

See `examples/demo.lua` for every component.

## Components

Created on a card with `card:CreateX(config)`.

| Method | Main options | Value |
|---|---|---|
| `CreateToggle` | `Name`, `Default`, `Callback` | boolean |
| `CreateButton` | `Name`, `Style` (Default, Accent, Danger), `Confirm`, `Callback` | |
| `CreateDropdown` | `Options`, `Multi`, `Default`, `Placeholder`, `Search` | string, or array when `Multi` |
| `CreateChips` | `Options`, `Multi`, `Default` (pill selector) | string, or array when `Multi` |
| `CreateSlider` | `Min`, `Max`, `Increment`, `Default`, `Suffix` | number |
| `CreateInput` | `Placeholder`, `Default`, `Numeric` | string or number |
| `CreateKeybind` | `Default`, `Callback`, `Pressed`, `Released`, `AllowMouse` | `Enum.KeyCode` or a mouse `Enum.UserInputType` |
| `CreateColorPicker` | `Default` | `Color3` |
| `CreateProgress` | `Min`, `Max`, `Value`, `Format` | number |
| `CreateStat` | `Name`, `Value`, `Style` (change later with `SetStyle`) | text |
| `CreateLabel`, `CreateParagraph`, `CreateDivider` | `Text`, `Title`, `Content` | text |

Long names, button text and card titles wrap onto a second line instead of being cut off with "..."; stat and progress values only take the width they need.

All controls support `Get`, `Set(value, silent)`, `SetName`, `SetDescription`, `SetDisabled`, `SetVisible` and `Destroy`. Callbacks run in their own thread inside `pcall`. Dropdowns and chips also provide `SetOptions`, `SelectAll` and `Clear`.

## Window

- `CreateTab{ Name, Icon, Group, Heading, Description }` adds a large gradient page heading with a description
- `Tab:CreateCard{ Name, Icon, Collapsed, Column, Highlight }`; `Highlight` gives the card an accent tinted background and border
- `Window:Notify{ Title, Content, Duration, Type }` with types Info, Success, Warning and Error
- `Window:Confirm{ Title, Content, ConfirmText, CancelText, Danger, OnConfirm, OnCancel }`
- `Window:Minimize()`, `Restore()`, `Hide()`, `Toggle()`, `SetToggleKey()`, `SetScale()`, `Destroy()`
- Options: `Icon`, `Mark`, `FabIcon`, `Footer`, `Theme`, `MinimizeStyle` (Auto, Pill, Bar), `Effects` (Full, Lite), `NotifyPosition`, `Size`, `Scale`, `TabIcons` (set `false` to hide every tab icon and its reserved space), `Glow` (0-3, same as `SetGlow`)
- `CreateTab{ Icon = false }` hides the icon for a single tab. A tab with no `Icon` still guesses one from its name unless `TabIcons = false`.
- `Window:IsOpen()` / `IsVisible()`, `Window:Show()` (same as `Restore`), `Hide()`, `Toggle()`

Minimizing shows a pill on touch devices and a title bar on desktop. The layout scales to the screen and switches to an icon sidebar with one column on narrow displays.

## Keybinds

`CreateKeybind` binds keyboard keys, gamepad buttons and mouse buttons. Click the key box, then press a key, or click in the game (not on the menu) to bind a mouse button. Escape cancels; Backspace or Delete clears.

- Mouse buttons show as `LMB`, `RMB` and `MMB`. Side buttons (`Mouse4`, `Mouse5`) bind automatically if the Roblox client reports them; Roblox does not currently expose them to scripts, so mouse software that maps a side button to a key (for example a numpad key) is the reliable route.
- `AllowMouse = false` limits a bind to keys.
- `Pressed` fires on press and `Released` on release; `bind:IsHeld()` tells you whether it is down right now (for hold-to-use features).
- Presses never trigger binds or the menu key while any keybind is waiting for input.
- `Default`, `Set` and `Window:SetToggleKey` accept an `EnumItem` or a name: `"F"`, `"MouseButton2"`, `"RMB"`, `"RightClick"`. Save `bind:GetKeyName()` (or `key.Name` from the callback) in configs and pass it straight back to `Set`; `""` means unbound.

`Window:CreateKeybindList{ Title, ShowWhen, Width, Position, Color, Draggable }` shows a floating list of binds. `list:Link{ Name, Toggle = toggle, Keybind = keybind }` lights an entry while its toggle is on and shows its key.

## Stat tracker

`Window:CreateStatTracker(config)` adds a Stats tab and a floating overlay with the same look as the keybind list. The overlay appears while the menu is minimized, can be dragged anywhere, and collapses when you tap its title.

```lua
local Stats = Window:CreateStatTracker({ Title = "Session", Tab = "Stats" })

Stats:AddLeaderstat("Coins", { Format = "Money", Mode = "Earned" })
Stats:AddLeaderstat("Level", { Format = "Number", Goal = 100 })
Stats:AddAttribute("XP")
local kills = Stats:AddCounter("Kills")

kills:Increment()
Stats:SetStatus("Farming room 3", "Accent")
```

Each stat shows its value, how much it changed this session, its rate per hour, and with a `Goal`, a progress bar and an ETA.

| Option | Description |
|---|---|
| `Title` | Overlay title (default `Stats`) |
| `Tab` | Tab name (default `Stats`), an existing tab, or `false` for overlay only |
| `TabGroup` | Sidebar group for the new tab |
| `ShowWhen` | `Minimized` (default), `Closed`, `Hidden` or `Always` |
| `Interval` | Seconds between updates (default 0.5) |
| `Width`, `Position`, `Draggable` | Overlay size and placement |
| `SessionCard` | Set `false` to leave out the Session card (clock, status, overlay options, pause, reset) |

`Stats:Add{ ... }` options:

| Option | Description |
|---|---|
| `Name`, `Id`, `Group` | Label, unique id (defaults to the name), and the card it goes in (default `Tracked`) |
| Source | One of `Leaderstat = "Coins"`, `Attribute = "Level"` (on the player, or on `Instance`), `Source = valueObjectOrTextLabel` (or a function returning one), `Get = function() return value end`. No source makes a counter you drive with `Set` / `Increment` |
| `Format` | `Compact` (1.23K, 15.3M, 2.5Qa; default), `Number` (1,234,567), `Money` ($1.5M), `Time`, `Clock`, `Percent`, `Text`, or a function |
| `Decimals`, `Prefix`, `Suffix` | Extra formatting |
| `Mode` | `Net` (default; current minus start) or `Earned` (only increases, so spending or a reset does not cancel progress) |
| `Goal` | Target value: adds a progress bar and an ETA |
| `Gain`, `Rate` | Set `false` to hide the session change or the per-hour rate |
| `Hud`, `Tab` | Set `false` to keep the stat out of the overlay or out of the tab |

Text such as `"$1.5M"`, `"12.3K Coins"` or `"1,234"` is read as a number, so stats can come straight from a game's own labels.

Shortcuts: `AddLeaderstat(name, opts)`, `AddAttribute(name, opts)`, `AddCounter(name, opts)`, and `AddLeaderstats{ Group, Exclude, Format }` to track every leaderstat, including ones the game adds later.

Stat methods: `Get`, `Set`, `Increment(n)`, `GetGained`, `GetRate`, `SetGoal`, `SetName`, `Reset`, `SetVisible`, `SetHud`, `Remove`.
Tracker methods: `SetStatus(text, style)`, `Pause`, `Resume`, `IsPaused`, `Reset`, `GetElapsed`, `Get(id)`, `GetStats`, `SetShowWhen`, `SetVisible`, `SetCollapsed`, `GetPosition`, `SetPosition`, `SetTitle`, `Destroy`. `tracker.Controls` holds the Session card's controls (`Overlay`, `ShowWhen`, `Pause`, `Reset`) so a config system can save them.

## Key system

`Library:CreateKeyGate(config)` shows a key window and validates the key with a function or a provider.

```lua
local luarmor = Library.Providers.Luarmor({ ScriptId = "YOUR_SCRIPT_ID" })

Library:CreateKeyGate({
    Title = "My Script",
    Provider = luarmor,
    Links = { { Name = "Get key", Url = "https://example.com/key" } },
    OnSuccess = function(key)
        luarmor.LoadScript(key)
    end,
})
```

| Option | Description |
|---|---|
| `Provider` or `Validate` | `Provider` from `Library.Providers`, or `Validate(key)` returning `ok, message, data` |
| `Links` | Buttons that copy a link: `{ Name, Url }` |
| `SaveKey` | Remember the key on the device (default on) |
| `Key` | Preset key; `getgenv().script_key` and the saved key are also tried first |
| `MaxAttempts`, `Cooldown` | Lock the input after repeated failures (default 5 attempts, 15 seconds) |
| `Timeout` | Seconds before a validation request counts as failed (default 20) |
| `OnSuccess(key, data)`, `OnClose` | Callbacks |

`gate:Wait()` yields until the key is accepted and returns `ok, key, data`. A custom backend only needs to return `true, message, data` or `false, message` from `Validate`; see `examples/keygate_custom.lua`.

## Themes and icons

Themes: `Mono` (default, black and white), `Dark` and `Ocean`. Switch with `Window:SetTheme("Dark")` or register one with `Library:RegisterTheme(name, overrides)`.

Colors can be changed at runtime with `Window:SetAccent(color)`, `Window:SetColor(token, color)` and `Window:SetGradient(first, second)`. `Window:SetGlow(0-3)` scales the glow relative to the theme default (1).

Without an `Icon` the window draws a logo mark in the top-left corner; choose its shape with `Mark` (`Cross`, `Diamond`, `Ring`, `Dot`). Marks use the two gradient colors, so they follow the theme. Any `Icon` or `FabIcon` also accepts `"mark:cross"` style names.

`Icon` accepts an emoji, a built-in name (`home`, `settings`, `shop`), a Roblox asset id, an image URL (requires executor file functions), or a name added with `Library:RegisterIcons{ name = assetId }`.

## Building

```
python3 build/check.py $(find src -name '*.lua')
python3 build/globals.py $(find src -name '*.lua')
python3 build/bundle.py
```

`bundle.py` combines `src/` into `dist/ui.lua`, the only file scripts load.

## Releases

Update `VERSION`, run the build, commit `dist/ui.lua` and publish a GitHub release tagged `vX.Y.Z`. Breaking changes increase the major version. Scripts can check it with `Library:CheckVersion("0")`.
