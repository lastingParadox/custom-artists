local alphaBlendFilter = require "necro.render.filter.AlphaBlendFilter"
local animations = require "necro.render.level.Animations"
local gameDLC = require "necro.game.data.resource.GameDLC"
local menu = require "necro.menu.Menu"
local player = require "necro.game.character.Player"
local playerList = require "necro.client.PlayerList"
local progression = require "necro.game.system.Progression"

local grayscaleFilter = require "necro.render.filter.GrayscaleFilter"

local color = require "system.utils.Color"
local ecs = require "system.game.Entities"
local gfx = require "system.gfx.GFX"
local try = require "system.utils.Try"

local songRandomizer = require "CustomArtists.scripts.randomizer.Randomizer"

-- Unlocked characters with a checkbox each, in the grid layout Change Skin uses

local MAX_MENU_WIDTH = 760
local MIN_COLUMN_WIDTH = 200
local MAX_COLUMNS = 3
local CELL_HEIGHT = 50
local ICON_WIDTH = 60
local MENU_V_MARGIN = 12

local function getLayout()
    local menuWidth = math.min(gfx.getWidth(), MAX_MENU_WIDTH)
    local columns = math.max(1, math.min(math.floor(menuWidth / MIN_COLUMN_WIDTH), MAX_COLUMNS))

    return {
        menuWidth = menuWidth,
        columns = columns,
        cellWidth = math.floor((menuWidth - 12) / columns),
    }
end

local iconPaths = {}

local function getIconPath(name)
    local body = ecs.getEntityPrototype(name)

    if not body or not body.sprite then
        return nil
    end

    local head = body.characterWithAttachment and ecs.getEntityPrototype(body.characterWithAttachment.attachmentType)

    if not head or not head.sprite then
        return "/" .. body.sprite.texture
    end

    return alphaBlendFilter.getPath({
        crop = true,
        src = "/" .. head.sprite.texture,
        dst = "/" .. body.sprite.texture,
        x = head.attachmentCopySpritePosition and -head.attachmentCopySpritePosition.offsetX or 0,
        y = head.attachmentCopySpritePosition and -head.attachmentCopySpritePosition.offsetY or 0,
    })
end

--- The character's animated sprite as an entry of its own, so the name keeps the rest of the cell
local function getIconEntry(name, x, y, randomized)
    if iconPaths[name] == nil then
        iconPaths[name] = try.getOrNil(getIconPath, name) or false
    end

    local image = iconPaths[name]
    local entity = ecs.getEntityPrototype(name)

    if not image or not entity or not entity.sprite or not entity.normalAnimation then
        return nil
    end

    local width, height = entity.sprite.width, entity.sprite.height

    if not randomized then
        image = grayscaleFilter.getPath(image)
    end

    return {
        x = x,
        y = y,
        label = "          ",
        alignX = 0,
        maxWidth = ICON_WIDTH,
        color = color.WHITE,
        icon = function()
            return {
                image = image,
                imageRect = { (animations.getAnimationFrame(entity, "normalAnimation") - 1) * width, 0, width, height },
                width = width,
                height = height,
                color = color.opacity(randomized and 1 or 0.5),
            }
        end,
    }
end

local function getName(name)
    local entity = ecs.getEntityPrototype(name)

    return entity and entity.friendlyName and entity.friendlyName.name or name
end

local function isUnlocked(name)
    return gameDLC.isCharacterOwned(name) and (progression.isCharacterUnlocked(name)
        or progression.isLocallyUnlocked(progression.UnlockType.PLAYABLE_CHARACTER, name))
end

local function getLobbyOrder(name)
    local entity = ecs.getEntityPrototype(name)

    return entity and entity.playableCharacter and entity.playableCharacter.lobbyOrder or 0
end

--- The order Change Skin lists characters in: modded ones last, then by lobby order and name
local function compareCharacters(name1, name2)
    local modded1, modded2 = name1:match("_") and 1 or 0, name2:match("_") and 1 or 0

    if modded1 ~= modded2 then
        return modded1 < modded2
    end

    local order1, order2 = getLobbyOrder(name1), getLobbyOrder(name2)

    if order1 ~= order2 then
        return order1 < order2
    end

    return name1 < name2
end

event.menu.add("customArtistsSongRandomizerCharacters", "CustomArtists_songRandomizerCharacters", function(ev)
    local characters = {}
    local playerCharacter = player.getCharacterType(playerList.getLocalPlayerID())

    for _, character in ipairs(player.getPlayableCharacterTypes()) do
        if isUnlocked(character) or character == playerCharacter then
            characters[#characters + 1] = character
        end
    end

    table.sort(characters, compareCharacters)

    local layout = getLayout()
    local columns = layout.columns
    local left = -math.floor(layout.menuWidth / 2)
    local top = MENU_V_MARGIN + 10
    local labels, icons = {}, {}

    --- Moves a whole cell at a time, leaving the grid for Done at either end
    local function step(index, diff)
        return function()
            menu.selectByID(characters[index + diff] or "done")
            menu.playSelectionSound(diff)
        end
    end

    for index, character in ipairs(characters) do
        local column = (index - 1) % columns
        local cellX = left + column * layout.cellWidth
        local cellY = top + math.ceil(index / columns) * CELL_HEIGHT
        local randomized = songRandomizer.isCharacterRandomized(character)

        labels[#labels + 1] = {
            id = character,
            label = getName(character),
            action = function()
                songRandomizer.setCharacterRandomized(character, not randomized)
                menu.update()
            end,
            alignX = 0,
            hideArrows = true,
            x = cellX + ICON_WIDTH,
            y = cellY,
            maxWidth = layout.cellWidth - ICON_WIDTH,
            color = not randomized and color.gray(0.5) or nil,
            selectedColor = not randomized and color.gray(0.8) or nil,
            selected = character == playerCharacter,
            leftAction = column > 0 and step(index, -1) or nil,
            rightAction = column < columns - 1 and characters[index + 1] and step(index, 1) or nil,
            upAction = step(index, -columns),
            downAction = step(index, columns),
            leftSound = "",
            rightSound = "",
        }

        icons[#icons + 1] = getIconEntry(character, cellX, cellY - 6, randomized)
    end

    local entries = {}

    for _, label in ipairs(labels) do
        entries[#entries + 1] = label
    end

    for _, icon in ipairs(icons) do
        entries[#entries + 1] = icon
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

    ev.menu = {
        label = "Randomized characters",
        entries = entries,
        escapeAction = function()
            menu.close()
        end,
    }
end)
