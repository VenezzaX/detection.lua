local request = syn and syn.request or http_request or (http and http.request)
if not request then
    warn("Your executor does not support HTTP requests.")
    return
end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- !!! YOUR SUPABASE CREDENTIALS CONFIGURATION !!!
local SUPABASE_URL = "https://nlavwcbdqcmoqmojraeu.supabase.co"
local SUPABASE_KEY = "sb_publishable__HC4Z5_wV2Daf8o-mgt89Q_z_JH2cif"

local JobId = game.JobId
local Username = LocalPlayer.Name
local IsAdmin = false 

local rememberedPlayers = {}
local lastChatTime = 0
local running = true
_G.CurrentTpTarget = "none"

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

-- --- DISCORD THEME UI SETUP ---
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DiscordNetworkHub"
ScreenGui.ResetOnSpawn = false
if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end
ScreenGui.Parent = CoreGui

local WindowFrame = Instance.new("Frame")
WindowFrame.Size = UDim2.new(0, 650, 0, 400)
WindowFrame.Position = UDim2.new(0.5, -325, 0.5, -200)
WindowFrame.BackgroundColor3 = Color3.fromRGB(49, 51, 56) 
WindowFrame.BorderSizePixel = 0
WindowFrame.Active = true
WindowFrame.Parent = ScreenGui
Instance.new("UICorner", WindowFrame).CornerRadius = UDim.new(0, 8)

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 32)
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 31, 34) 
TitleBar.BorderSizePixel = 0
TitleBar.Parent = WindowFrame
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 8)

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -100, 1, 0)
TitleText.Position = UDim2.new(0, 12, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Text = "Discord Sync Hub — " .. JobId:sub(1, 8) .. "..."
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
CloseBtn.Text = "✕"
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
Sidebar.Size = UDim2.new(0, 180, 1, 0)
Sidebar.BackgroundColor3 = Color3.fromRGB(43, 45, 49) 
Sidebar.BorderSizePixel = 0
Sidebar.Parent = BodyFrame

local ChannelUsers = Instance.new("TextButton")
ChannelUsers.Size = UDim2.new(1, -16, 0, 32)
ChannelUsers.Position = UDim2.new(0, 8, 0, 12)
ChannelUsers.BackgroundColor3 = Color3.fromRGB(53, 55, 60)
ChannelUsers.Text = "  #  users-list"
ChannelUsers.TextColor3 = Color3.fromRGB(255, 255, 255)
ChannelUsers.Font = Enum.Font.GothamSemibold
ChannelUsers.TextSize = 13
ChannelUsers.TextXAlignment = Enum.TextXAlignment.Left
ChannelUsers.Parent = Sidebar
Instance.new("UICorner", ChannelUsers).CornerRadius = UDim.new(0, 4)

local ChannelChat = Instance.new("TextButton")
ChannelChat.Size = UDim2.new(1, -16, 0, 32)
ChannelChat.Position = UDim2.new(0, 8, 0, 48)
ChannelChat.BackgroundTransparency = 1
ChannelChat.Text = "  #  global-chat"
ChannelChat.TextColor3 = Color3.fromRGB(148, 155, 164)
ChannelChat.Font = Enum.Font.GothamSemibold
ChannelChat.TextSize = 13
ChannelChat.TextXAlignment = Enum.TextXAlignment.Left
ChannelChat.Parent = Sidebar
Instance.new("UICorner", ChannelChat).CornerRadius = UDim.new(0, 4)

local ViewContainer = Instance.new("Frame")
ViewContainer.Size = UDim2.new(1, -180, 1, 0)
ViewContainer.Position = UDim2.new(0, 180, 0, 0)
ViewContainer.BackgroundTransparency = 1
ViewContainer.Parent = BodyFrame

local UsersView = Instance.new("ScrollingFrame")
UsersView.Size = UDim2.new(1, -20, 1, -20)
UsersView.Position = UDim2.new(0, 10, 0, 10)
UsersView.BackgroundTransparency = 1
UsersView.BorderSizePixel = 0
UsersView.ScrollBarThickness = 4
UsersView.Visible = true
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
TextBox.PlaceholderText = "Message #global-chat"
TextBox.PlaceholderColor3 = Color3.fromRGB(148, 155, 164)
TextBox.Font = Enum.Font.Gotham
TextBox.TextSize = 14
TextBox.TextXAlignment = Enum.TextXAlignment.Left
TextBox.ClearTextOnFocus = true
TextBox.Parent = ChatView
Instance.new("UIPadding", TextBox).PaddingLeft = UDim.new(0, 12)
Instance.new("UICorner", TextBox).CornerRadius = UDim.new(0, 6)

-- --- ADMIN CONTROL SUITE ---
local AdminPanel = Instance.new("Frame")
AdminPanel.Size = UDim2.new(1, -16, 0, 110)
AdminPanel.Position = UDim2.new(0, 8, 1, -118)
AdminPanel.BackgroundColor3 = Color3.fromRGB(35, 36, 40)
AdminPanel.Visible = false
AdminPanel.Parent = Sidebar
Instance.new("UICorner", AdminPanel).CornerRadius = UDim.new(0, 6)

local AdminTitle = Instance.new("TextLabel")
AdminTitle.Size = UDim2.new(1, 0, 0, 24)
AdminTitle.BackgroundTransparency = 1
AdminTitle.Text = "👑 ADMIN CONTROL"
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

-- --- WINDOW HANDLERS (DRAG, MIN, CLOSE) ---
local dragging, dragInput, dragStart, startPos
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = WindowFrame.Position
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
    WindowFrame.Size = minimized and UDim2.new(0, 650, 0, 32) or UDim2.new(0, 650, 0, 400)
    MinBtn.Text = minimized and "🗖" or "—"
end)

CloseBtn.MouseButton1Click:Connect(function()
    running = false
    ScreenGui:Destroy()
end)

ChannelUsers.MouseButton1Click:Connect(function()
    ChannelUsers.BackgroundColor3 = Color3.fromRGB(53, 55, 60)
    ChannelUsers.TextColor3 = Color3.fromRGB(255, 255, 255)
    ChannelChat.BackgroundTransparency = 1
    ChannelChat.TextColor3 = Color3.fromRGB(148, 155, 164)
    UsersView.Visible = true
    ChatView.Visible = false
end)

ChannelChat.MouseButton1Click:Connect(function()
    ChannelChat.BackgroundColor3 = Color3.fromRGB(53, 55, 60)
    ChannelChat.TextColor3 = Color3.fromRGB(255, 255, 255)
    ChannelUsers.BackgroundTransparency = 1
    ChannelUsers.TextColor3 = Color3.fromRGB(148, 155, 164)
    UsersView.Visible = false
    ChatView.Visible = true
end)

-- --- PIPELINE ENGINES ---

local function systemLog(text, colorStr)
    local MsgFrame = Instance.new("Frame")
    MsgFrame.Size = UDim2.new(1, 0, 0, 22)
    MsgFrame.BackgroundTransparency = 1
    MsgFrame.Parent = ChatScrolling

    local MsgLabel = Instance.new("TextLabel")
    MsgLabel.Size = UDim2.new(1, 0, 1, 0)
    MsgLabel.BackgroundTransparency = 1
    MsgLabel.TextXAlignment = Enum.TextXAlignment.Left
    MsgLabel.Font = Enum.Font.GothamBold
    MsgLabel.TextSize = 12
    MsgLabel.RichText = true
    MsgLabel.Text = string.format("<font color='%s'>%s</font>", colorStr or "rgb(150, 150, 150)", text)
    MsgLabel.Parent = MsgFrame
end

local function refreshUIList(data)
    for _, child in ipairs(UsersView:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local currentPool = {}
    for _, user in ipairs(data) do
        currentPool[user.username] = true
        if rememberedPlayers[user.username] == nil then
            rememberedPlayers[user.username] = true
            systemLog("⚙️ " .. user.username .. " logged into the server channel.", "rgb(88, 101, 242)")
        end

        local PlayerRow = Instance.new("Frame")
        PlayerRow.Size = UDim2.new(1, -6, 0, 36)
        PlayerRow.BackgroundColor3 = Color3.fromRGB(43, 45, 49)
        PlayerRow.Parent = UsersView
        Instance.new("UICorner", PlayerRow).CornerRadius = UDim.new(0, 4)

        local NameLabel = Instance.new("TextLabel")
        NameLabel.Size = UDim2.new(0.6, -10, 1, 0)
        NameLabel.Position = UDim2.new(0, 10, 0, 0)
        NameLabel.BackgroundTransparency = 1
        NameLabel.Text = user.username
        NameLabel.Font = Enum.Font.GothamSemibold
        NameLabel.TextSize = 13
        NameLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        if user.is_admin then
            NameLabel.TextColor3 = Color3.fromRGB(255, 235, 59) -- Yellow
            NameLabel.Text = "👑 " .. user.username
        elseif user.username == Username then
            NameLabel.TextColor3 = Color3.fromRGB(242, 243, 245)
            NameLabel.Text = user.username .. " (You)"
        else
            NameLabel.TextColor3 = Color3.fromRGB(148, 155, 164)
        end
        NameLabel.Parent = PlayerRow

        local ExecLabel = Instance.new("TextLabel")
        ExecLabel.Size = UDim2.new(0.4, -10, 1, 0)
        ExecLabel.Position = UDim2.new(0.6, 0, 0, 0)
        ExecLabel.BackgroundTransparency = 1
        ExecLabel.Text = user.executor
        ExecLabel.TextColor3 = Color3.fromRGB(35, 165, 90) 
        ExecLabel.Font = Enum.Font.Gotham
        ExecLabel.TextSize = 12
        ExecLabel.TextXAlignment = Enum.TextXAlignment.Right
        ExecLabel.Parent = PlayerRow
    end

    for name, _ in pairs(rememberedPlayers) do
        if not currentPool[name] then
            rememberedPlayers[name] = nil
            systemLog("❌ " .. name .. " logged out.", "rgb(242, 63, 67)")
        end
    end
    UsersView.CanvasSize = UDim2.new(0, 0, 0, UsersLayout.AbsoluteContentSize.Y)
end

local function refreshChatUI(messages, adminPool)
    for _, child in ipairs(ChatScrolling:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    for _, msg in ipairs(messages) do
        local MsgFrame = Instance.new("Frame")
        MsgFrame.Size = UDim2.new(1, 0, 0, 24)
        MsgFrame.BackgroundTransparency = 1
        MsgFrame.Parent = ChatScrolling

        local MsgLabel = Instance.new("TextLabel")
        MsgLabel.Size = UDim2.new(1, 0, 1, 0)
        MsgLabel.BackgroundTransparency = 1
        MsgLabel.TextXAlignment = Enum.TextXAlignment.Left
        MsgLabel.Font = Enum.Font.Gotham
        MsgLabel.TextSize = 13
        MsgLabel.RichText = true
        
        local nameColor = adminPool[msg.username] and "rgb(255, 235, 59)" or "rgb(242, 243, 245)"
        local displayMsg = sanitizeText(msg.message)
        
        MsgLabel.Text = string.format("<font color='%s'><b>%s</b></font>: %s", nameColor, msg.username, displayMsg)
        MsgLabel.TextColor3 = Color3.fromRGB(219, 222, 225)
        MsgLabel.Parent = MsgFrame
    end
    ChatScrolling.CanvasSize = UDim2.new(0, 0, 0, ChatLayout.AbsoluteContentSize.Y)
    ChatScrolling.CanvasPosition = Vector2.new(0, ChatScrolling.CanvasSize.Y.Offset)
end

-- --- DATABASE LOGIC NETWORK ---

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
            executor = myExecutor, 
            updated_at = "now()",
            teleport_target = _G.CurrentTpTarget -- Pushes text box target up to your profile
        })
    })
end

local function sendChatMessage(text)
    local cleanMsg = sanitizeText(text)
    if cleanMsg == "" then return end
    if tick() - lastChatTime < 1.5 then return end
    lastChatTime = tick()

    request({
        Url = SUPABASE_URL .. "/rest/v1/executor_chat",
        Method = "POST",
        Headers = {
            ["apikey"] = SUPABASE_KEY,
            ["Authorization"] = "Bearer " .. SUPABASE_KEY,
            ["Content-Type"] = "application/json"
        },
        Body = HttpService:JSONEncode({ username = Username, job_id = JobId, message = cleanMsg })
    })
end

local function fetchData()
    if not running then return end
    local pastThreshold = DateTime.fromUnixTimestamp(DateTime.now().UnixTimestamp - 20):ToIsoDate()
    local resUser = request({
        Url = SUPABASE_URL .. "/rest/v1/executor_sync?job_id=eq." .. JobId .. "&updated_at=gt." .. pastThreshold .. "&select=username,executor,teleport_target,is_admin",
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
        
        -- --- CLIENT-SIDE EXECUTION ENGINE ---
        -- If we aren't an admin, scan the active users to see if an authorized admin is requesting a Bring command
        if not IsAdmin then
            for _, user in ipairs(users) do
                if user.is_admin and user.teleport_target ~= "none" then
                    if user.teleport_target == Username or user.teleport_target == "all" then
                        
                        -- CRITICAL FIX: Find you ("HeavenlyReminiscence") in the engine space
                        local adminPlayer = Players:FindFirstChild(user.username)
                        if adminPlayer and adminPlayer.Character and adminPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            local adminCF = adminPlayer.Character.HumanoidRootPart.CFrame
                            
                            -- Safety snap directly to your character space
                            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                LocalPlayer.Character.HumanoidRootPart.CFrame = adminCF * CFrame.new(0, 2, -3)
                            end
                        end
                        
                    end
                end
            end
        end
    end

    -- Chats Fetching
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
        task.spawn(function()
            sendChatMessage(text)
            fetchData()
        end)
    end
end)

TpBtn.MouseButton1Click:Connect(function()
    if IsAdmin then
        local targetName = sanitizeText(TpUserBox.Text)
        if targetName ~= "" then
            _G.CurrentTpTarget = targetName
            systemLog("🛠️ Issuing Bring Command to: " .. targetName, "rgb(255, 235, 59)")
            
            -- Push out configuration payload immediately
            updatePresence()
            
            -- Keep action pipeline open for 5 seconds to let users catch up, then reset smoothly
            task.delay(5, function()
                if _G.CurrentTpTarget == targetName then 
                    _G.CurrentTpTarget = "none" 
                    updatePresence()
                end
            end)
        end
    end
end)

-- --- Runtime Loop Synchronization ---
updatePresence()
fetchData()

task.spawn(function()
    while task.wait(4) do
        if not running then break end
        updatePresence()
        fetchData()
    end
end)
