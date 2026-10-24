local menu = require "necro.menu.Menu"

local registry = require "CustomArtists.scripts.ArtistRegistry"

-- Where Custom Artists appears in the stock menus

local function openGrid()
    menu.open("CustomArtists_grid")
end

event.menu.add("addCustomArtistsEntry", { key = "customize", sequence = 1 }, function(ev)
    local entries = ev.menu and ev.menu.entries

    if type(entries) ~= "table" then
        return
    end

    local index = math.max(#entries - 1, 0)

    for i, entry in ipairs(entries) do
        if entry.id == "audio.changeSoundtrack" or entry.id == "audio.customMusic" then
            index = i
        end

        -- Every Custom Music playlist is a custom artist, and Custom Artists offers the same tools
        if entry.id == "audio.customMusic" then
            entry.hidden = true
        end
    end

    table.insert(entries, index + 1, {
        id = "CustomArtists_open",
        label = "Custom Artists",
        action = openGrid,
    })
end)

-- Audio options list settings by key, so the stock Custom Music action is swapped in place
event.menu.add("replaceAudioCustomMusicEntry", { key = "settings", sequence = 1 }, function(ev)
    local entries = ev.menu and ev.menu.entries

    if type(entries) ~= "table" then
        return
    end

    for i, entry in ipairs(entries) do
        if entry.id == "audio.customMusic" then
            entries[i] = {
                id = "CustomArtists_open",
                label = "Custom Artists",
                action = openGrid,
            }
        end
    end
end)

-- The stock Change Soundtrack menu reads excludeFromOptions, order and enum names while it builds its dropdowns
event.menu.add("applyArtistOverrides", { key = "changeSoundtrack", sequence = -1 }, function()
    registry.applyChangeSoundtrackOverrides()
end)

-- A dropdown's label names the artist it is set to, and resolves while the menu draws rather than now. Characters
-- without a soundtrack of their own name the default one, so a custom default shows up in every one of their rows.
event.menu.add("restoreArtistOverrides", { key = "changeSoundtrack", sequence = 1 }, function(ev)
    for _, entry in ipairs(ev.menu and ev.menu.entries or {}) do
        if entry.hasDropdown and type(entry.label) == "function" then
            local label = entry.label

            entry.label = function(...)
                return registry.withArtistTitles(label, ...)
            end
        end
    end

    registry.restoreChangeSoundtrackOverrides()
end)
