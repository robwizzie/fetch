class_name Palette
extends RefCounted
## The game's colours, measured from the cover art rather than invented.
##
## Every value here was sampled from images/fetch-home-screen.png: the band means down the
## image and the most common saturated pixels in it. That art is what the game is supposed to
## look like, so maps, menus and props all read from this one place instead of each drifting
## to its own idea of "green".
##
## Sampled figures, for anyone who wants to re-derive them:
##   sky band #8aab96 · canopy #98a083 · mid #ae9062 · grass #b5ae5d · foreground #9dac34
##   most common saturated pixels: #b3c436 (7757), #ce793c (1989), #dfc24c (1671), #5ab7fc (1512)

## The single most common saturated colour in the art: sunlit grass, warm and yellow-leaning.
## The old arenas used a cool #527538 and that is the main reason they looked nothing like it.
const GRASS := Color("8fae3a")
const GRASS_LIT := Color("b3c436")
const GRASS_DEEP := Color("6d8c2c")
## Ground outside the fence: darker, so the playfield reads as the bright part.
const GRASS_SURROUND := Color("4e6b22")

const SKY := Color("5ab7fc")
const SKY_PALE := Color("a9def0")

## Fences, crates, doghouses. The warm brown the cover uses for everything wooden.
const WOOD := Color("ce793c")
const WOOD_DARK := Color("9a5427")
const WOOD_LIGHT := Color("e39a5e")

## The golden yellow the logo and highlights use.
const GOLD := Color("dfc24c")
const LEAF := Color("4ea015")
const LEAF_LIGHT := Color("6fbf2e")

## Sunlight in the cover is warm, bright and high-key. Arenas key off these so a new map
## does not have to guess at its own lighting.
const SUN_COLOR := Color("fff4e0")
const SUN_ENERGY := 1.05
const AMBIENT_COLOR := Color("cfe4ff")
const AMBIENT_ENERGY := 0.78

## How dark a prop's contact shadow is. Enough to seat it on the ground, not enough to read
## as a second object.
const CONTACT_SHADOW := Color(0.10, 0.14, 0.06, 0.34)


## Nudges a colour toward the cover's look: a little warmer and a little more saturated, which
## is most of the difference between the old flat props and the art.
static func enrich(base: Color, amount: float = 0.12) -> Color:
	var out := base
	out.s = clampf(out.s + amount, 0.0, 1.0)
	out.h = lerpf(out.h, GOLD.h, amount * 0.25) if absf(out.h - GOLD.h) < 0.25 else out.h
	return out
