extends Node
## Global signal bus. Anything can listen without holding references to gameplay nodes.
## Emitted by gameplay code, consumed by HUD, modes, audio, stats, etc.

signal player_joined(slot: PlayerSlot)
signal player_left(slot: PlayerSlot)

signal round_started(round_number: int)
signal round_over(winner: PlayerSlot)          ## winner is null on a draw
signal match_over(winner: PlayerSlot)

signal toy_thrown(toy: Node, by: Node)
## A knockout worth shouting about (see Highlights): kind, who earned it, who it was on.
signal highlight(kind: StringName, by: PlayerSlot, victim: PlayerSlot)
## A downed dog was brought back by a pack-mate.
signal dog_revived(dog: Node, by: Node)
## A dog barked (the taunt button).
signal dog_barked(dog: Node)
## A wind-up just reached full power.
signal throw_charged(dog: Node)
## A bare-pawed dog swiped at another: the target dropped its toy or went dizzy.
signal dog_whacked(dog: Node, by: Node)
## A crate was opened; the kind was a mystery until this moment.
signal powerup_collected(dog: Node, kind: StringName)
signal toy_caught(toy: Node, by: Node)
signal dog_eliminated(dog: Node, by_toy: Node)
