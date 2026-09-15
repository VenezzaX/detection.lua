local request = (http and http.request) or http_request or (syn and (syn.request or syn.request))
if not request then return end

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
local JobId, PlaceId = game.JobId, game.PlaceId
local Username, UserId = LocalPlayer.Name, LocalPlayer.UserId

local IsAdmin, IsSubAdmin = false, false
local SelectedTarget = "none"
local handledCommands, running = {}, true
local currentTab = "users"

local gameName = "Roblox Experience"
pcall(function()
    gameName = MarketplaceService:GetProductInfo(PlaceId).Name
end)

local function getExecutor()
    if identifyexecutor then return identifyexecutor() or "Unknown" end
    return "Unknown"
end
local myExecutor = getExecutor()

-- Safely converts incoming JSON data to avoid null userdata crashes
local function safeString(val, fallback)
    if type(val) == "string" and val ~= "" then return val end
    if type(val) == "number" then return tostring(val) end
    return fallback
end

local function sanitizeText(text)
    local clean = string.gsub(safeString(text, ""), "<[^>]*>", "")
    return #clean > 1000 and string.sub(clean, 1, 1000) or clean
end

local function truncate(str, limit)
    str = safeString(str, "")
    limit = limit or 18
    return #str > limit and string.sub(str, 1, limit - 3) .. "..." or str
end

local function runExplosionEffect(targetName)
    local targetPlayer = Players:FindFirstChild(targetName)
    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local char = targetPlayer.Character
        local exp = Instance.new("Explosion")
        exp.Position = char.HumanoidRootPart.Position
        exp.BlastRadius, exp.BlastPressure = 0, 0
        exp.Parent = workspace
        if char:FindFirstChild("Humanoid") then char.Humanoid.Health = 0 end
        char:BreakJoints()
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then
                part.Velocity = Vector3.new(math.random(-80, 80), math.random(60, 120), math.random(-80, 80))
            end
        end
    end
end

-- UI SETUP
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SyncNetworkCore"
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)

local Root = Instance.new("Frame")
Root.Size = UDim2.new(0, 620, 0, 390)
Root.Position = UDim2.new(0.5, -310, 0.5, -195)
Root.BackgroundColor3 = Color3.fromRGB(18, 19, 23)
Root.BorderSizePixel = 0
Root.Active = true
Root.Parent = ScreenGui
Instance.new("UICorner", Root).CornerRadius = UDim.new(0, 10)

local RootStroke = Instance.new("UIStroke", Root)
RootStroke.Color = Color3.fromRGB(35, 38, 47)
RootStroke.Thickness = 1

local Topbar = Instance.new("Frame")
Topbar.Size = UDim2.new(1, 0, 0, 36)
Topbar.BackgroundColor3 = Color3.fromRGB(24, 25, 31)
Topbar.BorderSizePixel = 0
Topbar.Parent = Root
Instance.new("UICorner", Topbar).CornerRadius = UDim.new(0, 10)

local HeaderTitle = Instance.new("TextLabel")
HeaderTitle.Size = UDim2.new(0, 200, 1, 0)
HeaderTitle.Position = UDim2.new(0, 14, 0, 0)
HeaderTitle.BackgroundTransparency = 1
HeaderTitle.Text = "NETWORK // HUB"
HeaderTitle.TextColor3 = Color3.fromRGB(230, 232, 240)
HeaderTitle.Font = Enum.Font.GothamBold
HeaderTitle.TextSize = 12
HeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
HeaderTitle.Parent = Topbar

local WindowActions = Instance.new("Frame")
WindowActions.Size = UDim2.new(0, 50, 1, 0)
WindowActions.Position = UDim2.new(1, -54, 0, 0)
WindowActions.BackgroundTransparency = 1
WindowActions.Parent = Topbar

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 20, 0, 20)
MinBtn.Position = UDim2.new(0, 0, 0.5, -10)
MinBtn.BackgroundColor3 = Color3.fromRGB(32, 34, 42)
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.fromRGB(160, 165, 180)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 12
MinBtn.Parent = WindowActions
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 4)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 20, 0, 20)
CloseBtn.Position = UDim2.new(0, 24, 0.5, -10)
CloseBtn.BackgroundColor3 = Color3.fromRGB(32, 34, 42)
CloseBtn.Text = "x"
CloseBtn.TextColor3 = Color3.fromRGB(160, 165, 180)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 11
CloseBtn.Parent = WindowActions
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 4)

local MainArea = Instance.new("Frame")
MainArea.Size = UDim2.new(1, 0, 1, -36)
MainArea.Position = UDim2.new(0, 0, 0, 36)
MainArea.BackgroundTransparency = 1
MainArea.Parent = Root

local Navigation = Instance.new("Frame")
Navigation.Size = UDim2.new(0, 140, 1, 0)
Navigation.BackgroundColor3 = Color3.fromRGB(22, 23, 28)
Navigation.BorderSizePixel = 0
Navigation.Parent = MainArea

local NavLayout = Instance.new("UIListLayout", Navigation)
NavLayout.SortOrder = Enum.SortOrder.LayoutOrder
NavLayout.Padding = UDim.new(0, 4)
local NavPadding = Instance.new("UIPadding", Navigation)
NavPadding.PaddingTop = UDim.new(0, 8)
NavPadding.PaddingLeft = UDim.new(0, 8)
NavPadding.PaddingRight = UDim.new(0, 8)

local ContentHost = Instance.new("Frame")
ContentHost.Size = UDim2.new(1, -140, 1, 0)
ContentHost.Position = UDim2.new(0, 140, 0, 0)
ContentHost.BackgroundTransparency = 1
ContentHost.Parent = MainArea

local function createNavTab(name, layoutOrder)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 28)
    btn.LayoutOrder = layoutOrder
    btn.BackgroundColor3 = Color3.fromRGB(28, 30, 38)
    btn.BackgroundTransparency = 1
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(130, 135, 150)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 11
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = Navigation
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    Instance.new("UIPadding", btn).PaddingLeft = UDim.new(0, 8)
    return btn
end

local TabUsers = createNavTab("Network Entities", 1)
local TabGlobal = createNavTab("Global Link", 2)
local TabPanel = createNavTab("Admin Control", 3)
TabPanel.Visible = false

local UsersFrame = Instance.new("ScrollingFrame")
UsersFrame.Size = UDim2.new(1, -16, 1, -16)
UsersFrame.Position = UDim2.new(0, 8, 0, 8)
UsersFrame.BackgroundTransparency = 1
UsersFrame.BorderSizePixel = 0
UsersFrame.ScrollBarThickness = 3
UsersFrame.ScrollBarImageColor3 = Color3.fromRGB(50, 54, 66)
UsersFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
UsersFrame.Parent = ContentHost

local UsersLayout = Instance.new("UIListLayout", UsersFrame)
UsersLayout.SortOrder = Enum.SortOrder.LayoutOrder
UsersLayout.Padding = UDim.new(0, 6)

UsersLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    UsersFrame.CanvasSize = UDim2.new(0, 0, 0, UsersLayout.AbsoluteContentSize.Y + 8)
end)

local ChatFrame = Instance.new("Frame")
ChatFrame.Size = UDim2.new(1, -16, 1, -16)
ChatFrame.Position = UDim2.new(0, 8, 0, 8)
ChatFrame.BackgroundTransparency = 1
ChatFrame.Visible = false
ChatFrame.Parent = ContentHost

local ChatScroll = Instance.new("ScrollingFrame")
ChatScroll.Size = UDim2.new(1, 0, 1, -38)
ChatScroll.BackgroundTransparency = 1
ChatScroll.BorderSizePixel = 0
ChatScroll.ScrollBarThickness = 3
ChatScroll.ScrollBarImageColor3 = Color3.fromRGB(50, 54, 66)
ChatScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
ChatScroll.Parent = ChatFrame

local ChatLayout = Instance.new("UIListLayout", ChatScroll)
ChatLayout.SortOrder = Enum.SortOrder.LayoutOrder
ChatLayout.Padding = UDim.new(0, 4)

ChatLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ChatScroll.CanvasSize = UDim2.new(0, 0, 0, ChatLayout.AbsoluteContentSize.Y + 4)
    ChatScroll.CanvasPosition = Vector2.new(0, math.max(0, ChatScroll.CanvasSize.Y.Offset - ChatScroll.AbsoluteSize.Y))
end)

local ChatInput = Instance.new("TextBox")
ChatInput.Size = UDim2.new(1, 0, 0, 30)
ChatInput.Position = UDim2.new(0, 0, 1, -30)
ChatInput.BackgroundColor3 = Color3.fromRGB(25, 27, 34)
ChatInput.TextColor3 = Color3.fromRGB(220, 222, 230)
ChatInput.Font = Enum.Font.Gotham
ChatInput.TextSize = 11
ChatInput.PlaceholderText = "Write transmission..."
ChatInput.PlaceholderColor3 = Color3.fromRGB(80, 84, 100)
ChatInput.TextXAlignment = Enum.TextXAlignment.Left
ChatInput.ClearTextOnFocus = false
ChatInput.Parent = ChatFrame
Instance.new("UICorner", ChatInput).CornerRadius = UDim.new(0, 5)
Instance.new("UIPadding", ChatInput).PaddingLeft = UDim.new(0, 8)

local PanelFrame = Instance.new("Frame")
PanelFrame.Size = UDim2.new(1, -16, 1, -16)
PanelFrame.Position = UDim2.new(0, 8, 0, 8)
PanelFrame.BackgroundTransparency = 1
PanelFrame.Visible = false
PanelFrame.Parent = ContentHost

local TargetList = Instance.new("ScrollingFrame")
TargetList.Size = UDim2.new(0, 150, 1, 0)
TargetList.BackgroundColor3 = Color3.fromRGB(22, 23, 28)
TargetList.BorderSizePixel = 0
TargetList.ScrollBarThickness = 3
TargetList.ScrollBarImageColor3 = Color3.fromRGB(50, 54, 66)
TargetList.CanvasSize = UDim2.new(0, 0, 0, 0)
TargetList.Parent = PanelFrame
Instance.new("UICorner", TargetList).CornerRadius = UDim.new(0, 6)

local TargetLayout = Instance.new("UIListLayout", TargetList)
TargetLayout.Padding = UDim.new(0, 2)
local TargetPad = Instance.new("UIPadding", TargetList)
TargetPad.PaddingTop = UDim.new(0, 4)
TargetPad.PaddingLeft = UDim.new(0, 4)
TargetPad.PaddingRight = UDim.new(0, 4)

TargetLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    TargetList.CanvasSize = UDim2.new(0, 0, 0, TargetLayout.AbsoluteContentSize.Y + 8)
end)

local ActionsContainer = Instance.new("Frame")
ActionsContainer.Size = UDim2.new(1, -158, 1, 0)
ActionsContainer.Position = UDim2.new(0, 158, 0, 0)
ActionsContainer.BackgroundColor3 = Color3.fromRGB(22, 23, 28)
ActionsContainer.BorderSizePixel = 0
ActionsContainer.Parent = PanelFrame
Instance.new("UICorner", ActionsContainer).CornerRadius = UDim.new(0, 6)

local SelectedTargetLabel = Instance.new("TextLabel")
SelectedTargetLabel.Size = UDim2.new(1, -16, 0, 26)
SelectedTargetLabel.Position = UDim2.new(0, 8, 0, 4)
SelectedTargetLabel.BackgroundTransparency = 1
SelectedTargetLabel.Text = "TARGET: NONE"
SelectedTargetLabel.TextColor3 = Color3.fromRGB(150, 155, 170)
SelectedTargetLabel.Font = Enum.Font.GothamBold
SelectedTargetLabel.TextSize = 10
SelectedTargetLabel.TextXAlignment = Enum.TextXAlignment.Left
SelectedTargetLabel.Parent = ActionsContainer

local function createActionBtn(text, pos, bgCol)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.46, 0, 0, 30)
    btn.Position = pos
    btn.BackgroundColor3 = bgCol
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(240, 242, 250)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.Parent = ActionsContainer
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    return btn
end

local BringBtn = createActionBtn("TELEPORT LOCALLY", UDim2.new(0, 8, 0, 36), Color3.fromRGB(44, 52, 78))
local ToMeBtn = createActionBtn("PULL TO POSITION", UDim2.new(0.5, 2, 0, 36), Color3.fromRGB(38, 64, 56))
local KillBtn = createActionBtn("FORCE NEUTRALIZE", UDim2.new(0, 8, 0, 72), Color3.fromRGB(74, 38, 44))
local ExplodeBtn = createActionBtn("EXPULSION DETONATE", UDim2.new(0.5, 2, 0, 72), Color3.fromRGB(80, 54, 32))

local function setTab(tab)
    currentTab = tab
    TabUsers.BackgroundTransparency, TabUsers.TextColor3 = 1, Color3.fromRGB(130, 135, 150)
    TabGlobal.BackgroundTransparency, TabGlobal.TextColor3 = 1, Color3.fromRGB(130, 135, 150)
    TabPanel.BackgroundTransparency, TabPanel.TextColor3 = 1, Color3.fromRGB(130, 135, 150)
    UsersFrame.Visible, ChatFrame.Visible, PanelFrame.Visible = false, false, false

    if tab == "users" then
        TabUsers.BackgroundTransparency, TabUsers.TextColor3 = 0, Color3.fromRGB(230, 235, 250)
        UsersFrame.Visible = true
    elseif tab == "global" then
        TabGlobal.BackgroundTransparency, TabGlobal.TextColor3 = 0, Color3.fromRGB(230, 235, 250)
        ChatFrame.Visible = true
    elseif tab == "panel" then
        TabPanel.BackgroundTransparency, TabPanel.TextColor3 = 0, Color3.fromRGB(230, 235, 250)
        PanelFrame.Visible = true
    end
end

TabUsers.MouseButton1Click:Connect(function() setTab("users") end)
TabGlobal.MouseButton1Click:Connect(function() setTab("global") end)
TabPanel.MouseButton1Click:Connect(function() setTab("panel") end)

-- GRID POPULATION WITH SAFETY CHECKS
local function populateUserGrid(data)
    for _, child in ipairs(UsersFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    for _, child in ipairs(TargetList:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end

    local unique = {}
    for _, user in ipairs(data) do
        local uName = safeString(user.username, "Unknown")
        if not unique[uName] then
            unique[uName] = true

            local Item = Instance.new("Frame")
            Item.Size = UDim2.new(1, 0, 0, 40)
            Item.BackgroundColor3 = Color3.fromRGB(24, 25, 31)
            Item.BorderSizePixel = 0
            Item.Parent = UsersFrame
            Instance.new("UICorner", Item).CornerRadius = UDim.new(0, 6)

            local NameText = Instance.new("TextLabel")
            NameText.Size = UDim2.new(0.65, 0, 0, 18)
            NameText.Position = UDim2.new(0, 10, 0, 3)
            NameText.BackgroundTransparency = 1
            NameText.RichText = true
            NameText.Font = Enum.Font.GothamMedium
            NameText.TextSize = 11
            NameText.TextXAlignment = Enum.TextXAlignment.Left

            local tagBadge = ""
            if user.is_admin == true then
                tagBadge = "<font color='rgb(255,215,0)'><b>[ROOT ADMIN]</b></font> "
            elseif user.is_sub_admin == true then
                tagBadge = "<font color='rgb(180,120,240)'><b>[OPERATOR]</b></font> "
            elseif uName == Username then
                tagBadge = "<font color='rgb(120,220,140)'><b>[LOCAL]</b></font> "
            end

            NameText.Text = tagBadge .. truncate(uName, 18)
            NameText.TextColor3 = Color3.fromRGB(230, 232, 240)
            NameText.Parent = Item

            local safeGame = safeString(user.current_game, "Roblox Experience")
            local safeExec = safeString(user.executor, "Exec")

            local InfoText = Instance.new("TextLabel")
            InfoText.Size = UDim2.new(0.65, 0, 0, 14)
            InfoText.Position = UDim2.new(0, 10, 0, 21)
            InfoText.BackgroundTransparency = 1
            InfoText.Text = truncate(safeGame, 16) .. "  •  " .. truncate(safeExec, 10)
            InfoText.Font = Enum.Font.Gotham
            InfoText.TextSize = 9
            InfoText.TextColor3 = Color3.fromRGB(110, 115, 130)
            InfoText.TextXAlignment = Enum.TextXAlignment.Left
            InfoText.Parent = Item

            if uName ~= Username then
                local Join = Instance.new("TextButton")
                Join.Size = UDim2.new(0, 52, 0, 22)
                Join.Position = UDim2.new(1, -60, 0.5, -11)
                Join.BackgroundColor3 = Color3.fromRGB(35, 40, 52)
                Join.Text = "JOIN"
                Join.TextColor3 = Color3.fromRGB(190, 195, 210)
                Join.Font = Enum.Font.GothamBold
                Join.TextSize = 9
                Join.Parent = Item
                Instance.new("UICorner", Join).CornerRadius = UDim.new(0, 4)
                
                Join.MouseButton1Click:Connect(function()
                    if user.place_id and user.job_id then
                        TeleportService:TeleportToPlaceInstance(user.place_id, user.job_id, LocalPlayer)
                    end
                end)

                local TargetBtn = Instance.new("TextButton")
                TargetBtn.Size = UDim2.new(1, 0, 0, 24)
                TargetBtn.BackgroundColor3 = (SelectedTarget == uName) and Color3.fromRGB(40, 44, 56) or Color3.fromRGB(26, 28, 35)
                TargetBtn.Text = truncate(uName, 16)
                TargetBtn.TextColor3 = Color3.fromRGB(180, 184, 195)
                TargetBtn.Font = Enum.Font.GothamMedium
                TargetBtn.TextSize = 10
                TargetBtn.TextXAlignment = Enum.TextXAlignment.Left
                TargetBtn.Parent = TargetList
                Instance.new("UICorner", TargetBtn).CornerRadius = UDim.new(0, 4)
                Instance.new("UIPadding", TargetBtn).PaddingLeft = UDim.new(0, 6)

                TargetBtn.MouseButton1Click:Connect(function()
                    SelectedTarget = uName
                    SelectedTargetLabel.Text = "TARGET: " .. string.upper(uName)
                    for _, b in ipairs(TargetList:GetChildren()) do
                        if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(26, 28, 35) end
                    end
                    TargetBtn.BackgroundColor3 = Color3.fromRGB(40, 44, 56)
                end)
            end
        end
    end
end

local function populateChat(records, adminGroup)
    for _, child in ipairs(ChatScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    for _, msg in ipairs(records) do
        local Container = Instance.new("Frame")
        Container.Size = UDim2.new(1, 0, 0, 18)
        Container.BackgroundTransparency = 1
        Container.Parent = ChatScroll

        local Content = Instance.new("TextLabel")
        Content.Size = UDim2.new(1, 0, 1, 0)
        Content.BackgroundTransparency = 1
        Content.TextXAlignment = Enum.TextXAlignment.Left
        Content.Font = Enum.Font.Gotham
        Content.TextSize = 11
        Content.RichText = true
        
        local safeName = safeString(msg.username, "Unknown")
        local tagColor = adminGroup[safeName] and "rgb(255, 215, 0)" or "rgb(160, 165, 180)"
        Content.Text = string.format("<font color='%s'>%s</font>: %s", tagColor, truncate(safeName, 14), sanitizeText(msg.message))
        Content.TextColor3 = Color3.fromRGB(215, 218, 225)
        Content.Parent = Container
    end
end

-- DATABASE BACKEND 
local function updatePresence()
    if not running then return end
    
    local res = request({
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
            teleport_target = "none",
            active_effect = "none"
        })
    })

    if res and res.StatusCode > 299 then
        warn("[Network] Sync POST error: HTTP", res.StatusCode, res.Body)
    end
end

local function dispatchCommand(actionType, targetUser)
    if not (IsAdmin or IsSubAdmin) or ADMIN_KEY == "" or targetUser == "none" then return end
    request({
        Url = SUPABASE_URL .. "/rest/v1/remote_commands",
        Method = "POST",
        Headers = {
            ["apikey"] = SUPABASE_KEY,
            ["Authorization"] = "Bearer " .. SUPABASE_KEY,
            ["Content-Type"] = "application/json",
            ["x-admin-key"] = ADMIN_KEY
        },
        Body = HttpService:JSONEncode({
            sender_user_id = UserId,
            target_username = targetUser,
            action = actionType
        })
    })
end

local function transmitMessage(str)
    local filtered = sanitizeText(str)
    if filtered == "" or #filtered > 300 then return end
    request({
        Url = SUPABASE_URL .. "/rest/v1/executor_chat",
        Method = "POST",
        Headers = {
            ["apikey"] = SUPABASE_KEY,
            ["Authorization"] = "Bearer " .. SUPABASE_KEY,
            ["Content-Type"] = "application/json"
        },
        Body = HttpService:JSONEncode({ username = Username, message = filtered })
    })
end

local function fetchNetworkData()
    if not running then return end
    
    -- Added &nocache= to prevent exploit executors from returning a stale, cached GET response
    local syncRes = request({
        Url = SUPABASE_URL .. "/rest/v1/executor_sync?select=user_id,username,executor,is_admin,is_sub_admin,current_game,job_id,place_id,updated_at&order=updated_at.desc&limit=50&nocache=" .. tostring(tick()),
        Method = "GET",
        Headers = { ["apikey"] = SUPABASE_KEY, ["Authorization"] = "Bearer " .. SUPABASE_KEY }
    })

    local adminGroup = {}
    if not syncRes then
        warn("[Network] Sync GET request dropped.")
    elseif syncRes.StatusCode ~= 200 then
        warn("[Network] Sync GET error: HTTP", syncRes.StatusCode, syncRes.Body)
    else
        local success, userlist = pcall(function() return HttpService:JSONDecode(syncRes.Body) end)
        if success and type(userlist) == "table" then
            for _, u in ipairs(userlist) do
                if u.is_admin == true or u.is_sub_admin == true then
                    adminGroup[safeString(u.username, "Unknown")] = true
                end
                if u.user_id == UserId or safeString(u.username, "") == Username then
                    IsAdmin = (u.is_admin == true)
                    IsSubAdmin = (u.is_sub_admin == true)
                    TabPanel.Visible = (IsAdmin or IsSubAdmin) and (ADMIN_KEY ~= "")
                end
            end
            populateUserGrid(userlist)
        else
            warn("[Network] Failed to parse sync JSON array.")
        end
    end

    local cmdRes = request({
        Url = SUPABASE_URL .. "/rest/v1/remote_commands?target_username=in.(" .. Username .. ",all)&order=created_at.desc&limit=8&nocache=" .. tostring(tick()),
        Method = "GET",
        Headers = { ["apikey"] = SUPABASE_KEY, ["Authorization"] = "Bearer " .. SUPABASE_KEY }
    })

    if cmdRes and cmdRes.StatusCode == 200 then
        pcall(function()
            local cmds = HttpService:JSONDecode(cmdRes.Body)
            for _, c in ipairs(cmds) do
                if not handledCommands[c.id] then
                    handledCommands[c.id] = true
                    if c.action == "kill" or c.action == "explode" then
                        runExplosionEffect(Username)
                    elseif c.action == "teleport_to" then
                        for _, p in ipairs(Players:GetPlayers()) do
                            if p.UserId == c.sender_user_id and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                                local myChar = LocalPlayer.Character
                                if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                                    myChar.HumanoidRootPart.CFrame = p.Character.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0)
                                end
                                break
                            end
                        end
                    elseif c.action == "bring" then
                        for _, p in ipairs(Players:GetPlayers()) do
                            if p.UserId == c.sender_user_id then
                                TeleportService:TeleportToPlaceInstance(PlaceId, JobId, LocalPlayer)
                                break
                            end
                        end
                    end
                end
            end
        end)
    end

    local chatRes = request({
        Url = SUPABASE_URL .. "/rest/v1/executor_chat?order=created_at.desc&limit=25&nocache=" .. tostring(tick()),
        Method = "GET",
        Headers = { ["apikey"] = SUPABASE_KEY, ["Authorization"] = "Bearer " .. SUPABASE_KEY }
    })
    
    if chatRes and chatRes.StatusCode == 200 then
        pcall(function()
            local logs = HttpService:JSONDecode(chatRes.Body)
            local ordered = {}
            for i = #logs, 1, -1 do table.insert(ordered, logs[i]) end
            populateChat(ordered, adminGroup)
        end)
    end
end

ChatInput.FocusLost:Connect(function(enterPressed)
    if enterPressed and ChatInput.Text ~= "" then
        local raw = ChatInput.Text
        ChatInput.Text = ""
        task.spawn(function()
            transmitMessage(raw)
            fetchNetworkData()
        end)
    end
end)

BringBtn.MouseButton1Click:Connect(function() dispatchCommand("bring", SelectedTarget) end)
ToMeBtn.MouseButton1Click:Connect(function() dispatchCommand("teleport_to", SelectedTarget) end)
KillBtn.MouseButton1Click:Connect(function() dispatchCommand("kill", SelectedTarget) end)
ExplodeBtn.MouseButton1Click:Connect(function() dispatchCommand("explode", SelectedTarget) end)

local dragToggle, dragStart, startPos
Topbar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragToggle = true
        dragStart = input.Position
        startPos = Root.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragToggle = false end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and dragToggle then
        local delta = input.Position - dragStart
        Root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    MainArea.Visible = not minimized
    Root.Size = minimized and UDim2.new(0, 620, 0, 36) or UDim2.new(0, 620, 0, 390)
end)

CloseBtn.MouseButton1Click:Connect(function()
    running = false
    pcall(function() ScreenGui:Destroy() end)
end)

setTab("users")
updatePresence()
fetchNetworkData()

task.spawn(function()
    while running do
        task.wait(4)
        updatePresence()
        fetchNetworkData()
    end
end)
