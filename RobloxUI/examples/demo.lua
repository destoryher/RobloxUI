local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/v0.7.1/dist/ui.lua"))()

local Window = Library:CreateWindow({
	Title = "Demo",
	Subtitle = "v" .. Library.Version,
	Icon = "\u{1F47B}",
	ToggleKey = Enum.KeyCode.RightShift,
	Footer = { Avatar = true, Subtext = "Demo build" },
})

local Main = Window:CreateTab({
	Name = "Main",
	Icon = "home",
	Group = "Farm",
	Heading = "Make things simple",
	Description = "A short description that sits under the page heading.",
})
local Filters = Window:CreateTab({ Name = "Filters", Icon = "\u{1F9EA}", Group = "Farm" })
local Settings = Window:CreateTab({ Name = "Settings", Group = "Misc" })

local Auto = Main:CreateCard({ Name = "Automation", Highlight = true })
local farm = Auto:CreateToggle({
	Name = "Auto farm",
	Description = "Prints to the console when changed.",
	Callback = function(on) print("auto farm:", on) end,
})
Auto:CreateSlider({
	Name = "Farm delay",
	Min = 0, Max = 5, Increment = 0.1, Default = 1, Suffix = "s",
	Callback = function(v) print("delay:", v) end,
})
local pen = Auto:CreateProgress({ Name = "Pen", Min = 0, Max = 12, Value = 9 })
Auto:CreateStat({ Name = "Income", Value = "$5.75B/s", Style = "Success" })
Auto:CreateStat({ Name = "Weakest", Value = "$16.52K/s" })
Auto:CreateButton({ Name = "Add 1 to pen", Callback = function() pen:Set(pen:Get() + 1) end })
Auto:CreateButton({
	Name = "Sell everything",
	Style = "Danger",
	Confirm = { Title = "Sell everything?", Content = "This cannot be undone.", ConfirmText = "Sell" },
	Callback = function() Window:Notify({ Title = "Sold", Content = "Everything was sold.", Type = "Success" }) end,
})

local Rarity = Filters:CreateCard({ Name = "Sell filters" })
local rarity = Rarity:CreateDropdown({
	Name = "Rarity filter",
	Options = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" },
	Multi = true,
	Default = { "Rare" },
	Placeholder = "None (= all)",
	Callback = function(selected) print("rarity:", table.concat(selected, ", ")) end,
})
Rarity:CreateDropdown({
	Name = "Sort by",
	Options = { "Best income", "Rarity", "Newest" },
	Default = "Best income",
	Callback = function(choice) print("sort:", choice) end,
})
local many = {}
for i = 1, 300 do
	many[i] = "Item " .. i
end
Rarity:CreateDropdown({ Name = "Stress test (300 options)", Options = many, Multi = true, Placeholder = "None" })
Rarity:CreateChips({
	Name = "Mode",
	Options = { "Safe", "Balanced", "Fast" },
	Default = "Balanced",
	Callback = function(choice) print("mode:", choice) end,
})
Rarity:CreateChips({
	Name = "Rarities (chips)",
	Options = { "Common", "Rare", "Epic", "Legendary" },
	Multi = true,
	Callback = function(list) print(table.concat(list, ", ")) end,
})
Rarity:CreateInput({
	Name = "Sell below",
	Placeholder = "e.g. 100",
	Numeric = true,
	Callback = function(value) print("sell below:", value) end,
})
Rarity:CreateButton({
	Name = "Pick Legendary from code",
	Callback = function() rarity:Set({ "Legendary" }) end,
})

local Look = Settings:CreateCard({ Name = "Appearance" })
Look:CreateColorPicker({
	Name = "Accent color",
	Default = Color3.fromRGB(245, 245, 245),
	Callback = function(color) Window:SetAccent(color) end,
})
Look:CreateColorPicker({
	Name = "Gradient color",
	Default = Color3.fromRGB(140, 140, 140),
	Callback = function(color) Window:SetColor("AccentAlt", color) end,
})
Look:CreateSlider({
	Name = "Glow strength",
	Min = 0, Max = 3, Increment = 0.1, Default = 1,
	Callback = function(value) Window:SetGlow(value) end,
})
Look:CreateKeybind({
	Name = "Toggle UI key",
	Default = Enum.KeyCode.RightShift,
	Callback = function(key) if key then Window:SetToggleKey(key) end end,
})
Look:CreateDropdown({
	Name = "Minimize style",
	Options = { "Auto", "Pill", "Bar" },
	Default = "Auto",
	Callback = function(style) Window:SetMinimizeStyle(style) end,
})
Look:CreateButton({ Name = "Minimize now", Callback = function() Window:Minimize() end })
Look:CreateDivider({ Text = "Themes" })
Look:CreateButton({ Name = "Mono (black & white)", Callback = function() Window:SetTheme("Mono") end })
Look:CreateButton({ Name = "Dark (orange)", Callback = function() Window:SetTheme("Dark") end })
Look:CreateButton({ Name = "Ocean", Callback = function() Window:SetTheme("Ocean") end })
Look:CreateParagraph({ Title = "About", Content = "Notifications keep working while the window is minimized." })
Look:CreateButton({
	Name = "Send notification",
	Style = "Accent",
	Callback = function() Window:Notify({ Title = "Hello", Content = "This is a toast.", Type = "Info" }) end,
})
