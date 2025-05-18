local ADDON_NAME = "AudioControl"
local DISPLAY_ADDON_NAME = "Audio Control"
local isSoundSystemRestarting = false

local X_PADDING_MENU_EDGE = 15
local TOP_PADDING_MENU_EDGE = 20
local BOTTOM_PADDING_MENU_EDGE = 15
local ROW_HEIGHT = 26
local ROW_SPACING = 8
local OUTPUT_DEVICE_ROW_EXTRA_SPACING_BELOW = 5
local SLIDER_W_VALUE = 250

local OUTPUT_DEVICE_LABEL_WIDTH = 100

local LABEL_FIXED_WIDTH = 100
local PADDING_LABEL_TO_CHECKBOX = 8
local CHECKBOX_WIDGET_FRAME_WIDTH = 38
local CHECKBOX_ACTUAL_GRAPHIC_WIDTH = 26
local CHECKBOX_INTERNAL_LEFT_PADDING = (CHECKBOX_WIDGET_FRAME_WIDTH - CHECKBOX_ACTUAL_GRAPHIC_WIDTH) / 2
if CHECKBOX_INTERNAL_LEFT_PADDING < 0 then CHECKBOX_INTERNAL_LEFT_PADDING = 0 end
local CHECKBOX_ACTUAL_GRAPHIC_HEIGHT = 26
local PADDING_CHECKBOX_TO_SLIDER = 10
local SLIDER_H_VALUE = 22
local PADDING_SLIDER_TO_PERCENT_TEXT = 5
local PERCENT_TEXT_FIXED_WIDTH = 35

local NUM_ROWS_WITH_SLIDERS = 4
local NUM_OUTPUT_DEVICE_ROWS = 1
local TOTAL_ROWS = NUM_ROWS_WITH_SLIDERS + NUM_OUTPUT_DEVICE_ROWS

local CONTENT_PANE_WIDTH = X_PADDING_MENU_EDGE + LABEL_FIXED_WIDTH + PADDING_LABEL_TO_CHECKBOX +
                             CHECKBOX_WIDGET_FRAME_WIDTH +
                             PADDING_CHECKBOX_TO_SLIDER + SLIDER_W_VALUE +
                             PADDING_SLIDER_TO_PERCENT_TEXT + PERCENT_TEXT_FIXED_WIDTH + X_PADDING_MENU_EDGE

local CONTENT_PANE_HEIGHT = TOP_PADDING_MENU_EDGE +
                              (TOTAL_ROWS * ROW_HEIGHT) +
                              ((TOTAL_ROWS > 1 and TOTAL_ROWS - 1 or 0) * ROW_SPACING) +
                              (NUM_OUTPUT_DEVICE_ROWS > 0 and OUTPUT_DEVICE_ROW_EXTRA_SPACING_BELOW or 0) +
                              BOTTOM_PADDING_MENU_EDGE

local TEMPLATE_CONTENT_OFFSET_LEFT = 7
local TEMPLATE_CONTENT_OFFSET_RIGHT = 3
local TEMPLATE_CONTENT_OFFSET_TOP = 18
local TEMPLATE_CONTENT_OFFSET_BOTTOM = 3

local FRAME_WIDTH_EXPANDED = CONTENT_PANE_WIDTH + TEMPLATE_CONTENT_OFFSET_LEFT + TEMPLATE_CONTENT_OFFSET_RIGHT
local FRAME_HEIGHT_EXPANDED = CONTENT_PANE_HEIGHT + TEMPLATE_CONTENT_OFFSET_TOP + TEMPLATE_CONTENT_OFFSET_BOTTOM

local TRIGGER_BUTTON_SIZE = 26
local TRIGGER_BUTTON_DEFAULT_X = 5
local TRIGGER_BUTTON_DEFAULT_Y = -5
local MENU_TO_TRIGGER_PADDING = 5
local SCREEN_EDGE_PADDING = 5

local DEFAULT_FONT_FILE = "Fonts\\FRIZQT__.TTF"
local DEFAULT_FONT_SIZE_LABEL = 12
local DEFAULT_FONT_SIZE_PERCENT = 12
local DEFAULT_FONT_STYLE = ""
local DEFAULT_FONT_COLOR_LABEL_R, DEFAULT_FONT_COLOR_LABEL_G, DEFAULT_FONT_COLOR_LABEL_B = 1, 0.82, 0
local DEFAULT_FONT_COLOR_PERCENT_R, DEFAULT_FONT_COLOR_PERCENT_G, DEFAULT_FONT_COLOR_PERCENT_B = 1, 0.82, 0

local ICON_BLANK_PATH = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\iconblank"
local ICON_MAIN_PATH = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\icon"

local menuFrame
local triggerButton, triggerButtonText, triggerButtonBackgroundTexture
local enableSoundCheckbox
local outputDeviceControl
local musicEnableCheckbox, musicVolumeSlider, musicVolumeText
local ambienceEnableCheckbox, ambienceVolumeSlider, ambienceVolumeText
local dialogEnableCheckbox, dialogVolumeSlider, dialogVolumeText
local masterVolumeSlider, masterVolumeText

AudioControlDB = AudioControlDB or {}
local defaultTriggerPosition = { point = "TOPLEFT", relativeTo = "UIParent", relativePoint = "TOPLEFT", x = TRIGGER_BUTTON_DEFAULT_X, y = TRIGGER_BUTTON_DEFAULT_Y }
if not AudioControlDB.triggerPosition or not AudioControlDB.triggerPosition.point or not AudioControlDB.triggerPosition.relativeTo or not AudioControlDB.triggerPosition.relativePoint or type(AudioControlDB.triggerPosition.x) ~= "number" or type(AudioControlDB.triggerPosition.y) ~= "number" then
    AudioControlDB.triggerPosition = defaultTriggerPosition
end
local isTriggerDragging = false

local function DebugPrint(msg)
    if ADDON_NAME then DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99" .. ADDON_NAME .. ":|r " .. tostring(msg)) end
end

local UpdateAllSoundSettings, ToggleMenu, CreateMenuControls, CreateTriggerButton, UpdateTriggerButtonLook
local GenerateAudioDeviceMenu_BlizzMenu, GetCurrentDeviceName, RestartSoundSystem

local function SetAppFont(fontString, size, style, r, g, b, a, fontFile)
    fontString:SetFont(fontFile or DEFAULT_FONT_FILE, size, style or DEFAULT_FONT_STYLE)
    if r and g and b then
        fontString:SetTextColor(r, g, b, a or 1)
    end
end

GetCurrentDeviceName = function()
    if Sound_GameSystem_GetOutputDriverNameByIndex and C_CVar.GetCVar then
        local i = tonumber(C_CVar.GetCVar("Sound_OutputDriverIndex"))
        if i == 0 then return SYSTEM_DEFAULT
        elseif i and Sound_GameSystem_GetOutputDriverNameByIndex then
            local d = Sound_GameSystem_GetOutputDriverNameByIndex(i)
            if d and d ~= "" and string.lower(d) ~= "none" then return d else return SYSTEM_DEFAULT end
        end
    end
    return SYSTEM_DEFAULT
end

UpdateTriggerButtonLook = function()
    if not triggerButton or not triggerButtonText or not triggerButtonBackgroundTexture then return end
    if menuFrame and menuFrame:IsShown() then
        triggerButtonBackgroundTexture:SetTexture(ICON_MAIN_PATH)
        triggerButtonText:SetText("")
    else
        triggerButtonBackgroundTexture:SetTexture(ICON_BLANK_PATH)
        if GetCVarBool("Sound_EnableAllSound") then
            local mV = GetCVar("Sound_MasterVolume"); local num_mV = tonumber(mV)
            triggerButtonText:SetText(string.format("%d", num_mV and num_mV * 100 or 0))
            SetAppFont(triggerButtonText, 9, "OUTLINE", 1, 1, 1)
        else
            triggerButtonText:SetText("X")
            SetAppFont(triggerButtonText, 14, "OUTLINE", 1, 0, 0)
        end
    end
end

UpdateTriggerButtonText = function() UpdateTriggerButtonLook() end

UpdateAllSoundSettings = function(forceUpdate)
    if not menuFrame or (not menuFrame:IsShown() and not forceUpdate) then
        if not forceUpdate then UpdateTriggerButtonLook() end; return
    end
    if not enableSoundCheckbox then return end

    local sE = GetCVarBool("Sound_EnableAllSound") == true
    if enableSoundCheckbox.SetChecked then enableSoundCheckbox:SetChecked(sE) end
    UpdateTriggerButtonLook()

    local dN = GetCurrentDeviceName()
    if outputDeviceControl and outputDeviceControl.Dropdown then
        local currentDropdownText = UIDropDownMenu_GetText(outputDeviceControl.Dropdown)
        if currentDropdownText ~= dN then
            UIDropDownMenu_SetText(outputDeviceControl.Dropdown, dN)
        elseif forceUpdate then
             if outputDeviceControl.Dropdown.Text then
                 SetAppFont(outputDeviceControl.Dropdown.Text, DEFAULT_FONT_SIZE_LABEL, DEFAULT_FONT_STYLE, DEFAULT_FONT_COLOR_LABEL_R, DEFAULT_FONT_COLOR_LABEL_G, DEFAULT_FONT_COLOR_LABEL_B)
             end
        end
    end

    local function safeSetValue(sliderFrame, cvarName, textWidget)
        if not sliderFrame then return end
        local vS = GetCVar(cvarName); local vN = tonumber(vS)
        if type(vN) ~= "number" then vN = 0.5 end
        vN = math.max(0, math.min(1, vN))
        if sliderFrame.SetValue then
            sliderFrame.programmaticChange = true
            sliderFrame:SetValue(vN)
        end
        if textWidget then textWidget:SetText(string.format("%d%%", vN * 100)) end
    end

    if masterVolumeSlider then safeSetValue(masterVolumeSlider, "Sound_MasterVolume", masterVolumeText) end
    local mE = GetCVarBool("Sound_EnableMusic") == true
    if musicEnableCheckbox and musicEnableCheckbox.SetChecked then musicEnableCheckbox:SetChecked(mE) end
    if musicVolumeSlider then
        if musicVolumeSlider.SetEnabled then musicVolumeSlider:SetEnabled(mE and sE) end
        safeSetValue(musicVolumeSlider, "Sound_MusicVolume", musicVolumeText)
    end
    local aE = GetCVarBool("Sound_EnableAmbience") == true
    if ambienceEnableCheckbox and ambienceEnableCheckbox.SetChecked then ambienceEnableCheckbox:SetChecked(aE) end
    if ambienceVolumeSlider then
        if ambienceVolumeSlider.SetEnabled then ambienceVolumeSlider:SetEnabled(aE and sE) end
        safeSetValue(ambienceVolumeSlider, "Sound_AmbienceVolume", ambienceVolumeText)
    end
    local dE = GetCVarBool("Sound_EnableDialog") == true
    if dialogEnableCheckbox and dialogEnableCheckbox.SetChecked then dialogEnableCheckbox:SetChecked(dE) end
    if dialogVolumeSlider then
        if dialogVolumeSlider.SetEnabled then dialogVolumeSlider:SetEnabled(dE and sE) end
        safeSetValue(dialogVolumeSlider, "Sound_DialogVolume", dialogVolumeText)
    end
end

ToggleMenu = function()
    if not menuFrame or not triggerButton then return end
    if menuFrame:IsShown() then
        menuFrame:Hide()
    else
        menuFrame:ClearAllPoints()
        local sw, sh = GetScreenWidth(), GetScreenHeight(); local mw, mh = menuFrame:GetWidth(), menuFrame:GetHeight()
        local tr, tl, tt, tb = triggerButton:GetRight(), triggerButton:GetLeft(), triggerButton:GetTop(), triggerButton:GetBottom()
        local mp, mrt, mrp, mx, my = "TOPLEFT", triggerButton, "BOTTOMRIGHT", MENU_TO_TRIGGER_PADDING, -MENU_TO_TRIGGER_PADDING
        local pml, pmta = tr + MENU_TO_TRIGGER_PADDING, math.abs(tb) + MENU_TO_TRIGGER_PADDING
        if pml + mw > sw - SCREEN_EDGE_PADDING then mrp = "BOTTOMLEFT"; mx = -MENU_TO_TRIGGER_PADDING; pml = tl - MENU_TO_TRIGGER_PADDING - mw end
        if pmta + mh > sh - SCREEN_EDGE_PADDING then
            if mrp == "BOTTOMRIGHT" then mrp = "TOPRIGHT" elseif mrp == "BOTTOMLEFT" then mrp = "TOPLEFT" end
            my = MENU_TO_TRIGGER_PADDING; pmta = math.abs(tt) - MENU_TO_TRIGGER_PADDING - mh
        end
        if pmta < SCREEN_EDGE_PADDING then
            if mrp == "TOPRIGHT" then mrp = "BOTTOMRIGHT" elseif mrp == "TOPLEFT" then mrp = "BOTTOMLEFT" end
            my = -MENU_TO_TRIGGER_PADDING
        end
        if pml < SCREEN_EDGE_PADDING then
            if mrp == "BOTTOMLEFT" then mrp = "BOTTOMRIGHT" elseif mrp == "TOPLEFT" then mrp = "TOPRIGHT" end
            mx = MENU_TO_TRIGGER_PADDING
        end
        menuFrame:SetPoint(mp, mrt, mrp, mx, my)
        menuFrame:Show()
        if UpdateAllSoundSettings then UpdateAllSoundSettings(true) end
    end
    if UpdateTriggerButtonLook then UpdateTriggerButtonLook() end
end

local function CreateVolumeSliderWithCheckbox(parent, enableCVarNameForNonMaster, labelText, cVarToControl, currentY, isThisTheMasterRow)
    local rowFrame = CreateFrame("Frame", ADDON_NAME .. cVarToControl .. "RowFrame", parent)
    rowFrame:SetPoint("TOPLEFT", X_PADDING_MENU_EDGE, currentY)
    rowFrame:SetPoint("TOPRIGHT", -X_PADDING_MENU_EDGE, currentY)
    rowFrame:SetHeight(ROW_HEIGHT)

    local highlight = rowFrame:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(true); highlight:SetColorTexture(0.3, 0.3, 0.3, 0.3); highlight:Hide()
    rowFrame:SetScript("OnEnter", function(self) highlight:Show() end)
    rowFrame:SetScript("OnLeave", function(self) highlight:Hide() end)
    rowFrame:EnableMouse(true)

    local lbl = rowFrame:CreateFontString(nil, "ARTWORK")
    SetAppFont(lbl, DEFAULT_FONT_SIZE_LABEL, DEFAULT_FONT_STYLE, DEFAULT_FONT_COLOR_LABEL_R, DEFAULT_FONT_COLOR_LABEL_G, DEFAULT_FONT_COLOR_LABEL_B)
    lbl:SetText(labelText or "Label Error"); lbl:SetJustifyH("LEFT")
    lbl:SetWidth(LABEL_FIXED_WIDTH)
    lbl:SetPoint("LEFT", 0, 0)
    lbl:SetPoint("TOP", 0, -(ROW_HEIGHT - lbl:GetStringHeight()) / 2)

    local actualCheckbox
    if isThisTheMasterRow then
        actualCheckbox = CreateFrame("CheckButton", ADDON_NAME.."EnableSoundCheckbox", rowFrame, "SettingsCheckboxTemplate")
        enableSoundCheckbox = actualCheckbox
        actualCheckbox:SetScript("OnClick", function(slf)
            SetCVar("Sound_EnableAllSound", slf:GetChecked() and 1 or 0); PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            UpdateAllSoundSettings(false); UpdateTriggerButtonLook()
        end)
    else
        actualCheckbox = CreateFrame("CheckButton", ADDON_NAME .. enableCVarNameForNonMaster .. "Checkbox", rowFrame, "SettingsCheckboxTemplate")
        actualCheckbox:SetScript("OnClick", function(slf)
            local sliderElement = parent[cVarToControl .. "SliderElement"]
            SetCVar(enableCVarNameForNonMaster, slf:GetChecked() and 1 or 0); PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            if sliderElement and sliderElement.SetEnabled then
                sliderElement:SetEnabled(slf:GetChecked() and (GetCVarBool("Sound_EnableAllSound") == true))
            end
        end)
    end
    actualCheckbox:SetPoint("LEFT", lbl, "RIGHT", PADDING_LABEL_TO_CHECKBOX, 0)
    actualCheckbox:SetPoint("CENTER", 0, 0)
    actualCheckbox:SetHighlightTexture("")
    actualCheckbox:SetScript("OnEnter", nil)
    actualCheckbox:SetScript("OnLeave", nil)

    local sldrFrame = CreateFrame("Frame", ADDON_NAME .. cVarToControl .. "Slider", rowFrame, "MinimalSliderWithSteppersTemplate")
    sldrFrame:SetSize(SLIDER_W_VALUE, SLIDER_H_VALUE)
    sldrFrame:SetPoint("LEFT", actualCheckbox, "RIGHT", PADDING_CHECKBOX_TO_SLIDER, 0)
    sldrFrame:SetPoint("TOP", 0, -(ROW_HEIGHT - SLIDER_H_VALUE) / 2)
    parent[cVarToControl .. "SliderElement"] = sldrFrame
    sldrFrame.cvarName = cVarToControl

    local txt = rowFrame:CreateFontString(nil, "ARTWORK")
    SetAppFont(txt, DEFAULT_FONT_SIZE_PERCENT, DEFAULT_FONT_STYLE, DEFAULT_FONT_COLOR_PERCENT_R, DEFAULT_FONT_COLOR_PERCENT_G, DEFAULT_FONT_COLOR_PERCENT_B)
    txt:SetWidth(PERCENT_TEXT_FIXED_WIDTH); txt:SetJustifyH("RIGHT")
    txt:SetPoint("RIGHT", 0, 0)
    txt:SetPoint("CENTER", 0, 0)
    sldrFrame.textWidget = txt

    local initialVal = tonumber(GetCVar(cVarToControl) or 0.5)
    txt:SetText(string.format("%d%%", initialVal * 100))

    if sldrFrame.Init then sldrFrame:Init(initialVal, 0, 1, 100, nil)
    else DebugPrint(string.format("CRITICAL: sldrFrame.Init method not found for %s", cVarToControl)) end

    if sldrFrame.RegisterCallback then
        sldrFrame:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(cb_sldr, cb_val, cb_input)
            if not cb_sldr or type(cb_sldr) ~= "table" then return end
            if cb_sldr.programmaticChange then cb_sldr.programmaticChange = false; return end
            local v = tonumber(cb_val); if type(v) ~= "number" then v = 0.5 end
            v = math.max(0, math.min(1, v)); SetCVar(cb_sldr.cvarName, v)
            if cb_sldr.textWidget then cb_sldr.textWidget:SetText(string.format("%d%%", v * 100)) end
            if cb_sldr.cvarName == "Sound_MasterVolume" then UpdateTriggerButtonLook() end
        end, sldrFrame)
    else DebugPrint(string.format("CRITICAL: sldrFrame.RegisterCallback not found for %s", cVarToControl)) end

    C_Timer.After(0.05, function()
        if sldrFrame and sldrFrame.Slider and sldrFrame.Slider.Thumb and not sldrFrame.Slider.Thumb:IsShown() then sldrFrame.Slider.Thumb:Show()
        elseif sldrFrame and sldrFrame.Thumb and not sldrFrame.Thumb:IsShown() then sldrFrame.Thumb:Show() end
    end)

    return actualCheckbox, sldrFrame, txt, rowFrame
end

GetNextValidDriverIndex = function(currentIdx, direction, numTotalDrivers)
    if not Sound_GameSystem_GetOutputDriverNameByIndex then return currentIdx end
    local step = (direction == "next" and 1) or -1
    local nextIdx = currentIdx
    local attempts = 0
    repeat
        nextIdx = nextIdx + step
        if nextIdx > numTotalDrivers then nextIdx = 0
        elseif nextIdx < 0 then nextIdx = numTotalDrivers end
        local driverName
        if nextIdx == 0 then driverName = SYSTEM_DEFAULT
        else driverName = Sound_GameSystem_GetOutputDriverNameByIndex(nextIdx) end
        if driverName and driverName ~= "" and (nextIdx == 0 or string.lower(driverName) ~= "none") then return nextIdx end
        attempts = attempts + 1
    until attempts > numTotalDrivers + 1
    return currentIdx
end

RestartSoundSystem = function()
    isSoundSystemRestarting = true
    local restarted = false
    if _G["SoundTools_RestartSoundSystem"] then SoundTools_RestartSoundSystem(); restarted = true
    elseif _G["Sound_GameSystem_RestartSoundSystem"] then Sound_GameSystem_RestartSoundSystem(); restarted = true
    elseif _G["AudioOptionsFrame_AudioRestart"] then AudioOptionsFrame_AudioRestart(); restarted = true
    end

    if not restarted then
        DebugPrint("Sound system restart function not found.")
        isSoundSystemRestarting = false
        C_Timer.After(0.1, function() if UpdateAllSoundSettings then UpdateAllSoundSettings(true) end end)
        return false, "Error: Could not restart sound system."
    end
    local newDeviceName = GetCurrentDeviceName()
    return true, newDeviceName
end

GenerateAudioDeviceMenu_BlizzMenu = function(ownerDropdown, rootDescription)
    local currentDriverIndex = tonumber(C_CVar.GetCVar("Sound_OutputDriverIndex"))
    local function IsDeviceSelected(data) return data.value == currentDriverIndex end
    local function OnDeviceSelect(data)
        local newDriverIndex = data.value
        if newDriverIndex == currentDriverIndex and newDriverIndex ~= 0 then
            return MenuResponse.CloseAll
        end
        SetCVar("Sound_OutputDriverIndex", newDriverIndex)
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        RestartSoundSystem()
        return MenuResponse.CloseAll
    end
    local systemDefaultData = { text = SYSTEM_DEFAULT, value = 0 }
    local radioSys = rootDescription:CreateRadio(systemDefaultData.text, IsDeviceSelected, OnDeviceSelect, systemDefaultData)
    radioSys:AddInitializer(function(button, description, menu)
        if button.Text then SetAppFont(button.Text, DEFAULT_FONT_SIZE_LABEL, DEFAULT_FONT_STYLE, 1,1,1) end
    end)
    if Sound_GameSystem_GetNumOutputDrivers then
        local numDrivers = Sound_GameSystem_GetNumOutputDrivers()
        for i = 1, numDrivers do
            local driverName = Sound_GameSystem_GetOutputDriverNameByIndex(i)
            if driverName and driverName ~= "" and string.lower(driverName) ~= "none" then
                local deviceData = { text = driverName, value = i }
                local radioDev = rootDescription:CreateRadio(deviceData.text, IsDeviceSelected, OnDeviceSelect, deviceData)
                radioDev:AddInitializer(function(button, description, menu)
                    if button.Text then SetAppFont(button.Text, DEFAULT_FONT_SIZE_LABEL, DEFAULT_FONT_STYLE, 1,1,1) end
                end)
            end
        end
    end
end

CreateMenuControls = function()
    menuFrame = CreateFrame("Frame", ADDON_NAME .. "MenuFrame", UIParent, "SettingsFrameTemplate")
    if not menuFrame then DebugPrint("CRITICAL: Failed to create menuFrame with SettingsFrameTemplate"); return end

    if menuFrame.NineSlice and menuFrame.NineSlice.Text then
        menuFrame.NineSlice.Text:SetText(DISPLAY_ADDON_NAME)
    else
        local titleText = menuFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        titleText:SetText(DISPLAY_ADDON_NAME)
        titleText:SetPoint("TOP", menuFrame, "TOP", 0, -12)
    end

    if menuFrame.ClosePanelButton then
        menuFrame.ClosePanelButton:SetScript("OnClick", function()
            menuFrame:Hide()
            if UpdateTriggerButtonLook then UpdateTriggerButtonLook() end
        end)
    else
        local closeButton = CreateFrame("Button", ADDON_NAME .. "MenuFrameCloseButton", menuFrame, "UIPanelCloseButtonDefaultAnchors")
        closeButton:SetScript("OnClick", function()
            menuFrame:Hide()
            if UpdateTriggerButtonLook then UpdateTriggerButtonLook() end
        end)
    end

    menuFrame:SetAttribute("UIPanelLayout-enabled", true)
    menuFrame:SetAttribute("UIPanelLayout-key", "ESCAPE")
    menuFrame:SetAttribute("UIPanelLayout-whileDead", true)
    tinsert(UISpecialFrames, menuFrame:GetName())

    if menuFrame.Bg then
        menuFrame.Bg:Hide()
    end
    local newBg = menuFrame:CreateTexture(nil, "BACKGROUND", nil, -1)
    newBg:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", TEMPLATE_CONTENT_OFFSET_LEFT, -TEMPLATE_CONTENT_OFFSET_TOP)
    newBg:SetPoint("BOTTOMRIGHT", menuFrame, "BOTTOMRIGHT", -TEMPLATE_CONTENT_OFFSET_RIGHT, TEMPLATE_CONTENT_OFFSET_BOTTOM)
    newBg:SetColorTexture(0.05, 0.05, 0.05, 0.85)

    menuFrame:SetFrameStrata("DIALOG"); menuFrame:SetFrameLevel(UIParent:GetFrameLevel() + 150)
    menuFrame:SetClampedToScreen(true);
    menuFrame:Hide()

    local contentFrame = CreateFrame("Frame", ADDON_NAME .. "ContentFrame", menuFrame)
    contentFrame:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", TEMPLATE_CONTENT_OFFSET_LEFT, -TEMPLATE_CONTENT_OFFSET_TOP)
    contentFrame:SetPoint("BOTTOMRIGHT", menuFrame, "BOTTOMRIGHT", -TEMPLATE_CONTENT_OFFSET_RIGHT, TEMPLATE_CONTENT_OFFSET_BOTTOM)

    local curY = -TOP_PADDING_MENU_EDGE
    local rows_created_count = 0

    local outputDeviceRow = CreateFrame("Frame", ADDON_NAME .. "OutputDeviceRow", contentFrame)
    outputDeviceRow:SetPoint("TOPLEFT", X_PADDING_MENU_EDGE, curY)
    outputDeviceRow:SetPoint("TOPRIGHT", -X_PADDING_MENU_EDGE, curY)
    outputDeviceRow:SetHeight(ROW_HEIGHT)

    local outDevLbl = outputDeviceRow:CreateFontString(nil, "ARTWORK");
    SetAppFont(outDevLbl, DEFAULT_FONT_SIZE_LABEL, DEFAULT_FONT_STYLE, DEFAULT_FONT_COLOR_LABEL_R, DEFAULT_FONT_COLOR_LABEL_G, DEFAULT_FONT_COLOR_LABEL_B)
    outDevLbl:SetText("Output Device");
    outDevLbl:SetWidth(OUTPUT_DEVICE_LABEL_WIDTH);
    outDevLbl:SetJustifyH("LEFT")
    outDevLbl:SetPoint("LEFT", 0, 0)
    outDevLbl:SetPoint("TOP", 0, -(ROW_HEIGHT - outDevLbl:GetStringHeight())/2)

    outputDeviceControl = CreateFrame("Frame", ADDON_NAME .. "OutputDeviceControl", outputDeviceRow, "SettingsDropdownWithButtonsTemplate")
    if not outputDeviceControl then DebugPrint("CRITICAL: Failed to create outputDeviceControl") return end

    outputDeviceControl:ClearAllPoints()
    local outputControlLeftOffset = LABEL_FIXED_WIDTH + PADDING_LABEL_TO_CHECKBOX + CHECKBOX_INTERNAL_LEFT_PADDING
    outputDeviceControl:SetPoint("LEFT", outputDeviceRow, "LEFT", outputControlLeftOffset, 0)
    outputDeviceControl:SetPoint("RIGHT", outputDeviceRow, "RIGHT", 0, 0)

    local controlHeight = outputDeviceControl:GetHeight()
    if controlHeight == 0 then controlHeight = ROW_HEIGHT - 4 end
    outputDeviceControl:SetHeight(controlHeight)
    outputDeviceControl:SetPoint("CENTER", outputDeviceRow, "CENTER", 0, 0)

    if outputDeviceControl.Dropdown then
        UIDropDownMenu_SetText(outputDeviceControl.Dropdown, GetCurrentDeviceName())
        if outputDeviceControl.Dropdown.Text then
            SetAppFont(outputDeviceControl.Dropdown.Text, DEFAULT_FONT_SIZE_LABEL, DEFAULT_FONT_STYLE, DEFAULT_FONT_COLOR_LABEL_R, DEFAULT_FONT_COLOR_LABEL_G, DEFAULT_FONT_COLOR_LABEL_B)
        end

        if outputDeviceControl.DecrementButton and outputDeviceControl.IncrementButton then
            outputDeviceControl.Dropdown:ClearAllPoints()
            local decrementButtonWidth = outputDeviceControl.DecrementButton:GetWidth()
            local incrementButtonWidth = outputDeviceControl.IncrementButton:GetWidth()
            local paddingBetweenButtonAndDropdown = 1
            outputDeviceControl.Dropdown:SetPoint("LEFT", outputDeviceControl, "LEFT", decrementButtonWidth + paddingBetweenButtonAndDropdown, 0)
            outputDeviceControl.Dropdown:SetPoint("RIGHT", outputDeviceControl, "RIGHT", -(incrementButtonWidth + paddingBetweenButtonAndDropdown), 0)
            local buttonHeight = outputDeviceControl.DecrementButton:GetHeight()
            if buttonHeight == 0 and outputDeviceControl.IncrementButton then buttonHeight = outputDeviceControl.IncrementButton:GetHeight() end
            if buttonHeight == 0 then buttonHeight = controlHeight end
            outputDeviceControl.Dropdown:SetHeight(buttonHeight)
            outputDeviceControl.Dropdown:SetPoint("CENTER", outputDeviceControl, "CENTER", 0, 0)
        else
            DebugPrint("CRITICAL: DecrementButton or IncrementButton not found for Dropdown anchoring.")
        end

        outputDeviceControl.Dropdown:SetScript("OnClick", function(self_button)
            PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
            local anchorName = ADDON_NAME .. "BlizzMenuAnchor"
            local anchorFrame = _G[anchorName]
            if not anchorFrame then
                anchorFrame = CreateFrame("Frame", anchorName, UIParent)
                anchorFrame:SetSize(1,1); anchorFrame:SetAlpha(0)
            end
            anchorFrame:ClearAllPoints()
            anchorFrame:SetPoint("TOPLEFT", self_button, "BOTTOMLEFT", 0, -2)
            anchorFrame:SetPoint("TOPRIGHT", self_button, "BOTTOMRIGHT", 0, -2)
            MenuUtil.CreateContextMenu(anchorFrame, GenerateAudioDeviceMenu_BlizzMenu, self_button)
        end)
    else
        DebugPrint("CRITICAL: outputDeviceControl.Dropdown is nil")
    end

    if outputDeviceControl.DecrementButton then
        outputDeviceControl.DecrementButton:SetScript("OnClick", function()
            local idx = tonumber(C_CVar.GetCVar("Sound_OutputDriverIndex"))
            local numDrivers = Sound_GameSystem_GetNumOutputDrivers and Sound_GameSystem_GetNumOutputDrivers() or 0
            local newVal = GetNextValidDriverIndex(idx, "previous", numDrivers)
            if GetCVar("Sound_OutputDriverIndex") ~= tostring(newVal) then
                SetCVar("Sound_OutputDriverIndex", newVal); PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
                RestartSoundSystem()
            end
        end)
    end
    if outputDeviceControl.IncrementButton then
        outputDeviceControl.IncrementButton:SetScript("OnClick", function()
            local idx = tonumber(C_CVar.GetCVar("Sound_OutputDriverIndex"))
            local numDrivers = Sound_GameSystem_GetNumOutputDrivers and Sound_GameSystem_GetNumOutputDrivers() or 0
            local newVal = GetNextValidDriverIndex(idx, "next", numDrivers)
            if GetCVar("Sound_OutputDriverIndex") ~= tostring(newVal) then
                SetCVar("Sound_OutputDriverIndex", newVal); PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
                RestartSoundSystem()
            end
        end)
    end

    curY = curY - ROW_HEIGHT
    rows_created_count = rows_created_count + 1
    if rows_created_count < TOTAL_ROWS then
        curY = curY - ROW_SPACING
        if rows_created_count == NUM_OUTPUT_DEVICE_ROWS then
            curY = curY - OUTPUT_DEVICE_ROW_EXTRA_SPACING_BELOW
        end
    end

    local _, masterSl, masterTxt = CreateVolumeSliderWithCheckbox(contentFrame, nil, "Master Volume", "Sound_MasterVolume", curY, true)
    masterVolumeSlider = masterSl; masterVolumeText = masterTxt
    curY = curY - ROW_HEIGHT
    rows_created_count = rows_created_count + 1
    if rows_created_count < TOTAL_ROWS then
        curY = curY - ROW_SPACING
    end

    local musicCB, musicSl_t, musicTxt_t = CreateVolumeSliderWithCheckbox(contentFrame, "Sound_EnableMusic", "Music", "Sound_MusicVolume", curY, false)
    musicEnableCheckbox = musicCB; musicVolumeSlider = musicSl_t; musicVolumeText = musicTxt_t
    curY = curY - ROW_HEIGHT
    rows_created_count = rows_created_count + 1
    if rows_created_count < TOTAL_ROWS then
        curY = curY - ROW_SPACING
    end

    local ambienceCB, ambienceSl_t, ambienceTxt_t = CreateVolumeSliderWithCheckbox(contentFrame, "Sound_EnableAmbience", "Ambience", "Sound_AmbienceVolume", curY, false)
    ambienceEnableCheckbox = ambienceCB; ambienceVolumeSlider = ambienceSl_t; ambienceVolumeText = ambienceTxt_t
    curY = curY - ROW_HEIGHT
    rows_created_count = rows_created_count + 1
    if rows_created_count < TOTAL_ROWS then
        curY = curY - ROW_SPACING
    end

    local dialogCB, dialogSl_t, dialogTxt_t = CreateVolumeSliderWithCheckbox(contentFrame, "Sound_EnableDialog", "Dialog", "Sound_DialogVolume", curY, false)
    dialogEnableCheckbox = dialogCB; dialogVolumeSlider = dialogSl_t; dialogVolumeText = dialogTxt_t

    menuFrame:SetSize(FRAME_WIDTH_EXPANDED, FRAME_HEIGHT_EXPANDED)
end

CreateTriggerButton = function()
    triggerButton = CreateFrame("Button", ADDON_NAME .. "TriggerButton", UIParent)
    if not triggerButton then DebugPrint("CRITICAL: Failed to create triggerButton"); return end
    triggerButton:SetSize(TRIGGER_BUTTON_SIZE, TRIGGER_BUTTON_SIZE)
    local posData = AudioControlDB.triggerPosition
    if posData and posData.point and posData.relativeTo and posData.relativePoint and type(posData.x) == "number" and type(posData.y) == "number" then
        local relFrame = _G[posData.relativeTo] or UIParent
        if posData.relativeTo ~= "UIParent" and relFrame == UIParent then posData.relativeTo = "UIParent" end
        triggerButton:SetPoint(posData.point, relFrame, posData.relativePoint, posData.x, posData.y)
    else
        AudioControlDB.triggerPosition = defaultTriggerPosition
        triggerButton:SetPoint(defaultTriggerPosition.point, UIParent, defaultTriggerPosition.relativePoint, defaultTriggerPosition.x, defaultTriggerPosition.y)
    end
    triggerButton:SetFrameStrata("MEDIUM"); triggerButton:SetFrameLevel(10)
    triggerButton:SetMovable(true); triggerButton:EnableMouse(true)
    triggerButton:RegisterForDrag("LeftButton")
    triggerButton:SetClampedToScreen(true)

    triggerButtonBackgroundTexture = triggerButton:CreateTexture(nil, "BACKGROUND");
    triggerButtonBackgroundTexture:SetAllPoints(triggerButton)
    triggerButtonText = triggerButton:CreateFontString(nil, "OVERLAY");
    SetAppFont(triggerButtonText, 10, "OUTLINE", 1,1,1)
    triggerButtonText:SetPoint("CENTER", triggerButton, "CENTER", 0, 0)
    UpdateTriggerButtonLook()

    triggerButton:SetScript("OnMouseDown", function(self, button)
        if isTriggerDragging then return end

        if button == "LeftButton" then
            if IsAltKeyDown() then
                -- Sürükleme OnDragStart'ta ele alınacak
            elseif IsShiftKeyDown() then
                local cs = GetCVarBool("Sound_EnableAllSound") == true
                SetCVar("Sound_EnableAllSound", not cs and 1 or 0); PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                UpdateAllSoundSettings(false); UpdateTriggerButtonLook()
            else
                ToggleMenu()
            end
        elseif button == "RightButton" then
            if IsShiftKeyDown() then
                local currentDeviceIndex = tonumber(C_CVar.GetCVar("Sound_OutputDriverIndex"))
                local numDrivers = Sound_GameSystem_GetNumOutputDrivers and Sound_GameSystem_GetNumOutputDrivers() or 0
                local nextDeviceIndex = GetNextValidDriverIndex(currentDeviceIndex, "next", numDrivers)

                if GetCVar("Sound_OutputDriverIndex") ~= tostring(nextDeviceIndex) then
                    SetCVar("Sound_OutputDriverIndex", nextDeviceIndex)
                    PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
                    local success, resultMessage = RestartSoundSystem()

                    if not (menuFrame and menuFrame:IsShown()) then
                        if success then
                            DEFAULT_CHAT_FRAME:AddMessage(DISPLAY_ADDON_NAME .. ": Output device changed to |cFF00FF00" .. tostring(resultMessage) .. "|r.")
                        else
                            DEFAULT_CHAT_FRAME:AddMessage(DISPLAY_ADDON_NAME .. ": |cFFFF0000" .. tostring(resultMessage) .. "|r")
                        end
                    end
                else
                    if not (menuFrame and menuFrame:IsShown()) then
                         DEFAULT_CHAT_FRAME:AddMessage(DISPLAY_ADDON_NAME .. ": No other sound output device found or already on the next device.")
                    end
                end
            elseif IsAltKeyDown() then
                AudioControlDB.triggerPosition = defaultTriggerPosition
                if triggerButton then
                    triggerButton:ClearAllPoints()
                    local p = AudioControlDB.triggerPosition
                    triggerButton:SetPoint(p.point, _G[p.relativeTo] or UIParent, p.relativePoint, p.x, p.y)
                end
                if menuFrame and menuFrame:IsShown() then menuFrame:Hide() end
                UpdateTriggerButtonLook()
                print(DISPLAY_ADDON_NAME .. ": Trigger position reset.")
            end
        end
    end)

    triggerButton:SetScript("OnDragStart", function(self, buttonArg)
        if buttonArg == "LeftButton" and IsAltKeyDown() then
            self:StartMoving();
            isTriggerDragging = true;
            if menuFrame and menuFrame:IsShown() then menuFrame:Hide(); UpdateTriggerButtonLook() end
        else
            self:StopMovingOrSizing();
            isTriggerDragging = false;
        end
    end)

    triggerButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if not isTriggerDragging then return end
        local p, rf, rp, x, y = self:GetPoint()
        AudioControlDB.triggerPosition = { point = p, relativeTo = (rf and rf:GetName()) or "UIParent", relativePoint = rp, x = x, y = y }
        C_Timer.After(0, function() isTriggerDragging = false end)
    end)

    local kc = "|cFFFF9900"; local ac = "|cFF33FF33"; local rc = "|r"
    triggerButton:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s,"ANCHOR_RIGHT");
        GameTooltip:AddLine(DISPLAY_ADDON_NAME);
        GameTooltip:AddLine(kc .. "Left Click" .. rc .. ac .. ": Toggle Menu" .. rc);
        GameTooltip:AddLine(kc .. "Shift + Left Click" .. rc .. ac .. ": Toggle All Sound" .. rc);
        GameTooltip:AddLine(kc .. "Shift + Right Click" .. rc .. ac .. ": Change Output Device" .. rc);
        GameTooltip:AddLine(kc .. "Alt + Left Click & Drag" .. rc .. ac .. ": Move Button" .. rc);
        GameTooltip:AddLine(kc .. "Alt + Right Click" .. rc .. ac .. ": Reset Button Position" .. rc);
        GameTooltip:Show()
    end)
    triggerButton:SetScript("OnLeave", function(s) GameTooltip:Hide() end);
    triggerButton:Show()
end

local eventFrame = CreateFrame("Frame");
eventFrame:RegisterEvent("PLAYER_LOGIN");
eventFrame:RegisterEvent("CVAR_UPDATE")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        if not AudioControlDB.triggerPosition or type(AudioControlDB.triggerPosition.x) ~= "number" then AudioControlDB.triggerPosition = defaultTriggerPosition end
        C_Timer.After(0.35, function()
            if CreateMenuControls then CreateMenuControls() else DebugPrint("CreateMenuControls is nil at PLAYER_LOGIN") end
            if CreateTriggerButton then CreateTriggerButton() else DebugPrint("CreateTriggerButton is nil at PLAYER_LOGIN") end
            if UpdateAllSoundSettings then UpdateAllSoundSettings(true) else DebugPrint("UpdateAllSoundSettings is nil at PLAYER_LOGIN") end
        end)
    elseif event == "CVAR_UPDATE" then
        local cN = ...
        if isSoundSystemRestarting and cN ~= "Sound_OutputDriverIndex" then return end
        local relevantSliderFrame
        if cN == "Sound_MasterVolume" then relevantSliderFrame = masterVolumeSlider
        elseif cN == "Sound_MusicVolume" then relevantSliderFrame = musicVolumeSlider
        elseif cN == "Sound_AmbienceVolume" then relevantSliderFrame = ambienceVolumeSlider
        elseif cN == "Sound_DialogVolume" then relevantSliderFrame = dialogVolumeSlider
        end
        if relevantSliderFrame and relevantSliderFrame.programmaticChange == nil then relevantSliderFrame.programmaticChange = true end
        if cN == "Sound_OutputDriverIndex" then
            C_Timer.After(0.7, function()
                isSoundSystemRestarting = false;
                if UpdateAllSoundSettings then UpdateAllSoundSettings(true) end
            end)
        elseif string.find(cN, "Sound_") then
            if not isSoundSystemRestarting then
                if menuFrame and menuFrame:IsShown() or cN == "Sound_MasterVolume" or cN == "Sound_EnableAllSound" then
                     if UpdateAllSoundSettings then UpdateAllSoundSettings(menuFrame and menuFrame:IsShown()) end
                end
            end
        end
        if relevantSliderFrame and relevantSliderFrame.programmaticChange then
            C_Timer.After(0.01, function() if relevantSliderFrame then relevantSliderFrame.programmaticChange = false end end)
        end
    elseif event == "PLAYER_LOGOUT" then
        if menuFrame and menuFrame:GetName() then
            for i, frameName in ipairs(UISpecialFrames) do
                if frameName == menuFrame:GetName() then
                    tremove(UISpecialFrames, i)
                    break
                end
            end
        end
    end
end)

SLASH_AUDIOCONTROL1 = "/aca"; SLASH_AUDIOCONTROL2 = "/audioc"
SlashCmdList["AUDIOCONTROL"] = function(msg)
    msg = string.lower(msg)
    if msg == "toggle" then if ToggleMenu then ToggleMenu() end
    elseif msg == "resetmenu" then
        AudioControlDB.triggerPosition = defaultTriggerPosition
        if triggerButton then triggerButton:ClearAllPoints(); local p = AudioControlDB.triggerPosition; triggerButton:SetPoint(p.point, _G[p.relativeTo] or UIParent, p.relativePoint, p.x, p.y) end
        if menuFrame and menuFrame:IsShown() then menuFrame:Hide(); UpdateTriggerButtonLook() end
        print(DISPLAY_ADDON_NAME .. ": Trigger position reset.")
    end
end
print(DISPLAY_ADDON_NAME .. " " .. "2.1" .. " loaded. Commands: /aca or /audioc")
