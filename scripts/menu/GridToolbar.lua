local chat = require "necro.client.Chat"
local menu = require "necro.menu.Menu"

local utils = require "system.utils.Utilities"

local artistActions = require "CustomArtists.scripts.menu.ArtistActions"
local assets = require "CustomArtists.scripts.menu.Assets"
local fonts = require "CustomArtists.scripts.menu.Fonts"
local gridView = require "CustomArtists.scripts.menu.GridView"

-- Search, sort, view and icon size along the top of the artist grid

local GridToolbar = {}

local TOOL_WIDTH = 16
local TOOL_HEIGHT = 16

local function emptyAction()
end

--- Appends the toolbar and returns its id lookup, which the grid needs for up and down navigation.
--- opts: x, y, sortMode, view, viewSize, columnCount, doneID, getTileID
function GridToolbar.add(entries, opts)
    local count = 0
    local x = opts.x
    local spacing = opts.spacing

    local function getToolID(index)
        return "tool" .. utils.clamp(1, index, count)
    end

    local tools = {
        {
            icon = 17,
            label = "Search",
            action = function()
                local currentMenu = menu.getCurrent()

                if currentMenu then
                    currentMenu.searchText = ""
                end

                chat.openChatbox("Search", chat.Prompt.MENU_SEARCH)
                menu.update()
            end,
        },
        {
            icon = opts.sortMode.icon,
            image = opts.sortMode.image,
            label = "Sort by: " .. opts.sortMode.name,
            action = function()
                gridView.cycle("sort")
            end,
        },
        {
            icon = opts.view.icon,
            label = "View as: " .. opts.view.name,
            action = function()
                gridView.cycle("view")
            end,
        },
        {
            icon = opts.viewSize.icon,
            label = "Icon size: " .. opts.viewSize.name,
            action = function()
                gridView.cycle("size")
            end,
        },
    }

    if artistActions.canOpenDirectory then
        tools[#tools + 1] = {
            icon = 2,
            label = "Open mod directory",
            action = artistActions.openDirectory,
        }
    end

    for _, tool in ipairs(tools) do
        count = count + 1
        local index = count

        entries[#entries + 1] = {
            id = getToolID(index),
            toolLabel = tool.label,
            toolEnabled = true,
            hideArrows = true,
            -- Tools use an icon from the shared stock tools image, or a 16x16 image of their own
            icon = {
                image = tool.image or assets.TOOLS,
                imageRect = not tool.image and { TOOL_WIDTH * ((tool.icon or 1) - 1), 0, TOOL_WIDTH, TOOL_HEIGHT } or nil,
                width = TOOL_WIDTH,
                height = TOOL_HEIGHT,
                selectionTint = true,
            },
            boundingBox = {
                x - TOOL_WIDTH - spacing * 0.5,
                opts.y - TOOL_HEIGHT,
                TOOL_WIDTH * 2 + spacing,
                TOOL_HEIGHT * 2,
            },
            font = fonts.smallLowercase,
            x = x,
            y = opts.y,
            leftSound = "",
            rightSound = "",
            leftAction = function()
                menu.selectByID(getToolID(index - 1))
                menu.playSelectionSound(-1)
            end,
            rightAction = function()
                menu.selectByID(getToolID(index + 1))
                menu.playSelectionSound(1)
            end,
            upAction = function()
                menu.selectByID(opts.doneID)
                menu.playSelectionSound(-1)
            end,
            downAction = function()
                menu.selectByID(opts.getTileID(math.min(index - 1, opts.columnCount - 1)) or opts.doneID)
                menu.playSelectionSound(1)
            end,
            action = tool.action,
        }
        x = x + TOOL_WIDTH * 2 + spacing
    end

    -- Describes the hovered tool, to the right of the last one
    entries[#entries + 1] = {
        alignX = 0,
        x = x,
        y = opts.y,
        font = fonts.smallLowercase,
        label = function()
            return (menu.getSelectedEntry() or {}).toolLabel
        end,
        enableIf = function()
            return (menu.getSelectedEntry() or {}).toolEnabled
        end,
        action = emptyAction,
    }

    return getToolID
end

return GridToolbar
