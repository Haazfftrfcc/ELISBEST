-- ThemeManager.lua (별도 테마 매니저 - Library와 연동)
local HttpService = game:GetService("HttpService")

local ThemeManager = {}
ThemeManager.__index = ThemeManager

ThemeManager.Folder = "LinoriaCustomThemes"
ThemeManager.Presets = {
	["Default Red"] = {
		BackgroundColor = Color3.fromRGB(14, 14, 16),
		MainColor = Color3.fromRGB(20, 20, 23),
		AccentColor = Color3.fromRGB(185, 38, 46),
		OutlineColor = Color3.fromRGB(48, 48, 54),
		ElementColor = Color3.fromRGB(26, 26, 30),
		FontColor = Color3.fromRGB(232, 232, 236),
	},
	["Crimson Dark"] = {
		BackgroundColor = Color3.fromRGB(11, 11, 13),
		MainColor = Color3.fromRGB(17, 17, 20),
		AccentColor = Color3.fromRGB(215, 25, 45),
		OutlineColor = Color3.fromRGB(56, 56, 62),
		ElementColor = Color3.fromRGB(24, 24, 28),
		FontColor = Color3.fromRGB(240, 240, 245),
	},
	["Ash Gray"] = {
		BackgroundColor = Color3.fromRGB(15, 15, 17),
		MainColor = Color3.fromRGB(22, 22, 25),
		AccentColor = Color3.fromRGB(130, 130, 142),
		OutlineColor = Color3.fromRGB(62, 62, 68),
		ElementColor = Color3.fromRGB(30, 30, 34),
		FontColor = Color3.fromRGB(230, 230, 235),
	},
}

local function ColorToTable(c)
	return { R = c.R, G = c.G, B = c.B }
end

local function TableToColor(t)
	if typeof(t) == "Color3" then return t end
	if type(t) == "table" then
		return Color3.new(t.R or 0, t.G or 0, t.B or 0)
	end
	return nil
end

function ThemeManager.new(library)
	local self = setmetatable({}, ThemeManager)
	self.Library = library
	self.MemoryStore = {}
	return self
end

function ThemeManager:ApplyPreset(presetName)
	local preset = self.Presets[presetName]
	if not preset then return false end

	local converted = {}
	for k, v in pairs(preset) do
		converted[k] = TableToColor(v) or v
	end
	self.Library:ApplyTheme(converted)
	return true
end

function ThemeManager:SaveTheme(name)
	if not name or name == "" then
		return false, "Theme name required"
	end

	local data = {}
	for k, v in pairs(self.Library.Theme) do
		if typeof(v) == "Color3" then
			data[k] = ColorToTable(v)
		elseif typeof(v) == "EnumItem" then
			data[k] = tostring(v.Name)
		end
	end

	local encoded = HttpService:JSONEncode(data)
	self.MemoryStore[name] = encoded

	if type(writefile) == "function" then
		pcall(function()
			if type(makefolder) == "function" and not isfolder(self.Folder) then
				makefolder(self.Folder)
			end
			writefile(self.Folder .. "/" .. name .. ".json", encoded)
		end)
	end

	return true
end

function ThemeManager:LoadTheme(name)
	if not name or name == "" then
		return false, "No theme selected"
	end

	local raw = self.MemoryStore[name]
	if not raw and type(readfile) == "function" then
		pcall(function()
			local path = self.Folder .. "/" .. name .. ".json"
			if isfile and isfile(path) then
				raw = readfile(path)
			end
		end)
	end

	if not raw then
		return false, "Theme not found"
	end

	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or type(decoded) ~= "table" then
		return false, "Invalid theme data"
	end

	local patch = {}
	for k, v in pairs(decoded) do
		if k == "Font" and type(v) == "string" and Enum.Font[v] then
			patch.Font = Enum.Font[v]
		else
			local col = TableToColor(v)
			if col then
				patch[k] = col
			end
		end
	end

	self.Library:ApplyTheme(patch)
	return true
end

function ThemeManager:AttachToTab(tab)
	local gb = tab:AddGroupbox("Theme Manager")
	local presetNames = {}
	for k in pairs(self.Presets) do
		table.insert(presetNames, k)
	end
	table.sort(presetNames)

	gb:AddDropdown("ThemePresetSelect", {
		Text = "Theme Preset",
		Values = presetNames,
		Default = presetNames[1],
		Callback = function(val)
			self:ApplyPreset(val)
		end,
	})

	gb:AddButton({
		Text = "Apply Default Red",
		Callback = function()
			self:ApplyPreset("Default Red")
			self.Library:Notify("Applied Default Red theme", 2)
		end,
	})
end

return ThemeManager
