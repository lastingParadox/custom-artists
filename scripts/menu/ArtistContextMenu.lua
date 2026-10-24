local customMusic = require "necro.game.data.resource.CustomMusic"
local dropdownMenu = require "necro.menu.generic.DropdownMenu"
local menu = require "necro.menu.Menu"
local textFormat = require "necro.config.i18n.TextFormat"
local ui = require "necro.render.UI"

local utils = require "system.utils.Utilities"

local artistActions = require "CustomArtists.scripts.menu.ArtistActions"
local registry = require "CustomArtists.scripts.ArtistRegistry"

local ArtistContextMenu = {}

--- Right-click / "more options" dropdown of the artist grid. A nil id closes it.
function ArtistContextMenu.open(arg, id)
    if not id then
        menu.closeNamed("dropdown")
        menu.update()

        return
    end

    local function close()
        ArtistContextMenu.open(arg)
    end

    -- Checkboxes stay open while toggled; the other entries close the dropdown
    local entries = {
        {
            label = function()
                return "Randomize " .. textFormat.checkbox(registry.isRandomized(id))
            end,
            action = function()
                artistActions.toggleRandomized(id)
            end,
        },
        {
            label = function()
                return "Hide " .. textFormat.checkbox(registry.isHidden(id))
            end,
            action = function()
                artistActions.toggleHidden(id)
            end,
        },
    }

    if registry.isCustom(id) then
        -- The song editor links to the artist info page
        entries[#entries + 1] = {
            label = "Edit",
            action = function()
                close()
                customMusic.edit(id)
            end,
        }

        if artistActions.canOpenDirectory then
            entries[#entries + 1] = {
                label = "Open directory",
                action = function()
                    close()
                    artistActions.openDirectory(id)
                end,
            }
        end

        entries[#entries + 1] = {
            label = "Delete",
            action = function()
                close()
                artistActions.delete(id)
            end,
        }
    end

    local width = 300

    for _, entry in ipairs(entries) do
        local text = tostring(utils.eval(entry.label, ""))
        width = math.max(width, (ui.measureText({ font = ui.Font.MEDIUM, text = text }).width or 0) * 2 + 60)
    end

    arg.selectedArtist = id

    local entryHeight = 30 + menu.getPadding()
    local subScreen, screenAlignY = dropdownMenu.getSubScreen(width, #entries * entryHeight + 36)

    menu.open("dropdown", {
        entries = entries,
        subScreen = subScreen,
        screenAlignY = screenAlignY,
        width = width,
    })
end

return ArtistContextMenu
