local ui = require "necro.render.UI"

local utils = require "system.utils.Utilities"

local Fonts = {}

Fonts.smallLowercase = utils.mergeDefaults(ui.Font.SMALL, { uppercase = false })
Fonts.mediumLowercase = utils.mergeDefaults(ui.Font.MEDIUM, { uppercase = false })
Fonts.singleLine = utils.mergeDefaults(ui.Font.MEDIUM, { maxHeight = (ui.Font.MEDIUM.size + 1) * 2 })
Fonts.hint = utils.mergeDefaults(ui.Font.SMALL, { wordWrap = true })

return Fonts
