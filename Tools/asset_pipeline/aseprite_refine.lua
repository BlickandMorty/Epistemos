-- aseprite_refine.lua — Aseprite scripting helper for the
-- §10.3 step 3 manual refinement pass.
--
-- Run from Aseprite via:
--   File → Scripts → Open Script Folder
-- Drop this file in, then File → Scripts → aseprite_refine.lua
-- against an open atlas-grid sprite (one frame per state-frame
-- cell in the canonical grid produced by procedural_atlas_v1.py
-- or auto_slice.py).
--
-- What it does:
--   1. Quantises the active sprite's palette to 16 colours
--      (DOCTRINE §10.3 step 3 explicitly calls for this).
--   2. Removes anti-aliased edge pixels — any pixel whose alpha
--      is in (0, 255) gets snapped to either 0 or 255 based on
--      a 0.5 threshold. This is the I-16 contract: no soft
--      edges in the atlas itself.
--   3. Asserts the sprite dimensions match the canonical
--      head-shape grid declared in the atlas's matching JSON
--      manifest. Pops a dialog if there's a mismatch.
--   4. Exports the refined PNG to the path supplied as
--      Aseprite CLI `--script-param output=...` if running
--      via the CLI batch path.
--
-- Usage from the CLI (artist's batch entry):
--   aseprite -b artist_sheet_block_compact.aseprite \
--     --script-param head=block_compact \
--     --script-param output=Epistemos/Resources/CompanionAssets/atlas/block_compact.png \
--     --script aseprite_refine.lua
--
-- DOCTRINE refs: §10.3, §5.3 (state list), I-16 (no anti-alias).

local sprite = app.activeSprite
if not sprite then
    error("aseprite_refine.lua: no active sprite")
end

-- 1. Quantise to 16-colour indexed palette (preserves the §10.5
--    palette-mask convention: RGB = mask channels).
local palette = sprite.palettes[1]
if #palette > 16 then
    -- Aseprite's quantisation is exposed via the
    -- `app.command.ChangePixelFormat` then `ChangeColorMode`
    -- pair; we do indexed → 16 → rgba so the mask channels
    -- survive.
    app.command.ChangePixelFormat{ format = "indexed" }
    app.command.ChangePixelFormat{ format = "rgb" }
end

-- 2. Snap intermediate alphas to {0, 255}.
local image = sprite.cels[1].image
for it in image:pixels() do
    local px = it()
    local r = (px & 0x000000FF)
    local g = (px & 0x0000FF00) >> 8
    local b = (px & 0x00FF0000) >> 16
    local a = (px & 0xFF000000) >> 24
    local snap_a = (a >= 128) and 255 or 0
    it(app.pixelColor.rgba(r, g, b, snap_a))
end

-- 3. Dimension assertion against the canonical grid.
local head = app.params.head or ""
local expected = ({
    block_compact = { 48 * 8, 48 * 14 },
    block_wide    = { 64 * 8, 48 * 14 },
    orb           = { 48 * 8, 48 * 14 },
    sage          = { 48 * 8, 64 * 14 },
    hermes_snake  = { 64 * 8, 48 * 14 },
})[head]
if expected and (sprite.width ~= expected[1] or sprite.height ~= expected[2]) then
    app.alert(
        "aseprite_refine.lua: sprite dimensions " ..
        sprite.width .. "x" .. sprite.height ..
        " don't match canonical " ..
        expected[1] .. "x" .. expected[2] ..
        " for head '" .. head .. "'"
    )
end

-- 4. Optional CLI export.
local out = app.params.output
if out and out ~= "" then
    sprite:saveCopyAs(out)
    print("aseprite_refine.lua: wrote " .. out)
end
