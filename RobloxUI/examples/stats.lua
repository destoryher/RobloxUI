local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/destoryher/RobloxUI/main/RobloxUI/dist/ui.lua"))()

local Window = Library:CreateWindow({
	Title = "Stat Tracker Demo",
	Subtitle = "Any game",
	ToggleKey = Enum.KeyCode.RightShift,
})

local Main = Window:CreateTab({ Name = "Main", Group = "Main" })
local Farm = Main:CreateCard({ Name = "Auto Farm", Highlight = true })

local Stats = Window:CreateStatTracker({ Title = "Session", Tab = "Stats", TabGroup = "Main" })

Stats:AddLeaderstats({ Group = "Leaderstats" })
Stats:AddAttribute("XP", { Group = "Progress", Goal = 10000 })
local kills = Stats:AddCounter("Kills", { Group = "Progress" })
local runs = Stats:AddCounter("Runs Finished", { Group = "Progress" })
Stats:Add({
	Name = "Health",
	Group = "Character",
	Format = "Number",
	Gain = false,
	Rate = false,
	Get = function()
		local character = game:GetService("Players").LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		return humanoid and math.floor(humanoid.Health)
	end,
})

local running = false
Farm:CreateToggle({
	Name = "Enable Auto Farm",
	Callback = function(on)
		running = on
		Stats:SetStatus(on and "Farming" or "Idle", on and "Accent" or "Normal")
		task.spawn(function()
			while running do
				task.wait(2)
				kills:Increment()
				if math.random() < 0.2 then
					runs:Increment()
				end
			end
		end)
	end,
})

Farm:CreateKeybind({
	Name = "Test Key",
	Default = "RMB",
	Pressed = function()
		Window:Notify({ Title = "Right click pressed" })
	end,
})
