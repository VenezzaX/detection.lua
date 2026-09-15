local request = (http and http.request) or http_request or (syn and (syn.request or syn.request))
if not request then
    warn("Your executor does not support HTTP requests.")
    return
end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local MarketplaceService = game:GetService("MarketplaceService")
local LocalPlayer = Players.LocalPlayer

local SUPABASE_URL = "https://nlavwcbdqcmoqmojraeu.supabase.co"
local SUPABASE_KEY = "sb_publishable__HC4Z5_wV2Daf8o-mgt89Q_z_JH2cif"

local KEY_FILENAME = "admin_key.txt"
local function loadLocalAdminKey()
    if isfile and readfile and isfile(KEY_FILENAME) then
        local raw = readfile(KEY_FILENAME)
        if raw then return string.match(raw, "^%s*(.-)%s*$") or "" end
    end
    return ""
end
local ADMIN_KEY = loadLocalAdminKey()

local JobId = game.JobId
local PlaceId = game.PlaceId
local Username = LocalPlayer.Name
local UserId = LocalPlayer.UserId
local IsAdmin = false 
local IsSubAdmin = false
local SelectedTarget = "none" 

local handledCommands = {} 
local lastChatTime = 0
local lastTeleportTime = 0 
local running = true
local currentTab = "users" 

_G.CurrentTpTarget = "none"
_G.CurrentActiveEffect = "none"

local gameName = "Roblox Game"
pcall(function()
    local info = MarketplaceService:GetProductInfo(PlaceId)
    gameName = info.Name
end)

local function getExecutor()
    if identifyexecutor then local name = identifyexecutor() return name or "Potassium" end
    return "Potassium"
end
local myExecutor = getExecutor()

local function parseIsoToUnix(isoStr)
    if not isoStr or type(isoStr) ~= "string" then return 0 end
    local year, month, day, hour, min, sec = isoStr:match("(%d+)-(%d+)-(%d+)[T ](%d+):(%d+):(%d+)")
    if year then
        return os.time({
            year = tonumber(year),
            month = tonumber(month),
            day = tonumber(day),
            hour = tonumber(hour),
            min = tonumber(min),
            sec = tonumber(sec)
        })
    end
    return 0
end

local function isUserOnline(isoStr)
    local userTime = parseIsoToUnix(isoStr)
    if userTime == 0 then return false end
    local nowUtc = os.time(os.date("!*t"))
    return math.abs(nowUtc - userTime) <= 35
end

local function sanitizeText(text)
    local clean = string.gsub(tostring(text or ""), "<[^>]*>", "")
    if #clean > 1000 then clean = string.sub(clean, 1, 1000) end
    return clean
end

local function runLocalExplosionEffect(targetName)
    local targetPlayer = Players:FindFirstChild(targetName)
    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local char = targetPlayer.Character
        local exp = Instance.new("Explosion")
        exp.Position = char.HumanoidRootPart.Position
        exp.BlastRadius = 0; exp.BlastPressure = 0; exp.Parent = workspace
        if char:FindFirstChild("Humanoid") then char.Humanoid.Health = 0 end
        char:BreakJoints()
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then
                part.Velocity = Vector3.new(math.random(-100, 100), math.random(80, 150), math.random(-100, 100))
            end
        end
    end
end

-- UI SETUP
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DiscordNetworkHub"
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)

local WindowFrame = Instance.new("Frame")
WindowFrame.Size = UDim2.new(0, 680, 0, 440)
WindowFrame.Position = UDim2.new(0.5, -340, 0.5, -220)
WindowFrame.BackgroundColor3 = Color3.fromRGB(49, 51, 56); WindowFrame.BorderSizePixel = 0
WindowFrame.Active = true; WindowFrame.Parent = ScreenGui
Instance.new("UICorner", WindowFrame).CornerRadius = UDim.new(0, 8)

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 32); TitleBar.BackgroundColor3 = Color3.fromRGB(30, 31, 34); TitleBar.Parent = WindowFrame
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 8)

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -100, 1, 0); TitleText.Position = UDim2.new(0, 12, 0, 0); TitleText.BackgroundTransparency = 1
TitleText.Text = "Discord Sync Hub — Cross-Game Network"; TitleText.TextColor3 = Color3.fromRGB(242, 243, 245)
TitleText.Font = Enum.Font.GothamBold; TitleText.TextSize = 12; TitleText.TextXAlignment = Enum.TextXAlignment.Left; TitleText.Parent = TitleBar

local Controls = Instance.new("Frame")
Controls.Size = UDim2.new(0, 70, 1, 0); Controls.Position = UDim2.new(1, -75, 0, 0); Controls.BackgroundTransparency = 1; Controls.Parent = TitleBar

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 30, 0, 30); MinBtn.BackgroundTransparency = 1; MinBtn.Text = "—"; MinBtn.TextColor3 = Color3.fromRGB(181, 186, 193); MinBtn.Font = Enum.Font.GothamBold; MinBtn.TextSize = 14; MinBtn.Parent = Controls

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30); CloseBtn.Position = UDim2.new(0, 35, 0, 0); CloseBtn.BackgroundTransparency = 1; CloseBtn.Text = "X"; CloseBtn.TextColor3 = Color3.fromRGB(181, 186, 193); CloseBtn.Font = Enum.Font.GothamBold; CloseBtn.TextSize = 14; CloseBtn.Parent = Controls

local BodyFrame = Instance.new("Frame")
BodyFrame.Size = UDim2.new(1, 0, 1, -32); BodyFrame.Position = UDim2.new(0, 0, 0, 32); BodyFrame.BackgroundTransparency = 1; BodyFrame.Parent = WindowFrame

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 190, 1, 0); Sidebar.BackgroundColor3 = Color3.fromRGB(43, 45, 49); Sidebar.Parent = BodyFrame

local ChannelUsers = Instance.new("TextButton")
ChannelUsers.Size = UDim2.new(1, -16, 0, 32); ChannelUsers.Position = UDim2.new(0, 8, 0, 12); ChannelUsers.BackgroundColor3 = Color3.fromRGB(53, 55, 60); ChannelUsers.Text = "  #  users-network"; ChannelUsers.TextColor3 = Color3.fromRGB(255, 255, 255); ChannelUsers.Font = Enum.Font.GothamSemibold; ChannelUsers.TextSize = 13; ChannelUsers.TextXAlignment = Enum.TextXAlignment.Left; ChannelUsers.Parent = Sidebar
Instance.new("UICorner", ChannelUsers).CornerRadius = UDim.new(0, 4)

local ChannelServerChat = Instance.new("TextButton")
ChannelServerChat.Size = UDim2.new(1, -16, 0, 32); ChannelServerChat.Position = UDim2.new(0, 8, 0, 48); ChannelServerChat.BackgroundTransparency = 1; ChannelServerChat.Text = "  #  server-chat"; ChannelServerChat.TextColor3 = Color3.fromRGB(148, 155, 164); ChannelServerChat.Font = Enum.Font.GothamSemibold; ChannelServerChat.TextSize = 13; ChannelServerChat.TextXAlignment = Enum.TextXAlignment.Left; ChannelServerChat.Parent = Sidebar
Instance.new("UICorner", ChannelServerChat).CornerRadius = UDim.new(0, 4)

local ChannelGlobalChat = Instance.new("TextButton")
ChannelGlobalChat.Size = UDim2.new(1, -16, 0, 32); ChannelGlobalChat.Position = UDim2.new(0, 8, 0, 84); ChannelGlobalChat.BackgroundTransparency = 1; ChannelGlobalChat.Text = "  💬  global-cross-chat"; ChannelGlobalChat.TextColor3 = Color3.fromRGB(148, 155, 164); ChannelGlobalChat.Font = Enum.Font.GothamSemibold; ChannelGlobalChat.TextSize = 12; ChannelGlobalChat.TextXAlignment = Enum.TextXAlignment.Left; ChannelGlobalChat.Parent = Sidebar
Instance.new("UICorner", ChannelGlobalChat).CornerRadius = UDim.new(0, 4)

local ChannelExecPanel = Instance.new("TextButton")
ChannelExecPanel.Size = UDim2.new(1, -16, 0, 32); ChannelExecPanel.Position = UDim2.new(0, 8, 0, 120); ChannelExecPanel.BackgroundTransparency = 1; ChannelExecPanel.Text = "  🛠️  executor-panel"; ChannelExecPanel.TextColor3 = Color3.fromRGB(148, 155, 164); ChannelExecPanel.Font = Enum.Font.GothamSemibold; ChannelExecPanel.TextSize = 12; ChannelExecPanel.TextXAlignment = Enum.TextXAlignment.Left; ChannelExecPanel.Visible = false; ChannelExecPanel.Parent = Sidebar
Instance.new("UICorner", ChannelExecPanel).CornerRadius = UDim.new(0, 4)

local ViewContainer = Instance.new("Frame")
ViewContainer.Size = UDim2.new(1, -190, 1, 0); ViewContainer.Position = UDim2.new(0, 190, 0, 0); ViewContainer.BackgroundTransparency = 1; ViewContainer.Parent = BodyFrame

local UsersView = Instance.new("ScrollingFrame")
UsersView.Size = UDim2.new(1, -20, 1, -20); UsersView.Position = UDim2.new(0, 10, 0, 10); UsersView.BackgroundTransparency = 1; UsersView.BorderSizePixel = 0; UsersView.ScrollBarThickness = 4; UsersView.Parent = ViewContainer
local UsersLayout = Instance.new("UIListLayout", UsersView); UsersLayout.SortOrder = Enum.SortOrder.LayoutOrder; UsersLayout.Padding = UDim.new(0, 4)

UsersLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    UsersView.CanvasSize = UDim2.new(0, 0, 0, UsersLayout.AbsoluteContentSize.Y + 12)
end)

local ChatView = Instance.new("Frame")
ChatView.Size = UDim2.new(1, -20, 1, -20); ChatView.Position = UDim2.new(0, 10, 0, 10); ChatView.BackgroundTransparency = 1; ChatView.Visible = false; ChatView.Parent = ViewContainer

local ChatScrolling = Instance.new("ScrollingFrame")
ChatScrolling.Size = UDim2.new(1, 0, 1, -45); ChatScrolling.BackgroundTransparency = 1; ChatScrolling.BorderSizePixel = 0; ChatScrolling.ScrollBarThickness = 4; ChatScrolling.Parent = ChatView
local ChatLayout = Instance.new("UIListLayout", ChatScrolling); ChatLayout.SortOrder = Enum.SortOrder.LayoutOrder; ChatLayout.Padding = UDim.new(0, 6)

ChatLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ChatScrolling.CanvasSize = UDim2.new(0, 0, 0, ChatLayout.AbsoluteContentSize.Y)
    ChatScrolling.CanvasPosition = Vector2.new(0, math.max(0, ChatScrolling.CanvasSize.Y.Offset - ChatScrolling.AbsoluteSize.Y))
end)

local TextBox = Instance.new("TextBox")
TextBox.Size = UDim2.new(1, 0, 0, 38); TextBox.Position = UDim2.new(0, 0, 1, -38); TextBox.BackgroundColor3 = Color3.fromRGB(56, 58, 64); TextBox.TextColor3 = Color3.fromRGB(219, 222, 225); TextBox.Font = Enum.Font.Gotham; TextBox.TextSize = 14; TextBox.TextXAlignment = Enum.TextXAlignment.Left; TextBox.ClearTextOnFocus = true; TextBox.Parent = ChatView
Instance.new("UIPadding", TextBox).PaddingLeft = UDim.new(0, 12); Instance.new("UICorner", TextBox).CornerRadius = UDim.new(0, 6)

local ExecPanelFrame = Instance.new("Frame")
ExecPanelFrame.Size = UDim2.new(1, -20, 1, -20); ExecPanelFrame.Position = UDim2.new(0, 10, 0, 10); ExecPanelFrame.BackgroundTransparency = 1; ExecPanelFrame.Visible = false; ExecPanelFrame.Parent = ViewContainer

local TargetScroller = Instance.new("ScrollingFrame")
TargetScroller.Size = UDim2.new(0, 200, 1, 0); TargetScroller.BackgroundColor3 = Color3.fromRGB(30, 31, 34); TargetScroller.BorderSizePixel = 0; TargetScroller.ScrollBarThickness = 4; TargetScroller.Parent = ExecPanelFrame
local TargetLayout = Instance.new("UIListLayout", TargetScroller); TargetLayout.Padding = UDim.new(0, 4)
Instance.new("UICorner", TargetScroller).CornerRadius = UDim.new(0, 6)

TargetLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    TargetScroller.CanvasSize = UDim2.new(0, 0, 0, TargetLayout.AbsoluteContentSize.Y + 10)
end)

local ControlPanel = Instance.new("Frame")
ControlPanel.Size = UDim2.new(1, -210, 1, 0); ControlPanel.Position = UDim2.new(0, 210, 0, 0); ControlPanel.BackgroundColor3 = Color3.fromRGB(43, 45, 49); ControlPanel.Parent = ExecPanelFrame
Instance.new("UICorner", ControlPanel).CornerRadius = UDim.new(0, 6)

local TopActionFrame = Instance.new("Frame")
TopActionFrame.Size = UDim2.new(1, 0, 0, 140); TopActionFrame.BackgroundTransparency = 1; TopActionFrame.Parent = ControlPanel

local ActiveTargetTitle = Instance.new("TextLabel")
ActiveTargetTitle.Size = UDim2.new(1, 0, 0, 25); ActiveTargetTitle.Position = UDim2.new(0, 10, 0, 5); ActiveTargetTitle.BackgroundTransparency = 1; ActiveTargetTitle.Text = "Selected Target: none"; ActiveTargetTitle.TextColor3 = Color3.fromRGB(255, 255, 255); ActiveTargetTitle.Font = Enum.Font.GothamBold; ActiveTargetTitle.TextSize = 13; ActiveTargetTitle.TextXAlignment = Enum.TextXAlignment.Left; ActiveTargetTitle.Parent = TopActionFrame

local BringBtn = Instance.new("TextButton")
BringBtn.Size = UDim2.new(0, 115, 0, 28); BringBtn.Position = UDim2.new(0, 10, 0, 35); BringBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242); BringBtn.Text = "Bring User (Server)"; BringBtn.TextColor3 = Color3.fromRGB(255, 255, 255); BringBtn.Font = Enum.Font.GothamBold; BringBtn.TextSize = 10; BringBtn.Parent = TopActionFrame
Instance.new("UICorner", BringBtn).CornerRadius = UDim.new(0, 4)

local TeleportToMeBtn = Instance.new("TextButton")
TeleportToMeBtn.Size = UDim2.new(1, -145, 0, 28); TeleportToMeBtn.Position = UDim2.new(0, 135, 0, 35); TeleportToMeBtn.BackgroundColor3 = Color3.fromRGB(35, 165, 90); TeleportToMeBtn.Text = "Teleport User to Me"; TeleportToMeBtn.TextColor3 = Color3.fromRGB(255, 255, 255); TeleportToMeBtn.Font = Enum.Font.GothamBold; TeleportToMeBtn.TextSize = 10; TeleportToMeBtn.Parent = TopActionFrame
Instance.new("UICorner", TeleportToMeBtn).CornerRadius = UDim.new(0, 4)

local RemoteKillBtn = Instance.new("TextButton")
RemoteKillBtn.Size = UDim2.new(0, 115, 0, 28); RemoteKillBtn.Position = UDim2.new(0, 10, 0, 70); RemoteKillBtn.BackgroundColor3 = Color3.fromRGB(242, 63, 67); RemoteKillBtn.Text = "Remote Kill"; RemoteKillBtn.TextColor3 = Color3.fromRGB(255, 255, 255); RemoteKillBtn.Font = Enum.Font.GothamBold; RemoteKillBtn.TextSize = 11; RemoteKillBtn.Parent = TopActionFrame
Instance.new("UICorner", RemoteKillBtn).CornerRadius = UDim.new(0, 4)

local RemoteExplodeBtn = Instance.new("TextButton")
RemoteExplodeBtn.Size = UDim2.new(1, -145, 0, 28); RemoteExplodeBtn.Position = UDim2.new(0, 135, 0, 70); RemoteExplodeBtn.BackgroundColor3 = Color3.fromRGB(230, 126, 34); RemoteExplodeBtn.Text = "Remote Explode"; RemoteExplodeBtn.TextColor3 = Color3.fromRGB(255, 255, 255); RemoteExplodeBtn.Font = Enum.Font.GothamBold; RemoteExplodeBtn.TextSize = 11; RemoteExplodeBtn.Parent = TopActionFrame
Instance.new("UICorner", RemoteExplodeBtn).CornerRadius = UDim.new(0, 4)

local function selectTab(tab)
    currentTab = tab
    ChannelUsers.BackgroundTransparency = 1; ChannelUsers.TextColor3 = Color3.fromRGB(148, 155, 164)
    ChannelServerChat.BackgroundTransparency = 1; ChannelServerChat.TextColor3 = Color3.fromRGB(148, 155, 164)
    ChannelGlobalChat.BackgroundTransparency = 1; ChannelGlobalChat.TextColor3 = Color3.fromRGB(148, 155, 164)
    ChannelExecPanel.BackgroundTransparency = 1; ChannelExecPanel.TextColor3 = Color3.fromRGB(148, 155, 164)
    UsersView.Visible = false; ChatView.Visible = false; ExecPanelFrame.Visible = false

    if tab == "users" then
        ChannelUsers.BackgroundColor3 = Color3.fromRGB(53, 55, 60); ChannelUsers.TextColor3 = Color3.fromRGB(255, 255, 255); UsersView.Visible = true
    elseif tab == "server" then
        ChannelServerChat.BackgroundColor3 = Color3.fromRGB(53, 55, 60); ChannelServerChat.TextColor3 = Color3.fromRGB(255, 255, 255); TextBox.PlaceholderText = "Message #server-chat"; ChatView.Visible = true
    elseif tab == "global" then
        ChannelGlobalChat.BackgroundColor3 = Color3.fromRGB(53, 55, 60); ChannelGlobalChat.TextColor3 = Color3.fromRGB(255, 255, 255); TextBox.PlaceholderText = "Message #global-cross-chat"; ChatView.Visible = true
    elseif tab == "exec" then
        ChannelExecPanel.BackgroundColor3 = Color3.fromRGB(53, 55, 60); ChannelExecPanel.TextColor3 = Color3.fromRGB(255, 255, 255); ExecPanelFrame.Visible = true
    end
end

ChannelUsers.MouseButton1Click:Connect(function() selectTab("users") end)
ChannelServerChat.MouseButton1Click:Connect(function() selectTab("server") end)
ChannelGlobalChat.MouseButton1Click:Connect(function() selectTab("global") end)
ChannelExecPanel.MouseButton1Click:Connect(function() selectTab("exec") end)

local function createCategoryHeader(titleText, color)
    local Header = Instance.new("Frame")
    Header.Size = UDim2.new(1, -6, 0, 20)
    Header.BackgroundTransparency = 1
    Header.Parent = UsersView

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 1, 0)
    Label.BackgroundTransparency = 1
    Label.Text = string.upper(titleText)
    Label.TextColor3 = color or Color3.fromRGB(148, 155, 164)
    Label.Font = Enum.Font.GothamBold
    Label.TextSize = 10
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Header
end

local function createUserRow(user, online)
    local uName = tostring(user.username or "Unknown")
    local PlayerRow = Instance.new("Frame")
    PlayerRow.Size = UDim2.new(1, -6, 0, 45)
    PlayerRow.BackgroundColor3 = online and Color3.fromRGB(43, 45, 49) or Color3.fromRGB(33, 34, 38)
    PlayerRow.Parent = UsersView
    Instance.new("UICorner", PlayerRow).CornerRadius = UDim.new(0, 4)

    local NameLabel = Instance.new("TextLabel")
    NameLabel.Size = UDim2.new(0.5, -10, 0, 22)
    NameLabel.Position = UDim2.new(0, 10, 0, 2)
    NameLabel.BackgroundTransparency = 1
    NameLabel.Font = Enum.Font.GothamSemibold
    NameLabel.TextSize = 13
    NameLabel.TextXAlignment = Enum.TextXAlignment.Left

    local statusDot = online and "🟢 " or "⚪ "
    if user.is_admin == true then 
        NameLabel.TextColor3 = Color3.fromRGB(255, 235, 59)
        NameLabel.Text = statusDot .. "👑 " .. uName
    elseif user.is_sub_admin == true then 
        NameLabel.TextColor3 = Color3.fromRGB(168, 85, 247)
        NameLabel.Text = statusDot .. "🛡️ " .. uName
    elseif uName == Username then 
        NameLabel.TextColor3 = Color3.fromRGB(242, 243, 245)
        NameLabel.Text = statusDot .. uName .. " (You)"
    else 
        NameLabel.TextColor3 = online and Color3.fromRGB(219, 222, 225) or Color3.fromRGB(120, 125, 134)
        NameLabel.Text = statusDot .. uName
    end
    NameLabel.Parent = PlayerRow

    local Subtitle = Instance.new("TextLabel")
    Subtitle.Size = UDim2.new(0.55, 0, 0, 18)
    Subtitle.Position = UDim2.new(0, 10, 0, 22)
    Subtitle.BackgroundTransparency = 1
    Subtitle.Font = Enum.Font.Gotham
    Subtitle.TextSize = 10
    Subtitle.TextXAlignment = Enum.TextXAlignment.Left
    
    if online then
        Subtitle.Text = "🎮 " .. tostring(user.current_game or "Roblox") .. " | ⚙️ " .. tostring(user.executor or "Exec")
        Subtitle.TextColor3 = Color3.fromRGB(110, 115, 122)
    else
        Subtitle.Text = "Last seen: " .. tostring(user.updated_at or "Unknown")
        Subtitle.TextColor3 = Color3.fromRGB(80, 84, 92)
    end
    Subtitle.Parent = PlayerRow

    if online and uName ~= Username then
        local JoinBtn = Instance.new("TextButton")
        JoinBtn.Size = UDim2.new(0, 65, 0, 26)
        JoinBtn.Position = UDim2.new(1, -75, 0, 9)
        JoinBtn.BackgroundColor3 = Color3.fromRGB(35, 165, 90)
        JoinBtn.Text = "Join Game"
        JoinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        JoinBtn.Font = Enum.Font.GothamBold
        JoinBtn.TextSize = 10
        JoinBtn.Parent = PlayerRow
        Instance.new("UICorner", JoinBtn).CornerRadius = UDim.new(0, 4)
        JoinBtn.MouseButton1Click:Connect(function() 
            if user.place_id and user.job_id then
                TeleportService:TeleportToPlaceInstance(user.place_id, user.job_id, LocalPlayer) 
            end
        end)
    end
end

local function refreshUIList(data)
    for _, child in ipairs(UsersView:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    for _, child in ipairs(TargetScroller:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
    
    local onlineList = {}
    local offlineList = {}
    local seen = {}

    for _, user in ipairs(data) do
        local uName = tostring(user.username or "Unknown")
        if not seen[uName] then
            seen[uName] = true
            if isUserOnline(user.updated_at) then
                table.insert(onlineList, user)
            else
                table.insert(offlineList, user)
            end
        end
    end

    -- 1. Render Online Users
    createCategoryHeader("Online — " .. #onlineList, Color3.fromRGB(35, 165, 90))
    for _, user in ipairs(onlineList) do
        createUserRow(user, true)

        -- Add online players to executor target panel
        local uName = tostring(user.username or "Unknown")
        if uName ~= Username then
            local TargetSelectorBtn = Instance.new("TextButton")
            TargetSelectorBtn.Size = UDim2.new(1, -10, 0, 32)
            TargetSelectorBtn.BackgroundColor3 = (SelectedTarget == uName) and Color3.fromRGB(53, 55, 60) or Color3.fromRGB(43, 45, 49)
            TargetSelectorBtn.Text = "  🟢 " .. uName
            TargetSelectorBtn.TextColor3 = Color3.fromRGB(219, 222, 225)
            TargetSelectorBtn.Font = Enum.Font.GothamSemibold
            TargetSelectorBtn.TextSize = 12
            TargetSelectorBtn.TextXAlignment = Enum.TextXAlignment.Left
            TargetSelectorBtn.Parent = TargetScroller
            Instance.new("UICorner", TargetSelectorBtn).CornerRadius = UDim.new(0, 4)

            TargetSelectorBtn.MouseButton1Click:Connect(function()
                SelectedTarget = uName
                ActiveTargetTitle.Text = "Selected Target: " .. uName
                for _, btn in ipairs(TargetScroller:GetChildren()) do
                    if btn:IsA("TextButton") then btn.BackgroundColor3 = Color3.fromRGB(43, 45, 49) end
                end
                TargetSelectorBtn.BackgroundColor3 = Color3.fromRGB(53, 55, 60)
            end)
        end
    end

    -- 2. Render Registered / Offline Users exclusively for Admin & SubAdmin
    if (IsAdmin or IsSubAdmin) and #offlineList > 0 then
        createCategoryHeader("Offline Registry (Admin History) — " .. #offlineList, Color3.fromRGB(110, 115, 122))
        for _, user in ipairs(offlineList) do
            createUserRow(user, false)
        end
    end
end

local function refreshChatUI(messages, adminPool)
    for _, child in ipairs(ChatScrolling:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    for _, msg in ipairs(messages) do
        local MsgFrame = Instance.new("Frame")
        MsgFrame.Size = UDim2.new(1, 0, 0, 24); MsgFrame.BackgroundTransparency = 1; MsgFrame.Parent = ChatScrolling

        local MsgLabel = Instance.new("TextLabel")
        MsgLabel.Size = UDim2.new(1, 0, 1, 0); MsgLabel.BackgroundTransparency = 1; MsgLabel.TextXAlignment = Enum.TextXAlignment.Left; MsgLabel.Font = Enum.Font.Gotham; MsgLabel.TextSize = 13; MsgLabel.RichText = true
        
        local nameColor = adminPool[msg.username] and "rgb(255, 235, 59)" or "rgb(242, 243, 245)"
        local displayMsg = sanitizeText(msg.message)
        
        MsgLabel.Text = string.format("<font color='%s'><b>%s</b></font>: %s", nameColor, tostring(msg.username or "Unknown"), displayMsg)
        MsgLabel.TextColor3 = Color3.fromRGB(219, 222, 225); MsgLabel.Parent = MsgFrame
    end
end

-- DATABASE OPERATIONS
local function updatePresence()
    if not running then return end
    request({
        Url = SUPABASE_URL .. "/rest/v1/executor_sync?on_conflict=username",
        Method = "POST",
        Headers = { 
            ["apikey"] = SUPABASE_KEY, 
            ["Authorization"] = "Bearer " .. SUPABASE_KEY, 
            ["Content-Type"] = "application/json", 
            ["Prefer"] = "resolution=merge-duplicates" 
        },
        Body = HttpService:JSONEncode({ 
            user_id = UserId,
            username = Username, 
            job_id = JobId, 
            place_id = PlaceId, 
            current_game = gameName, 
            executor = myExecutor, 
            updated_at = os.date("!%Y-%m-%dT%H:%M:%SZ"), 
            teleport_target = _G.CurrentTpTarget, 
            active_effect = _G.CurrentActiveEffect 
        })
    })
end

local function sendChatMessage(text)
    local cleanMsg = sanitizeText(text)
    if cleanMsg == "" then return end
    if tick() - lastChatTime < 1.5 then return end
    lastChatTime = tick()

    local targetPayload = { username = Username, message = cleanMsg }
    if currentTab == "server" then targetPayload.job_id = JobId end

    request({
        Url = SUPABASE_URL .. "/rest/v1/executor_chat",
        Method = "POST",
        Headers = { ["apikey"] = SUPABASE_KEY, ["Authorization"] = "Bearer " .. SUPABASE_KEY, ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode(targetPayload)
    })
end

local function fetchData()
    if not running then return end
    
    local resUser = request({
        Url = SUPABASE_URL .. "/rest/v1/executor_sync?select=user_id,username,executor,teleport_target,active_effect,is_admin,is_sub_admin,current_game,job_id,place_id,updated_at&order=updated_at.desc&limit=100",
        Method = "GET",
        Headers = { ["apikey"] = SUPABASE_KEY, ["Authorization"] = "Bearer " .. SUPABASE_KEY }
    })
    
    local adminPool = {}
    if resUser and resUser.StatusCode == 200 then
        local success, users = pcall(function() return HttpService:JSONDecode(resUser.Body) end)
        if success and type(users) == "table" then
            for _, u in ipairs(users) do
                if u.is_admin == true or u.is_sub_admin == true then 
                    adminPool[u.username] = true 
                end
                if u.user_id == UserId or u.username == Username then
                    IsAdmin = (u.is_admin == true)
                    IsSubAdmin = (u.is_sub_admin == true)
                    ChannelExecPanel.Visible = (IsAdmin or IsSubAdmin) and (ADMIN_KEY ~= "")
                end
            end
            
            refreshUIList(users)
            
            -- SAFE ROLE-BASED INTERCEPTOR
            for _, user in ipairs(users) do
                if user.teleport_target ~= "none" and (user.teleport_target == Username or user.teleport_target == "all") then
                    if tick() - lastTeleportTime > 5 then 
                        if user.is_admin == true or user.is_sub_admin == true then
                            lastTeleportTime = tick() 
                            TeleportService:TeleportToPlaceInstance(user.place_id, user.job_id, LocalPlayer)
                        end
                    end
                end

                if user.active_effect and user.active_effect ~= "none" then
                    local cmdData = string.split(user.active_effect, ":")
                    local action = cmdData[1]
                    local target = cmdData[2]
                    local uniqueHash = cmdData[3] 

                    if uniqueHash and not handledCommands[uniqueHash] then
                        if user.is_admin == true or user.is_sub_admin == true then
                            handledCommands[uniqueHash] = true 
                            if action == "kill" or action == "explode" then
                                if target == Username or target == "all" then 
                                    runLocalExplosionEffect(Username)
                                end
                            elseif action == "teleport_to" and target == Username then
                                for _, p in ipairs(Players:GetPlayers()) do
                                    if p.Name == user.username and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                                        local myChar = LocalPlayer.Character
                                        if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                                            myChar.HumanoidRootPart.CFrame = p.Character.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0)
                                        end
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local queryFilter = (currentTab == "global") and "job_id=is.null" or "job_id=eq." .. JobId
    local resChat = request({
        Url = SUPABASE_URL .. "/rest/v1/executor_chat?" .. queryFilter .. "&order=created_at.desc&limit=30",
        Method = "GET",
        Headers = { ["apikey"] = SUPABASE_KEY, ["Authorization"] = "Bearer " .. SUPABASE_KEY }
    })
    if resChat and resChat.StatusCode == 200 then
        local success, msgs = pcall(function() return HttpService:JSONDecode(resChat.Body) end)
        if success and type(msgs) == "table" then
            local orderedMsgs = {}
            for i = #msgs, 1, -1 do table.insert(orderedMsgs, msgs[i]) end
            refreshChatUI(orderedMsgs, adminPool)
        end
    end
end

-- --- INPUT HANDLERS ---
TextBox.FocusLost:Connect(function(enterPressed) 
    if enterPressed then 
        local text = TextBox.Text
        TextBox.Text = "" 
        task.spawn(function() 
            sendChatMessage(text) 
            fetchData() 
        end) 
    end 
end)

BringBtn.MouseButton1Click:Connect(function()
    if (IsAdmin or IsSubAdmin) and ADMIN_KEY ~= "" and SelectedTarget ~= "none" then
        _G.CurrentTpTarget = SelectedTarget
        updatePresence()
        task.delay(3, function() 
            if _G.CurrentTpTarget == SelectedTarget then 
                _G.CurrentTpTarget = "none" 
                updatePresence() 
            end 
        end)
    end
end)

TeleportToMeBtn.MouseButton1Click:Connect(function()
    if (IsAdmin or IsSubAdmin) and ADMIN_KEY ~= "" and SelectedTarget ~= "none" then
        local hash = tostring(os.time() .. math.random(1,1000))
        _G.CurrentActiveEffect = "teleport_to:" .. SelectedTarget .. ":" .. hash
        updatePresence()
        task.delay(4, function()
            if _G.CurrentActiveEffect:sub(1,11) == "teleport_to" then
                _G.CurrentActiveEffect = "none"
                updatePresence()
            end
        end)
    end
end)

RemoteKillBtn.MouseButton1Click:Connect(function()
    if (IsAdmin or IsSubAdmin) and ADMIN_KEY ~= "" and SelectedTarget ~= "none" then
        local hash = tostring(os.time() .. math.random(1,1000))
        _G.CurrentActiveEffect = "kill:" .. SelectedTarget .. ":" .. hash
        updatePresence()
        task.delay(3, function() 
            if _G.CurrentActiveEffect:sub(1,4) == "kill" then 
                _G.CurrentActiveEffect = "none" 
                updatePresence() 
            end 
        end)
    end
end)

RemoteExplodeBtn.MouseButton1Click:Connect(function()
    if (IsAdmin or IsSubAdmin) and ADMIN_KEY ~= "" and SelectedTarget ~= "none" then
        local hash = tostring(os.time() .. math.random(1,1000))
        _G.CurrentActiveEffect = "explode:" .. SelectedTarget .. ":" .. hash
        updatePresence()
        task.delay(3, function() 
            if _G.CurrentActiveEffect:sub(1,7) == "explode" then 
                _G.CurrentActiveEffect = "none" 
                updatePresence() 
            end 
        end)
    end
end)

local dragging, dragInput, dragStart, startPos
TitleBar.InputBegan:Connect(function(input) 
    if input.UserInputType == Enum.UserInputType.MouseButton1 then 
        dragging = true; dragStart = input.Position; startPos = WindowFrame.Position; 
        input.Changed:Connect(function() 
            if input.UserInputState == Enum.UserInputState.End then dragging = false end 
        end) 
    end 
end)

TitleBar.InputChanged:Connect(function(input) 
    if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end 
end)

UserInputService.InputChanged:Connect(function(input) 
    if input == dragInput and dragging then 
        local delta = input.Position - dragStart 
        WindowFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) 
    end 
end)

local minimized = false
MinBtn.MouseButton1Click:Connect(function() 
    minimized = not minimized
    BodyFrame.Visible = not minimized
    WindowFrame.Size = minimized and UDim2.new(0, 680, 0, 32) or UDim2.new(0, 680, 0, 440) 
    MinBtn.Text = minimized and "🗖" or "—" 
end)

CloseBtn.MouseButton1Click:Connect(function() 
    running = false
    pcall(function() ScreenGui:Destroy() end) 
end)

-- INITIALIZATION
updatePresence()
fetchData()
task.spawn(function() 
    while running do 
        task.wait(4)
        updatePresence()
        fetchData() 
    end 
end)
