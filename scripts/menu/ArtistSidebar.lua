local controls = require "necro.config.Controls"
local menu = require "necro.menu.Menu"
local textFormat = require "necro.config.i18n.TextFormat"

local color = require "system.utils.Color"
local gfx = require "system.gfx.GFX"
local utils = require "system.utils.Utilities"

local fonts = require "CustomArtists.scripts.menu.Fonts"
local registry = require "CustomArtists.scripts.ArtistRegistry"
local songRandomizer = require "CustomArtists.scripts.randomizer.Randomizer"

-- Details of the hovered artist, down the right side of the grid

local ArtistSidebar = {}

local ENTRY_HEIGHT = 24
local ENTRY_SPACING = 16

local function emptyAction()
end

--- opts: x, y, width, selectedArtist, itemsByEntry, highlightSearchQuery
function ArtistSidebar.add(entries, opts)
    local index = 0
    local y = opts.y
    -- Counting reads the artist's playlist, so it happens once per artist while the grid is open
    local songCounts = {}

    local function forCurrentItem(func)
        if type(func) ~= "function" then
            return func
        end

        return function()
            local item = opts.selectedArtist or opts.itemsByEntry[menu.getSelection()]

            if item then
                return func(item, type(item) == "table" and item or nil)
            end
        end
    end

    local function isItemEnabled(item)
        return type(item) == "table" or registry.isRandomized(item)
    end

    local function add(data)
        index = index + 1
        data.id = "sidebar" .. index
        data.label = forCurrentItem(data.label)
        data.icon = forCurrentItem(data.icon)
        data.enableIf = forCurrentItem(isItemEnabled)
        data.action = emptyAction
        data.selectableIf = function()
            return false
        end
        entries[#entries + 1] = utils.mergeTables({
            sticky = true,
            x = opts.x,
            y = y,
            maxWidth = opts.width + 20,
        }, data)
        y = y + (data.height or ENTRY_HEIGHT) + ENTRY_SPACING
    end

    add({
        height = 100,
        icon = function(item, placeholder)
            -- Without a banner, show the icon scaled to fit the banner area
            local image = not placeholder and (registry.getBanner(item) or registry.getIcon(item))

            if image then
                local width, height = gfx.getImageSize(image)
                local scale = math.min(160 / math.max(width, 1), 80 / math.max(height, 1))
                    * math.min(1, opts.width / 320)

                return {
                    image = image,
                    width = width * scale,
                    height = height * scale,
                }
            end
        end,
    })
    add({
        height = 18,
        maxWidth = opts.width,
        font = fonts.singleLine,
        label = function(item, placeholder)
            return placeholder and placeholder.title or opts.highlightSearchQuery(registry.getTitle(item))
        end,
    })
    add({
        height = 16,
        font = fonts.smallLowercase,
        label = function(item, placeholder)
            if placeholder then
                return nil
            end

            local author = registry.getAuthor(item)

            if author then
                return string.format("Author: %s", author)
            end

            return registry.isCustom(item) and (registry.getImportLabel(item) or "Custom artist") or "Built-in artist"
        end,
    })
    add({
        height = 16,
        font = fonts.smallLowercase,
        label = function(item, placeholder)
            if placeholder then
                return nil
            end

            songCounts[item] = songCounts[item] or songRandomizer.countSongs(item)

            local count = songCounts[item]
            local status = {
                registry.isRandomized(item) and "Included for randomization" or "Not included for randomization",
                string.format("%d %s", count, count == 1 and "song" or "songs"),
            }

            if registry.isHidden(item) then
                status[#status + 1] = "hidden"
            end

            return table.concat(status, ", ")
        end,
    })
    add({
        alignX = 0,
        alignY = 0,
        height = 16,
        x = opts.x - opts.width * 0.5,
        y = y - 8,
        maxWidth = opts.width,
        font = utils.mergeTables({ wordWrap = true, maxHeight = menu.getScreenHeight() - y - 150 }, fonts.smallLowercase),
        label = function(item, placeholder)
            return placeholder and placeholder.description or registry.getDescription(item)
        end,
    })

    if not opts.selectedArtist then
        local keybind = textFormat.color(controls.getFriendlyMiscKeyBind(controls.Misc.SELECT_2), color.WHITE)
        local hint = textFormat.color(string.format("Press %s for more options", keybind), color.gray())
        local mouseHint = textFormat.color("Right click for more options", color.gray())

        add({
            sticky = 1,
            y = -20,
            font = fonts.smallLowercase,
            label = function(item)
                if type(item) == "string" and not menu.isTouchControlActive() then
                    return menu.isMouseControlActive() and mouseHint or hint
                end
            end,
        })
    end
end

return ArtistSidebar
