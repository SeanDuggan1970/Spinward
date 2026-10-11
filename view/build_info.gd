## Which build this is, for the title screen: the deploy writes res://build_id.txt
## (run number and commit, as itch.io shows it) before exporting. Run from a clone
## (Play.cmd, the editor) there is no such file, so it reads the checkout's commit and
## branch from .git, so an out-of-date local copy is easy to spot.
extends RefCounted

const BUILD_FILE := "res://build_id.txt"

static var _text := ""


static func text() -> String:
	if _text == "":
		_text = _read()
	return _text


static func _read() -> String:
	if FileAccess.file_exists(BUILD_FILE):
		var id := FileAccess.get_file_as_string(BUILD_FILE).strip_edges()
		if id != "":
			return "build " + id
	var git := _git_dir()
	if git == "":
		return "dev build"
	var head := FileAccess.get_file_as_string(git.path_join("HEAD")).strip_edges()
	if not head.begins_with("ref: "):
		return "dev %s" % head.left(7) if head.length() >= 7 else "dev build"
	var ref := head.trim_prefix("ref: ")
	var branch := ref.trim_prefix("refs/heads/")
	var sha := FileAccess.get_file_as_string(git.path_join(ref)).strip_edges() if FileAccess.file_exists(git.path_join(ref)) else ""
	if sha == "":
		for line in FileAccess.get_file_as_string(git.path_join("packed-refs")).split("\n"):
			if line.ends_with(" " + ref):
				sha = line.get_slice(" ", 0)
	return "dev %s (%s)" % [sha.left(7), branch] if sha != "" else "dev (%s)" % branch


## The checkout's git directory: .git, or where a worktree's .git file points.
static func _git_dir() -> String:
	var root := ProjectSettings.globalize_path("res://")
	if root == "" or root.begins_with("res://"):
		return ""
	var dot := root.path_join(".git")
	if DirAccess.dir_exists_absolute(dot):
		return dot
	if FileAccess.file_exists(dot):
		var line := FileAccess.get_file_as_string(dot).strip_edges()
		if line.begins_with("gitdir: "):
			var dir := line.trim_prefix("gitdir: ")
			return dir if dir.is_absolute_path() else root.path_join(dir)
	return ""
