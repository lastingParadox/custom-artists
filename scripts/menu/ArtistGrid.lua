local grayscaleFilter = require "necro.render.filter.GrayscaleFilter"
local menu = require "necro.menu.Menu"
local textFormat = require "necro.config.i18n.TextFormat"
local theme = require "necro.config.Theme"
local ui = require "necro.render.UI"

local color = require "system.utils.Color"
local gfx = require "system.gfx.GFX"
local stringUtils = require "system.utils.StringUtilities"
local utils = require "system.utils.Utilities"

local artistActions = require "CustomArtists.scripts.menu.ArtistActions"
local artistContextMenu = require "CustomArtists.scripts.menu.ArtistContextMenu"
local artistSidebar = require "CustomArtists.scripts.menu.ArtistSidebar"
local assets = require "CustomArtists.scripts.menu.Assets"
local fonts = require "CustomArtists.scripts.menu.Fonts"
local gridToolbar = require "CustomArtists.scripts.menu.GridToolbar"
local gridView = require "CustomArtists.scripts.menu.GridView"
local registry = require "CustomArtists.scripts.ArtistRegistry"

-- Layout and icons mirror the stock mod grid (necro.menu.mod.ModGrid)

local max = math.max
local min = math.min

local ID_DONE = "done"

local function emptyAction()
end

local EMPTY_PLACEHOLDER = {
    empty = true,
    icon = assets.EMPTY,
    title = "",
    description = "",
    cursorColor = color.opacity(0.5),
}

local NEW_ARTIST_PLACEHOLDER = {
    id = "newArtist",
    icon = assets.CREATE,
    title = "New artist",
    description = "Create a new custom artist",
    action = function()
        artistActions.create()
    end,
}

local IMPORT_PACK_PLACEHOLDER = {
    id = "importPack",
    icon = assets.DEFAULT_ICON,
    title = "Import resource pack",
    description = "Create a custom artist with a copy of an installed resource pack's songs",
    action = function()
        menu.open("CustomArtists_importPack")
    end,
}

local function buildGroups(artistList, sortMode, searching)
    local groups = {}

    if sortMode.id == "MODDED" then
        local customArtists, vanillaArtists = {}, {}

        for _, id in ipairs(artistList) do
            table.insert(registry.isCustom(id) and customArtists or vanillaArtists, id)
        end

        -- artistList is already sorted by name; built-in artists follow the vanilla music pack order instead
        table.sort(vanillaArtists, function(id1, id2)
            local order1, order2 = registry.getVanillaOrder(id1), registry.getVanillaOrder(id2)

            if order1 ~= order2 then
                return order1 < order2
            end

            return stringUtils.compareIgnoreCase(registry.getTitle(id1), registry.getTitle(id2))
        end)

        groups[#groups + 1] = { name = "Custom artists", items = customArtists }
        groups[#groups + 1] = { name = "Vanilla artists", items = vanillaArtists }
    elseif sortMode.id == "ENABLED" then
        local randomizedArtists, otherArtists = {}, {}

        for _, id in ipairs(artistList) do
            table.insert(registry.isRandomized(id) and randomizedArtists or otherArtists, id)
        end

        groups[#groups + 1] = { name = "Included for randomization", items = randomizedArtists }
        groups[#groups + 1] = { name = "Not included for randomization", items = otherArtists }
    else
        groups[#groups + 1] = { items = artistList }
    end

    if not searching then
        -- Same as the "Tools" group of the stock mod grid (necro.mod.ModGroup.Type.TOOLS)
        groups[#groups + 1] = { name = "Tools", items = { NEW_ARTIST_PLACEHOLDER, IMPORT_PACK_PLACEHOLDER } }
    end

    return groups
end

event.menu.add("customArtistsGrid", "CustomArtists_grid", function(ev)
    ev.arg = ev.arg or {}
    local arg = ev.arg
    local entries = {}
    local selectedArtist = arg.selectedArtist

    if not ev.update then
        -- Artists deleted through the stock uninstall action stay registered until scripts reload
        registry.unassignDeletedArtists()
        -- Picks up beatmaps added to or removed from artist folders by hand
        registry.refreshAllAlternateRhythm()
    end

    local sortMode = gridView.get("sort")
    local view = gridView.get("view")
    local viewSize = gridView.get("size")

    local artistList = registry.listAll()
    local lowerQuery = nil

    if ev.searchText and ev.searchText ~= "" then
        lowerQuery = utf8.lower(ev.searchText)

        utils.removeIf(artistList, function(id)
            return not utf8.lower(registry.getTitle(id)):find(lowerQuery, 1, true)
        end)

        arg.searchFilterDisplay = ev.searchText
        arg.scrollToTargetPending = true
    else
        arg.searchFilterDisplay = nil
    end

    table.sort(artistList, function(id1, id2)
        return stringUtils.compareIgnoreCase(registry.getTitle(id1), registry.getTitle(id2))
    end)

    local groups = buildGroups(artistList, sortMode, lowerQuery ~= nil)

    local function highlightSearchQuery(displayName)
        if not lowerQuery then
            return displayName
        end

        local result, found = textFormat.highlightSearchQuery(displayName, lowerQuery)

        if not found then
            for word in string.gmatch(lowerQuery, "[^%s]+") do
                result, found = textFormat.highlightSearchQuery(displayName, word)

                if found then
                    break
                end
            end
        end

        return result
    end

    local menuWidth = menu.getScreenWidth() - utils.clamp(80, menu.getScreenWidth() - 640, 140)
    local menuHalfWidth = math.floor(menuWidth / 2)
    local toolSpacing = math.floor(utils.clamp(2, (menuWidth - 310) / 8 + 8, 10))
    local tileWidth = viewSize.size
    local tileHeight = viewSize.size
    local tileSpacingX = viewSize.spacing
    local tileSpacingY = viewSize.spacing
    local tileOffsetX = -menuHalfWidth - 26 + viewSize.size * 0.5
    local tileOffsetY = 28 + viewSize.size * 0.5
    local maxTileY = 0
    local sidebarWidth = min(320, menuHalfWidth)
    local sidebarOffsetX = menuHalfWidth - sidebarWidth / 2 + 20
    local listOffsetX = 10
    local listOffsetY = 12 + viewSize.spacing + (viewSize.listOffsetY or 0)
    local listTextWidth = max(1, menuWidth - sidebarWidth + 22 - viewSize.size)
    local columnCount = view.singleColumn and 1
        or max(1, math.floor((menuWidth - sidebarWidth + 45) / (viewSize.size + viewSize.spacing)))
    local defaultIconDisabled = grayscaleFilter.getPath(assets.DEFAULT_ICON)

    local tileIndex = 0
    local tileIndexLimit = nil
    local lastNonEmptyTileIndex = 0
    local tileIDs = {}
    local itemsByEntry = {}
    local autoSelect, autoSelectFallback = nil, nil

    local function getTileIDByIndex(index)
        return tileIDs[utils.clamp(0, index, tileIndexLimit or tileIndex)]
    end

    local getToolID = gridToolbar.add(entries, {
        x = -menuHalfWidth - 6,
        y = 2,
        spacing = toolSpacing,
        sortMode = sortMode,
        view = view,
        viewSize = viewSize,
        columnCount = columnCount,
        doneID = ID_DONE,
        getTileID = getTileIDByIndex,
    })

    if arg.searchFilterDisplay then
        tileOffsetY = tileOffsetY + 50
        entries[#entries + 1] = {
            id = "searchQuery",
            alignX = 0,
            selectableIf = false,
            label = ui.upper("Search: ") .. tostring(arg.searchFilterDisplay),
            x = tileOffsetX - tileWidth / 2,
            y = tileOffsetY - (tileHeight / 2 + 24),
            maxWidth = listTextWidth + viewSize.size,
            font = fonts.mediumLowercase,
        }
    end

    local function addTile(item)
        local placeholder = type(item) == "table" and item or nil
        local tx = tileIndex % columnCount
        local ty = math.floor(tileIndex / columnCount)
        local x = tileOffsetX + (tileWidth + tileSpacingX) * tx
        local y = tileOffsetY + (tileHeight + tileSpacingY) * ty
        local i = tileIndex
        local tileID = "tile_" .. (placeholder and (placeholder.id or ("empty" .. i)) or item)
        tileIDs[i] = tileID

        if not (placeholder and placeholder.empty) then
            lastNonEmptyTileIndex = tileIndex
        end

        local displayName = placeholder and placeholder.title or registry.getTitle(item)
        local enabled = placeholder ~= nil or registry.isRandomized(item)
        local fade = enabled and 1 or 0.5
        local textColor = color.gray(fade)
        local image = not placeholder and registry.getIcon(item)
        local iconImage, iconAlpha = nil, 1

        if placeholder then
            iconImage = placeholder.icon
        elseif image then
            iconImage, iconAlpha = enabled and image or grayscaleFilter.getPath(image), fade
        else
            iconImage, iconAlpha = enabled and assets.DEFAULT_ICON or defaultIconDisabled, 0.4 * fade
        end

        -- Menus stretch an icon to the size they are given, and an artist's picture is whatever shape its author made
        -- it, so fit it inside the tile instead
        local iconWidth, iconHeight = gfx.getImageSize(iconImage)
        local iconScale = math.min(tileWidth / math.max(iconWidth, 1), tileHeight / math.max(iconHeight, 1)) * 0.5

        entries[#entries + 1] = {
            font = ui.Font.LARGE,
            color = color.WHITE,
            hideCursor = true,
            icon = {
                image = iconImage,
                width = iconWidth * iconScale,
                height = iconHeight * iconScale,
                color = color.opacity(iconAlpha),
            },
            x = x,
            y = y,
        }

        entries[#entries + 1] = {
            id = tileID,
            label = not placeholder and not image and stringUtils.initialism(displayName) or nil,
            font = viewSize.tileFont,
            color = textColor,
            hideCursor = true,
            icon = {
                image = selectedArtist ~= nil and selectedArtist == item and assets.CURSOR_SELECTED or assets.EMPTY,
                selectedImage = assets.CURSOR,
                width = tileWidth * 0.5,
                height = tileHeight * 0.5,
                color = placeholder and placeholder.cursorColor or color.WHITE,
            },
            x = x,
            y = y,
            boundingBox = not (placeholder and placeholder.empty) and {
                x - (tileWidth + tileSpacingX) * 0.5,
                y - (tileHeight + tileSpacingY) * 0.5,
                (view.boundingBoxFullWidth and tileWidth + listTextWidth or tileWidth) + tileSpacingX,
                tileHeight + tileSpacingY,
            } or false,
            maxWidth = tileWidth,
            leftSound = "",
            rightSound = "",
            upAction = function()
                if ty > 0 then
                    menu.selectByID(getTileIDByIndex(i - columnCount))
                else
                    menu.selectByID(getToolID(tx + 1))
                end

                menu.playSelectionSound(-1)
            end,
            downAction = function()
                if i < tileIndex - columnCount then
                    menu.selectByID(getTileIDByIndex(i + columnCount))
                else
                    menu.selectByID(ID_DONE)
                end

                menu.playSelectionSound(1)
            end,
            leftAction = function()
                menu.selectByID(getTileIDByIndex(i - (view.pageScroll or 1)))
                menu.playSelectionSound(-1)
            end,
            rightAction = function()
                menu.selectByID(getTileIDByIndex(i + (view.pageScroll or 1)))
                menu.playSelectionSound(1)
            end,
            action = placeholder and (placeholder.action or emptyAction) or function()
                artistActions.toggleRandomized(item)
            end,
            specialAction = placeholder and (placeholder.action or emptyAction) or function()
                if menu.isMouseControlActive() and selectedArtist == item then
                    artistContextMenu.open(arg)
                else
                    artistContextMenu.open(arg, item)
                end
            end,
        }

        if placeholder then
            autoSelectFallback = autoSelectFallback or #entries
        else
            autoSelect = autoSelect or #entries
        end

        itemsByEntry[#entries] = item

        if view.showNames then
            entries[#entries + 1] = {
                alignX = 0,
                hideCursor = true,
                label = highlightSearchQuery(displayName)
                    .. (not placeholder and registry.isHidden(item) and textFormat.fade("  (hidden)") or ""),
                visualSelection = function()
                    return menu.getSelectedID() == tileID
                end,
                color = textColor,
                selectedColor = theme.Color.SELECTION,
                x = x + listOffsetX + tileWidth * 0.5,
                y = y + listOffsetY - tileHeight * 0.5,
                maxWidth = listTextWidth,
                font = fonts.singleLine,
                action = emptyAction,
            }
        end

        if view.showDescriptions and viewSize.descLines > 0 then
            entries[#entries + 1] = {
                alignX = 0,
                alignY = 0,
                label = placeholder and placeholder.description or registry.getDescription(item),
                color = textColor,
                x = x + listOffsetX + tileWidth * 0.5,
                y = y + listOffsetY - tileHeight * 0.5 + 18,
                maxWidth = listTextWidth,
                font = utils.mergeTables({ wordWrap = true, maxLines = viewSize.descLines }, fonts.smallLowercase),
                action = emptyAction,
            }
        end

        maxTileY = max(maxTileY, y)
        tileIndex = tileIndex + 1
    end

    local hasVisibleItems = false

    for _, group in ipairs(groups) do
        if #group.items > 0 then
            hasVisibleItems = true

            if group.name then
                tileOffsetY = tileOffsetY + 36
                entries[#entries + 1] = {
                    alignX = 0,
                    label = group.name,
                    x = tileOffsetX - tileWidth / 2,
                    y = tileOffsetY - (tileHeight / 2 + 15)
                        + (tileHeight + tileSpacingY) * math.floor(tileIndex / columnCount),
                    action = emptyAction,
                    color = color.opacity(0.9),
                    font = viewSize.groupFont or ui.Font.MEDIUM,
                    maxWidth = menuWidth - sidebarWidth + 32,
                }
            end

            for _, item in ipairs(group.items) do
                addTile(item)
            end

            for _ = (tileIndex - 1) % columnCount, columnCount - 2 do
                addTile(EMPTY_PLACEHOLDER)
            end
        end
    end

    if entries[autoSelect or autoSelectFallback] then
        entries[autoSelect or autoSelectFallback].selected = true
    end

    if not hasVisibleItems then
        entries[#entries + 1] = {
            y = 200,
            label = "No results",
        }
    end

    tileIndexLimit = tileIndex - 1

    artistSidebar.add(entries, {
        x = sidebarOffsetX,
        y = 60,
        width = sidebarWidth,
        selectedArtist = selectedArtist,
        itemsByEntry = itemsByEntry,
        highlightSearchQuery = highlightSearchQuery,
    })

    local function closeMenu()
        menu.close()
        menu.update()
    end

    entries[#entries + 1] = {
        id = ID_DONE,
        label = "Done",
        sound = "UIBack",
        boundingBox = true,
        maxWidth = 300,
        selected = not hasVisibleItems,
        y = max(menu.getScreenHeight() - 124, maxTileY + tileHeight + tileSpacingY),
        action = closeMenu,
        upAction = function()
            menu.selectByID(getTileIDByIndex(lastNonEmptyTileIndex) or getToolID(1))
            menu.playSelectionSound(-1)
        end,
        downAction = function()
            menu.selectByID(getToolID(1))
            menu.playSelectionSound(1)
        end,
    }

    -- Filtering is done above, so stop the generic menu search from removing entries
    ev.searchText = nil
    ev.menu = {
        label = "Custom Artists",
        entries = entries,
        closeOnRunReset = false,
        directionalConfirmation = false,
        dismissable = false,
        fixedHeight = true,
        fixedWidth = true,
        generateBoundingBoxes = false,
        padding = false,
        searchable = true,
        width = menu.getScreenWidth(),
        height = menu.getScreenHeight(),
        escapeAction = closeMenu,
        tickCallback = function(currentMenu, calledFromUpdate)
            if calledFromUpdate and arg.scrollToTargetPending then
                arg.scrollToTargetPending = nil

                if tileIDs[0] then
                    menu.selectByID(tileIDs[0], currentMenu)
                end

                menu.scrollToTarget(currentMenu)
            end
        end,
        returnCallback = function()
            arg.selectedArtist = nil
            menu.update()
        end,
    }
end)
