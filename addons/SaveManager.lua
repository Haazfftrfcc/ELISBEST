-- SaveManager.lua (별도 콘픽 매니저 - Setting 탭에 Config UI 자동 배치)
local HttpService = game:GetService("HttpService")

local SaveManager = {}
SaveManager.__index = SaveManager

SaveManager.Folder = "LinoriaCustomConfigs"

function SaveManager.new(library)
	local self = setmetatable({}, SaveManager)
	self.Library = library
	self.Configs = {} -- [configName] = jsonString
	self.SelectedConfig = ""
	self.ConfigInputName = ""
	return self
end

function SaveManager:GetConfigNames()
	local names = {}
	for k in pairs(self.Configs) do
		table.insert(names, k)
	end

	if type(listfiles) == "function" and type(isfolder) == "function" then
		pcall(function()
			if isfolder(self.Folder) then
				for _, filePath in ipairs(listfiles(self.Folder)) do
					local fileName = tostring(filePath):match("([^/\\]+)%.json$")
					if fileName and not table.find(names, fileName) then
						table.insert(names, fileName)
					end
				end
			end
		end)
	end

	table.sort(names)
	return names
end

function SaveManager:CollectFlags()
	local data = {}
	for flagName, flagObj in pairs(self.Library.Flags or {}) do
		if flagName ~= "ConfigNameInput" and flagName ~= "ConfigListDropdown" then
			local val = flagObj.Value
			if typeof(val) == "Color3" then
				data[flagName] = { __type = "Color3", R = val.R, G = val.G, B = val.B }
			elseif typeof(val) == "EnumItem" then
				data[flagName] = { __type = "EnumItem", EnumType = tostring(val.EnumType), Name = val.Name }
			else
				data[flagName] = val
			end
		end
	end
	return data
end

function SaveManager:ApplyFlags(data)
	for flagName, savedVal in pairs(data or {}) do
		local flagObj = self.Library.Flags[flagName]
		if flagObj and type(flagObj.Set) == "function" then
			local finalVal = savedVal
			if type(savedVal) == "table" and savedVal.__type == "Color3" then
				finalVal = Color3.new(savedVal.R or 0, savedVal.G or 0, savedVal.B or 0)
			elseif type(savedVal) == "table" and savedVal.__type == "EnumItem" then
				local enumRoot = Enum[savedVal.EnumType]
				if enumRoot and enumRoot[savedVal.Name] then
					finalVal = enumRoot[savedVal.Name]
				end
			end
			flagObj.Set(finalVal)
		end
	end
end

function SaveManager:SaveConfig(name)
	name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then
		self.Library:Notify("Enter a config name first", 2)
		return false
	end

	local payload = self:CollectFlags()
	local encoded = HttpService:JSONEncode(payload)
	self.Configs[name] = encoded

	if type(writefile) == "function" then
		pcall(function()
			if type(makefolder) == "function" and (not isfolder or not isfolder(self.Folder)) then
				makefolder(self.Folder)
			end
			writefile(self.Folder .. "/" .. name .. ".json", encoded)
		end)
	end

	self.SelectedConfig = name
	return true
end

function SaveManager:LoadConfig(name)
	name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then
		self.Library:Notify("Select a config to load", 2)
		return false
	end

	local raw = self.Configs[name]
	if not raw and type(readfile) == "function" then
		pcall(function()
			local path = self.Folder .. "/" .. name .. ".json"
			if isfile and isfile(path) then
				raw = readfile(path)
				self.Configs[name] = raw
			end
		end)
	end

	if not raw then
		self.Library:Notify("Config not found: " .. name, 2)
		return false
	end

	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or type(decoded) ~= "table" then
		self.Library:Notify("Failed to decode config", 2)
		return false
	end

	self:ApplyFlags(decoded)
	return true
end

function SaveManager:DeleteConfig(name)
	name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then
		self.Library:Notify("Select a config to delete", 2)
		return false
	end

	self.Configs[name] = nil

	if type(delfile) == "function" then
		pcall(function()
			local path = self.Folder .. "/" .. name .. ".json"
			if isfile and isfile(path) then
				delfile(path)
			end
		end)
	end

	if self.SelectedConfig == name then
		self.SelectedConfig = ""
	end

	return true
end

-- Setting 탭에 Config 이름 입력, Save config, Config 리스트, Load config, Deleted config 자동 세팅
function SaveManager:BuildSettingUI(window)
	local settingTab = window.SettingTab or window:AddTab("Setting")
	local configGb = settingTab:AddGroupbox("Configuration")

	local nameInput = configGb:AddInput("ConfigNameInput", {
		Text = "Config name",
		Placeholder = "Enter config name...",
		Default = "",
		Callback = function(v)
			self.ConfigInputName = v
		end,
	})

	local listDropdown
	local function RefreshConfigList(selectName)
		local names = self:GetConfigNames()
		if listDropdown then
			listDropdown.Refresh(names)
			if selectName and table.find(names, selectName) then
				self.SelectedConfig = selectName
				listDropdown.Set(selectName)
			elseif #names > 0 then
				if not table.find(names, self.SelectedConfig) then
					self.SelectedConfig = names[1]
				end
				listDropdown.Set(self.SelectedConfig)
			else
				self.SelectedConfig = ""
				listDropdown.Set("")
			end
		end
	end

	listDropdown = configGb:AddDropdown("ConfigListDropdown", {
		Text = "Config list",
		Values = self:GetConfigNames(),
		Default = "",
		Callback = function(val)
			self.SelectedConfig = val
		end,
	})

	configGb:AddButton({
		Text = "Save config",
		Callback = function()
			local targetName = nameInput.Get()
			if targetName == "" then
				targetName = self.ConfigInputName
			end
			if self:SaveConfig(targetName) then
				RefreshConfigList(targetName)
				self.Library:Notify("Saved config: " .. targetName, 2)
			end
		end,
	})

	configGb:AddButton({
		Text = "Load config",
		Callback = function()
			local target = listDropdown.Get()
			if target == "" then
				target = self.SelectedConfig
			end
			if self:LoadConfig(target) then
				self.Library:Notify("Loaded config: " .. target, 2)
			end
		end,
	})

	configGb:AddButton({
		Text = "Deleted config",
		Callback = function()
			local target = listDropdown.Get()
			if target == "" then
				target = self.SelectedConfig
			end
			if self:DeleteConfig(target) then
				RefreshConfigList()
				self.Library:Notify("Deleted config: " .. target, 2)
			end
		end,
	})

	RefreshConfigList()
	return configGb
end

return SaveManager
