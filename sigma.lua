local request = syn and syn.request or http_request or (http and http.request)
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

local rememberedPlayers = {}
local handledCommands = {} 
local lastChatTime = 0
local running = true
local currentTab = "users" -- "users", "server-chat", "global-chat"

_G.CurrentTpTarget = "none"
_G.CurrentActiveEffect = "none"

-- Automatically fetch the real name of the current Roblox game
local gameName = "Roblox Game"
pcall(function()
    local info = MarketplaceService:GetProductInfo(PlaceId)
    gameName = info.Name
end)

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

local function sanitizeText(text)
    local clean = string.gsub(text, "<[^>]*>", "")
    if #clean > 120 then clean = string.sub(clean, 1, 120) end
    return clean
end

-- --- LOCAL SPECIAL EFFECTS ---
local function runLocalExplosionEffect(targetName)
    local targetPlayer = Players:FindFirstChild(targetName)
    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local char = targetPlayer.Character
        local exp = Instance.new("Explosion")
        exp.Position = char.HumanoidRootPart.Position
        exp.BlastRadius = 0 
        exp.BlastPressure = 0 
        exp.Parent = workspace
        
        if char:FindFirstChild("Humanoid") then char.Humanoid.Health = 0 end
        char:BreakJoints()
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then
                part.Velocity = Vector3.new(math.random(-100, 100), math.random(80, 150), math.random(-100, 100))
            end
        end
    end
end

-- --- DISCORD MASTER UI SYSTEM ---
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DiscordNetworkHub"
ScreenGui.ResetOnSpawn = false
if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end
ScreenGui.Parent = CoreGui

local WindowFrame = Instance.new("Frame")
WindowFrame.Size = UDim2.new(0, 680, 0, 440) 
WindowFrame.Position = UDim2.new(0.5, -340, 0.5, -220)
WindowFrame.BackgroundColor3 = Color3.fromRGB(49, 51, 56) 
WindowFrame.BorderSizePixel = 0
WindowFrame.Active = true
WindowFrame.Parent = ScreenGui
Instance.new("UICorner", WindowFrame).CornerRadius = UDim.new(0, 8)

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 32)
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 31, 34) 
TitleBar.Parent = WindowFrame
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 8)

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -100, 1, 0)
TitleText.Position = UDim2.new(0, 12, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Text = "Discord Sync Hub — Cross-Game Network"
TitleText.TextColor3 = Color3.fromRGB(242, 243, 245)
TitleText.Font = Enum.Font.GothamBold
TitleText.TextSize = 12
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = TitleBar

local Controls = Instance.new("Frame")
Controls.Size = UDim2.new(0, 70, 1, 0)
Controls.Position = UDim2.new(1, -75, 0, 0)
Controls.BackgroundTransparency = 1
Controls.Parent = TitleBar

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.BackgroundTransparency = 1
MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.fromRGB(181, 186, 193)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 14
MinBtn.Parent = Controls

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(0, 35, 0, 0)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "X" -- Fix: Changed to clean standard "X" capital letter string
CloseBtn.TextColor3 = Color3.fromRGB(181, 186, 193)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Parent = Controls

local BodyFrame = Instance.new("Frame")
BodyFrame.Size = UDim2.new(1, 0, 1, -32)
BodyFrame.Position = UDim2.new(0, 0, 0, 32)
BodyFrame.BackgroundTransparency = 1
BodyFrame.Parent = WindowFrame

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 190, 1, 0)
Sidebar.BackgroundColor3 = Color3.fromRGB(43, 45, 49) 
Sidebar.Parent = BodyFrame

-- Channel Switcher Elements
local ChannelUsers = Instance.new("TextButton")
ChannelUsers.Size = UDim2.new(1, -16, 0, 32)
ChannelUsers.Position = UDim2.new(0, 8, 0, 12)
ChannelUsers.BackgroundColor3 = Color3.fromRGB(53, 55, 60)
ChannelUsers.Text = "  #  users-network"
ChannelUsers.TextColor3 = Color3.fromRGB(255, 255, 255)
ChannelUsers.Font = Enum.Font.GothamSemibold
ChannelUsers.TextSize = 13
ChannelUsers.TextXAlignment = Enum.TextXAlignment.Left
ChannelUsers.Parent = Sidebar
Instance.new("UICorner", ChannelUsers).CornerRadius = UDim.new(0, 4)

local ChannelServerChat = Instance.new("TextButton")
ChannelServerChat.Size = UDim2.new(1, -16, 0, 32)
ChannelServerChat.Position = UDim2.new(0, 8, 0, 48)
ChannelServerChat.BackgroundTransparency = 1
ChannelServerChat.Text = "  #  server-chat"
ChannelServerChat.TextColor3 = Color3.fromRGB(148, 155, 164)
ChannelServerChat.Font = Enum.Font.GothamSemibold
ChannelServerChat.TextSize = 13
ChannelServerChat.TextXAlignment = Enum.TextXAlignment.Left
ChannelServerChat.Parent = Sidebar
Instance.new("UICorner", ChannelServerChat).CornerRadius = UDim.new(0, 4)

local ChannelGlobalChat = Instance.new("TextButton")
ChannelGlobalChat.Size = UDim2.new(1, -16, 0, 32)
ChannelGlobalChat.Position = UDim2.new(0, 8, 0, 84)
ChannelGlobalChat.BackgroundTransparency = 1
ChannelGlobalChat.Text = "  💬  global-cross-chat"
ChannelGlobalChat.TextColor3 = Color3.fromRGB(148, 155, 164)
ChannelGlobalChat.Font = Enum.Font.GothamSemibold
ChannelGlobalChat.TextSize = 12
ChannelGlobalChat.TextXAlignment = Enum.TextXAlignment.Left
ChannelGlobalChat.Parent = Sidebar
Instance.new("UICorner", ChannelGlobalChat).CornerRadius = UDim.new(0, 4)

local ViewContainer = Instance.new("Frame")
ViewContainer.Size = UDim2.new(1, -190, 1, 0)
ViewContainer.Position = UDim2.new(0, 190, 0, 0)
ViewContainer.BackgroundTransparency = 1
ViewContainer.Parent = BodyFrame

-- Container Viewports
local UsersView = Instance.new("ScrollingFrame")
UsersView.Size = UDim2.new(1, -20, 1, -20)
UsersView.Position = UDim2.new(0, 10, 0, 10)
UsersView.BackgroundTransparency = 1
UsersView.BorderSizePixel = 0
UsersView.ScrollBarThickness = 4
UsersView.Parent = ViewContainer
local UsersLayout = Instance.new("UIListLayout", UsersView)
UsersLayout.SortOrder = Enum.SortOrder.LayoutOrder
UsersLayout.Padding = UDim.new(0, 4)

local ChatView = Instance.new("Frame")
ChatView.Size = UDim2.new(1, -20, 1, -20)
ChatView.Position = UDim2.new(0, 10, 0, 10)
ChatView.BackgroundTransparency = 1
ChatView.Visible = false
ChatView.Parent = ViewContainer

local ChatScrolling = Instance.new("ScrollingFrame")
ChatScrolling.Size = UDim2.new(1, 0, 1, -45)
ChatScrolling.BackgroundTransparency = 1
ChatScrolling.BorderSizePixel = 0
ChatScrolling.ScrollBarThickness = 4
ChatScrolling.Parent = ChatView
local ChatLayout = Instance.new("UIListLayout", ChatScrolling)
ChatLayout.SortOrder = Enum.SortOrder.LayoutOrder
ChatLayout.Padding = UDim.new(0, 6)

local TextBox = Instance.new("TextBox")
TextBox.Size = UDim2.new(1, 0, 0, 38)
TextBox.Position = UDim2.new(0, 0, 1, -38)
TextBox.BackgroundColor3 = Color3.fromRGB(56, 58, 64) 
TextBox.TextColor3 = Color3.fromRGB(219, 222, 225)
TextBox.PlaceholderText = "Message..."
TextBox.Font = Enum.Font.Gotham
TextBox.TextSize = 14
TextBox.TextXAlignment = Enum.TextXAlignment.Left
TextBox.ClearTextOnFocus = true
TextBox.Parent = ChatView
Instance.new("UIPadding", TextBox).PaddingLeft = UDim.new(0, 12)
Instance.new("UICorner", TextBox).CornerRadius = UDim.new(0, 6)

-- --- DISCORD ADMIN PANEL ---
local AdminPanel = Instance.new("Frame")
AdminPanel.Size = UDim2.new(1, -16, 0, 195)
AdminPanel.Position = UDim2.new(0, 8, 1, -205)
AdminPanel.BackgroundColor3 = Color3.fromRGB(35, 36, 40)
AdminPanel.Visible = false
AdminPanel.Parent = Sidebar
Instance.new("UICorner", AdminPanel).CornerRadius = UDim.new(0, 6)

local AdminTitle = Instance.new("TextLabel")
AdminTitle.Size = UDim2.new(1, 0, 0, 24)
AdminTitle.BackgroundTransparency = 1
AdminTitle.Text = "👑 ADMIN PANEL"
AdminTitle.TextColor3 = Color3.fromRGB(255, 235, 59)
AdminTitle.Font = Enum.Font.GothamBold
AdminTitle.TextSize = 11
AdminTitle.Parent = AdminPanel

local TpUserBox = Instance.new("TextBox")
TpUserBox.Size = UDim2.new(1, -16, 0, 28)
TpUserBox.Position = UDim2.new(0, 8, 0, 30)
TpUserBox.BackgroundColor3 = Color3.fromRGB(49, 51, 56)
TpUserBox.PlaceholderText = "Target user or 'all'"
TpUserBox.TextColor3 = Color3.fromRGB(255, 255, 255)
TpUserBox.Font = Enum.Font.Gotham
TpUserBox.TextSize = 11
TpUserBox.Parent = AdminPanel
Instance.new("UICorner", TpUserBox).CornerRadius = UDim.new(0, 4)

local TpBtn = Instance.new("TextButton")
TpBtn.Size = UDim2.new(1, -16, 0, 32)
TpBtn.Position = UDim2.new(0, 8, 0, 66)
TpBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242) 
TpBtn.Text = "Bring To Me"
TpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
TpBtn.Font = Enum.Font.GothamBold
TpBtn.TextSize = 12
TpBtn.Parent = AdminPanel
Instance.new("UICorner", TpBtn).CornerRadius = UDim.new(0, 4)

local KillBtn = Instance.new("TextButton")
KillBtn.Size = UDim2.new(0.5, -12, 0, 32)
KillBtn.Position = UDim2.new(0, 8, 0, 106)
KillBtn.BackgroundColor3 = Color3.fromRGB(242, 63, 67) 
KillBtn.Text = "Kill"
KillBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
KillBtn.Font = Enum.Font.GothamBold
KillBtn.TextSize = 12
KillBtn.Parent = AdminPanel
Instance.new("UICorner", KillBtn).CornerRadius = UDim.new(0, 4)

local ExplodeBtn = Instance.new("TextButton")
ExplodeBtn.Size = UDim2.new(0.5, -12, 0, 32)
ExplodeBtn.Position = UDim2.new(0.5, 4, 0, 106)
ExplodeBtn.BackgroundColor3 = Color3.fromRGB(230, 126, 34) 
ExplodeBtn.Text = "Explode"
ExplodeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ExplodeBtn.Font = Enum.Font.GothamBold
ExplodeBtn.TextSize = 12
ExplodeBtn.Parent = AdminPanel
Instance.new("UICorner", ExplodeBtn).CornerRadius = UDim.new(0, 4)

local ClearCmdBtn = Instance.new("TextButton")
ClearCmdBtn.Size = UDim2.new(1, -16, 0, 32)
ClearCmdBtn.Position = UDim2.new(0, 8, 0, 148)
ClearCmdBtn.BackgroundColor3 = Color3.fromRGB(78, 80, 88)
ClearCmdBtn.Text = "Clear Active Commands"
ClearCmdBtn.TextColor3 = Color3.fromRGB(220, 221, 222)
ClearCmdBtn.Font = Enum.Font.GothamBold
ClearCmdBtn.TextSize = 11
ClearCmdBtn.Parent = AdminPanel
Instance.new("UICorner", ClearCmdBtn).CornerRadius = UDim.new(0, 4)

-- --- WINDOW HANDLERS ---
local dragging, dragInput, dragStart, startPos
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = input.Position; startPos = WindowFrame.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end)
TitleBar.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end end)
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
    WindowFrame.Size = minimized and UDim2.new(0, 650, 0, 32) or UDim2.new(0, 680, 0, 440)
    MinBtn.Text = minimized and "🗖" or "—"
end)

CloseBtn.MouseButton1Click:Connect(function() running = false; ScreenGui:Destroy() end)

-- --- CHANNEL SWITCHERS CONTROLLER ---
local function selectTab(tab)
    currentTab = tab
    ChannelUsers.BackgroundTransparency = 1; ChannelUsers.TextColor3 = Color3.fromRGB(148, 155, 164)
    ChannelServerChat.BackgroundTransparency = 1; ChannelServerChat.TextColor3 = Color3.fromRGB(148, 155, 164)
    ChannelGlobalChat.BackgroundTransparency = 1; ChannelGlobalChat.TextColor3 = Color3.fromRGB(148, 155, 164)
    UsersView.Visible = false; ChatView.Visible = false

    if tab == "users" then
        ChannelUsers.BackgroundColor3 = Color3.fromRGB(53, 55, 60); ChannelUsers.TextColor3 = Color3.fromRGB(255, 255, 255)
        UsersView.Visible = true
    elseif tab == "server" then
        ChannelServerChat.BackgroundColor3 = Color3.fromRGB(53, 55, 60); ChannelServerChat.TextColor3 = Color3.fromRGB(255, 255, 255)
        TextBox.PlaceholderText = "Message #server-chat"
        ChatView.Visible = true
    elseif tab == "global" then
        ChannelGlobalChat.BackgroundColor3 = Color3.fromRGB(53, 55, 60); ChannelGlobalChat.TextColor3 = Color3.fromRGB(255, 255, 255)
        TextBox.PlaceholderText = "Message #global-cross-chat"
        ChatView.Visible = true
    end
end

ChannelUsers.MouseButton1Click:Connect(function() selectTab("users") end)
ChannelServerChat.MouseButton1Click:Connect(function() selectTab("server") end)
ChannelGlobalChat.MouseButton1Click:Connect(function() selectTab("global") end)

-- --- INTERFACE PIPELINES ---
local function refreshUIList(data)
    for _, child in ipairs(UsersView:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    
    for _, user in ipairs(data) do
        local PlayerRow = Instance.new("Frame")
        PlayerRow.Size = UDim2.new(1, -6, 0, 45)
        PlayerRow.BackgroundColor3 = Color3.fromRGB(43, 45, 49)
        PlayerRow.Parent = UsersView
        Instance.new("UICorner", PlayerRow).CornerRadius = UDim.new(0, 4)

        local NameLabel = Instance.new("TextLabel")
        NameLabel.Size = UDim2.new(0.4, -10, 0, 22)
        NameLabel.Position = UDim2.new(0, 10, 0, 2)
        NameLabel.BackgroundTransparency = 1
        NameLabel.Text = user.username
        NameLabel.Font = Enum.Font.GothamSemibold
        NameLabel.TextSize = 13
        NameLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        if user.is_admin then
            NameLabel.TextColor3 = Color3.fromRGB(255, 235, 59); NameLabel.Text = "👑 " .. user.username
        elseif user.username == Username then
            NameLabel.TextColor3 = Color3.fromRGB(242, 243, 245); NameLabel.Text = user.username .. " (You)"
        else
            NameLabel.TextColor3 = Color3.fromRGB(148, 155, 164)
        end
        NameLabel.Parent = PlayerRow

        -- Subtitle: Displays live Game Name + Executor String
        local Subtitle = Instance.new("TextLabel")
        Subtitle.Size = UDim2.new(0.6, 0, 0, 18)
        Subtitle.Position = UDim2.new(0, 10, 0, 22)
        Subtitle.BackgroundTransparency = 1
        Subtitle.Text = "🎮 " .. user.current_game .. " | ⚙️ " .. user.executor
        Subtitle.TextColor3 = Color3.fromRGB(110, 115, 122)
        Subtitle.Font = Enum.Font.Gotham
        Subtitle.TextSize = 10
        Subtitle.TextXAlignment = Enum.TextXAlignment.Left
        Subtitle.Parent = PlayerRow

        -- Discord Style Join Server Action Button
        if user.username ~= Username then
            local JoinBtn = Instance.new("TextButton")
            JoinBtn.Size = UDim2.new(0, 65, 0, 26)
            JoinBtn.Position = UDim2.new(1, -75, 0, 9)
            JoinBtn.BackgroundColor3 = Color3.fromRGB(35, 165, 90) -- Discord Green
            JoinBtn.Text = "Join Game"
            JoinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            JoinBtn.Font = Enum.Font.GothamBold
            JoinBtn.TextSize = 10
            JoinBtn.Parent = PlayerRow
            Instance.new("UICorner", JoinBtn).CornerRadius = UDim.new(0, 4)

            JoinBtn.MouseButton1Click:Connect(function()
                -- Instantly execute teleport handshake into their distinct server instance
                TeleportService:TeleportToPlaceInstance(user.place_id, user.job_id, LocalPlayer)
            end)
        end
    end
    UsersView.CanvasSize = UDim2.new(0, 0, 0, UsersLayout.AbsoluteContentSize.Y)
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
        MsgLabel.TextColor3 = Color3.fromRGB(219, 222, 225)
        MsgLabel.Parent = MsgFrame
    end
    ChatScrolling.CanvasSize = UDim2.new(0, 0, 0, ChatLayout.AbsoluteContentSize.Y)
    ChatScrolling.CanvasPosition = Vector2.new(0, ChatScrolling.CanvasSize.Y.Offset)
end

-- --- NETWORK BACKEND HANDSHAKES ---
local function updatePresence()
    if not running then return end
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
            place_id = PlaceId,
            current_game = gameName, -- Synchronize real-time game info fields
            executor = myExecutor, 
            updated_at = "now()",
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

    -- Map destination pointer target keys based on selected sidebar view channel status
    local destinationJobId = (currentTab == "global") and nil or JobId

    request({
        Url = SUPABASE_URL .. "/rest/v1/executor_chat",
        Method = "POST",
        Headers = { ["apikey"] = SUPABASE_KEY, ["Authorization"] = "Bearer " .. SUPABASE_KEY, ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode({ username = Username, job_id = destinationJobId, message = cleanMsg })
    })
end

local function fetchData()
    if not running then return end
    local pastThreshold = DateTime.fromUnixTimestamp(DateTime.now().UnixTimestamp - 25):ToIsoDate()
    
    -- 1. Fetch ALL active global network users across every distinct place file
    local resUser = request({
        Url = SUPABASE_URL .. "/rest/v1/executor_sync?updated_at=gt." .. pastThreshold .. "&select=username,executor,teleport_target,active_effect,is_admin,current_game,job_id,place_id",
        Method = "GET",
        Headers = { ["apikey"] = SUPABASE_KEY, ["Authorization"] = "Bearer " .. SUPABASE_KEY }
    })
    
    local adminPool = {}
    if resUser.StatusCode == 200 then
        local users = HttpService:JSONDecode(resUser.Body)
        
        for _, u in ipairs(users) do
            if u.is_admin then adminPool[u.username] = true end
            if u.username == Username and u.is_admin and not IsAdmin then
                IsAdmin = true
                AdminPanel.Visible = true 
            end
        end
        
        refreshUIList(users)
        
        -- --- CROSS-CLIENT INTERCEPTOR ENGINE ---
        for _, user in ipairs(users) do
            -- Enforce that admin operational chains only match if running inside the exact same JobId server space
            if user.is_admin and user.job_id == JobId then
                if user.teleport_target ~= "none" and not IsAdmin and (user.teleport_target == Username or user.teleport_target == "all") then
                    local adminPlayer = Players:FindFirstChild(user.username)
                    if adminPlayer and adminPlayer.Character and adminPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local adminCF = adminPlayer.Character.HumanoidRootPart.CFrame
                        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            LocalPlayer.Character.HumanoidRootPart.CFrame = adminCF * CFrame.new(0, 2, -3)
                        end
                    end
                end

                if user.active_effect ~= "none" then
                    local cmdData = string.split(user.active_effect, ":")
                    local action = cmdData[1]
                    local target = cmdData[2]
                    local uniqueHash = cmdData[3] 

                    if not handledCommands[uniqueHash] then
                        handledCommands[uniqueHash] = true 
                        if not IsAdmin then
                            if target == Username or target == "all" then
                                if action == "kill" then task.spawn(function() runLocalExplosionEffect(Username) end)
                                elseif action == "explode" then task.spawn(function() runLocalExplosionEffect(Username) end) end
                            elseif target ~= Username and target ~= "all" then
                                if action == "kill" or action == "explode" then task.spawn(function() runLocalExplosionEffect(target) end) end
                            end
                        end
                    end
                end
            end
        end
    end

    -- 2. Fetch Chat Records dynamically based on whether Server or Global tabs are active
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

-- --- BUTTON HANDLERS ---
TextBox.FocusLost:Connect(function(enterPressed) if enterPressed then local text = TextBox.Text; TextBox.Text = "" task.spawn(function() sendChatMessage(text) fetchData() end) end end)

TpBtn.MouseButton1Click:Connect(function()
    if IsAdmin then
        local targetName = sanitizeText(TpUserBox.Text)
        if targetName ~= "" then _G.CurrentTpTarget = targetName; updatePresence()
            task.delay(4, function() if _G.CurrentTpTarget == targetName then _G.CurrentTpTarget = "none"; updatePresence() end end)
        end
    end
end)

KillBtn.MouseButton1Click:Connect(function()
    if IsAdmin then
        local targetName = sanitizeText(TpUserBox.Text)
        if targetName ~= "" then
            _G.CurrentActiveEffect = "kill:" .. targetName .. ":" .. tostring(os.time() .. math.random(1,1000))
            runLocalExplosionEffect(targetName)
            updatePresence()
            task.delay(4, function() if _G.CurrentActiveEffect:sub(1,4) == "kill" then _G.CurrentActiveEffect = "none"; updatePresence() end end)
        end
    end
end)

ExplodeBtn.MouseButton1Click:Connect(function()
    if IsAdmin then
        local targetName = sanitizeText(TpUserBox.Text)
        if targetName ~= "" then
            _G.CurrentActiveEffect = "explode:" .. targetName .. ":" .. tostring(os.time() .. math.random(1,1000))
            runLocalExplosionEffect(targetName)
            updatePresence()
            task.delay(4, function() if _G.CurrentActiveEffect:sub(1,7) == "explode" then _G.CurrentActiveEffect = "none"; updatePresence() end end)
        end
    end
end)

ClearCmdBtn.MouseButton1Click:Connect(function()
    if IsAdmin then _G.CurrentTpTarget = "none"; _G.CurrentActiveEffect = "none"; updatePresence() end
end)

-- --- LOOP OPERATIONS ---
updatePresence()
fetchData()
task.spawn(function() while task.wait(4) do if not running then break end updatePresence() fetchData() end end)
