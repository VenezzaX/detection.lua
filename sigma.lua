local request = syn and syn.request or http_request or (http and http.request)
if not request then
    warn("Your executor does not support HTTP requests.")
    return
end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- !!! YOUR SUPABASE CREDENTIALS CONFIGURATION !!!
local SUPABASE_URL = "https://nlavwcbdqcmoqmojraeu.supabase.co"
local SUPABASE_KEY = "sb_publishable__HC4Z5_wV2Daf8o-mgt89Q_z_JH2cif"

local JobId = game.JobId
local Username = LocalPlayer.Name
local IsAdmin = false -- Controlled purely by the database response now

local rememberedPlayers = {}

local function getExecutor()
    if identifyexecutor then
        local name, version = identifyexecutor()
        return name or "Unknown Exploit"
    elseif getexecutorname then
        return getexecutorname() or "Unknown Exploit"
    end
    return "Unknown/External"
end
local myExecutor = getExecutor()

-- --- UI SETUP ---
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ExecutorNetworkHub"
ScreenGui.ResetOnSpawn = false
if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end
ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 650, 0, 400)
MainFrame.Position = UDim2.new(0.5, -325, 0.5, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local Header = Instance.new("TextLabel")
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
Header.Text = "📡 Script Users Network & Global Chat"
Header.TextColor3 = Color3.fromRGB(255, 255, 255)
Header.Font = Enum.Font.GothamBold
Header.TextSize = 16
Header.Parent = MainFrame
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 8)

-- Layout views
local UsersFrame = Instance.new("Frame")
UsersFrame.Size = UDim2.new(0, 250, 1, -50)
UsersFrame.Position = UDim2.new(0, 10, 0, 45)
UsersFrame.BackgroundTransparency = 1
UsersFrame.Parent = MainFrame

local ListScrolling = Instance.new("ScrollingFrame")
ListScrolling.Size = UDim2.new(1, 0, 1, -25)
ListScrolling.Position = UDim2.new(0, 0, 0, 25)
ListScrolling.BackgroundTransparency = 1
ListScrolling.ScrollBarThickness = 4
ListScrolling.Parent = UsersFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 6)
UIListLayout.Parent = ListScrolling

local ChatFrame = Instance.new("Frame")
ChatFrame.Size = UDim2.new(1, -280, 1, -50)
ChatFrame.Position = UDim2.new(0, 270, 0, 45)
ChatFrame.BackgroundTransparency = 1
ChatFrame.Parent = MainFrame

local ChatScrolling = Instance.new("ScrollingFrame")
ChatScrolling.Size = UDim2.new(1, 0, 1, -65)
ChatScrolling.Position = UDim2.new(0, 0, 0, 25)
ChatScrolling.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
ChatScrolling.ScrollBarThickness = 4
ChatScrolling.Parent = ChatFrame
Instance.new("UICorner", ChatScrolling).CornerRadius = UDim.new(0, 6)

local UIChatList = Instance.new("UIListLayout")
UIChatList.SortOrder = Enum.SortOrder.LayoutOrder
UIChatList.Padding = UDim.new(0, 4)
UIChatList.Parent = ChatScrolling

local TextBox = Instance.new("TextBox")
TextBox.Size = UDim2.new(1, 0, 0, 35)
TextBox.Position = UDim2.new(0, 0, 1, -35)
TextBox.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
TextBox.PlaceholderText = "Type a message here..."
TextBox.Font = Enum.Font.Gotham
TextBox.TextSize = 14
TextBox.TextXAlignment = Enum.TextXAlignment.Left
TextBox.ClearTextOnFocus = true
TextBox.Parent = ChatFrame
Instance.new("UIPadding", TextBox).PaddingLeft = UDim.new(0, 10)
Instance.new("UICorner", TextBox).CornerRadius = UDim.new(0, 6)

local function systemLog(text, colorStr)
    local MsgFrame = Instance.new("Frame")
    MsgFrame.Size = UDim2.new(1, -10, 0, 24)
    MsgFrame.BackgroundTransparency = 1
    MsgFrame.Parent = ChatScrolling

    local MsgLabel = Instance.new("TextLabel")
    MsgLabel.Size = UDim2.new(1, 0, 1, 0)
    MsgLabel.Position = UDim2.new(0, 6, 0, 0)
    MsgLabel.BackgroundTransparency = 1
    MsgLabel.TextXAlignment = Enum.TextXAlignment.Left
    MsgLabel.Font = Enum.Font.GothamItalic
    MsgLabel.TextSize = 12
    MsgLabel.RichText = true
    MsgLabel.Text = string.format("<font color='%s'>%s</font>", colorStr or "rgb(150, 150, 150)", text)
    MsgLabel.Parent = MsgFrame
end

local function refreshUIList(data)
    for _, child in ipairs(ListScrolling:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local currentPool = {}
    for _, user in ipairs(data) do
        currentPool[user.username] = true
        
        if rememberedPlayers[user.username] == nil then
            rememberedPlayers[user.username] = true
            systemLog("⚡ " .. user.username .. " connected to the network.", "rgb(120, 230, 135)")
        end

        local PlayerRow = Instance.new("Frame")
        PlayerRow.Size = UDim2.new(1, -6, 0, 35)
        PlayerRow.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
        PlayerRow.Parent = ListScrolling
        Instance.new("UICorner", PlayerRow).CornerRadius = UDim.new(0, 6)

        local NameLabel = Instance.new("TextLabel")
        NameLabel.Size = UDim2.new(0.6, -10, 1, 0)
        NameLabel.Position = UDim2.new(0, 8, 0, 0)
        NameLabel.BackgroundTransparency = 1
        NameLabel.Text = user.username
        NameLabel.Font = Enum.Font.GothamSemibold
        NameLabel.TextSize = 13
        NameLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        -- Custom Formatting Rules checking database profile fields
        if user.is_admin then
            NameLabel.TextColor3 = Color3.fromRGB(255, 235, 59) -- Yellow
            NameLabel.Text = "👑 " .. user.username
        elseif user.username == Username then
            NameLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
            NameLabel.Text = user.username .. " (You)"
        else
            NameLabel.TextColor3 = Color3.fromRGB(220, 220, 225)
        end
        NameLabel.Parent = PlayerRow

        local ExecLabel = Instance.new("TextLabel")
        ExecLabel.Size = UDim2.new(0.4, -10, 1, 0)
        ExecLabel.Position = UDim2.new(0.6, 0, 0, 0)
        ExecLabel.BackgroundTransparency = 1
        ExecLabel.Text = user.executor
        ExecLabel.TextColor3 = Color3.fromRGB(120, 230, 135)
        ExecLabel.Font = Enum.Font.Gotham
        ExecLabel.TextSize = 12
        ExecLabel.TextXAlignment = Enum.TextXAlignment.Right
        ExecLabel.Parent = PlayerRow
    end

    for name, _ in pairs(rememberedPlayers) do
        if not currentPool[name] then
            rememberedPlayers[name] = nil
            systemLog("❌ " .. name .. " disconnected from the network.", "rgb(235, 90, 90)")
        end
    end
    ListScrolling.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y)
end

local function refreshChatUI(messages, adminPool)
    for _, child in ipairs(ChatScrolling:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    for _, msg in ipairs(messages) do
        local MsgFrame = Instance.new("Frame")
        MsgFrame.Size = UDim2.new(1, -10, 0, 24)
        MsgFrame.BackgroundTransparency = 1
        MsgFrame.Parent = ChatScrolling

        local MsgLabel = Instance.new("TextLabel")
        MsgLabel.Size = UDim2.new(1, 0, 1, 0)
        MsgLabel.Position = UDim2.new(0, 6, 0, 0)
        MsgLabel.BackgroundTransparency = 1
        MsgLabel.TextXAlignment = Enum.TextXAlignment.Left
        MsgLabel.Font = Enum.Font.Gotham
        MsgLabel.TextSize = 13
        MsgLabel.RichText = true
        
        local isAdminUser = adminPool[msg.username]
        local nameColor = isAdminUser and "rgb(255, 235, 59)" or "rgb(150, 200, 255)"
        local prefix = isAdminUser and "👑 " or ""
        
        MsgLabel.Text = string.format("<font color='%s'><b>%s%s</b></font>: %s", nameColor, prefix, msg.username, msg.message)
        MsgLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
        MsgLabel.Parent = MsgFrame
    end
    ChatScrolling.CanvasSize = UDim2.new(0, 0, 0, UIChatList.AbsoluteContentSize.Y)
    ChatScrolling.CanvasPosition = Vector2.new(0, ChatScrolling.CanvasSize.Y.Offset)
end

-- --- NETWORK HANDLERS ---

local function updatePresence()
    local posStr = "none"
    if IsAdmin and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local pos = LocalPlayer.Character.HumanoidRootPart.Position
        posStr = string.format("%f,%f,%f", pos.X, pos.Y, pos.Z)
    end

    request({
        Url = SUPABASE_URL .. "/rest/v1/executor_sync",
        Method = "POST",
        Headers = {
            ["apikey"] = SUPABASE_KEY,
            ["Authorization"] = "Bearer " .. SUPABASE_KEY,
            ["Content-Type"] = "application/json",
            ["Prefer"] = "resolution=merge-duplicates"
        },
        Body = HttpService:JSONEncode({ 
            username = Username, 
            job_id = JobId, 
            executor = myExecutor, 
            updated_at = "now()",
            teleport_target = (IsAdmin and _G.CurrentTpTarget or nil),
            admin_position = (IsAdmin and posStr or nil)
        })
    })
end

local function sendChatMessage(text)
    if text == "" or #text > 150 then return end
    request({
        Url = SUPABASE_URL .. "/rest/v1/executor_chat",
        Method = "POST",
        Headers = {
            ["apikey"] = SUPABASE_KEY,
            ["Authorization"] = "Bearer " .. SUPABASE_KEY,
            ["Content-Type"] = "application/json"
        },
        Body = HttpService:JSONEncode({ username = Username, job_id = JobId, message = text })
    })
end

local function fetchData()
    local pastThreshold = DateTime.fromUnixTimestamp(DateTime.now().UnixTimestamp - 20):ToIsoDate()
    local resUser = request({
        Url = SUPABASE_URL .. "/rest/v1/executor_sync?job_id=eq." .. JobId .. "&updated_at=gt." .. pastThreshold .. "&select=username,executor,teleport_target,admin_position,is_admin",
        Method = "GET",
        Headers = { ["apikey"] = SUPABASE_KEY, ["Authorization"] = "Bearer " .. SUPABASE_KEY }
    })
    
    local adminPool = {}
    if resUser.StatusCode == 200 then
        local users = HttpService:JSONDecode(resUser.Body)
        
        -- Determine our admin state straight from what the DB records say
        for _, u in ipairs(users) do
            if u.is_admin then adminPool[u.username] = true end
            if u.username == Username then
                if u.is_admin and not IsAdmin then
                    IsAdmin = true
                    Header.Text = "📡 Script Users Network & Global Chat [ADMIN MODE]"
                    TextBox.PlaceholderText = "Type chat or admin commands (!tp username)..."
                end
            end
        end
        
        refreshUIList(users)
        
        -- Execution check for active Teleport targets
        if not IsAdmin then
            for _, user in ipairs(users) do
                if user.is_admin and user.teleport_target ~= "none" and user.admin_position ~= "none" then
                    if user.teleport_target == Username or user.teleport_target == "all" then
                        local coords = string.split(user.admin_position, ",")
                        local targetCFrame = CFrame.new(tonumber(coords[1]), tonumber(coords[2]) + 2, tonumber(coords[3]))
                        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            LocalPlayer.Character.HumanoidRootPart.CFrame = targetCFrame
                        end
                    end
                end
            end
        end
    end

    -- Fetch Chats
    local resChat = request({
        Url = SUPABASE_URL .. "/rest/v1/executor_chat?job_id=eq." .. JobId .. "&order=created_at.desc&limit=30",
        Method = "GET",
        Headers = { ["apikey"] = SUPABASE_KEY, ["Authorization"] = "Bearer " .. SUPABASE_KEY }
    })
    if resChat.StatusCode == 200 then
        local msgs = HttpService:JSONDecode(resChat.Body)
        local orderedMsgs = {}
        for i = #msgs, 1, -1 do table.insert(orderedMsgs, msgs[i]) end
        refreshChatUI(orderedMsgs, adminPool)
    end
end

TextBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        local text = TextBox.Text
        TextBox.Text = ""
        
        if IsAdmin and string.sub(text, 1, 4) == "!tp " then
            local target = string.sub(text, 5)
            _G.CurrentTpTarget = target
            systemLog("System: Issuing teleportation command to target: " .. target, "rgb(255, 235, 59)")
            
            task.delay(4, function()
                if _G.CurrentTpTarget == target then _G.CurrentTpTarget = "none" end
            end)
        else
            task.spawn(function()
                sendChatMessage(text)
                fetchData()
            end)
        end
    end
end)

-- --- Startup Loops ---
_G.CurrentTpTarget = "none"
updatePresence()
fetchData()

task.spawn(function()
    while task.wait(4) do
        updatePresence()
        fetchData()
    end
end)
