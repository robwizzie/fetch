class_name LastDogStanding
extends GameMode
## Free-for-all: the round ends when one (or zero) dogs are left alive.


func is_round_over(dogs: Array[Dog]) -> bool:
	var alive := _alive(dogs)
	if dogs.size() <= 1:
		return alive.is_empty()
	return alive.size() <= 1


func round_winner(dogs: Array[Dog]) -> PlayerSlot:
	var alive := _alive(dogs)
	return alive[0].slot if alive.size() == 1 else null


func hud_hint() -> String:
	return "Last dog standing wins the round"


func _alive(dogs: Array[Dog]) -> Array[Dog]:
	var out: Array[Dog] = []
	for d in dogs:
		if d.alive:
			out.append(d)
	return out
