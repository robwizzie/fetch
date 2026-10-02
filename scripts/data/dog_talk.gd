class_name DogTalk
extends RefCounted
## Every bit of dog-flavoured patter the game says out loud, in one place. The same "BONK!" on
## every knockout stops being read after the third one; a small rotating pool keeps the callouts
## worth glancing at without ever making them long enough to cost a player their eyes.

const KNOCKOUTS: Array[String] = ["BONK!", "RUFF!", "YELP!", "OOF!", "WHUMP!", "BAD DOG!"]
## Bonked by your own toy coming back off a wall.
const SELF_BONKS: Array[String] = ["SELF-BONK!", "CHASED OWN TAIL!", "WHO THREW THAT?!", "BONKED BY OWN TOY!"]
const CATCHES: Array[String] = ["CATCH!", "CHOMP!", "GOOD CATCH!", "NICE MOUTH!", "GOTCHA!"]
const DISARMS: Array[String] = ["DROP IT!", "LEAVE IT!", "MINE NOW!"]
## A throw knocked away by the toy in your mouth.
const MOUTH_BLOCKS: Array[String] = ["BLOCKED!", "CLANK!", "NOT TODAY!", "NICE PARRY!"]
const SHIELD_POPS: Array[String] = ["BLOCKED!", "SHIELD SAVE!", "NOT TODAY!"]
const ROUND_WINS: Array[String] = [
	"%s wins the round!",
	"%s fetches the round!",
	"Who's a good dog? %s is!",
	"%s takes the bone!",
	"%s is top dog!",
	"Treats for %s!",
]
const DRAWS: Array[String] = ["Draw! Fetch again.", "Nobody's a good dog. Again!", "Everybody's in the doghouse!"]
const LOADING: Array[String] = [
	"Getting the pack together…",
	"Sniffing out the toys…",
	"Burying a few bones…",
	"Chasing tails. Nearly caught one…",
	"Hiding the squeaky ones from the cat…",
	"Fluffing the dog beds…",
]
const MATCH_BRAGS: Array[String] = [
	"The goodest dog in the whole park.",
	"Extra belly rubs tonight.",
	"First pick of the treat jar.",
	"Gets the good spot on the couch.",
	"Tail has not stopped wagging.",
]


static func knockout() -> String:
	return KNOCKOUTS.pick_random()


static func self_bonk() -> String:
	return SELF_BONKS.pick_random()


static func catch_line() -> String:
	return CATCHES.pick_random()


static func disarm() -> String:
	return DISARMS.pick_random()


static func mouth_block() -> String:
	return MOUTH_BLOCKS.pick_random()


static func shield_pop() -> String:
	return SHIELD_POPS.pick_random()


static func round_win(winner_name: String) -> String:
	return ROUND_WINS.pick_random() % winner_name


static func draw() -> String:
	return DRAWS.pick_random()


static func loading_line() -> String:
	return LOADING.pick_random()


static func match_brag() -> String:
	return MATCH_BRAGS.pick_random()


## Where a dog finished, in dog-show terms: first is top dog, last is in the doghouse.
static func placing(place: int, of: int) -> String:
	if place == 1:
		return "TOP DOG"
	if place == of and of > 2:
		return "IN THE DOGHOUSE"
	if place == 2:
		return "GOOD PUP"
	return "GOOD EFFORT"
