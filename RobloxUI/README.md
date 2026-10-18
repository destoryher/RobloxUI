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
| `CreateKeybind` | `Default`, `Callback`, `Pressed` | `Enum.KeyCode` |
| `CreateColorPicker` | `Default` | `Color3` |
| `CreateProgress` | `Min`, `Max`, `Value`, `Format` | number |
| `CreateStat` | `Name`, `Value`, `Style` | text |
| `CreateLabel`, `CreateParagraph`, `CreateDivider` | `Text`, `Title`, `Content` | text |

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
