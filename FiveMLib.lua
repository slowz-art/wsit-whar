--[[
    FiveMLib - FiveM Style UI Library
    Linoria / 1up API Compatible
    
    Visual style matching the FiveM menu (dark cards, blue accents, left icon sidebar)
    
    API:
        Library:CreateWindow → Window:AddTab → Tab:AddLeftGroupbox / AddRightGroupbox
        Groupbox:AddToggle / AddSlider / AddDropdown / AddButton / AddInput / AddKeybind / AddLabel / AddDivider
    
    Usage example at bottom of file.
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local TextService = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local Library = {
    Flags = {},
    Toggles = {},
    Options = {},
    Labels = {},
    Buttons = {},
    Connections = {},
    ThemeMap = {},
    ThemeItems = {},
    OpenFrames = {},
    UnnamedFlags = 0,
    UnnamedConnections = 0,
    Holder = nil,
    NotifHolder = nil,
    Font = Enum.Font.Gotham,
    MenuKeybind = Enum.KeyCode.RightControl,
    Tween = {
        Time = 0.2,
        Style = Enum.EasingStyle.Quad,
        Direction = Enum.EasingDirection.Out
    },
    FadeSpeed = 0.15,
}

Library.__index = Library

-------------------------------------------------
-- THEME (FiveM style)
-------------------------------------------------
local Theme = {
    Background          = Color3.fromRGB(18, 18, 22),
    Background2         = Color3.fromRGB(14, 14, 18),
    Sidebar             = Color3.fromRGB(12, 12, 16),
    Card                = Color3.fromRGB(28, 28, 34),
    CardHover           = Color3.fromRGB(34, 34, 42),
    Element             = Color3.fromRGB(35, 35, 42),
    ElementHover        = Color3.fromRGB(45, 45, 55),
    Accent              = Color3.fromRGB(0, 140, 255),
    AccentDark          = Color3.fromRGB(0, 100, 200),
    AccentGradient      = Color3.fromRGB(0, 180, 255),
    Text                = Color3.fromRGB(240, 240, 245),
    TextDark            = Color3.fromRGB(160, 160, 175),
    TextMuted           = Color3.fromRGB(120, 120, 135),
    Stroke              = Color3.fromRGB(45, 45, 55),
    StrokeLight         = Color3.fromRGB(60, 60, 70),
    ToggleOff           = Color3.fromRGB(55, 55, 65),
    ToggleOn            = Color3.fromRGB(0, 140, 255),
    Success             = Color3.fromRGB(80, 200, 120),
    Warning             = Color3.fromRGB(255, 180, 50),
    Error               = Color3.fromRGB(255, 80, 80),
    ScrollBar           = Color3.fromRGB(0, 140, 255),
}

Library.Theme = Theme

-------------------------------------------------
-- UTILITY
-------------------------------------------------
local function FromRGB(r, g, b)
    return Color3.fromRGB(r, g, b)
end

local function Create(className, properties)
    local instance = Instance.new(className)
    for property, value in pairs(properties or {}) do
        if property ~= "Parent" then
            pcall(function()
                instance[property] = value
            end)
        end
    end
    if properties and properties.Parent then
        instance.Parent = properties.Parent
    end
    return instance
end

local function Corner(parent, radius)
    local c = Create("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
        Parent = parent
    })
    return c
end

local function Stroke(parent, color, thickness, transparency)
    local s = Create("UIStroke", {
        Color = color or Theme.Stroke,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent
    })
    return s
end

local function Padding(parent, top, bottom, left, right)
    return Create("UIPadding", {
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or 0),
        Parent = parent
    })
end

local function ListLayout(parent, padding, direction, horizontalAlign, verticalAlign)
    return Create("UIListLayout", {
        Padding = UDim.new(0, padding or 6),
        FillDirection = direction or Enum.FillDirection.Vertical,
        HorizontalAlignment = horizontalAlign or Enum.HorizontalAlignment.Left,
        VerticalAlignment = verticalAlign or Enum.VerticalAlignment.Top,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = parent
    })
end

local function Tween(instance, properties, duration, style, direction)
    local info = TweenInfo.new(
        duration or Library.Tween.Time,
        style or Library.Tween.Style,
        direction or Library.Tween.Direction
    )
    local tw = TweenService:Create(instance, info, properties)
    tw:Play()
    return tw
end

local function MakeDraggable(frame, handle)
    handle = handle or frame
    local dragging = false
    local dragStart = nil
    local startPos = nil

    local function update(input)
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
end

local function GetTextSize(text, size, font, absoluteSize)
    return TextService:GetTextSize(text, size, font or Enum.Font.Gotham, absoluteSize or Vector2.new(1000, 1000))
end

local function Round(num, decimalPlaces)
    local mult = 10 ^ (decimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

local function Clamp(value, min, max)
    return math.clamp(value, min, max)
end

-------------------------------------------------
-- CONNECTION HELPER
-------------------------------------------------
function Library:Connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(self.Connections, connection)
    return connection
end

function Library:AddConnection(connection)
    table.insert(self.Connections, connection)
    return connection
end

function Library:DisconnectAll()
    for _, connection in ipairs(self.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    self.Connections = {}
end

-------------------------------------------------
-- FLAG SYSTEM
-------------------------------------------------
function Library:SetFlag(flag, value)
    self.Flags[flag] = value
end

function Library:GetFlag(flag)
    return self.Flags[flag]
end

-------------------------------------------------
-- NOTIFICATIONS
-------------------------------------------------
function Library:Notify(cfg)
    cfg = cfg or {}
    local title = cfg.Title or "Notification"
    local content = cfg.Content or cfg.Text or ""
    local duration = cfg.Duration or 4
    local type_ = cfg.Type or "Info" -- Info, Success, Warning, Error

    if not self.NotifHolder then
        self.NotifHolder = Create("Frame", {
            Name = "NotificationHolder",
            Size = UDim2.new(0, 320, 1, -40),
            Position = UDim2.new(1, -340, 0, 20),
            BackgroundTransparency = 1,
            Parent = self.Holder or ((gethui and gethui()) or CoreGui)
        })
        ListLayout(self.NotifHolder, 8, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Top)
    end

    local accentColor = Theme.Accent
    if type_ == "Success" then accentColor = Theme.Success
    elseif type_ == "Warning" then accentColor = Theme.Warning
    elseif type_ == "Error" then accentColor = Theme.Error end

    local notif = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        Parent = self.NotifHolder
    })
    Corner(notif, 10)
    Stroke(notif)

    local accentBar = Create("Frame", {
        Size = UDim2.new(0, 4, 1, 0),
        BackgroundColor3 = accentColor,
        BorderSizePixel = 0,
        Parent = notif
    })
    Corner(accentBar, 2)

    local titleLabel = Create("TextLabel", {
        Size = UDim2.new(1, -24, 0, 22),
        Position = UDim2.new(0, 16, 0, 10),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.Text,
        TextSize = 14,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = notif
    })

    local contentLabel = Create("TextLabel", {
        Size = UDim2.new(1, -24, 0, 0),
        Position = UDim2.new(0, 16, 0, 32),
        BackgroundTransparency = 1,
        Text = content,
        TextColor3 = Theme.TextDark,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = notif
    })

    Padding(notif, 0, 12, 0, 0)

    notif.BackgroundTransparency = 1
    titleLabel.TextTransparency = 1
    contentLabel.TextTransparency = 1

    Tween(notif, {BackgroundTransparency = 0}, 0.25)
    Tween(titleLabel, {TextTransparency = 0}, 0.25)
    Tween(contentLabel, {TextTransparency = 0}, 0.25)

    task.delay(duration, function()
        Tween(notif, {BackgroundTransparency = 1}, 0.3)
        Tween(titleLabel, {TextTransparency = 1}, 0.3)
        Tween(contentLabel, {TextTransparency = 1}, 0.3)
        task.wait(0.35)
        notif:Destroy()
    end)
end

-------------------------------------------------
-- WATERMARK
-------------------------------------------------
function Library:SetWatermark(text)
    if self.Watermark then
        self.Watermark.Text = text
        return
    end

    local wm = Create("TextLabel", {
        Name = "Watermark",
        Size = UDim2.new(0, 200, 0, 28),
        Position = UDim2.new(0, 20, 0, 20),
        BackgroundColor3 = Theme.Card,
        Text = text or "FiveMLib",
        TextColor3 = Theme.Text,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        Parent = self.Holder or ((gethui and gethui()) or CoreGui)
    })
    Corner(wm, 6)
    Stroke(wm)
    Padding(wm, 0, 0, 12, 12)
    self.Watermark = wm
end

function Library:SetWatermarkVisibility(visible)
    if self.Watermark then
        self.Watermark.Visible = visible
    end
end

-------------------------------------------------
-- WINDOW
-------------------------------------------------
function Library:CreateWindow(cfg)
    cfg = type(cfg) == "table" and cfg or {}
    local title = cfg.Title or cfg.Name or "World > Local Player"
    local center = cfg.Center ~= false
    local autoShow = cfg.AutoShow ~= false
    local size = cfg.Size or UDim2.new(0, 780, 0, 520)

    -- Main ScreenGui
    local screenGui = Create("ScreenGui", {
        Name = "FiveMLib",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        Parent = (gethui and gethui()) or CoreGui
    })
    self.Holder = screenGui

    -- Main Frame
    local main = Create("Frame", {
        Name = "Main",
        Size = size,
        Position = center and UDim2.new(0.5, -size.X.Offset/2, 0.5, -size.Y.Offset/2) or UDim2.new(0, 100, 0, 100),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Visible = autoShow,
        Parent = screenGui
    })
    Corner(main, 14)
    Stroke(main, Color3.fromRGB(40, 40, 55), 1.5)

    -- Shadow-like outer glow
    local glow = Create("ImageLabel", {
        Name = "Glow",
        Size = UDim2.new(1, 40, 1, 40),
        Position = UDim2.new(0, -20, 0, -20),
        BackgroundTransparency = 1,
        Image = "rbxassetid://5028857084",
        ImageColor3 = Color3.fromRGB(0, 0, 0),
        ImageTransparency = 0.6,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(24, 24, 276, 276),
        ZIndex = 0,
        Parent = main
    })

    -- Sidebar
    local sidebar = Create("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, 62, 1, 0),
        BackgroundColor3 = Theme.Sidebar,
        BorderSizePixel = 0,
        Parent = main
    })
    Corner(sidebar, 14)

    -- Sidebar inner cut for clean look
    local sidebarInner = Create("Frame", {
        Size = UDim2.new(0, 20, 1, 0),
        Position = UDim2.new(1, -10, 0, 0),
        BackgroundColor3 = Theme.Sidebar,
        BorderSizePixel = 0,
        Parent = sidebar
    })

    -- Logo
    local logo = Create("TextLabel", {
        Name = "Logo",
        Size = UDim2.new(1, 0, 0, 56),
        BackgroundTransparency = 1,
        Text = "S",
        TextColor3 = Theme.Text,
        TextSize = 26,
        Font = Enum.Font.GothamBold,
        Parent = sidebar
    })

    -- Accent line under logo
    local logoLine = Create("Frame", {
        Size = UDim2.new(0, 24, 0, 2),
        Position = UDim2.new(0.5, -12, 0, 50),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = sidebar
    })
    Corner(logoLine, 1)

    -- Tab buttons container
    local tabButtonContainer = Create("ScrollingFrame", {
        Name = "TabButtons",
        Size = UDim2.new(1, 0, 1, -120),
        Position = UDim2.new(0, 0, 0, 64),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = sidebar
    })
    ListLayout(tabButtonContainer, 8, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Center)

    -- Top Bar
    local topBar = Create("Frame", {
        Name = "TopBar",
        Size = UDim2.new(1, -62, 0, 50),
        Position = UDim2.new(0, 62, 0, 0),
        BackgroundTransparency = 1,
        Parent = main
    })

    local titleLabel = Create("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, -100, 1, 0),
        Position = UDim2.new(0, 18, 0, 0),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.Text,
        TextSize = 15,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = topBar
    })

    -- Close button
    local closeBtn = Create("TextButton", {
        Name = "Close",
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -42, 0.5, -15),
        BackgroundColor3 = Theme.Element,
        Text = "×",
        TextColor3 = Theme.Text,
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        Parent = topBar
    })
    Corner(closeBtn, 7)
    Stroke(closeBtn)

    closeBtn.MouseEnter:Connect(function()
        Tween(closeBtn, {BackgroundColor3 = Theme.Error}, 0.15)
    end)
    closeBtn.MouseLeave:Connect(function()
        Tween(closeBtn, {BackgroundColor3 = Theme.Element}, 0.15)
    end)

    -- Minimize / settings gear
    local gearBtn = Create("TextButton", {
        Name = "Gear",
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -80, 0.5, -15),
        BackgroundColor3 = Theme.Element,
        Text = "⚙",
        TextColor3 = Theme.TextDark,
        TextSize = 14,
        Font = Enum.Font.Gotham,
        AutoButtonColor = false,
        Parent = topBar
    })
    Corner(gearBtn, 7)
    Stroke(gearBtn)

    -- Content Area
    local contentArea = Create("Frame", {
        Name = "Content",
        Size = UDim2.new(1, -74, 1, -62),
        Position = UDim2.new(0, 68, 0, 54),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = main
    })

    -- Make main draggable from top bar
    MakeDraggable(main, topBar)

    local Window = {
        Tabs = {},
        CurrentTab = nil,
        ScreenGui = screenGui,
        Main = main,
        Sidebar = sidebar,
        TabButtonContainer = tabButtonContainer,
        ContentArea = contentArea,
        TitleLabel = titleLabel,
        Visible = autoShow,
    }

    function Window:SetTitle(newTitle)
        titleLabel.Text = newTitle
    end

    function Window:SetVisible(visible)
        main.Visible = visible
        Window.Visible = visible
    end

    function Window:Toggle()
        Window:SetVisible(not Window.Visible)
    end

    closeBtn.MouseButton1Click:Connect(function()
        Window:SetVisible(false)
    end)

    -- Menu keybind
    Library:Connect(UserInputService.InputBegan, function(input, gpe)
        if gpe then return end
        if input.KeyCode == Library.MenuKeybind then
            Window:Toggle()
        end
    end)

    -------------------------------------------------
    -- ADD TAB
    -------------------------------------------------
    function Window:AddTab(name, iconId)
        name = tostring(name or "Tab")

        local tabButton = Create("TextButton", {
            Name = name,
            Size = UDim2.new(0, 42, 0, 42),
            BackgroundColor3 = Theme.Element,
            Text = "",
            AutoButtonColor = false,
            Parent = tabButtonContainer
        })
        Corner(tabButton, 10)
        Stroke(tabButton)

        local iconLabel = Create("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = iconId and "" or string.sub(name, 1, 1):upper(),
            TextColor3 = Theme.TextDark,
            TextSize = 16,
            Font = Enum.Font.GothamBold,
            Parent = tabButton
        })

        if iconId and typeof(iconId) == "number" then
            local img = Create("ImageLabel", {
                Size = UDim2.new(0, 20, 0, 20),
                Position = UDim2.new(0.5, -10, 0.5, -10),
                BackgroundTransparency = 1,
                Image = "rbxassetid://" .. tostring(iconId),
                ImageColor3 = Theme.TextDark,
                Parent = tabButton
            })
            iconLabel.Visible = false
        end

        local indicator = Create("Frame", {
            Name = "Indicator",
            Size = UDim2.new(0, 3, 0, 16),
            Position = UDim2.new(0, -1, 0.5, -8),
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
            Visible = false,
            Parent = tabButton
        })
        Corner(indicator, 2)

        -- Page
        local page = Create("Frame", {
            Name = name .. "_Page",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Visible = false,
            Parent = contentArea
        })

        -- Left column
        local leftColumn = Create("ScrollingFrame", {
            Name = "Left",
            Size = UDim2.new(0.5, -7, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Accent,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Parent = page
        })
        ListLayout(leftColumn, 12)
        Padding(leftColumn, 4, 12, 2, 6)

        -- Right column
        local rightColumn = Create("ScrollingFrame", {
            Name = "Right",
            Size = UDim2.new(0.5, -7, 1, 0),
            Position = UDim2.new(0.5, 7, 0, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Accent,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Parent = page
        })
        ListLayout(rightColumn, 12)
        Padding(rightColumn, 4, 12, 6, 2)

        local Tab = {
            Name = name,
            Button = tabButton,
            Page = page,
            LeftColumn = leftColumn,
            RightColumn = rightColumn,
            Indicator = indicator,
            IconLabel = iconLabel,
            Groupboxes = {},
        }

        local function SelectTab()
            for _, t in pairs(Window.Tabs) do
                t.Page.Visible = false
                t.Indicator.Visible = false
                Tween(t.Button, {BackgroundColor3 = Theme.Element}, 0.15)
                if t.IconLabel then
                    Tween(t.IconLabel, {TextColor3 = Theme.TextDark}, 0.15)
                end
            end
            page.Visible = true
            indicator.Visible = true
            Tween(tabButton, {BackgroundColor3 = Theme.Accent}, 0.15)
            if iconLabel then
                Tween(iconLabel, {TextColor3 = Color3.fromRGB(255, 255, 255)}, 0.15)
            end
            Window.CurrentTab = Tab
        end

        tabButton.MouseButton1Click:Connect(SelectTab)
        tabButton.MouseEnter:Connect(function()
            if Window.CurrentTab ~= Tab then
                Tween(tabButton, {BackgroundColor3 = Theme.ElementHover}, 0.12)
            end
        end)
        tabButton.MouseLeave:Connect(function()
            if Window.CurrentTab ~= Tab then
                Tween(tabButton, {BackgroundColor3 = Theme.Element}, 0.12)
            end
        end)

        -------------------------------------------------
        -- GROUPBOX CREATION
        -------------------------------------------------
        local function CreateGroupbox(parent, boxName, side)
            boxName = tostring(boxName or "Groupbox")

            local card = Create("Frame", {
                Name = boxName,
                Size = UDim2.new(1, 0, 0, 40),
                BackgroundColor3 = Theme.Card,
                BorderSizePixel = 0,
                AutomaticSize = Enum.AutomaticSize.Y,
                Parent = parent
            })
            Corner(card, 10)
            Stroke(card)

            local header = Create("TextLabel", {
                Name = "Header",
                Size = UDim2.new(1, -20, 0, 30),
                Position = UDim2.new(0, 14, 0, 6),
                BackgroundTransparency = 1,
                Text = boxName,
                TextColor3 = Theme.Text,
                TextSize = 13,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = card
            })

            -- Subtle accent under header
            local headerLine = Create("Frame", {
                Size = UDim2.new(1, -28, 0, 1),
                Position = UDim2.new(0, 14, 0, 34),
                BackgroundColor3 = Theme.Stroke,
                BorderSizePixel = 0,
                Parent = card
            })

            local container = Create("Frame", {
                Name = "Container",
                Size = UDim2.new(1, -16, 0, 0),
                Position = UDim2.new(0, 8, 0, 42),
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,
                Parent = card
            })
            ListLayout(container, 6)
            Padding(container, 0, 12, 4, 4)

            local Groupbox = {
                Name = boxName,
                Card = card,
                Container = container,
                Side = side,
                Elements = {},
            }

            -- Add methods
            function Groupbox:AddToggle(flag, options)
                return Library:_CreateToggle(self, flag, options)
            end

            function Groupbox:AddSlider(flag, options)
                return Library:_CreateSlider(self, flag, options)
            end

            function Groupbox:AddDropdown(flag, options)
                return Library:_CreateDropdown(self, flag, options)
            end

            function Groupbox:AddButton(options)
                return Library:_CreateButton(self, options)
            end

            function Groupbox:AddInput(flag, options)
                return Library:_CreateInput(self, flag, options)
            end

            function Groupbox:AddKeybind(flag, options)
                return Library:_CreateKeybind(self, flag, options)
            end

            function Groupbox:AddLabel(text, doesWrap)
                return Library:_CreateLabel(self, text, doesWrap)
            end

            function Groupbox:AddDivider()
                return Library:_CreateDivider(self)
            end

            function Groupbox:AddBlank(height)
                local blank = Create("Frame", {
                    Size = UDim2.new(1, 0, 0, height or 8),
                    BackgroundTransparency = 1,
                    Parent = self.Container
                })
                return blank
            end

            table.insert(Tab.Groupboxes, Groupbox)
            return Groupbox
        end

        function Tab:AddLeftGroupbox(name)
            return CreateGroupbox(leftColumn, name, "Left")
        end

        function Tab:AddRightGroupbox(name)
            return CreateGroupbox(rightColumn, name, "Right")
        end

        -- Aliases for full Linoria compatibility
        Tab.AddLeftTabbox = function(self, name)
            -- Simplified: just return a left groupbox for now
            return self:AddLeftGroupbox(name or "Tabbox")
        end
        Tab.AddRightTabbox = function(self, name)
            return self:AddRightGroupbox(name or "Tabbox")
        end

        table.insert(Window.Tabs, Tab)

        if #Window.Tabs == 1 then
            SelectTab()
        end

        return Tab
    end

    Library.Window = Window
    return Window
end

-------------------------------------------------
-- TOGGLE
-------------------------------------------------
function Library:_CreateToggle(groupbox, flag, options)
    options = options or {}
    local text = options.Text or options.Name or tostring(flag)
    local default = options.Default or false
    local callback = options.Callback or function() end
    local risky = options.Risky or false

    Library.UnnamedFlags = Library.UnnamedFlags + 1
    flag = flag or ("Toggle_" .. Library.UnnamedFlags)

    local holder = Create("Frame", {
        Name = "Toggle_" .. text,
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        Parent = groupbox.Container
    })

    local label = Create("TextLabel", {
        Size = UDim2.new(1, -48, 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = risky and Theme.Warning or Theme.Text,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = holder
    })

    local toggleTrack = Create("Frame", {
        Size = UDim2.new(0, 36, 0, 18),
        Position = UDim2.new(1, -40, 0.5, -9),
        BackgroundColor3 = default and Theme.ToggleOn or Theme.ToggleOff,
        BorderSizePixel = 0,
        Parent = holder
    })
    Corner(toggleTrack, 9)

    local toggleCircle = Create("Frame", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = default and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        Parent = toggleTrack
    })
    Corner(toggleCircle, 7)

    local state = default
    Library.Flags[flag] = state
    Library.Toggles[flag] = {
        Value = state,
        Type = "Toggle",
    }

    local function Set(value)
        state = not not value
        Library.Flags[flag] = state
        Library.Toggles[flag].Value = state

        Tween(toggleTrack, {
            BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff
        }, 0.15)

        Tween(toggleCircle, {
            Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        }, 0.15)

        pcall(callback, state)
    end

    local hitbox = Create("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        Parent = holder
    })

    hitbox.MouseButton1Click:Connect(function()
        Set(not state)
    end)

    hitbox.MouseEnter:Connect(function()
        Tween(label, {TextColor3 = Theme.Accent}, 0.12)
    end)
    hitbox.MouseLeave:Connect(function()
        Tween(label, {TextColor3 = risky and Theme.Warning or Theme.Text}, 0.12)
    end)

    local toggleObj = {
        Flag = flag,
        Set = Set,
        Get = function() return state end,
        Type = "Toggle",
    }

    Library.Toggles[flag] = toggleObj
    table.insert(groupbox.Elements, toggleObj)
    return toggleObj
end

-------------------------------------------------
-- SLIDER
-------------------------------------------------
function Library:_CreateSlider(groupbox, flag, options)
    options = options or {}
    local text = options.Text or options.Name or tostring(flag)
    local min = options.Min or 0
    local max = options.Max or 100
    local default = options.Default or min
    local rounding = options.Rounding or options.Decimals or 0
    local suffix = options.Suffix or ""
    local callback = options.Callback or function() end

    Library.UnnamedFlags = Library.UnnamedFlags + 1
    flag = flag or ("Slider_" .. Library.UnnamedFlags)

    default = Clamp(default, min, max)

    local holder = Create("Frame", {
        Name = "Slider_" .. text,
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundTransparency = 1,
        Parent = groupbox.Container
    })

    local label = Create("TextLabel", {
        Size = UDim2.new(1, -70, 0, 18),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.Text,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = holder
    })

    local valueLabel = Create("TextLabel", {
        Size = UDim2.new(0, 65, 0, 18),
        Position = UDim2.new(1, -65, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(Round(default, rounding)) .. suffix,
        TextColor3 = Theme.TextDark,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = holder
    })

    local barBackground = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 6),
        Position = UDim2.new(0, 0, 0, 28),
        BackgroundColor3 = Theme.Element,
        BorderSizePixel = 0,
        Parent = holder
    })
    Corner(barBackground, 3)

    local barFill = Create("Frame", {
        Size = UDim2.new((default - min) / math.max(max - min, 0.001), 0, 1, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = barBackground
    })
    Corner(barFill, 3)

    local value = default
    Library.Flags[flag] = value
    Library.Options[flag] = {Value = value, Type = "Slider"}

    local function Set(v)
        v = Clamp(v, min, max)
        v = Round(v, rounding)
        value = v
        Library.Flags[flag] = v
        Library.Options[flag].Value = v
        valueLabel.Text = tostring(v) .. suffix
        local alpha = (v - min) / math.max(max - min, 0.001)
        barFill.Size = UDim2.new(alpha, 0, 1, 0)
        pcall(callback, v)
    end

    local sliding = false

    local function updateFromInput(input)
        local relative = Clamp((input.Position.X - barBackground.AbsolutePosition.X) / barBackground.AbsoluteSize.X, 0, 1)
        Set(min + (max - min) * relative)
    end

    barBackground.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            updateFromInput(input)
        end
    end)

    Library:Connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end)

    Library:Connect(UserInputService.InputChanged, function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromInput(input)
        end
    end)

    local sliderObj = {
        Flag = flag,
        Set = Set,
        Get = function() return value end,
        Type = "Slider",
    }

    Library.Options[flag] = sliderObj
    table.insert(groupbox.Elements, sliderObj)
    return sliderObj
end

-------------------------------------------------
-- DROPDOWN
-------------------------------------------------
function Library:_CreateDropdown(groupbox, flag, options)
    options = options or {}
    local text = options.Text or options.Name or tostring(flag)
    local values = options.Values or options.List or {}
    local default = options.Default or (values[1] or "")
    local multi = options.Multi or false
    local callback = options.Callback or function() end
    local maxVisible = options.MaxVisibleDropdownItems or 6

    Library.UnnamedFlags = Library.UnnamedFlags + 1
    flag = flag or ("Dropdown_" .. Library.UnnamedFlags)

    local holder = Create("Frame", {
        Name = "Dropdown_" .. text,
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundTransparency = 1,
        ClipsDescendants = false,
        Parent = groupbox.Container
    })

    local label = Create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.Text,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = holder
    })

    local dropButton = Create("TextButton", {
        Size = UDim2.new(1, 0, 0, 28),
        Position = UDim2.new(0, 0, 0, 22),
        BackgroundColor3 = Theme.Element,
        Text = "",
        AutoButtonColor = false,
        Parent = holder
    })
    Corner(dropButton, 6)
    Stroke(dropButton)

    local selectedLabel = Create("TextLabel", {
        Size = UDim2.new(1, -30, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(default),
        TextColor3 = Theme.Text,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = dropButton
    })

    local arrow = Create("TextLabel", {
        Size = UDim2.new(0, 20, 1, 0),
        Position = UDim2.new(1, -24, 0, 0),
        BackgroundTransparency = 1,
        Text = "▼",
        TextColor3 = Theme.TextDark,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        Parent = dropButton
    })

    local dropFrame = Create("Frame", {
        Name = "DropFrame",
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 0, 54),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 50,
        Parent = holder
    })
    Corner(dropFrame, 6)
    Stroke(dropFrame)

    local dropScroll = Create("ScrollingFrame", {
        Size = UDim2.new(1, -4, 1, -4),
        Position = UDim2.new(0, 2, 0, 2),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 51,
        Parent = dropFrame
    })
    ListLayout(dropScroll, 2)
    Padding(dropScroll, 4, 4, 4, 4)

    local open = false
    local selected = default
    if multi then
        selected = type(default) == "table" and default or {}
    end

    Library.Flags[flag] = selected
    Library.Options[flag] = {Value = selected, Type = "Dropdown"}

    local function RefreshList()
        for _, child in ipairs(dropScroll:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end

        for _, value in ipairs(values) do
            local optionBtn = Create("TextButton", {
                Size = UDim2.new(1, 0, 0, 26),
                BackgroundColor3 = Theme.Element,
                Text = "",
                AutoButtonColor = false,
                ZIndex = 52,
                Parent = dropScroll
            })
            Corner(optionBtn, 4)

            local optionLabel = Create("TextLabel", {
                Size = UDim2.new(1, -10, 1, 0),
                Position = UDim2.new(0, 8, 0, 0),
                BackgroundTransparency = 1,
                Text = tostring(value),
                TextColor3 = Theme.Text,
                TextSize = 12,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 53,
                Parent = optionBtn
            })

            optionBtn.MouseEnter:Connect(function()
                Tween(optionBtn, {BackgroundColor3 = Theme.ElementHover}, 0.1)
            end)
            optionBtn.MouseLeave:Connect(function()
                Tween(optionBtn, {BackgroundColor3 = Theme.Element}, 0.1)
            end)

            optionBtn.MouseButton1Click:Connect(function()
                if multi then
                    local idx = table.find(selected, value)
                    if idx then
                        table.remove(selected, idx)
                    else
                        table.insert(selected, value)
                    end
                    selectedLabel.Text = #selected > 0 and table.concat(selected, ", ") or "None"
                else
                    selected = value
                    selectedLabel.Text = tostring(value)
                    open = false
                    dropFrame.Visible = false
                    holder.Size = UDim2.new(1, 0, 0, 52)
                    arrow.Text = "▼"
                end
                Library.Flags[flag] = selected
                Library.Options[flag].Value = selected
                pcall(callback, selected)
            end)
        end

        local itemCount = math.min(#values, maxVisible)
        dropFrame.Size = UDim2.new(1, 0, 0, itemCount * 28 + 8)
    end

    RefreshList()

    dropButton.MouseButton1Click:Connect(function()
        open = not open
        dropFrame.Visible = open
        arrow.Text = open and "▲" or "▼"
        if open then
            holder.Size = UDim2.new(1, 0, 0, 52 + dropFrame.Size.Y.Offset + 4)
            RefreshList()
        else
            holder.Size = UDim2.new(1, 0, 0, 52)
        end
    end)

    local dropdownObj = {
        Flag = flag,
        Set = function(v)
            selected = v
            selectedLabel.Text = multi and (type(v) == "table" and table.concat(v, ", ") or tostring(v)) or tostring(v)
            Library.Flags[flag] = v
            Library.Options[flag].Value = v
            pcall(callback, v)
        end,
        Get = function() return selected end,
        SetValues = function(newValues)
            values = newValues
            RefreshList()
        end,
        Type = "Dropdown",
    }

    Library.Options[flag] = dropdownObj
    table.insert(groupbox.Elements, dropdownObj)
    return dropdownObj
end

-------------------------------------------------
-- BUTTON
-------------------------------------------------
function Library:_CreateButton(groupbox, options)
    options = options or {}
    local text = options.Text or options.Name or "Button"
    local callback = options.Callback or options.Func or function() end
    local doubleClick = options.DoubleClick or false

    local btn = Create("TextButton", {
        Name = "Button_" .. text,
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Theme.Element,
        Text = text,
        TextColor3 = Theme.Text,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = false,
        Parent = groupbox.Container
    })
    Corner(btn, 6)
    Stroke(btn)

    btn.MouseEnter:Connect(function()
        Tween(btn, {BackgroundColor3 = Theme.Accent}, 0.12)
    end)
    btn.MouseLeave:Connect(function()
        Tween(btn, {BackgroundColor3 = Theme.Element}, 0.12)
    end)

    local lastClick = 0
    btn.MouseButton1Click:Connect(function()
        if doubleClick then
            local now = tick()
            if now - lastClick < 0.4 then
                pcall(callback)
            end
            lastClick = now
        else
            pcall(callback)
        end
    end)

    local buttonObj = {
        Type = "Button",
        SetText = function(t)
            btn.Text = t
        end,
    }

    table.insert(groupbox.Elements, buttonObj)
    table.insert(Library.Buttons, buttonObj)
    return buttonObj
end

-------------------------------------------------
-- INPUT / TEXTBOX
-------------------------------------------------
function Library:_CreateInput(groupbox, flag, options)
    options = options or {}
    local text = options.Text or options.Name or tostring(flag)
    local default = options.Default or options.Value or ""
    local placeholder = options.Placeholder or options.PlaceholderText or ""
    local callback = options.Callback or function() end
    local numeric = options.Numeric or false
    local finished = options.Finished or false -- only callback on focus lost

    Library.UnnamedFlags = Library.UnnamedFlags + 1
    flag = flag or ("Input_" .. Library.UnnamedFlags)

    local holder = Create("Frame", {
        Name = "Input_" .. text,
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundTransparency = 1,
        Parent = groupbox.Container
    })

    local label = Create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.Text,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = holder
    })

    local box = Create("TextBox", {
        Size = UDim2.new(1, 0, 0, 28),
        Position = UDim2.new(0, 0, 0, 22),
        BackgroundColor3 = Theme.Element,
        Text = tostring(default),
        PlaceholderText = placeholder,
        PlaceholderColor3 = Theme.TextMuted,
        TextColor3 = Theme.Text,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        ClearTextOnFocus = false,
        Parent = holder
    })
    Corner(box, 6)
    Stroke(box)
    Padding(box, 0, 0, 10, 10)

    Library.Flags[flag] = default
    Library.Options[flag] = {Value = default, Type = "Input"}

    local function fire(value)
        Library.Flags[flag] = value
        Library.Options[flag].Value = value
        pcall(callback, value)
    end

    if finished then
        box.FocusLost:Connect(function()
            fire(box.Text)
        end)
    else
        box:GetPropertyChangedSignal("Text"):Connect(function()
            if numeric then
                local n = box.Text:gsub("[^%d%.%-]", "")
                if n ~= box.Text then
                    box.Text = n
                end
            end
            fire(box.Text)
        end)
    end

    local inputObj = {
        Flag = flag,
        Set = function(v)
            box.Text = tostring(v)
            fire(tostring(v))
        end,
        Get = function() return box.Text end,
        Type = "Input",
    }

    Library.Options[flag] = inputObj
    table.insert(groupbox.Elements, inputObj)
    return inputObj
end

-------------------------------------------------
-- KEYBIND
-------------------------------------------------
function Library:_CreateKeybind(groupbox, flag, options)
    options = options or {}
    local text = options.Text or options.Name or tostring(flag)
    local default = options.Default or Enum.KeyCode.Unknown
    local callback = options.Callback or function() end
    local mode = options.Mode or "Toggle" -- Toggle, Hold, Always

    Library.UnnamedFlags = Library.UnnamedFlags + 1
    flag = flag or ("Keybind_" .. Library.UnnamedFlags)

    local holder = Create("Frame", {
        Name = "Keybind_" .. text,
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        Parent = groupbox.Container
    })

    local label = Create("TextLabel", {
        Size = UDim2.new(1, -90, 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.Text,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = holder
    })

    local keyBtn = Create("TextButton", {
        Size = UDim2.new(0, 80, 0, 22),
        Position = UDim2.new(1, -84, 0.5, -11),
        BackgroundColor3 = Theme.Element,
        Text = default ~= Enum.KeyCode.Unknown and default.Name or "None",
        TextColor3 = Theme.TextDark,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        AutoButtonColor = false,
        Parent = holder
    })
    Corner(keyBtn, 5)
    Stroke(keyBtn)

    local currentKey = default
    local listening = false
    local active = false

    Library.Flags[flag] = currentKey
    Library.Options[flag] = {Value = currentKey, Type = "Keybind", Mode = mode}

    local function SetKey(key)
        currentKey = key
        keyBtn.Text = key ~= Enum.KeyCode.Unknown and key.Name or "None"
        Library.Flags[flag] = key
        Library.Options[flag].Value = key
    end

    keyBtn.MouseButton1Click:Connect(function()
        if listening then return end
        listening = true
        keyBtn.Text = "..."
        Tween(keyBtn, {BackgroundColor3 = Theme.Accent}, 0.1)
    end)

    Library:Connect(UserInputService.InputBegan, function(input, gpe)
        if listening then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.Escape then
                    SetKey(Enum.KeyCode.Unknown)
                else
                    SetKey(input.KeyCode)
                end
                listening = false
                Tween(keyBtn, {BackgroundColor3 = Theme.Element}, 0.1)
            end
            return
        end

        if gpe then return end
        if input.KeyCode == currentKey and currentKey ~= Enum.KeyCode.Unknown then
            if mode == "Toggle" then
                active = not active
                pcall(callback, active)
            elseif mode == "Hold" then
                active = true
                pcall(callback, true)
            end
        end
    end)

    if mode == "Hold" then
        Library:Connect(UserInputService.InputEnded, function(input)
            if input.KeyCode == currentKey then
                active = false
                pcall(callback, false)
            end
        end)
    end

    local keybindObj = {
        Flag = flag,
        Set = SetKey,
        Get = function() return currentKey end,
        Type = "Keybind",
    }

    Library.Options[flag] = keybindObj
    table.insert(groupbox.Elements, keybindObj)
    return keybindObj
end

-------------------------------------------------
-- LABEL
-------------------------------------------------
function Library:_CreateLabel(groupbox, text, doesWrap)
    local label = Create("TextLabel", {
        Name = "Label",
        Size = UDim2.new(1, 0, 0, doesWrap and 0 or 20),
        AutomaticSize = doesWrap and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
        BackgroundTransparency = 1,
        Text = tostring(text or ""),
        TextColor3 = Theme.TextDark,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = doesWrap or false,
        Parent = groupbox.Container
    })

    local labelObj = {
        Type = "Label",
        SetText = function(t)
            label.Text = tostring(t)
        end,
    }

    table.insert(groupbox.Elements, labelObj)
    table.insert(Library.Labels, labelObj)
    return labelObj
end

-------------------------------------------------
-- DIVIDER
-------------------------------------------------
function Library:_CreateDivider(groupbox)
    local div = Create("Frame", {
        Name = "Divider",
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel = 0,
        Parent = groupbox.Container
    })
    return div
end

-------------------------------------------------
-- UNLOAD / DESTROY
-------------------------------------------------
function Library:Unload()
    self:DisconnectAll()
    if self.Holder then
        self.Holder:Destroy()
    end
    if self.NotifHolder then
        self.NotifHolder:Destroy()
    end
    getgenv().FiveMLib = nil
end

function Library:Destroy()
    self:Unload()
end

-------------------------------------------------
-- GLOBAL EXPORTS (Linoria style)
-------------------------------------------------
getgenv().Library = Library
getgenv().Toggles = Library.Toggles
getgenv().Options = Library.Options
getgenv().FiveMLib = Library

return Library


--[[
================================================
EXAMPLE USAGE
================================================

local Library = loadstring(game:HttpGet("YOUR_RAW_LINK"))()

local Window = Library:CreateWindow({
    Title = "World > Local Player",
    Center = true,
    AutoShow = true,
})

local Tab = Window:AddTab("Player")

local Left = Tab:AddLeftGroupbox("Conditions")
local Right = Tab:AddRightGroupbox("Customization")

Left:AddToggle("GodMode", {
    Text = "God Mode",
    Default = false,
    Callback = function(Value)
        print("God Mode:", Value)
    end
})

Left:AddToggle("SemGodMode", {
    Text = "Sem God Mode",
    Default = false,
})

Left:AddToggle("Invisible", {
    Text = "Invisible",
    Default = false,
})

Left:AddToggle("SuperJump", {
    Text = "Super Jump",
    Default = false,
})

Left:AddToggle("InfiniteStamina", {
    Text = "Infinite Stamina",
    Default = false,
})

Left:AddToggle("NoRagdoll", {
    Text = "No Ragdoll",
    Default = false,
})

Left:AddToggle("NoClip", {
    Text = "NoClip",
    Default = true,
})

Left:AddToggle("InvisibleNoClip", {
    Text = "Invisible NoClip",
    Default = true,
})

Left:AddToggle("RunSpeed", {
    Text = "Run Speed",
    Default = false,
})

Left:AddToggle("SwimSpeed", {
    Text = "Swim Speed",
    Default = false,
})

Left:AddToggle("NeverWanted", {
    Text = "Never Wanted",
    Default = false,
})

Right:AddSlider("NoClipSpeed", {
    Text = "NoClip Speed",
    Default = 1,
    Min = 0.1,
    Max = 5,
    Rounding = 2,
    Suffix = "",
    Callback = function(Value)
        print("NoClip Speed:", Value)
    end
})

Right:AddSlider("RunSpeedMult", {
    Text = "Run Speed Multiplier",
    Default = 1,
    Min = 0.5,
    Max = 3,
    Rounding = 2,
    Suffix = "x",
})

Right:AddSlider("SwimSpeedMult", {
    Text = "Swim Speed Multiplier",
    Default = 1,
    Min = 0.5,
    Max = 3,
    Rounding = 2,
    Suffix = "x",
})

Right:AddDropdown("NoClipMode", {
    Text = "NoClip Mode",
    Values = {"Direction", "Velocity", "CFrame"},
    Default = "Direction",
})

Right:AddSlider("HealthAmount", {
    Text = "Health Amount",
    Default = 100,
    Min = 1,
    Max = 500,
    Rounding = 0,
})

Right:AddSlider("ArmorAmount", {
    Text = "Armor Amount",
    Default = 100,
    Min = 0,
    Max = 100,
    Rounding = 0,
})

Right:AddButton({
    Text = "Apply Health/Armor",
    Callback = function()
        Library:Notify({
            Title = "Applied",
            Content = "Health and Armor updated",
            Duration = 3,
            Type = "Success"
        })
    end
})

Library:SetWatermark("FiveMLib | v1.0")
Library:Notify({
    Title = "Loaded",
    Content = "FiveM style UI library ready",
    Duration = 4
})
]]
