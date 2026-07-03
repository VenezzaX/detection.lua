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

-- Identify executor name
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

-- Expanded Main Frame to fit both users and chat side-by-side
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 650, 0, 400)
MainFrame.Position = UDim2.new(0.5, -325, 0.5, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

-- Top Header Title
local Header = Instance.new("TextLabel")
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
Header.Text = "📡 Script Users Network & Global Chat"
Header.TextColor3 = Color3.fromRGB(255, 255, 255)
Header.Font = Enum.Font.GothamBold
Header.TextSize = 16
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 8)
HeaderCorner.Parent = Header

-- LEFT SIDE: Users List Frame
local UsersFrame = Instance.new("Frame")
UsersFrame.Size = UDim2.new(0, 250, 1, -50)
UsersFrame.Position = UDim2.new(0, 10, 0, 45)
UsersFrame.BackgroundTransparency = 1
UsersFrame.Parent = MainFrame

local UsersTitle = Instance.new("TextLabel")
UsersTitle.Size = UDim2.new(1, 0, 0, 20)
UsersTitle.Text = "ACTIVE USERS"
UsersTitle.TextColor3 = Color3.fromRGB(150, 150, 160)
UsersTitle.Font = Enum.Font.GothamBold
UsersTitle.TextSize = 12
UsersTitle.TextXAlignment = Enum.TextXAlignment.Left
UsersTitle.BackgroundTransparency = 1
UsersTitle.Parent = UsersFrame

local ListScrolling = Instance.new("ScrollingFrame")
ListScrolling.Size = UDim2.new(1, 0, 1, -25)
ListScrolling.Position = UDim2.new(0, 0, 0, 25)
ListScrolling.BackgroundTransparency = 1
ListScrolling.BorderSizePixel = 0
ListScrolling.ScrollBarThickness = 4
ListScrolling.Parent = UsersFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 6)
UIListLayout.Parent = ListScrolling

-- RIGHT SIDE: Chat Frame
local ChatFrame = Instance.new("Frame")
ChatFrame.Size = UDim2.new(1, -280, 1, -50)
ChatFrame.Position = UDim2.new(0, 270, 0, 45)
ChatFrame.BackgroundTransparency = 1
ChatFrame.Parent = MainFrame

local ChatTitle = Instance.new("TextLabel")
ChatTitle.Size = UDim2.new(1, 0, 0, 20)
ChatTitle.Text = "SERVER ROOM CHAT"
ChatTitle.TextColor3 = Color3.fromRGB(150, 150, 160)
ChatTitle.Font = Enum.Font.GothamBold
ChatTitle.TextSize = 12
ChatTitle.TextXAlignment = Enum.TextXAlignment.Left
ChatTitle.BackgroundTransparency = 1
ChatTitle.Parent = ChatFrame

local ChatScrolling = Instance.new("ScrollingFrame")
ChatScrolling.Size = UDim2.new(1, 0, 1, -65)
ChatScrolling.Position = UDim2.new(0, 0, 0, 25)
ChatScrolling.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
ChatScrolling.BorderSizePixel = 0
ChatScrolling.ScrollBarThickness = 4
ChatScrolling.Parent = ChatFrame

local ChatCorner = Instance.new("UICorner")
ChatCorner.CornerRadius = UDim.new(0, 6)
ChatCorner.Parent = ChatScrolling

local UIChatList = Instance.new("UIListLayout")
UIChatList.SortOrder = Enum.SortOrder.LayoutOrder
UIChatList.Padding = UDim.new(0, 4)
UIChatList.Parent = ChatScrolling

-- Bottom Text Box Input for chat
local TextBox = Instance.new("TextBox")
TextBox.Size = UDim2.new(1, 0, 0, 35)
TextBox.Position = UDim2.new(0, 0, 1, -35)
TextBox.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
TextBox.BorderSizePixel = 0
TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
TextBox.PlaceholderText = "Type a message here and press Enter..."
TextBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
TextBox.Font = Enum.Font.Gotham
TextBox.TextSize = 14
TextBox.TextXAlignment = Enum.TextXAlignment.Left
TextBox.ClearTextOnFocus = true
TextBox.Parent = ChatFrame

local TextPadding = Instance.new("UIPadding")
TextPadding.PaddingLeft = UDim.new(0, 10)
TextPadding.Parent = TextBox

local TextBoxCorner = Instance.new("UICorner")
TextBoxCorner.CornerRadius = UDim.new(0, 6)
TextBoxCorner.Parent = TextBox

-- --- FUNCTIONS ---

local function refreshUIList(data)
    for _, child in ipairs(ListScrolling:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    for _, user in ipairs(data) do
        local PlayerRow = Instance.new("Frame")
        PlayerRow.Size = UDim2.new(1, -6, 0, 35)
        PlayerRow.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
        PlayerRow.BorderSizePixel = 0
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
        
        if user.username == "HeavenlyReminiscence" then
            NameLabel.TextColor3 = Color3.fromRGB(255, 235, 59)
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
    ListScrolling.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y)
end

local function refreshChatUI(messages)
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
        
        local nameColor = (msg.username == "HeavenlyReminiscence") and "rgb(255, 235, 59)" or "rgb(150, 200, 255)"
        MsgLabel.Text = string.format("<font color='%s'><b>%s</b></font>: %s", nameColor, msg.username, msg.message)
        MsgLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
        MsgLabel.Parent = MsgFrame
    end
    ChatScrolling.CanvasSize = UDim2.new(0, 0, 0, UIChatList.AbsoluteContentSize.Y)
    ChatScrolling.CanvasPosition = Vector2.new(0, ChatScrolling.CanvasSize.Y.Offset)
end

-- --- NETWORK BACKEND POSTS & GETS ---

local function updatePresence()
    request({
        Url = SUPABASE_URL .. "/rest/v1/executor_sync",
        Method = "POST",
        Headers = {
            ["apikey"] = SUPABASE_KEY,
            ["Authorization"] = "Bearer " .. SUPABASE_KEY,
            ["Content-Type"] = "application/json",
            ["Prefer"] = "resolution=merge-duplicates"
        },
        Body = HttpService:JSONEncode({ username = Username, job_id = JobId, executor = myExecutor, updated_at = "now()" })
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
    -- Get User Presence
    local resUser = request({
        Url = SUPABASE_URL .. "/rest/v1/executor_sync?job_id=eq." .. JobId .. "&select=username,executor",
        Method = "GET",
        Headers = { ["apikey"] = SUPABASE_KEY, ["Authorization"] = "Bearer " .. SUPABASE_KEY }
    })
    if resUser.StatusCode == 200 then
        refreshUIList(HttpService:JSONDecode(resUser.Body))
    end

    -- Get Last 30 Messages from Chat Room
    local resChat = request({
        Url = SUPABASE_URL .. "/rest/v1/executor_chat?job_id=eq." .. JobId .. "&order=created_at.desc&limit=30",
        Method = "GET",
        Headers = { ["apikey"] = SUPABASE_KEY, ["Authorization"] = "Bearer " .. SUPABASE_KEY }
    })
    if resChat.StatusCode == 200 then
        local msgs = HttpService:JSONDecode(resChat.Body)
        -- Reverse layout order array so oldest is on top, newest at bottom
        local orderedMsgs = {}
        for i = #msgs, 1, -1 do table.insert(orderedMsgs, msgs[i]) end
        refreshChatUI(orderedMsgs)
    end
end

-- Event when user hits 'Enter' inside the Text Box
TextBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        local text = TextBox.Text
        TextBox.Text = ""
        task.spawn(function()
            sendChatMessage(text)
            fetchData() -- Refresh instantly upon chat message send
        end)
    end
end)

-- --- Loops ---
updatePresence()
fetchData()

task.spawn(function()
    while task.wait(5) do -- Refreshes fast (every 5 seconds) to ensure chat feels relatively live
        updatePresence()
        fetchData()
    end
end)
