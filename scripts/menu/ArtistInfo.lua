local customMusic = require "necro.game.data.resource.CustomMusic"
local menu = require "necro.menu.Menu"
local textFormat = require "necro.config.i18n.TextFormat"
local textPrompt = require "necro.render.ui.TextPrompt"

local color = require "system.utils.Color"
local gfx = require "system.gfx.GFX"
local utils = require "system.utils.Utilities"

local assets = require "CustomArtists.scripts.menu.Assets"
local fonts = require "CustomArtists.scripts.menu.Fonts"
local registry = require "CustomArtists.scripts.ArtistRegistry"

-- Artist info page: editable fields on the left, a preview in the style of the grid sidebar on the right

local max = math.max
local min = math.min

local EDITOR_ROW_HEIGHT = 30

local DESCRIPTION_MIN_HEIGHT = 80
-- Imported resource pack descriptions use the same limit (ResourcePacks)
local DESCRIPTION_MAX_LENGTH = 2000

--- Every playlist is an artist; playlists made in Custom Music get their artist block on first edit
local function getArtistInfo(metadata)
    if type(metadata.customArtist) ~= "table" then
        metadata.customArtist = { description = "" }
    end

    return metadata.customArtist
end

--- A word-wrapped text box where Enter adds a new line, like the stock mod report and upload menus
local function multiLineTextPrompt(args)
    args.multiLine = true
    args.uppercase = false

    local entry = textPrompt.menuEntry(args)
    entry.font = utils.mergeDefaults(fonts.smallLowercase, {
        maxHeight = args.height,
        uppercase = false,
        wordWrap = true,
    })
    entry.textPrompt.cursorOffsetX = 4
    entry.textPrompt.cursorOffsetY = -1
    entry.height = args.height
    entry.alignY = 0

    return entry
end

--- A left/right selector cycling through "Automatic" and the image files in the playlist folder
local function imageSelector(id, label, info, key, playlist)
    local function cycle(direction)
        local options = registry.listFolderImages(playlist)
        local index = 0

        for i, fileName in ipairs(options) do
            if fileName == info[key] then
                index = i
            end
        end

        -- Index 0 is "Automatic"
        index = (index + direction) % (#options + 1)
        info[key] = options[index]
    end

    return {
        id = id,
        label = function()
            return string.format("%s: %s", label, info[key] or "Automatic")
        end,
        action = function()
            cycle(1)
        end,
        rightAction = function()
            cycle(1)
        end,
        leftAction = function()
            cycle(-1)
        end,
    }
end

event.menu.add("customArtistInfo", "CustomArtists_info", function(ev)
    ev.arg = ev.arg or {}
    local arg = ev.arg
    local playlist = arg.playlist

    -- Keep editing the same table across updates; opened from the song editor this is the editor's metadata
    arg.metadata = arg.metadata or customMusic.readMetadata(playlist) or {}
    local metadata = arg.metadata
    local info = getArtistInfo(metadata)

    local menuWidth = menu.getScreenWidth() - utils.clamp(80, menu.getScreenWidth() - 640, 140)
    local menuHalfWidth = math.floor(menuWidth / 2)
    local sidebarWidth = min(320, menuHalfWidth)
    local sidebarOffsetX = menuHalfWidth - sidebarWidth / 2 + 20
    local fieldX = -menuHalfWidth - 10
    local fieldWidth = max(1, menuWidth - sidebarWidth - 40)
    local fieldSpacing = 36
    local fieldY = 60
    local entries = {}

    local function closePage()
        -- Opened from the song editor, the editor saves this metadata when it closes
        if not arg.savedByEditor then
            customMusic.writeMetadata(playlist, metadata)
        end

        menu.close()
        menu.update()
    end

    local function addField(entry, height)
        entry.x = fieldX
        entry.y = fieldY
        entry.alignX = 0
        entry.maxWidth = fieldWidth
        entries[#entries + 1] = entry
        fieldY = fieldY + (height or fieldSpacing)
    end

    addField(textPrompt.menuEntry({
        id = "name",
        label = "Name",
        get = function()
            return metadata.displayName or ""
        end,
        set = function(value)
            metadata.displayName = value
        end,
    }))
    addField(textPrompt.menuEntry({
        id = "author",
        label = "Author",
        get = function()
            return metadata.author or ""
        end,
        set = function(value)
            metadata.author = value
        end,
    }))

    local hasImages = registry.getBasePath(playlist) ~= nil
    local headerHeight = 24
    local hintGap = 16
    local hintHeight = 28
    -- Every other row has a fixed height, so the description gets the rest of the space above Done
    local rowsBelowDescription = hintGap + hintHeight + (hasImages and fieldSpacing * 2 or 0)
    local doneY = menu.getScreenHeight() - 124
    local descriptionHeight = max(DESCRIPTION_MIN_HEIGHT,
        doneY - fieldSpacing - (fieldY + headerHeight) - rowsBelowDescription)

    addField({
        label = "Description",
        selectableIf = false,
    }, headerHeight)
    addField(multiLineTextPrompt({
        id = "description",
        height = descriptionHeight,
        maxLength = DESCRIPTION_MAX_LENGTH,
        get = function()
            return info.description or ""
        end,
        set = function(value)
            info.description = value
        end,
        view = function()
            return info.description ~= "" and info.description or textFormat.fade("No description")
        end,
        -- The description is drawn from its top, but the hint is centered on its row
    }), descriptionHeight + hintGap)
    addField({
        label = textFormat.fade("Enter adds a new line. Press down at the end to finish."),
        font = fonts.smallLowercase,
        selectableIf = false,
    }, hintHeight)

    if hasImages then
        addField(imageSelector("icon", "Icon", info, "icon", playlist))
        addField(imageSelector("banner", "Banner", info, "banner", playlist))
    end

    entries[#entries + 1] = {
        id = "done",
        label = "Done",
        sound = "UIBack",
        boundingBox = true,
        maxWidth = 300,
        y = max(menu.getScreenHeight() - 124, fieldY + fieldSpacing * 0.5),
        action = closePage,
    }

    entries[1].selected = true

    local previewY = 60

    local function addPreview(data, height)
        data.x = data.x or sidebarOffsetX
        data.y = data.y or previewY
        data.maxWidth = data.maxWidth or sidebarWidth
        data.selectableIf = false
        entries[#entries + 1] = data

        if height then
            previewY = previewY + height + 16
        end
    end

    addPreview({
        icon = function()
            local image = registry.getBanner(playlist, metadata) or registry.getIcon(playlist, metadata)

            if image then
                local width, height = gfx.getImageSize(image)
                local scale = min(160 / max(width, 1), 80 / max(height, 1)) * min(1, sidebarWidth / 320)

                return {
                    image = image,
                    width = width * scale,
                    height = height * scale,
                }
            end
        end,
    }, 100)

    local iconSize = 16
    local rowLeft = sidebarOffsetX - sidebarWidth / 2

    addPreview({
        x = rowLeft + iconSize,
        icon = function()
            local image = registry.getIcon(playlist, metadata)

            return {
                image = image or assets.DEFAULT_ICON,
                width = iconSize,
                height = iconSize,
                color = color.opacity(image and 1 or 0.4),
            }
        end,
    })
    addPreview({
        alignX = 0,
        x = rowLeft + iconSize * 2 + 12,
        maxWidth = sidebarWidth - iconSize * 2 - 12,
        font = fonts.singleLine,
        label = function()
            return metadata.displayName or ""
        end,
    }, 24)
    addPreview({
        font = fonts.smallLowercase,
        label = function()
            local author = metadata.author

            return type(author) == "string" and author ~= "" and string.format("Author: %s", author) or "Custom artist"
        end,
    }, 16)
    addPreview({
        alignX = 0,
        alignY = 0,
        x = rowLeft,
        font = utils.mergeTables({ wordWrap = true, maxHeight = menu.getScreenHeight() - previewY - 150 },
            fonts.smallLowercase),
        label = function()
            return info.description or ""
        end,
    })

    ev.menu = {
        label = "Artist info",
        entries = entries,
        width = menu.getScreenWidth(),
        height = menu.getScreenHeight(),
        fixedWidth = true,
        fixedHeight = true,
        escapeAction = closePage,
    }
end)

-- "Artist info..." below the playlist name in the stock Custom Music editor. The page edits the editor's own
-- metadata table, which the editor saves when it closes.
event.menu.add("customArtistEditorFields", { key = "customMusic", sequence = 1 }, function(ev)
    local metadata = ev.arg and ev.arg.metadata
    local entries = ev.menu and ev.menu.entries

    if type(metadata) ~= "table" or type(entries) ~= "table" then
        return
    end

    getArtistInfo(metadata)

    ev.menu.label = "Custom artist"

    local nameIndex = nil

    for i, entry in ipairs(entries) do
        if entry.id == "playlistName" then
            nameIndex = i

            break
        end
    end

    if not nameIndex then
        return
    end

    -- Song entries use absolute y positions, so push them down to make room
    for i = nameIndex + 1, #entries do
        if type(entries[i].y) == "number" then
            entries[i].y = entries[i].y + EDITOR_ROW_HEIGHT
        end
    end

    local playlist = ev.arg.name

    table.insert(entries, nameIndex + 1, {
        id = "CustomArtists_info",
        label = "Artist info...",
        action = function()
            menu.open("CustomArtists_info", {
                playlist = playlist,
                metadata = metadata,
                savedByEditor = true,
            })
        end,
    })
end)
