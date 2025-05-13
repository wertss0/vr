--// Services
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

--// Chat Compatibility
local oldChat = TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService
local function Chat(msg)
	if not oldChat then
		TextChatService.TextChannels.RBXGeneral:SendAsync(msg)
	else
		ReplicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(msg, "All")
	end
end

--// State
local adornments = {}
local nameTags = {}
local primaryParts = {}
local isKilled = false
local espEnabled = true
local playersESPEnabled = true
local guiVisible = true

--// Folder colors
local folderColors = {
	Monsters = Color3.fromRGB(255, 0, 0),
	Generators = Color3.fromRGB(255, 255, 0),
	Items = Color3.fromRGB(0, 170, 255),
	InGamePlayers = Color3.fromRGB(0, 255, 0)
}

--// GUI Setup
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ESP GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ESPGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 250)
frame.Position = UDim2.new(0.5, -100, 0.2, 0)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = screenGui

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(1, -10, 0, 40)
toggleButton.Position = UDim2.new(0, 5, 0, 10)
toggleButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
toggleButton.TextColor3 = Color3.new(1, 1, 1)
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.TextScaled = true
toggleButton.Text = "ESP: ON"
toggleButton.Parent = frame
toggleButton.MouseButton1Click:Connect(function()
	espEnabled = not espEnabled
	toggleButton.Text = "ESP: " .. (espEnabled and "ON" or "OFF")
	toggleButton.BackgroundColor3 = espEnabled and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(100, 0, 0)
	if not espEnabled then clearAll() end
end)

local playerButton = Instance.new("TextButton")
playerButton.Size = UDim2.new(1, -10, 0, 40)
playerButton.Position = UDim2.new(0, 5, 0, 60)
playerButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
playerButton.TextColor3 = Color3.new(1, 1, 1)
playerButton.Font = Enum.Font.SourceSansBold
playerButton.TextScaled = true
playerButton.Text = "Players: ON"
playerButton.Parent = frame
playerButton.MouseButton1Click:Connect(function()
	playersESPEnabled = not playersESPEnabled
	playerButton.Text = "Players: " .. (playersESPEnabled and "ON" or "OFF")
	playerButton.BackgroundColor3 = playersESPEnabled and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(100, 0, 0)
end)

local monsterButton = Instance.new("TextButton")
monsterButton.Size = UDim2.new(1, -10, 0, 40)
monsterButton.Position = UDim2.new(0, 5, 0, 110)
monsterButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
monsterButton.TextColor3 = Color3.new(1, 1, 1)
monsterButton.Font = Enum.Font.SourceSansBold
monsterButton.TextScaled = true
monsterButton.Text = "Say Monsters"
monsterButton.Parent = frame
monsterButton.MouseButton1Click:Connect(function()
	local room = Workspace:FindFirstChild("CurrentRoom")
	local model = room and room:FindFirstChildWhichIsA("Model")
	local folder = model and model:FindFirstChild("Monsters")
	local names = {}
	if folder then
		for _, obj in ipairs(folder:GetChildren()) do
			local name = obj.Name:gsub("[Mm]onster", ""):gsub("_", " "):gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")
			table.insert(names, name)
		end
	end
	Chat(#names > 0 and "Monsters: " .. table.concat(names, ", ") or "Monsters: None found")
end)

local healthButton = Instance.new("TextButton")
healthButton.Size = UDim2.new(1, -10, 0, 40)
healthButton.Position = UDim2.new(0, 5, 0, 160)
healthButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
healthButton.TextColor3 = Color3.new(1, 1, 1)
healthButton.Font = Enum.Font.SourceSansBold
healthButton.TextScaled = true
healthButton.Text = "Say Health Items"
healthButton.Parent = frame
healthButton.MouseButton1Click:Connect(function()
	local room = Workspace:FindFirstChild("CurrentRoom")
	local model = room and room:FindFirstChildWhichIsA("Model")
	local folder = model and model:FindFirstChild("Items")
	local names = {}
	if folder then
		for _, obj in ipairs(folder:GetChildren()) do
			local lower = obj.Name:lower()
			if lower:find("bandage") or lower:find("healthkit") then
				table.insert(names, obj.Name)
			end
		end
	end
	Chat(#names > 0 and "Items: " .. table.concat(names, ", ") or "Items: No Health Items")
end)

-- GUI visibility toggle (RightShift)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		guiVisible = not guiVisible
		screenGui.Enabled = guiVisible
		if listGui then listGui.Enabled = guiVisible end
	end
end)

-- Kill switch
local listGui -- define early
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.L then
		isKilled = true
		clearAll()
		if screenGui then screenGui:Destroy() end
		if listGui then listGui:Destroy() end
	end
end)

-- ESP logic
function setupESP(obj, color)
	if adornments[obj] then return end
	local part = obj:IsA("Model") and obj.PrimaryPart or obj
	if obj:IsA("Model") and not part then
		obj.PrimaryPart = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
		part = obj.PrimaryPart
	end
	if not part then return end
	primaryParts[obj] = part

	local box = Instance.new("BoxHandleAdornment")
	box.Adornee = part
	box.AlwaysOnTop = true
	box.ZIndex = 0
	box.Color3 = color
	box.Transparency = 0.3
	box.Size = obj:IsA("Model") and obj:GetExtentsSize() or obj.Size
	box.Parent = part
	adornments[obj] = box

	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = part
	billboard.Size = UDim2.new(0, 100, 0, 20)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.new(1, 0, 1, 0)
	text.Text = obj.Name
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0
	text.TextScaled = true
	text.Font = Enum.Font.SourceSansBold
	text.Parent = billboard

	nameTags[obj] = billboard
end

function clearAll()
	for _, a in pairs(adornments) do if a then a:Destroy() end end
	for _, b in pairs(nameTags) do if b then b:Destroy() end end
	adornments, nameTags, primaryParts = {}, {}, {}
end

-- Create List GUI
listGui = Instance.new("ScreenGui")
listGui.Name = "ESPListGui"
listGui.ResetOnSpawn = false
listGui.IgnoreGuiInset = true
listGui.Parent = playerGui

local listFrame = Instance.new("Frame")
listFrame.Size = UDim2.new(0, 300, 0, 300)
listFrame.Position = UDim2.new(0, 30, 0.2, 0)
listFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
listFrame.BorderSizePixel = 0
listFrame.Active = true
listFrame.Draggable = true
listFrame.Parent = listGui

local dragHandle = Instance.new("TextButton")
dragHandle.Size = UDim2.new(1, 0, 0, 25)
dragHandle.Position = UDim2.new(0, 0, 0, 0)
dragHandle.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
dragHandle.Text = "Monster & Item List"
dragHandle.TextColor3 = Color3.new(1, 1, 1)
dragHandle.Font = Enum.Font.SourceSansBold
dragHandle.TextSize = 18
dragHandle.AutoButtonColor = false
dragHandle.Parent = listFrame

local monsterList = Instance.new("TextLabel")
monsterList.Size = UDim2.new(0.5, 0, 1, -25)
monsterList.Position = UDim2.new(0, 0, 0, 25)
monsterList.BackgroundColor3 = Color3.fromRGB(40, 0, 0)
monsterList.TextColor3 = Color3.new(1, 1, 1)
monsterList.TextXAlignment = Enum.TextXAlignment.Left
monsterList.TextYAlignment = Enum.TextYAlignment.Top
monsterList.TextWrapped = true
monsterList.TextScaled = false
monsterList.Font = Enum.Font.Code
monsterList.Text = "Monsters:"
monsterList.Parent = listFrame

local itemList = Instance.new("TextLabel")
itemList.Size = UDim2.new(0.5, 0, 1, -25)
itemList.Position = UDim2.new(0.5, 0, 0, 25)
itemList.BackgroundColor3 = Color3.fromRGB(0, 0, 40)
itemList.TextColor3 = Color3.new(1, 1, 1)
itemList.TextXAlignment = Enum.TextXAlignment.Left
itemList.TextYAlignment = Enum.TextYAlignment.Top
itemList.TextWrapped = true
itemList.TextScaled = false
itemList.Font = Enum.Font.Code
itemList.Text = "Items:"
itemList.Parent = listFrame

-- Real-time update loop
RunService.RenderStepped:Connect(function()
	if isKilled or not espEnabled then return end

	local currentRoom = Workspace:FindFirstChild("CurrentRoom")
	local activeRoom = currentRoom and currentRoom:FindFirstChildWhichIsA("Model")
	local seen = {}

	local monsters, items = {}, {}

	for folderName, color in pairs(folderColors) do
		local folder = (folderName == "InGamePlayers" and playersESPEnabled) and Workspace:FindFirstChild("InGamePlayers") or activeRoom and activeRoom:FindFirstChild(folderName)
		if folder then
			for _, obj in ipairs(folder:GetChildren()) do
				if obj:IsA("Model") or obj:IsA("BasePart") then
					setupESP(obj, color)
					seen[obj] = true
					if folderName == "Monsters" then table.insert(monsters, obj.Name) end
					if folderName == "Items" then table.insert(items, obj.Name) end
				end
			end
		end
	end

	-- Cleanup old ESPs
	for obj in pairs(adornments) do
		if not seen[obj] or not obj:IsDescendantOf(Workspace) then
			if adornments[obj] then adornments[obj]:Destroy() end
			if nameTags[obj] then nameTags[obj]:Destroy() end
			adornments[obj] = nil
			nameTags[obj] = nil
			primaryParts[obj] = nil
		end
	end

	-- Update text lists
	monsterList.Text = "Monsters:\n" .. table.concat(monsters, "\n")
	itemList.Text = "Items:\n" .. table.concat(items, "\n")
end)
