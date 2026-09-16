extends SceneTree
## godot --headless --path . --script tools/asset_pipeline/validate_dogs.gd [-- --strict]
## --strict fails if any dog is technically invalid OR still awaiting likeness review.


func _initialize() -> void:
	var failures := 0
	var files := DirAccess.get_files_at("res://data/dogs")
	files.sort()
	for file in files:
		if not file.ends_with(".tres"):
			continue
		var data := load("res://data/dogs/" + file) as DogData
		if data == null:
			printerr("[asset-audit] Cannot load " + file)
			failures += 1
			continue
		var report := DogAssetValidator.inspect(data)
		print("[asset-audit] %s: %s; likeness %s" % [data.display_name,
			"technical PASS" if report.valid else "technical MISSING/INVALID",
			"reviewed" if report.likeness_reviewed else "NOT REVIEWED"])
		for issue in report.errors:
			print("  ERROR: " + issue)
		for warning in report.warnings:
			print("  REVIEW: " + warning)
		if not report.valid or not report.likeness_reviewed:
			failures += 1
	print("[asset-audit] %d dogs require delivery or review. Read assets/models/dogs/README.md." % failures)
	quit(1 if failures > 0 and OS.get_cmdline_user_args().has("--strict") else 0)
