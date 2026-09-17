class_name LastDogStanding
extends GameMode
## The round ends when one side is left standing: one dog in a free-for-all, or one pack when
## teams are on.


func is_round_over(dogs: Array[Dog]) -> bool:
	var alive := _alive(dogs)
	if dogs.size() <= 1:
		return alive.is_empty()
	if Game.team_mode:
		# A pack with two dogs left is still fighting; the round ends when only one side remains.
		return _sides(alive).size() <= 1
	return alive.size() <= 1


func round_winner(dogs: Array[Dog]) -> PlayerSlot:
	var alive := _alive(dogs)
	if alive.is_empty():
		return null
	if Game.team_mode:
		# Any survivor stands for their pack; the scoreboard reads the team off the slot.
		return alive[0].slot if _sides(alive).size() == 1 else null
	return alive[0].slot if alive.size() == 1 else null


func hud_hint() -> String:
	return "Last pack standing wins the round" if Game.team_mode else "Last dog standing wins the round"


func _alive(dogs: Array[Dog]) -> Array[Dog]:
	var out: Array[Dog] = []
	for d in dogs:
		if d.alive:
			out.append(d)
	return out


## Which teams still have a dog in the fight.
func _sides(alive: Array[Dog]) -> Array[int]:
	var teams: Array[int] = []
	for d in alive:
		var team: int = d.slot.team if d.slot != null else -1
		if not teams.has(team):
			teams.append(team)
	return teams
