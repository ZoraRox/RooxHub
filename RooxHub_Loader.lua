--[[
    ═══════════════════════════════════════════════════════
                    ROOX HUB | LICENSE LOADER
    ═══════════════════════════════════════════════════════
    Alur: UI License -> Validasi (Junkie) -> Animasi Loader -> Script Game
    Theme: Dark Crimson & Obsidian Black Gradient
    Compatibility: Solara, Wave, Synapse Z, Delta, Codex, Hydrogen, Fluxus, etc.
    100% Lua 5.1 & ZeroLua Compatible
--]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 5)

local ROOX_LOGO_ID = "rbxassetid://72595419713638"

--------------------------------------------------------------------------------
-- KONFIGURASI (ISI DI SINI)
--------------------------------------------------------------------------------
local CONFIG = {
    -- Junkie Key System (nilai publik, bukan rahasia)
    SDK_URL = "https://jnkie.com/sdk/library.lua",
    SERVICE = "104136",           -- Service Junkie "RooxHub"
    IDENTIFIER = "1219288",       -- Junkie owner user id
    PROVIDER = "27513",           -- Provider "Get key RooxHub" (24 jam)

    -- Halaman Get Key di website kamu (user diarahkan ke sini)
    GET_KEY_URL = "https://rooxhub.my.id/key",

    -- Script asli (loader game) yang dijalankan setelah key valid.
    SCRIPT_URL = "https://flowauth.net/v1/loaders/2d664646cd0f5af40993c5e407bd3a43.lua",

    KEY_CACHE_FILE = "RooxHub_key.txt"
}

-- Debug: tampilkan pesan error teknis dari Junkie di status UI
local DEBUG = false

--------------------------------------------------------------------------------
-- BOOTSTRAP SDK JUNKIE
--------------------------------------------------------------------------------
local Junkie = nil
local sdkError = nil

task.spawn(function()
    local okFetch, src = pcall(function()
        return game:HttpGet(CONFIG.SDK_URL)
    end)
    if not okFetch or not src or #src == 0 then
        sdkError = "Gagal mengambil SDK validasi"
        return
    end

    local fn, compileErr = loadstring(src)
    if not fn then
        sdkError = "Gagal memuat SDK: " .. tostring(compileErr)
        return
    end

    local okInit, lib = pcall(fn)
    if not okInit or type(lib) ~= "table" then
        sdkError = "SDK validasi tidak valid"
        return
    end

    lib.service = CONFIG.SERVICE
    lib.identifier = CONFIG.IDENTIFIER
    lib.provider = CONFIG.PROVIDER
    Junkie = lib
end)

--------------------------------------------------------------------------------
-- HELPER: CACHE KEY, CLIPBOARD, VALIDASI
--------------------------------------------------------------------------------
local function readCachedKey()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then return nil end
    local okExists, exists = pcall(isfile, CONFIG.KEY_CACHE_FILE)
    if not okExists or not exists then return nil end
    local okRead, data = pcall(readfile, CONFIG.KEY_CACHE_FILE)
    if okRead and type(data) == "string" then
        local key = data:gsub("%s+", "")
        if #key > 0 then return key end
    end
    return nil
end

local function saveCachedKey(key)
    if type(writefile) ~= "function" then return end
    pcall(writefile, CONFIG.KEY_CACHE_FILE, key)
end

local function copyToClipboard(text)
    local copied = false
    if type(setclipboard) == "function" then
        pcall(function() setclipboard(text) copied = true end)
    end
    if not copied and type(toclipboard) == "function" then
        pcall(function() toclipboard(text) copied = true end)
    end
    if not copied and type(writeclipboard) == "function" then
        pcall(function() writeclipboard(text) copied = true end)
    end
    return copied
end

-- Terjemahkan hasil Junkie.check_key menjadi pesan ramah pengguna.
local function describeCheckError(errCode)
    local map = {
        KEY_INVALID = "Key tidak valid. Periksa kembali key kamu.",
        KEY_EXPIRED = "Key sudah kadaluarsa. Ambil key baru.",
        KEY_INVALIDATED = "Key dinonaktifkan. Hubungi admin.",
        ALREADY_USED = "Key sekali pakai sudah terpakai.",
        HWID_MISMATCH = "Key terikat ke device lain.",
        HWID_BANNED = "Device kamu diblokir.",
        SERVICE_MISMATCH = "Key bukan untuk layanan ini.",
        SERVICE_NOT_FOUND = "Layanan tidak ditemukan.",
        PREMIUM_REQUIRED = "Key premium diperlukan."
    }
    return map[tostring(errCode)] or ("Key ditolak: " .. tostring(errCode))
end

-- Panggil Junkie.check_key dengan pcall (dua lapis: exception + hasil).
local function checkKey(key)
    if not Junkie then return false, sdkError or "SDK belum siap" end
    if type(Junkie.check_key) ~= "function" then return false, "SDK tidak mendukung check_key" end

    local ok, result = pcall(Junkie.check_key, key)
    if not ok then
        return false, "Gagal menghubungi server validasi. Coba lagi."
    end
    if type(result) ~= "table" then
        return false, "Respons validasi tidak valid."
    end
    if result.valid then
        return true, "OK"
    end
    return false, describeCheckError(result.error)
end

-- Retry hanya untuk error transien (bukan key invalid/rejected).
local function validateKey(key)
    if not Junkie then return false, sdkError or "SDK belum siap" end

    local lastMessage = "Gagal validasi"
    for attempt = 1, 3 do
        local ok, message = checkKey(key)
        if ok then return true, "OK" end
        lastMessage = message
        -- Error definitif tidak perlu diulang.
        if message:find("Key tidak valid")
            or message:find("kadaluarsa")
            or message:find("ditolak")
            or message:find("diblokir")
            or message:find("terikat")
            or message:find("sekali pakai")
            or message:find("bukan untuk")
            or message:find("dinonaktifkan")
            or message:find("premium") then
            return false, message
        end
        task.wait(attempt * 2)
    end
    return false, lastMessage
end

-- Ambil parent GUI yang aman (gethui, CoreGui, atau PlayerGui)
local function getSafeGuiParent()
    if gethui then
        local okHui, hui = pcall(gethui)
        if okHui and hui then return hui end
    end
    local success, core = pcall(function() return CoreGui end)
    if success and core then return core end
    return PlayerGui
end

-- Bersihkan loader lama jika ada
local oldLoader = getSafeGuiParent():FindFirstChild("RooxHub_LoaderGui")
if oldLoader then
    pcall(function() oldLoader:Destroy() end)
end

--------------------------------------------------------------------------------
-- PEMBUATAN UI (DARK & RED CRIMSON ELEGAN)
--------------------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RooxHub_LoaderGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function()
    if syn and syn.protect_gui then
        syn.protect_gui(ScreenGui)
    end
end)
ScreenGui.Parent = getSafeGuiParent()

-- Main Container Card
local MainCard = Instance.new("Frame")
MainCard.Name = "MainCard"
MainCard.Size = UDim2.new(0, 420, 0, 250)
MainCard.Position = UDim2.new(0.5, 0, 0.5, 30)
MainCard.AnchorPoint = Vector2.new(0.5, 0.5)
MainCard.BackgroundColor3 = Color3.fromRGB(12, 10, 14)
MainCard.BackgroundTransparency = 1
MainCard.BorderSizePixel = 0
MainCard.ClipsDescendants = true
MainCard.Parent = ScreenGui

local CardCorner = Instance.new("UICorner")
CardCorner.CornerRadius = UDim.new(0, 16)
CardCorner.Parent = MainCard

local CardGradient = Instance.new("UIGradient")
CardGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.0, Color3.fromRGB(10, 8, 12)),
    ColorSequenceKeypoint.new(0.45, Color3.fromRGB(26, 8, 14)),
    ColorSequenceKeypoint.new(1.0, Color3.fromRGB(68, 10, 22))
})
CardGradient.Rotation = 135
CardGradient.Parent = MainCard

local CardStroke = Instance.new("UIStroke")
CardStroke.Name = "CardStroke"
CardStroke.Thickness = 1.5
CardStroke.Color = Color3.fromRGB(140, 25, 40)
CardStroke.Transparency = 1
CardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
CardStroke.Parent = MainCard

local StrokeGradient = Instance.new("UIGradient")
StrokeGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.0, Color3.fromRGB(220, 35, 55)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 15, 25)),
    ColorSequenceKeypoint.new(1.0, Color3.fromRGB(220, 35, 55))
})
StrokeGradient.Rotation = 45
StrokeGradient.Parent = CardStroke

local GlowBar = Instance.new("Frame")
GlowBar.Name = "GlowBar"
GlowBar.Size = UDim2.new(1, 0, 0, 3)
GlowBar.Position = UDim2.new(0, 0, 0, 0)
GlowBar.BackgroundColor3 = Color3.fromRGB(215, 30, 50)
GlowBar.BorderSizePixel = 0
GlowBar.Parent = MainCard

local GlowGradient = Instance.new("UIGradient")
GlowGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.0, Color3.fromRGB(10, 8, 12)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(240, 40, 65)),
    ColorSequenceKeypoint.new(1.0, Color3.fromRGB(10, 8, 12))
})
GlowGradient.Parent = GlowBar

-- Header
local HeaderFrame = Instance.new("Frame")
HeaderFrame.Name = "HeaderFrame"
HeaderFrame.Size = UDim2.new(1, -40, 0, 52)
HeaderFrame.Position = UDim2.new(0, 20, 0, 20)
HeaderFrame.BackgroundTransparency = 1
HeaderFrame.Parent = MainCard

local LogoBox = Instance.new("Frame")
LogoBox.Name = "LogoBox"
LogoBox.Size = UDim2.new(0, 46, 0, 46)
LogoBox.Position = UDim2.new(0, 0, 0, 3)
LogoBox.BackgroundColor3 = Color3.fromRGB(22, 12, 16)
LogoBox.BorderSizePixel = 0
LogoBox.Parent = HeaderFrame

local LogoBoxCorner = Instance.new("UICorner")
LogoBoxCorner.CornerRadius = UDim.new(0, 12)
LogoBoxCorner.Parent = LogoBox

local LogoBoxStroke = Instance.new("UIStroke")
LogoBoxStroke.Thickness = 1.2
LogoBoxStroke.Color = Color3.fromRGB(180, 25, 45)
LogoBoxStroke.Parent = LogoBox

local LogoText = Instance.new("TextLabel")
LogoText.Name = "LogoText"
LogoText.Size = UDim2.new(1, 0, 1, 0)
LogoText.BackgroundTransparency = 1
LogoText.Font = Enum.Font.GothamBold
LogoText.Text = "RH"
LogoText.TextSize = 20
LogoText.TextColor3 = Color3.fromRGB(255, 245, 245)
LogoText.Parent = LogoBox

local LogoGradient = Instance.new("UIGradient")
LogoGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 240, 240)),
    ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255, 75, 95))
})
LogoGradient.Rotation = 45
LogoGradient.Parent = LogoText

pcall(function()
    local img = Instance.new("ImageLabel")
    img.Name = "LogoImage"
    img.Size = UDim2.new(1, -8, 1, -8)
    img.Position = UDim2.new(0, 4, 0, 4)
    img.BackgroundTransparency = 1
    img.Image = ROOX_LOGO_ID
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = img
    img.Parent = LogoBox
    LogoText.Visible = false
end)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "TitleLabel"
TitleLabel.Size = UDim2.new(0, 200, 0, 24)
TitleLabel.Position = UDim2.new(0, 56, 0, 4)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "ROOX HUB"
TitleLabel.TextSize = 20
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = HeaderFrame

local SubtitleLabel = Instance.new("TextLabel")
SubtitleLabel.Name = "SubtitleLabel"
SubtitleLabel.Size = UDim2.new(0, 200, 0, 18)
SubtitleLabel.Position = UDim2.new(0, 56, 0, 26)
SubtitleLabel.BackgroundTransparency = 1
SubtitleLabel.Font = Enum.Font.GothamMedium
SubtitleLabel.Text = "Premium Suite • License System"
SubtitleLabel.TextSize = 12
SubtitleLabel.TextColor3 = Color3.fromRGB(220, 160, 170)
SubtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
SubtitleLabel.Parent = HeaderFrame

-- User Badge
local UserBadge = Instance.new("Frame")
UserBadge.Name = "UserBadge"
UserBadge.Size = UDim2.new(0, 120, 0, 32)
UserBadge.Position = UDim2.new(1, -120, 0, 10)
UserBadge.BackgroundColor3 = Color3.fromRGB(20, 10, 14)
UserBadge.BackgroundTransparency = 0.3
UserBadge.BorderSizePixel = 0
UserBadge.Parent = HeaderFrame

local UserBadgeCorner = Instance.new("UICorner")
UserBadgeCorner.CornerRadius = UDim.new(0, 8)
UserBadgeCorner.Parent = UserBadge

local UserBadgeStroke = Instance.new("UIStroke")
UserBadgeStroke.Thickness = 1
UserBadgeStroke.Color = Color3.fromRGB(90, 18, 28)
UserBadgeStroke.Parent = UserBadge

local AvatarImg = Instance.new("ImageLabel")
AvatarImg.Name = "AvatarImg"
AvatarImg.Size = UDim2.new(0, 24, 0, 24)
AvatarImg.Position = UDim2.new(0, 4, 0, 4)
AvatarImg.BackgroundColor3 = Color3.fromRGB(30, 12, 16)
AvatarImg.BorderSizePixel = 0
AvatarImg.Image = "rbxassetid://0"
AvatarImg.Parent = UserBadge

local AvatarCorner = Instance.new("UICorner")
AvatarCorner.CornerRadius = UDim.new(0, 6)
AvatarCorner.Parent = AvatarImg

task.spawn(function()
    local ok, thumb, isReady = pcall(function()
        return Players:GetUserThumbnailAsync(
            LocalPlayer.UserId,
            Enum.ThumbnailType.HeadShot,
            Enum.ThumbnailSize.Size48x48
        )
    end)
    if ok and isReady and thumb and AvatarImg and AvatarImg.Parent then
        AvatarImg.Image = thumb
    end
end)

local UserNameLabel = Instance.new("TextLabel")
UserNameLabel.Name = "UserNameLabel"
UserNameLabel.Size = UDim2.new(1, -34, 1, 0)
UserNameLabel.Position = UDim2.new(0, 32, 0, 0)
UserNameLabel.BackgroundTransparency = 1
UserNameLabel.Font = Enum.Font.GothamBold
UserNameLabel.Text = LocalPlayer.DisplayName or LocalPlayer.Name
UserNameLabel.TextSize = 11
UserNameLabel.TextColor3 = Color3.fromRGB(240, 235, 238)
UserNameLabel.TextXAlignment = Enum.TextXAlignment.Left
UserNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
UserNameLabel.Parent = UserBadge

--------------------------------------------------------------------------------
-- VIEW 1: INPUT LICENSE
--------------------------------------------------------------------------------
local KeyView = Instance.new("Frame")
KeyView.Name = "KeyView"
KeyView.Size = UDim2.new(1, 0, 0, 118)
KeyView.Position = UDim2.new(0, 0, 0, 84)
KeyView.BackgroundTransparency = 1
KeyView.Parent = MainCard

local KeyLabel = Instance.new("TextLabel")
KeyLabel.Name = "KeyLabel"
KeyLabel.Size = UDim2.new(1, -40, 0, 16)
KeyLabel.Position = UDim2.new(0, 20, 0, 0)
KeyLabel.BackgroundTransparency = 1
KeyLabel.Font = Enum.Font.GothamMedium
KeyLabel.Text = "Masukkan License Key"
KeyLabel.TextSize = 12
KeyLabel.TextColor3 = Color3.fromRGB(220, 170, 180)
KeyLabel.TextXAlignment = Enum.TextXAlignment.Left
KeyLabel.Parent = KeyView

local KeyBox = Instance.new("TextBox")
KeyBox.Name = "KeyBox"
KeyBox.Size = UDim2.new(1, -40, 0, 34)
KeyBox.Position = UDim2.new(0, 20, 0, 20)
KeyBox.BackgroundColor3 = Color3.fromRGB(20, 12, 16)
KeyBox.BorderSizePixel = 0
KeyBox.Font = Enum.Font.GothamMedium
KeyBox.PlaceholderText = "Tempel key di sini..."
KeyBox.PlaceholderColor3 = Color3.fromRGB(150, 110, 120)
KeyBox.Text = ""
KeyBox.TextSize = 13
KeyBox.TextColor3 = Color3.fromRGB(245, 235, 240)
KeyBox.TextXAlignment = Enum.TextXAlignment.Left
KeyBox.ClearTextOnFocus = false
KeyBox.Parent = KeyView

local KeyBoxCorner = Instance.new("UICorner")
KeyBoxCorner.CornerRadius = UDim.new(0, 8)
KeyBoxCorner.Parent = KeyBox

local KeyBoxStroke = Instance.new("UIStroke")
KeyBoxStroke.Thickness = 1
KeyBoxStroke.Color = Color3.fromRGB(90, 18, 28)
KeyBoxStroke.Parent = KeyBox

local KeyBoxPad = Instance.new("UIPadding")
KeyBoxPad.PaddingLeft = UDim.new(0, 10)
KeyBoxPad.PaddingRight = UDim.new(0, 10)
KeyBoxPad.Parent = KeyBox

local function makeButton(name, text, pos, primary)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(0, 180, 0, 34)
    btn.Position = pos
    btn.BackgroundColor3 = primary and Color3.fromRGB(160, 20, 35) or Color3.fromRGB(24, 14, 18)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold
    btn.Text = text
    btn.TextSize = 13
    btn.TextColor3 = Color3.fromRGB(255, 245, 245)
    btn.AutoButtonColor = true
    btn.Parent = KeyView
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Color = primary and Color3.fromRGB(220, 35, 55) or Color3.fromRGB(90, 18, 28)
    stroke.Parent = btn
    return btn
end

local GetKeyBtn = makeButton("GetKeyBtn", "Get Key", UDim2.new(0, 20, 0, 64), false)
local ConfirmBtn = makeButton("ConfirmBtn", "Confirm", UDim2.new(0, 220, 0, 64), true)

local KeyStatus = Instance.new("TextLabel")
KeyStatus.Name = "KeyStatus"
KeyStatus.Size = UDim2.new(1, -40, 0, 16)
KeyStatus.Position = UDim2.new(0, 20, 0, 102)
KeyStatus.BackgroundTransparency = 1
KeyStatus.Font = Enum.Font.GothamMedium
KeyStatus.Text = "Masukkan key lalu tekan Confirm."
KeyStatus.TextSize = 12
KeyStatus.TextColor3 = Color3.fromRGB(220, 170, 180)
KeyStatus.TextXAlignment = Enum.TextXAlignment.Left
KeyStatus.TextTruncate = Enum.TextTruncate.AtEnd
KeyStatus.Parent = KeyView

--------------------------------------------------------------------------------
-- VIEW 2: PROGRESS / ANIMASI LOADER
--------------------------------------------------------------------------------
local ProgressView = Instance.new("Frame")
ProgressView.Name = "ProgressView"
ProgressView.Size = UDim2.new(1, 0, 0, 60)
ProgressView.Position = UDim2.new(0, 0, 0, 90)
ProgressView.BackgroundTransparency = 1
ProgressView.Visible = false
ProgressView.Parent = MainCard

local StatusDot = Instance.new("Frame")
StatusDot.Name = "StatusDot"
StatusDot.Size = UDim2.new(0, 8, 0, 8)
StatusDot.Position = UDim2.new(0, 20, 0, 8)
StatusDot.BackgroundColor3 = Color3.fromRGB(220, 35, 55)
StatusDot.BorderSizePixel = 0
StatusDot.Parent = ProgressView

local DotCorner = Instance.new("UICorner")
DotCorner.CornerRadius = UDim.new(1, 0)
DotCorner.Parent = StatusDot

local StatusText = Instance.new("TextLabel")
StatusText.Name = "StatusText"
StatusText.Size = UDim2.new(1, -110, 0, 20)
StatusText.Position = UDim2.new(0, 36, 0, 2)
StatusText.BackgroundTransparency = 1
StatusText.Font = Enum.Font.GothamMedium
StatusText.Text = "Menyiapkan..."
StatusText.TextSize = 13
StatusText.TextColor3 = Color3.fromRGB(245, 235, 240)
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.TextTruncate = Enum.TextTruncate.AtEnd
StatusText.Parent = ProgressView

local PercentText = Instance.new("TextLabel")
PercentText.Name = "PercentText"
PercentText.Size = UDim2.new(0, 70, 0, 20)
PercentText.Position = UDim2.new(1, -90, 0, 2)
PercentText.BackgroundTransparency = 1
PercentText.Font = Enum.Font.GothamBold
PercentText.Text = "0%"
PercentText.TextSize = 13
PercentText.TextColor3 = Color3.fromRGB(255, 75, 95)
PercentText.TextXAlignment = Enum.TextXAlignment.Right
PercentText.Parent = ProgressView

local ProgressTrack = Instance.new("Frame")
ProgressTrack.Name = "ProgressTrack"
ProgressTrack.Size = UDim2.new(1, -40, 0, 8)
ProgressTrack.Position = UDim2.new(0, 20, 0, 34)
ProgressTrack.BackgroundColor3 = Color3.fromRGB(20, 12, 16)
ProgressTrack.BorderSizePixel = 0
ProgressTrack.Parent = ProgressView

local TrackCorner = Instance.new("UICorner")
TrackCorner.CornerRadius = UDim.new(0, 4)
TrackCorner.Parent = ProgressTrack

local TrackStroke = Instance.new("UIStroke")
TrackStroke.Thickness = 1
TrackStroke.Color = Color3.fromRGB(80, 15, 25)
TrackStroke.Parent = ProgressTrack

local ProgressFill = Instance.new("Frame")
ProgressFill.Name = "ProgressFill"
ProgressFill.Size = UDim2.new(0, 0, 1, 0)
ProgressFill.Position = UDim2.new(0, 0, 0, 0)
ProgressFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ProgressFill.BorderSizePixel = 0
ProgressFill.Parent = ProgressTrack

local FillCorner = Instance.new("UICorner")
FillCorner.CornerRadius = UDim.new(0, 4)
FillCorner.Parent = ProgressFill

local FillGradient = Instance.new("UIGradient")
FillGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.0, Color3.fromRGB(160, 20, 35)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(230, 35, 60)),
    ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255, 80, 105))
})
FillGradient.Parent = ProgressFill

-- Footer (selalu tampil)
local FooterText = Instance.new("TextLabel")
FooterText.Name = "FooterText"
FooterText.Size = UDim2.new(1, -40, 0, 16)
FooterText.Position = UDim2.new(0, 20, 0, 222)
FooterText.BackgroundTransparency = 1
FooterText.Font = Enum.Font.GothamMedium
FooterText.Text = "Status: Premium Access • Anti-Detection Shield Active"
FooterText.TextSize = 11
FooterText.TextColor3 = Color3.fromRGB(170, 120, 130)
FooterText.TextXAlignment = Enum.TextXAlignment.Center
FooterText.Parent = MainCard

--------------------------------------------------------------------------------
-- LOGIKA UI & ANIMASI
--------------------------------------------------------------------------------
local dotTween = TweenService:Create(
    StatusDot,
    TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    { BackgroundColor3 = Color3.fromRGB(255, 80, 100) }
)
dotTween:Play()

local function setKeyStatus(text, color)
    KeyStatus.Text = text
    KeyStatus.TextColor3 = color or Color3.fromRGB(220, 170, 180)
end

local function showKeyView()
    KeyView.Visible = true
    ProgressView.Visible = false
end

local function showProgressView()
    KeyView.Visible = false
    ProgressView.Visible = true
end

local function tweenProgress(pct, delay)
    local fillTween = TweenService:Create(ProgressFill, TweenInfo.new(delay, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(pct, 0, 1, 0)
    })
    fillTween:Play()

    local targetPercent = math.floor(pct * 100)
    local rawNum = PercentText.Text:match("%d+")
    local startPercent = tonumber(rawNum) or 0
    local frames = 10
    for f = 1, frames do
        local cur = math.floor(startPercent + (targetPercent - startPercent) * (f / frames))
        PercentText.Text = tostring(cur) .. "%"
        task.wait(delay / frames)
    end
    PercentText.Text = tostring(targetPercent) .. "%"
end

-- Animasi masuk
MainCard.Position = UDim2.new(0.5, 0, 0.5, 25)
MainCard.BackgroundTransparency = 1
CardStroke.Transparency = 1

local enterTween = TweenService:Create(MainCard, TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
    Position = UDim2.new(0.5, 0, 0.5, 0),
    BackgroundTransparency = 0
})
local strokeTween = TweenService:Create(CardStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
    Transparency = 0
})
enterTween:Play()
strokeTween:Play()

--------------------------------------------------------------------------------
-- SEKUENS LOADING + PREFETCH SCRIPT GAME + EKSEKUSI
--------------------------------------------------------------------------------
local function runLoadingSequence()
    -- Prefetch script game paralel dengan animasi
    local prefetch = { code = nil, done = false, error = nil }
    task.spawn(function()
        local ok, code = pcall(function()
            return game:HttpGet(CONFIG.SCRIPT_URL)
        end)
        if ok and code and #code > 0 then
            prefetch.code = code
        else
            prefetch.error = "Gagal memuat script game"
        end
        prefetch.done = true
    end)

    local loadingSteps = {
        { pct = 0.20, text = "Menginisialisasi dependensi library...", delay = 0.4 },
        { pct = 0.45, text = "Menghubungi server...", delay = 0.5 },
        { pct = 0.70, text = "Mengunduh modul pendukung...", delay = 0.6 },
        { pct = 0.90, text = "Memvalidasi lisensi sistem...", delay = 0.5 },
    }
    for i = 1, #loadingSteps do
        local step = loadingSteps[i]
        StatusText.Text = step.text
        tweenProgress(step.pct, step.delay)
    end

    StatusText.Text = "Menyiapkan RooxHub..."
    local deadline = os.clock() + 20
    while not prefetch.done and os.clock() < deadline do
        task.wait(0.1)
    end

    if not prefetch.code then
        StatusText.Text = prefetch.error or "Gagal memuat script game."
        StatusText.TextColor3 = Color3.fromRGB(255, 80, 80)
        PercentText.Text = "ERR"
        PercentText.TextColor3 = Color3.fromRGB(255, 80, 80)
        task.wait(3)
        pcall(function() ScreenGui:Destroy() end)
        return
    end

    StatusText.Text = "Memuat RooxHub..."
    task.wait(0.4)
    tweenProgress(1, 0.3)
    task.wait(0.4)

    StatusText.Text = "Selamat Datang, " .. (LocalPlayer.DisplayName or LocalPlayer.Name) .. "!"
    StatusText.TextColor3 = Color3.fromRGB(0, 255, 160)
    PercentText.TextColor3 = Color3.fromRGB(0, 255, 160)
    task.wait(0.6)

    -- Animasi keluar
    local exitTween = TweenService:Create(MainCard, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
        Position = UDim2.new(0.5, 0, 0.5, -30),
        BackgroundTransparency = 1
    })
    local exitStroke = TweenService:Create(CardStroke, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
        Transparency = 1
    })
    exitTween:Play()
    exitStroke:Play()
    task.wait(0.5)
    pcall(function() ScreenGui:Destroy() end)

    -- Jalankan script game
    local fn, compileErr = loadstring(prefetch.code)
    if fn then
        local okRun, runErr = pcall(fn)
        if not okRun then
            warn("[RooxHub] Script game error: " .. tostring(runErr))
        end
    else
        warn("[RooxHub] Gagal compile script game: " .. tostring(compileErr))
    end
end

--------------------------------------------------------------------------------
-- HANDLER: GET KEY / CONFIRM / AUTO-LOGIN
--------------------------------------------------------------------------------
GetKeyBtn.MouseButton1Click:Connect(function()
    local copied = copyToClipboard(CONFIG.GET_KEY_URL)
    if copied then
        setKeyStatus("Link Get Key disalin: " .. CONFIG.GET_KEY_URL, Color3.fromRGB(0, 255, 160))
    else
        setKeyStatus("Get Key: " .. CONFIG.GET_KEY_URL, Color3.fromRGB(255, 200, 120))
    end
end)

local validating = false
ConfirmBtn.MouseButton1Click:Connect(function()
    if validating then return end

    local key = KeyBox.Text or ""
    key = key:gsub("%s+", "")
    if #key == 0 then
        setKeyStatus("Masukkan key terlebih dahulu.", Color3.fromRGB(255, 120, 120))
        return
    end
    if not Junkie then
        setKeyStatus(sdkError or "Menyiapkan sistem validasi...", Color3.fromRGB(255, 200, 120))
        return
    end

    validating = true
    ConfirmBtn.Text = "Memeriksa..."
    setKeyStatus("Memvalidasi key...", Color3.fromRGB(255, 200, 120))

    task.spawn(function()
        local okValid, message = validateKey(key)
        if okValid then
            saveCachedKey(key)
            setKeyStatus("Key valid!", Color3.fromRGB(0, 255, 160))
            task.wait(0.3)
            showProgressView()
            runLoadingSequence()
        else
            validating = false
            ConfirmBtn.Text = "Confirm"
            if DEBUG then
                setKeyStatus(message, Color3.fromRGB(255, 120, 120))
            else
                setKeyStatus(message or "Key tidak valid.", Color3.fromRGB(255, 120, 120))
            end
        end
    end)
end)

-- Auto-login: pakai key tersimpan bila valid
task.spawn(function()
    local cached = readCachedKey()
    if not cached then return end

    local deadline = os.clock() + 20
    while not Junkie and not sdkError and os.clock() < deadline do
        task.wait(0.1)
    end
    if not Junkie then return end

    local okValid = validateKey(cached)
    if okValid then
        showProgressView()
        runLoadingSequence()
    end
end)
