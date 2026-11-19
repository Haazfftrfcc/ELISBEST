-- Library.lua (Linoria-inspired Left-Tab Dark UI Library - 350x300)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")

local Library = {}
Library.__index = Library

Library.Flags = {}
Library.Registry = {}
Library.Signals = {}
Library.Unloaded = false

-- 리노리아 특유 짙은 다크 & 그레이/블랙 멀티 보더 팔레트
Library.Theme = {
	BackgroundColor = Color3.fromRGB(14, 14, 16),
	MainColor = Color3.fromRGB(20, 20, 23),
	AccentColor = Color3.fromRGB(185, 38, 46),
	OutlineColor = Color3.fromRGB(48, 48, 54),
	InnerBorderColor = Color3.fromRGB(6, 6, 8),
	FontColor = Color3.fromRGB(232, 232, 236),
	SubFontColor = Color3.fromRGB(155, 155, 165),
	ElementColor = Color3.fromRGB(26, 26, 30),
	ElementHover = Color3.fromRGB(34, 34, 40),
	TabSelected = Color3.fromRGB(30, 30, 36),
	TabIdle = Color3.fromRGB(17, 17, 20),
	Font = Enum.Font.Code, -- 리노리아 특유 모노스페이스/고정폭 느낌
}

local function GetParentGui()
	local ok, coreGui = pcall(function()
		return game:GetService("CoreGui")
	end)
	if ok and coreGui then
		local test = Instance.new("Folder")
		local canUseCore = pcall(function()
			test.Parent = coreGui
			test:Destroy()
		end)
		if canUseCore then
			return coreGui
		end
	end
	return PlayerGui
end

local function Create(className, props, children)
	local inst = Instance.new(className)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

-- 리노리아 시그니처: 바깥 진한 검정선 + 중간 회색선 + 안쪽 진한 검정선
local function ApplyLinoriaBorder(frame, outerBlack, midGray, innerBlack)
	outerBlack = outerBlack or Color3.fromRGB(5, 5, 7)
	midGray = midGray or Library.Theme.OutlineColor
	innerBlack = innerBlack or Color3.fromRGB(7, 7, 9)

	local oldOuter = frame:FindFirstChild("LinoriaOuterStroke")
	if oldOuter then oldOuter:Destroy() end
	local oldInnerFrame = frame:FindFirstChild("LinoriaInnerFrame")
	if oldInnerFrame then oldInnerFrame:Destroy() end

	local outerStroke = Create("UIStroke", {
		Name = "LinoriaOuterStroke",
		Color = outerBlack,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = frame,
	})

	local midFrame = Create("Frame", {
		Name = "LinoriaInnerFrame",
		Size = UDim2.new(1, -2, 1, -2),
		Position = UDim2.fromOffset(1, 1),
		BackgroundTransparency = 1,
		ZIndex = frame.ZIndex + 1,
		Parent = frame,
	})

	local midStroke = Create("UIStroke", {
		Name = "LinoriaMidGrayStroke",
		Color = midGray,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = midFrame,
	})

	local innerBlackBox = Create("Frame", {
		Name = "LinoriaInnerBlackLine",
		Size = UDim2.new(1, -2, 1, -2),
		Position = UDim2.fromOffset(1, 1),
		BackgroundTransparency = 1,
		ZIndex = frame.ZIndex + 2,
		Parent = midFrame,
	})

	local innerStroke = Create("UIStroke", {
		Name = "LinoriaInnerBlackStroke",
		Color = innerBlack,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = innerBlackBox,
	})

	return {
		Outer = outerStroke,
		Mid = midStroke,
		Inner = innerStroke,
		ContentHolder = innerBlackBox,
	}
end

local function MakeDraggable(dragHandle, targetWindow)
	local dragging = false
	local dragInput = nil
	local dragStart = nil
	local startPos = nil

	local conn1 = dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = targetWindow.Position

			local releaseConn
			releaseConn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					if releaseConn then
						releaseConn:Disconnect()
					end
				end
			end)
		end
	end)

	local conn2 = dragHandle.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	local conn3 = UserInputService.InputChanged:Connect(function(input)
		if dragging and input == dragInput then
			local delta = input.Position - dragStart
			targetWindow.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)

	table.insert(Library.Signals, conn1)
	table.insert(Library.Signals, conn2)
	table.insert(Library.Signals, conn3)
end

function Library:RegisterTheme(instance, propName, themeKey)
	table.insert(Library.Registry, {
		Instance = instance,
		Property = propName,
		ThemeKey = themeKey,
	})
	if Library.Theme[themeKey] ~= nil then
		pcall(function()
			instance[propName] = Library.Theme[themeKey]
		end)
	end
end

function Library:ApplyTheme(customTheme)
	for k, v in pairs(customTheme or {}) do
		Library.Theme[k] = v
	end
	for i = #Library.Registry, 1, -1 do
		local entry = Library.Registry[i]
		if entry.Instance and entry.Instance.Parent then
			local val = Library.Theme[entry.ThemeKey]
			if val ~= nil then
				pcall(function()
					entry.Instance[entry.Property] = val
				end)
			end
		else
			table.remove(Library.Registry, i)
		end
	end
end

function Library:Notify(text, duration)
	duration = duration or 2.5
	if not self._Gui then return end

	local holder = self._Gui:FindFirstChild("NotifyHolder")
	if not holder then
		holder = Create("Frame", {
			Name = "NotifyHolder",
			Size = UDim2.fromOffset(220, 140),
			Position = UDim2.new(1, -230, 1, -150),
			BackgroundTransparency = 1,
			Parent = self._Gui,
		})
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 6),
			Parent = holder,
		})
	end

	local toast = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = Library.Theme.MainColor,
		BorderSizePixel = 0,
		Parent = holder,
	})
	ApplyLinoriaBorder(toast, Color3.fromRGB(4, 4, 6), Library.Theme.OutlineColor, Color3.fromRGB(6, 6, 8))

	local accentBar = Create("Frame", {
		Size = UDim2.new(0, 3, 1, -4),
		Position = UDim2.fromOffset(2, 2),
		BackgroundColor3 = Library.Theme.AccentColor,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = toast,
	})

	local lbl = Create("TextLabel", {
		Size = UDim2.new(1, -14, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		BackgroundTransparency = 1,
		Text = tostring(text),
		TextColor3 = Library.Theme.FontColor,
		Font = Library.Theme.Font,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 5,
		Parent = toast,
	})

	Library:RegisterTheme(toast, "BackgroundColor3", "MainColor")
	Library:RegisterTheme(accentBar, "BackgroundColor3", "AccentColor")
	Library:RegisterTheme(lbl, "TextColor3", "FontColor")
	Library:RegisterTheme(lbl, "Font", "Font")

	task.delay(duration, function()
		if toast and toast.Parent then
			toast:Destroy()
		end
	end)
end

function Library:CreateWindow(options)
	options = options or {}
	local titleText = options.Title or "LINORIA STYLE UI"
	local windowSize = UDim2.fromOffset(350, 300) -- 가로 350, 세로 300 고정 기준

	local parentGui = GetParentGui()
	local old = parentGui:FindFirstChild("LinoriaLeftTabUI_350x300")
	if old then old:Destroy() end

	local screenGui = Create("ScreenGui", {
		Name = "LinoriaLeftTabUI_350x300",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999,
		Parent = parentGui,
	})
	self._Gui = screenGui

	-- 메인 윈도우 (350 x 300)
	local mainFrame = Create("Frame", {
		Name = "MainWindow",
		Size = windowSize,
		Position = UDim2.new(0.5, -175, 0.5, -150),
		BackgroundColor3 = Library.Theme.BackgroundColor,
		BorderSizePixel = 0,
		Active = true,
		Parent = screenGui,
	})
	Library:RegisterTheme(mainFrame, "BackgroundColor3", "BackgroundColor")
	local mainBorders = ApplyLinoriaBorder(mainFrame, Color3.fromRGB(4, 4, 6), Library.Theme.OutlineColor, Color3.fromRGB(6, 6, 8))
	Library:RegisterTheme(mainBorders.Mid, "Color", "OutlineColor")

	-- 상단 타이틀 바
	local topBar = Create("Frame", {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Library.Theme.MainColor,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = mainBorders.ContentHolder,
	})
	Library:RegisterTheme(topBar, "BackgroundColor3", "MainColor")

	local topAccent = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 2),
		Position = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Library.Theme.AccentColor,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = topBar,
	})
	Library:RegisterTheme(topAccent, "BackgroundColor3", "AccentColor")

	local titleLabel = Create("TextLabel", {
		Size = UDim2.new(1, -16, 1, -2),
		Position = UDim2.fromOffset(8, 2),
		BackgroundTransparency = 1,
		Text = titleText,
		TextColor3 = Library.Theme.FontColor,
		Font = Library.Theme.Font,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
		Parent = topBar,
	})
	Library:RegisterTheme(titleLabel, "TextColor3", "FontColor")
	Library:RegisterTheme(titleLabel, "Font", "Font")

	-- 타이틀 바와 본문 구분선 (회색 + 진한 검정)
	local topDividerGray = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.fromOffset(0, 24),
		BackgroundColor3 = Library.Theme.OutlineColor,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = mainBorders.ContentHolder,
	})
	Library:RegisterTheme(topDividerGray, "BackgroundColor3", "OutlineColor")

	local topDividerBlack = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.fromOffset(0, 25),
		BackgroundColor3 = Color3.fromRGB(4, 4, 6),
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = mainBorders.ContentHolder,
	})

	MakeDraggable(topBar, mainFrame)

	-- 좌측 세로 탭 영역 (가로 84px, 세로 나머지 전체)
	local leftTabColumn = Create("Frame", {
		Name = "LeftTabColumn",
		Size = UDim2.new(0, 84, 1, -26),
		Position = UDim2.fromOffset(0, 26),
		BackgroundColor3 = Library.Theme.MainColor,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = mainBorders.ContentHolder,
	})
	Library:RegisterTheme(leftTabColumn, "BackgroundColor3", "MainColor")

	local tabListLayout = Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 3),
		Parent = leftTabColumn,
	})
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		Parent = leftTabColumn,
	})

	-- 좌측 탭과 우측 컨텐츠 사이 구분선 (회색 + 진한 검정)
	local vDividerGray = Create("Frame", {
		Size = UDim2.new(0, 1, 1, -26),
		Position = UDim2.fromOffset(84, 26),
		BackgroundColor3 = Library.Theme.OutlineColor,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = mainBorders.ContentHolder,
	})
	Library:RegisterTheme(vDividerGray, "BackgroundColor3", "OutlineColor")

	local vDividerBlack = Create("Frame", {
		Size = UDim2.new(0, 1, 1, -26),
		Position = UDim2.fromOffset(85, 26),
		BackgroundColor3 = Color3.fromRGB(4, 4, 6),
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = mainBorders.ContentHolder,
	})

	-- 우측 컨텐츠 영역
	local contentArea = Create("Frame", {
		Name = "ContentArea",
		Size = UDim2.new(1, -86, 1, -26),
		Position = UDim2.fromOffset(86, 26),
		BackgroundColor3 = Library.Theme.BackgroundColor,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = mainBorders.ContentHolder,
	})
	Library:RegisterTheme(contentArea, "BackgroundColor3", "BackgroundColor")

	-- 전용 끄고/닫는 토글 버튼 (드래그 가능 + 클릭/터치 시 UI 열고 닫기)
	local toggleBtn = Create("TextButton", {
		Name = "DedicatedToggleButton",
		Size = UDim2.fromOffset(64, 24),
		Position = UDim2.new(0, 12, 0.5, -12),
		BackgroundColor3 = Library.Theme.MainColor,
		Text = "Toggle",
		TextColor3 = Library.Theme.FontColor,
		Font = Library.Theme.Font,
		TextSize = 11,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		ZIndex = 50,
		Parent = screenGui,
	})
	Library:RegisterTheme(toggleBtn, "BackgroundColor3", "MainColor")
	Library:RegisterTheme(toggleBtn, "TextColor3", "FontColor")
	Library:RegisterTheme(toggleBtn, "Font", "Font")
	local toggleBorders = ApplyLinoriaBorder(toggleBtn, Color3.fromRGB(4, 4, 6), Library.Theme.OutlineColor, Color3.fromRGB(6, 6, 8))
	Library:RegisterTheme(toggleBorders.Mid, "Color", "OutlineColor")

	local toggleAccent = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 2),
		Position = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Library.Theme.AccentColor,
		BorderSizePixel = 0,
		ZIndex = 52,
		Parent = toggleBorders.ContentHolder,
	})
	Library:RegisterTheme(toggleAccent, "BackgroundColor3", "AccentColor")

	local isOpen = true
	local function SetWindowVisible(state)
		isOpen = state and true or false
		mainFrame.Visible = isOpen
		toggleBtn.Text = isOpen and "Toggle" or "Open UI"
		toggleAccent.BackgroundColor3 = isOpen and Library.Theme.AccentColor or Color3.fromRGB(95, 95, 105)
	end

	local draggingToggle = false
	local toggleDragInput = nil
	local toggleDragStart = nil
	local toggleStartPos = nil
	local toggleClickMoved = false

	local tConn1 = toggleBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingToggle = true
			toggleClickMoved = false
			toggleDragStart = input.Position
			toggleStartPos = toggleBtn.Position

			local releaseConn
			releaseConn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					draggingToggle = false
					if releaseConn then
						releaseConn:Disconnect()
					end
				end
			end)
		end
	end)

	local tConn2 = toggleBtn.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			toggleDragInput = input
		end
	end)

	local tConn3 = UserInputService.InputChanged:Connect(function(input)
		if draggingToggle and input == toggleDragInput then
			if (input.Position - toggleDragStart).Magnitude > 5 then
				toggleClickMoved = true
			end
			local delta = input.Position - toggleDragStart
			toggleBtn.Position = UDim2.new(
				toggleStartPos.X.Scale,
				toggleStartPos.X.Offset + delta.X,
				toggleStartPos.Y.Scale,
				toggleStartPos.Y.Offset + delta.Y
			)
		end
	end)

	local tConn4 = toggleBtn.MouseButton1Click:Connect(function()
		if not toggleClickMoved then
			SetWindowVisible(not isOpen)
		end
	end)

	table.insert(Library.Signals, tConn1)
	table.insert(Library.Signals, tConn2)
	table.insert(Library.Signals, tConn3)
	table.insert(Library.Signals, tConn4)

	local Window = {
		Tabs = {},
		ActiveTab = nil,
		ScreenGui = screenGui,
		MainFrame = mainFrame,
		ToggleButton = toggleBtn,
		SetVisible = SetWindowVisible,
	}

	function Window:SelectTab(tabObj)
		if Window.ActiveTab == tabObj then return end
		Window.ActiveTab = tabObj

		for _, t in ipairs(Window.Tabs) do
			local active = (t == tabObj)
			t.Page.Visible = active
			t.Button.BackgroundColor3 = active and Library.Theme.TabSelected or Library.Theme.TabIdle
			t.Label.TextColor3 = active and Library.Theme.FontColor or Library.Theme.SubFontColor
			t.Indicator.Visible = active
		end
	end

	-- 왼쪽 세로 탭 생성기
	-- 그룹박스 배치 규칙:
	-- 1번째: 왼쪽 상단 / 2번째: 오른쪽 상단 / 3번째: 왼쪽 아래 / 4번째: 오른쪽 아래 / 5번째: 그 아래 왼쪽 ...
	function Window:AddTab(name)
		local tabOrder = #Window.Tabs + 1

		local tabBtn = Create("TextButton", {
			Name = "TabBtn_" .. tostring(name),
			Size = UDim2.new(1, 0, 0, 24),
			LayoutOrder = tabOrder,
			BackgroundColor3 = Library.Theme.TabIdle,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 5,
			Parent = leftTabColumn,
		})
		ApplyLinoriaBorder(tabBtn, Color3.fromRGB(5, 5, 7), Library.Theme.OutlineColor, Color3.fromRGB(7, 7, 9))

		local indicator = Create("Frame", {
			Size = UDim2.new(0, 2, 1, -6),
			Position = UDim2.fromOffset(3, 3),
			BackgroundColor3 = Library.Theme.AccentColor,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 8,
			Parent = tabBtn,
		})
		Library:RegisterTheme(indicator, "BackgroundColor3", "AccentColor")

		local tabLbl = Create("TextLabel", {
			Size = UDim2.new(1, -10, 1, 0),
			Position = UDim2.fromOffset(8, 0),
			BackgroundTransparency = 1,
			Text = tostring(name),
			TextColor3 = Library.Theme.SubFontColor,
			Font = Library.Theme.Font,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 8,
			Parent = tabBtn,
		})
		Library:RegisterTheme(tabLbl, "Font", "Font")

		local page = Create("ScrollingFrame", {
			Name = "Page_" .. tostring(name),
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Library.Theme.OutlineColor,
			CanvasSize = UDim2.fromOffset(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Visible = false,
			ZIndex = 5,
			Parent = contentArea,
		})
		Library:RegisterTheme(page, "ScrollBarImageColor3", "OutlineColor")

		Create("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 8),
			Parent = page,
		})

		-- 좌/우 두 칼럼으로 나누되, 그룹박스가 1(좌) -> 2(우) -> 3(좌) -> 4(우) -> 5(좌) 순으로 추가되도록 배치
		local leftCol = Create("Frame", {
			Name = "LeftColumn",
			Size = UDim2.new(0.5, -3, 0, 0),
			Position = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			ZIndex = 5,
			Parent = page,
		})
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
			Parent = leftCol,
		})

		local rightCol = Create("Frame", {
			Name = "RightColumn",
			Size = UDim2.new(0.5, -3, 0, 0),
			Position = UDim2.new(0.5, 3, 0, 0),
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			ZIndex = 5,
			Parent = page,
		})
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
			Parent = rightCol,
		})

		local Tab = {
			Name = name,
			Button = tabBtn,
			Label = tabLbl,
			Indicator = indicator,
			Page = page,
			LeftColumn = leftCol,
			RightColumn = rightCol,
			GroupCount = 0,
		}

		tabBtn.MouseButton1Click:Connect(function()
			Window:SelectTab(Tab)
		end)

		table.insert(Window.Tabs, Tab)
		if #Window.Tabs == 1 then
			Window:SelectTab(Tab)
		end

		-- 그룹박스 생성기
		function Tab:AddGroupbox(gbTitle)
			Tab.GroupCount += 1
			local idx = Tab.GroupCount
			-- 홀수(1, 3, 5...)는 왼쪽, 짝수(2, 4, 6...)는 오른쪽
			local targetCol = (idx % 2 == 1) and Tab.LeftColumn or Tab.RightColumn

			local gbFrame = Create("Frame", {
				Name = "Groupbox_" .. tostring(gbTitle),
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = idx,
				BackgroundColor3 = Library.Theme.MainColor,
				BorderSizePixel = 0,
				ZIndex = 6,
				Parent = targetCol,
			})
			Library:RegisterTheme(gbFrame, "BackgroundColor3", "MainColor")

			-- 리노리아 그룹박스: 진한 검정 외곽선 + 회색선 + 진한 검정 내곽선
			local gbBorders = ApplyLinoriaBorder(
				gbFrame,
				Color3.fromRGB(3, 3, 4),
				Library.Theme.OutlineColor,
				Color3.fromRGB(4, 4, 6)
			)
			Library:RegisterTheme(gbBorders.Mid, "Color", "OutlineColor")

			-- 그룹박스 상단 제목 바
			local header = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundColor3 = Library.Theme.ElementColor,
				BorderSizePixel = 0,
				ZIndex = 7,
				Parent = gbBorders.ContentHolder,
			})
			Library:RegisterTheme(header, "BackgroundColor3", "ElementColor")

			local titleLbl = Create("TextLabel", {
				Size = UDim2.new(1, -8, 1, 0),
				Position = UDim2.fromOffset(6, 0),
				BackgroundTransparency = 1,
				Text = tostring(gbTitle),
				TextColor3 = Library.Theme.FontColor,
				Font = Library.Theme.Font,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 8,
				Parent = header,
			})
			Library:RegisterTheme(titleLbl, "TextColor3", "FontColor")
			Library:RegisterTheme(titleLbl, "Font", "Font")

			-- 제목 아래 회색 선 + 진한 검정 선
			local hGray = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 1),
				Position = UDim2.fromOffset(0, 18),
				BackgroundColor3 = Library.Theme.OutlineColor,
				BorderSizePixel = 0,
				ZIndex = 8,
				Parent = gbBorders.ContentHolder,
			})
			Library:RegisterTheme(hGray, "BackgroundColor3", "OutlineColor")

			local hBlack = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 1),
				Position = UDim2.fromOffset(0, 19),
				BackgroundColor3 = Color3.fromRGB(3, 3, 5),
				BorderSizePixel = 0,
				ZIndex = 8,
				Parent = gbBorders.ContentHolder,
			})

			local itemHolder = Create("Frame", {
				Name = "Items",
				Size = UDim2.new(1, 0, 0, 0),
				Position = UDim2.fromOffset(0, 20),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				ZIndex = 7,
				Parent = gbBorders.ContentHolder,
			})

			Create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 5),
				Parent = itemHolder,
			})
			Create("UIPadding", {
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				Parent = itemHolder,
			})

			local Groupbox = {
				Frame = gbFrame,
				Items = itemHolder,
			}

			local function BindFlag(flag, defaultVal, setter)
				if flag then
					Library.Flags[flag] = {
						Value = defaultVal,
						Set = function(val)
							Library.Flags[flag].Value = val
							setter(val)
						end,
						Get = function()
							return Library.Flags[flag].Value
						end,
					}
				end
			end

			function Groupbox:AddLabel(text)
				local lbl = Create("TextLabel", {
					Size = UDim2.new(1, 0, 0, 16),
					BackgroundTransparency = 1,
					Text = tostring(text),
					TextColor3 = Library.Theme.SubFontColor,
					Font = Library.Theme.Font,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextWrapped = true,
					AutomaticSize = Enum.AutomaticSize.Y,
					ZIndex = 8,
					Parent = itemHolder,
				})
				Library:RegisterTheme(lbl, "TextColor3", "SubFontColor")
				Library:RegisterTheme(lbl, "Font", "Font")
				return {
					SetText = function(t)
						lbl.Text = tostring(t)
					end,
				}
			end

			function Groupbox:AddButton(opts)
				opts = type(opts) == "table" and opts or { Text = tostring(opts) }
				local btn = Create("TextButton", {
					Size = UDim2.new(1, 0, 0, 20),
					BackgroundColor3 = Library.Theme.ElementColor,
					Text = opts.Text or "Button",
					TextColor3 = Library.Theme.FontColor,
					Font = Library.Theme.Font,
					TextSize = 11,
					BorderSizePixel = 0,
					AutoButtonColor = false,
					ZIndex = 8,
					Parent = itemHolder,
				})
				Library:RegisterTheme(btn, "BackgroundColor3", "ElementColor")
				Library:RegisterTheme(btn, "TextColor3", "FontColor")
				Library:RegisterTheme(btn, "Font", "Font")
				local bBorders = ApplyLinoriaBorder(btn, Color3.fromRGB(4, 4, 6), Library.Theme.OutlineColor, Color3.fromRGB(6, 6, 8))
				Library:RegisterTheme(bBorders.Mid, "Color", "OutlineColor")

				btn.MouseEnter:Connect(function()
					btn.BackgroundColor3 = Library.Theme.ElementHover
				end)
				btn.MouseLeave:Connect(function()
					btn.BackgroundColor3 = Library.Theme.ElementColor
				end)
				btn.MouseButton1Click:Connect(function()
					if opts.Callback then
						opts.Callback()
					end
				end)

				return btn
			end

			function Groupbox:AddToggle(flag, opts)
				opts = opts or {}
				local state = opts.Default == true

				local row = Create("TextButton", {
					Size = UDim2.new(1, 0, 0, 18),
					BackgroundTransparency = 1,
					Text = "",
					AutoButtonColor = false,
					ZIndex = 8,
					Parent = itemHolder,
				})

				local box = Create("Frame", {
					Size = UDim2.fromOffset(14, 14),
					Position = UDim2.new(0, 0, 0.5, -7),
					BackgroundColor3 = state and Library.Theme.AccentColor or Library.Theme.ElementColor,
					BorderSizePixel = 0,
					ZIndex = 9,
					Parent = row,
				})
				local boxBorders = ApplyLinoriaBorder(box, Color3.fromRGB(4, 4, 6), Library.Theme.OutlineColor, Color3.fromRGB(6, 6, 8))
				Library:RegisterTheme(boxBorders.Mid, "Color", "OutlineColor")

				local lbl = Create("TextLabel", {
					Size = UDim2.new(1, -20, 1, 0),
					Position = UDim2.fromOffset(20, 0),
					BackgroundTransparency = 1,
					Text = opts.Text or tostring(flag),
					TextColor3 = Library.Theme.FontColor,
					Font = Library.Theme.Font,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					ZIndex = 9,
					Parent = row,
				})
				Library:RegisterTheme(lbl, "TextColor3", "FontColor")
				Library:RegisterTheme(lbl, "Font", "Font")

				local function SetState(v)
					state = v and true or false
					box.BackgroundColor3 = state and Library.Theme.AccentColor or Library.Theme.ElementColor
					if Library.Flags[flag] then
						Library.Flags[flag].Value = state
					end
					if opts.Callback then
						opts.Callback(state)
					end
				end

				row.MouseButton1Click:Connect(function()
					SetState(not state)
				end)

				BindFlag(flag, state, SetState)
				if opts.Callback then
					task.defer(opts.Callback, state)
				end

				return {
					Set = SetState,
					Get = function() return state end,
				}
			end

			function Groupbox:AddInput(flag, opts)
				opts = opts or {}
				local val = tostring(opts.Default or "")

				local wrap = Create("Frame", {
					Size = UDim2.new(1, 0, 0, opts.Text and 34 or 20),
					BackgroundTransparency = 1,
					ZIndex = 8,
					Parent = itemHolder,
				})

				local inputTopOffset = 0
				if opts.Text then
					local cap = Create("TextLabel", {
						Size = UDim2.new(1, 0, 0, 13),
						Position = UDim2.fromOffset(0, 0),
						BackgroundTransparency = 1,
						Text = opts.Text,
						TextColor3 = Library.Theme.SubFontColor,
						Font = Library.Theme.Font,
						TextSize = 10,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 9,
						Parent = wrap,
					})
					Library:RegisterTheme(cap, "TextColor3", "SubFontColor")
					Library:RegisterTheme(cap, "Font", "Font")
					inputTopOffset = 14
				end

				local boxFrame = Create("Frame", {
					Size = UDim2.new(1, 0, 0, 20),
					Position = UDim2.fromOffset(0, inputTopOffset),
					BackgroundColor3 = Library.Theme.ElementColor,
					BorderSizePixel = 0,
					ZIndex = 9,
					Parent = wrap,
				})
				Library:RegisterTheme(boxFrame, "BackgroundColor3", "ElementColor")
				local iBorders = ApplyLinoriaBorder(boxFrame, Color3.fromRGB(4, 4, 6), Library.Theme.OutlineColor, Color3.fromRGB(6, 6, 8))
				Library:RegisterTheme(iBorders.Mid, "Color", "OutlineColor")

				local tBox = Create("TextBox", {
					Size = UDim2.new(1, -8, 1, 0),
					Position = UDim2.fromOffset(4, 0),
					BackgroundTransparency = 1,
					Text = val,
					PlaceholderText = opts.Placeholder or "",
					PlaceholderColor3 = Color3.fromRGB(115, 115, 125),
					TextColor3 = Library.Theme.FontColor,
					Font = Library.Theme.Font,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					ClearTextOnFocus = opts.ClearTextOnFocus == true,
					ZIndex = 10,
					Parent = boxFrame,
				})
				Library:RegisterTheme(tBox, "TextColor3", "FontColor")
				Library:RegisterTheme(tBox, "Font", "Font")

				local function SetVal(newV)
					val = tostring(newV or "")
					tBox.Text = val
					if Library.Flags[flag] then
						Library.Flags[flag].Value = val
					end
					if opts.Callback then
						opts.Callback(val)
					end
				end

				tBox.FocusLost:Connect(function(enterPressed)
					SetVal(tBox.Text)
					if opts.OnEnter and enterPressed then
						opts.OnEnter(val)
					end
				end)

				BindFlag(flag, val, SetVal)
				return {
					Set = SetVal,
					Get = function() return val end,
					TextBox = tBox,
				}
			end

			function Groupbox:AddSlider(flag, opts)
				opts = opts or {}
				local minVal = opts.Min or 0
				local maxVal = opts.Max or 100
				local rounding = opts.Rounding or 0
				local current = opts.Default or minVal

				local function Round(n)
					if rounding <= 0 then
						return math.floor(n + 0.5)
					end
					local mult = 10 ^ rounding
					return math.floor(n * mult + 0.5) / mult
				end

				current = math.clamp(Round(current), minVal, maxVal)

				local wrap = Create("Frame", {
					Size = UDim2.new(1, 0, 0, 32),
					BackgroundTransparency = 1,
					ZIndex = 8,
					Parent = itemHolder,
				})

				local topRow = Create("Frame", {
					Size = UDim2.new(1, 0, 0, 14),
					BackgroundTransparency = 1,
					ZIndex = 9,
					Parent = wrap,
				})

				local sTitle = Create("TextLabel", {
					Size = UDim2.new(0.65, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = opts.Text or tostring(flag),
					TextColor3 = Library.Theme.FontColor,
					Font = Library.Theme.Font,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					ZIndex = 9,
					Parent = topRow,
				})
				Library:RegisterTheme(sTitle, "TextColor3", "FontColor")
				Library:RegisterTheme(sTitle, "Font", "Font")

				local sVal = Create("TextLabel", {
					Size = UDim2.new(0.35, 0, 1, 0),
					Position = UDim2.fromScale(0.65, 0),
					BackgroundTransparency = 1,
					Text = tostring(current) .. (opts.Suffix or ""),
					TextColor3 = Library.Theme.SubFontColor,
					Font = Library.Theme.Font,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Right,
					ZIndex = 9,
					Parent = topRow,
				})
				Library:RegisterTheme(sVal, "TextColor3", "SubFontColor")
				Library:RegisterTheme(sVal, "Font", "Font")

				local barBg = Create("Frame", {
					Size = UDim2.new(1, 0, 0, 14),
					Position = UDim2.fromOffset(0, 16),
					BackgroundColor3 = Library.Theme.ElementColor,
					BorderSizePixel = 0,
					ZIndex = 9,
					Parent = wrap,
				})
				Library:RegisterTheme(barBg, "BackgroundColor3", "ElementColor")
				local slBorders = ApplyLinoriaBorder(barBg, Color3.fromRGB(4, 4, 6), Library.Theme.OutlineColor, Color3.fromRGB(6, 6, 8))
				Library:RegisterTheme(slBorders.Mid, "Color", "OutlineColor")

				local fill = Create("Frame", {
					Size = UDim2.fromScale(0, 1),
					BackgroundColor3 = Library.Theme.AccentColor,
					BorderSizePixel = 0,
					ZIndex = 10,
					Parent = slBorders.ContentHolder,
				})
				Library:RegisterTheme(fill, "BackgroundColor3", "AccentColor")

				local function SetSlider(v)
					local num = tonumber(v)
					if not num then return end
					current = math.clamp(Round(num), minVal, maxVal)
					local alpha = (maxVal == minVal) and 0 or ((current - minVal) / (maxVal - minVal))
					fill.Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
					sVal.Text = tostring(current) .. (opts.Suffix or "")
					if Library.Flags[flag] then
						Library.Flags[flag].Value = current
					end
					if opts.Callback then
						opts.Callback(current)
					end
				end

				local sliding = false
				local function UpdateFromInput(input)
					local absPos = slBorders.ContentHolder.AbsolutePosition.X
					local absSize = math.max(slBorders.ContentHolder.AbsoluteSize.X, 1)
					local rel = math.clamp((input.Position.X - absPos) / absSize, 0, 1)
					SetSlider(minVal + (maxVal - minVal) * rel)
				end

				barBg.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						sliding = true
						UpdateFromInput(input)
					end
				end)

				UserInputService.InputChanged:Connect(function(input)
					if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
						UpdateFromInput(input)
					end
				end)

				UserInputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						sliding = false
					end
				end)

				SetSlider(current)
				BindFlag(flag, current, SetSlider)

				return {
					Set = SetSlider,
					Get = function() return current end,
				}
			end

			function Groupbox:AddDropdown(flag, opts)
				opts = opts or {}
				local values = opts.Values or {}
				local selected = opts.Default or values[1] or ""
				local open = false

				local wrap = Create("Frame", {
					Size = UDim2.new(1, 0, 0, opts.Text and 34 or 20),
					BackgroundTransparency = 1,
					ZIndex = 12,
					Parent = itemHolder,
				})

				local topOff = 0
				if opts.Text then
					local cap = Create("TextLabel", {
						Size = UDim2.new(1, 0, 0, 13),
						BackgroundTransparency = 1,
						Text = opts.Text,
						TextColor3 = Library.Theme.SubFontColor,
						Font = Library.Theme.Font,
						TextSize = 10,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 12,
						Parent = wrap,
					})
					Library:RegisterTheme(cap, "TextColor3", "SubFontColor")
					Library:RegisterTheme(cap, "Font", "Font")
					topOff = 14
				end

				local dropBtn = Create("TextButton", {
					Size = UDim2.new(1, 0, 0, 20),
					Position = UDim2.fromOffset(0, topOff),
					BackgroundColor3 = Library.Theme.ElementColor,
					Text = tostring(selected),
					TextColor3 = Library.Theme.FontColor,
					Font = Library.Theme.Font,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					BorderSizePixel = 0,
					AutoButtonColor = false,
					ZIndex = 13,
					Parent = wrap,
				})
				Library:RegisterTheme(dropBtn, "BackgroundColor3", "ElementColor")
				Library:RegisterTheme(dropBtn, "TextColor3", "FontColor")
				Library:RegisterTheme(dropBtn, "Font", "Font")
				Create("UIPadding", {
					PaddingLeft = UDim.new(0, 6),
					PaddingRight = UDim.new(0, 18),
					Parent = dropBtn,
				})
				local dBorders = ApplyLinoriaBorder(dropBtn, Color3.fromRGB(4, 4, 6), Library.Theme.OutlineColor, Color3.fromRGB(6, 6, 8))
				Library:RegisterTheme(dBorders.Mid, "Color", "OutlineColor")

				local arrow = Create("TextLabel", {
					Size = UDim2.fromOffset(14, 14),
					Position = UDim2.new(1, -16, 0.5, -7),
					BackgroundTransparency = 1,
					Text = "v",
					TextColor3 = Library.Theme.SubFontColor,
					Font = Library.Theme.Font,
					TextSize = 11,
					ZIndex = 15,
					Parent = dropBtn,
				})

				local listFrame = Create("ScrollingFrame", {
					Size = UDim2.new(1, 0, 0, math.min(#values * 18 + 4, 90)),
					Position = UDim2.fromOffset(0, topOff + 21),
					BackgroundColor3 = Library.Theme.MainColor,
					BorderSizePixel = 0,
					ScrollBarThickness = 2,
					CanvasSize = UDim2.fromOffset(0, 0),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					Visible = false,
					ZIndex = 30,
					Parent = wrap,
				})
				Library:RegisterTheme(listFrame, "BackgroundColor3", "MainColor")
				local lBorders = ApplyLinoriaBorder(listFrame, Color3.fromRGB(3, 3, 4), Library.Theme.OutlineColor, Color3.fromRGB(5, 5, 7))
				Library:RegisterTheme(lBorders.Mid, "Color", "OutlineColor")

				Create("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 2),
					Parent = lBorders.ContentHolder,
				})
				Create("UIPadding", {
					PaddingTop = UDim.new(0, 2),
					PaddingBottom = UDim.new(0, 2),
					PaddingLeft = UDim.new(0, 2),
					PaddingRight = UDim.new(0, 2),
					Parent = lBorders.ContentHolder,
				})

				local function SetDropdown(v)
					selected = tostring(v or "")
					dropBtn.Text = selected
					if Library.Flags[flag] then
						Library.Flags[flag].Value = selected
					end
					if opts.Callback then
						opts.Callback(selected)
					end
				end

				local function RebuildOptions(newList)
					values = newList or {}
					for _, child in ipairs(lBorders.ContentHolder:GetChildren()) do
						if child:IsA("TextButton") then
							child:Destroy()
						end
					end
					for i, itemVal in ipairs(values) do
						local optBtn = Create("TextButton", {
							Size = UDim2.new(1, 0, 0, 16),
							LayoutOrder = i,
							BackgroundColor3 = Library.Theme.ElementColor,
							Text = tostring(itemVal),
							TextColor3 = Library.Theme.FontColor,
							Font = Library.Theme.Font,
							TextSize = 10,
							BorderSizePixel = 0,
							AutoButtonColor = false,
							ZIndex = 32,
							Parent = lBorders.ContentHolder,
						})
						optBtn.MouseButton1Click:Connect(function()
							SetDropdown(itemVal)
							open = false
							listFrame.Visible = false
							wrap.Size = UDim2.new(1, 0, 0, opts.Text and 34 or 20)
						end)
					end
					listFrame.Size = UDim2.new(1, 0, 0, math.min(#values * 18 + 6, 90))
				end

				RebuildOptions(values)

				dropBtn.MouseButton1Click:Connect(function()
					open = not open
					listFrame.Visible = open
					if open then
						local extra = listFrame.Size.Y.Offset + 2
						wrap.Size = UDim2.new(1, 0, 0, (opts.Text and 34 or 20) + extra)
					else
						wrap.Size = UDim2.new(1, 0, 0, opts.Text and 34 or 20)
					end
				end)

				BindFlag(flag, selected, SetDropdown)

				return {
					Set = SetDropdown,
					Get = function() return selected end,
					Refresh = RebuildOptions,
				}
			end

			return Groupbox
		end

		return Tab
	end

	-- UI 불러올 때 Setting 탭이 무조건 존재하도록 자동 생성
	local settingTab = Window:AddTab("Setting")
	Window.SettingTab = settingTab

	return Window
end

return Library
