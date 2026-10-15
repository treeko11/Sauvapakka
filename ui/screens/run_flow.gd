class_name RunFlow
extends RefCounted
## Moves a run through its screens: Preview, Workshop, Choose, Duel, then
## Reward or the end of the run.

var app: App
var run: RunState


func _init(p_app: App, p_seed: int) -> void:
	app = p_app
	run = RunState.create(app.db, p_seed)


func show_preview() -> void:
	app.show_screen(PreviewScreen.new(self))


func start_workshop() -> void:
	run.deal_hand()
	show_workshop()


func show_workshop() -> void:
	app.show_screen(Workshop.new(self))


func show_book() -> void:
	app.show_screen(SpellBookScreen.new(self))


func show_choose() -> void:
	app.show_screen(ChooseScreen.new(self))


func test_wand(wand_i: int) -> void:
	var dummy := WandBuild.new()
	dummy.display_name = "Training Dummy"
	dummy.frame = load(RunState.STARTER_FRAME)
	var screen := DuelScreen.new()
	screen.setup(run.wands[wand_i], dummy, app.db, 0, false, true)
	screen.continue_text = "Back to workshop"
	screen.finished.connect(func(_w: int) -> void: show_workshop())
	app.show_screen(screen)


func fight(wand_i: int) -> void:
	var screen := DuelScreen.new()
	screen.setup_factory(run.make_duel.bind(wand_i), app.db)
	screen.enemy_robe = run.current_fight()["def"].robe
	screen.finished.connect(func(_w: int) -> void: _after_fight(screen.duel))
	app.show_screen(screen)


func _after_fight(d: Duel) -> void:
	run.finish_fight(d)
	match run.phase:
		RunState.Phase.REWARD:
			app.show_screen(RewardScreen.new(self))
		_:
			app.show_screen(RunEndScreen.new(self))


func take_rewards(choice: String, frame_target: int) -> void:
	run.take_rewards(choice, frame_target)
	show_preview()
