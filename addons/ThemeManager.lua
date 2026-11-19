-- ThemeManager.lua (Gray 컬러 전용 통합 코드 - Library와 연동)
local HttpService = game:GetService("HttpService")

local ThemeManager = {}
ThemeManager.__index = ThemeManager

ThemeManager.Folder = "LinoriaCustomThemes"
ThemeManager.GrayTheme = {
	BackgroundColor = Color3.fromRGB(24, 24, 27),
	MainColor = Color3.fromRGB(34, 34, 38),
	AccentColor = Color3.fromRGB(130, 130, 140),
	OutlineColor = Color3.fromRGB(78, 78, 86),
	InnerBorderColor = Color3.fromRGB(14, 14, 16),
	FontColor = Color3.fromRGB(235, 235, 240),
	SubFontColor = Color3.fromRGB(165, 165, 175),
	ElementColor = Color3.fromRGB(44, 44, 50),
	ElementHover = Color3.fromRGB(56, 56, 64),
	TabSelected = Color3.fromRGB(52, 52, 58),
	TabIdle = Color3.fromRGB(30, 30, 34),
}

ThemeManager.Presets = {
	["Gray"] = ThemeManager.GrayTheme,
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

function ThemeManager:ApplyGray()
	local converted = {}
	for k, v in pairs(self.GrayTheme) do
		converted[k] = TableToColor(v) or v
	end
	self.Library:ApplyTheme(converted)
	return true
end

function ThemeManager:ApplyPreset(presetName)
	local preset = self.Presets[presetName] or self.GrayTheme
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
			if type(makefolder) == "function" and (not isfolder or not isfolder(self.Folder)) then
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
	self:ApplyGray()

	if tab and tab.Button then
		tab.Button.MouseButton1Click:Connect(function()
			self:ApplyGray()
		end)
	end

	local gb = tab:AddGroupbox("Theme Manager")
	gb:AddDropdown("ThemePresetSelect", {
		Text = "Theme Preset",
		Values = { "Gray" },
		Default = "Gray",
		Callback = function()
			self:ApplyGray()
		end,
	})

	gb:AddButton({
		Text = "Apply Gray",
		Callback = function()
			self:ApplyGray()
			self.Library:Notify("Applied Gray theme", 2)
		end,
	})
end

return ThemeManager
