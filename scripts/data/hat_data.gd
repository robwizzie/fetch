class_name HatData
extends Resource
## A hat any dog can wear. Hats are earned by playing - each one names the lifetime stat that
## unlocks it and how much of it - and picked on the dog select screen. Content is data: add a
## hat by adding a .tres in data/hats/.

enum Style { PARTY, CAP, FLOWERS, PROPELLER, CHEF, COWBOY, VIKING, TOP_HAT, HALO, CROWN }

@export var id: StringName = &"party_hat"
@export var display_name: String = "Party Hat"
## How to earn it, shown while it is still locked.
@export var unlock_text: String = "Yours from the start"
## The Progress stat that unlocks it; empty means it is unlocked from the start.
@export var stat: StringName = &""
@export var threshold: int = 0
@export var style: Style = Style.PARTY
@export var color: Color = Color("e94b5a")
@export var accent: Color = Color("f6d34a")


## The leader's crown - not a hat anyone earns, but worn the same way by whoever is in front.
static func crown() -> HatData:
	var hat := HatData.new()
	hat.id = &"crown"
	hat.display_name = "Crown"
	hat.style = Style.CROWN
	hat.color = Color("f2cf4c")
	hat.accent = Color("e94b5a")
	return hat
