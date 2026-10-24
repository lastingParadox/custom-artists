local menu = require "necro.menu.Menu"
local textFormat = require "necro.config.i18n.TextFormat"

local color = require "system.utils.Color"
local utils = require "system.utils.Utilities"

local fonts = require "CustomArtists.scripts.menu.Fonts"
local songRandomizer = require "CustomArtists.scripts.randomizer.Randomizer"

local Mode = songRandomizer.Mode
local ArtistScope = songRandomizer.ArtistScope
local Duplicates = songRandomizer.Duplicates
local Seeding = songRandomizer.Seeding

local MODES = {
    { value = Mode.OFF, name = "Off", desc = "Every character plays the artist it is set to in the Change Soundtrack menu" },
    {
        value = Mode.RANDOM_ARTIST,
        name = "Random artist",
        desc = "Every area keeps its own song, played by a random artist"
    },
    {
        value = Mode.SHUFFLE_SONGS,
        name = "Shuffle songs",
        desc = "Every song the picked artists have is dealt out across the run"
    },
}

local ARTIST_SCOPES = {
    { value = ArtistScope.PER_RUN,   name = "Per run",   desc = "A random artist will be played each run" },
    { value = ArtistScope.PER_ZONE,  name = "Per zone",  desc = "A random artist will be played each zone" },
    { value = ArtistScope.PER_FLOOR, name = "Per floor", desc = "A random artist will be played each floor" },
}

local DUPLICATES = {
    { value = Duplicates.MINIMAL, name = "Minimal",  desc = "Each song is played once, by whichever artist gets it" },
    { value = Duplicates.PARTIAL, name = "Partial",  desc = "A song can return in another artist's version" },
    { value = Duplicates.COMPLETE, name = "Complete", desc = "Any song can be played repeatedly" },
}

local SEEDINGS = {
    { value = Seeding.PER_CHARACTER, name = "Per character", desc = "Every character keeps its own seeded song list" },
    { value = Seeding.FULLY_RANDOM,  name = "Fully random",  desc = "A new song list every run" },
}

local function findChoice(choices, value)
    for index, choice in ipairs(choices) do
        if choice.value == value then
            return index, choice
        end
    end

    return 1, choices[1]
end

local function note(text)
    return {
        label = textFormat.fade(text),
        font = fonts.smallLowercase,
        selectableIf = false,
    }
end

--- Describes the selected entry at the bottom of the menu, the way the stock settings menus do
local function createFooter()
    local text = ""

    local footer = {
        alignY = 1,
        color = color.gray(0.6),
        font = fonts.hint,
        ignoreWidth = true,
        selectableIf = false,
        sticky = 1,
        y = -14,
        label = function()
            return text
        end,
    }

    return footer, function(currentMenu)
        local entry = menu.getSelectedEntry()
        local desc = entry and entry.customDesc

        if type(desc) == "function" then
            desc = desc()
        end

        text = desc or ""

        -- The rows the hint covers fade out, except the selected one, and Done has no hint to cover it
        local lineCount = select(2, text:gsub("\n", ""))
        local footerSize = text ~= "" and (lineCount + 3) * 14 or 0
        currentMenu.footerSize = utils.lerp(currentMenu.footerSize or footerSize, footerSize, 0.25)
    end
end

event.menu.add("addSongRandomizerEntry", { key = "customize", sequence = 2 }, function(ev)
    local entries = ev.menu and ev.menu.entries

    if type(entries) ~= "table" then
        return
    end

    local index = math.max(#entries - 1, 0)

    for i, entry in ipairs(entries) do
        if entry.id == "CustomArtists_open" then
            index = i
        end
    end

    table.insert(entries, index + 1, {
        id = "CustomArtists_songRandomizer",
        label = "Song Randomizer",
        action = function()
            menu.open("CustomArtists_songRandomizer")
        end,
    })
end)

event.menu.add("customArtistsSongRandomizer", "CustomArtists_songRandomizer", function(ev)
    local entries = {}

    local function addChoice(id, label, choices, getValue, setValue)
        local function step(direction)
            return function()
                local index = findChoice(choices, getValue())
                setValue(choices[(index - 1 + direction) % #choices + 1].value)
                menu.update()
            end
        end

        entries[#entries + 1] = {
            id = id,
            label = function()
                local _, choice = findChoice(choices, getValue())

                return string.format("%s: %s", label, choice.name)
            end,
            customDesc = function()
                local _, choice = findChoice(choices, getValue())

                return choice.desc
            end,
            action = step(1),
            leftAction = step(-1),
            rightAction = step(1),
        }
    end

    addChoice("mode", "Mode", MODES, songRandomizer.getMode, songRandomizer.setMode)

    local mode = songRandomizer.getMode()

    if mode == Mode.RANDOM_ARTIST then
        addChoice("artistScope", "New artist", ARTIST_SCOPES, songRandomizer.getArtistScope,
            songRandomizer.setArtistScope)
    elseif mode == Mode.SHUFFLE_SONGS then
        addChoice("seeding", "Shuffle", SEEDINGS, songRandomizer.getSeeding, songRandomizer.setSeeding)
        addChoice("duplicates", "Song duplication", DUPLICATES, songRandomizer.getDuplicates,
            songRandomizer.setDuplicates)

        if songRandomizer.getSeeding() == Seeding.PER_CHARACTER then
            entries[#entries + 1] = {
                id = "reshuffle",
                label = "Reshuffle Songs",
                customDesc = "Deals every character a new shuffled songlist",
                action = songRandomizer.reshuffle,
            }
        end
    end

    entries[#entries + 1] = {
        id = "characters",
        label = "Toggle Characters",
        customDesc = "Pick which characters will be affected by the song randomizer",
        action = function()
            menu.open("CustomArtists_songRandomizerCharacters")
        end,
    }

    entries[#entries + 1] = {
        id = "customArtists",
        label = "Toggle Custom Artists",
        customDesc = "Pick which artists will be included in the song randomizer",
        action = function()
            menu.open("CustomArtists_grid")
        end,
    }

    local overridden, source = songRandomizer.isOverridden()

    if overridden then
        -- The name comes from another mod, so it is trimmed to something a menu row can hold
        entries[#entries + 1] = note(string.format("%s is affecting the randomizer right now",
            source and source:sub(1, 32) or "Another mod"))
    end

    entries[#entries + 1] = { height = 0 }
    entries[#entries + 1] = {
        id = "done",
        label = "Done",
        sound = "UIBack",
        action = function()
            menu.close()
        end,
    }

    local footer, tickCallback = createFooter()
    entries[#entries + 1] = footer

    ev.menu = {
        label = "Song Randomizer",
        entries = entries,
        tickCallback = tickCallback,
        escapeAction = function()
            menu.close()
        end,
    }
end)
