# Shelved modes

`Game._load_dir` lists files, not folders, so anything in here is out of the mode picker and the
gallery while staying in the repo. Move a `.tres` back up one level - with a `mode_script` - and it
returns.

- **Pack Battle** and **Custom Match** were never separate rules: teams are the setup screen's
  "Two packs" option, and every custom rule lives on the setup screen too.
- **Fetch Frenzy**, **Treat Hunt** and **Squirrel!** were ideas without rules written yet. Golden Ball
  (the fourth) was finished and lives in `data/modes/10_golden_ball.tres`.
