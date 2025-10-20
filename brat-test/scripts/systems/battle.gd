# battle.gd (ПОШАГОВЫЙ БОЙ)
extends CanvasLayer

signal battle_ended(victory: bool)

var player_hp: int = 100
var player_max_hp: int = 100
var enemy_hp: int = 80
var enemy_max_hp: int = 80
var enemy_name: String = "Гопник"
var turn: String = "player"
var defense: bool = false
var buttons_locked: bool = false  # НОВОЕ: Блокировка кнопок
var is_first_battle: bool = false  # НОВОЕ: Первый бой (обучение)

var player_stats
var player_data
var battle_log_lines: Array = []
var max_log_lines: int = 15

func _ready():
	layer = 200  # # ✅ Layer = 200 (Бой выше всего кроме Банды/Инвентаря)
	
	player_stats = get_node("/root/PlayerStats")
	create_ui()

func setup(p_data: Dictionary, enemy_type: String = "gopnik", first_battle: bool = false):
	player_data = p_data
	is_first_battle = first_battle
	
	if player_data and player_data.has("health"):
		player_hp = player_data["health"]
	else:
		player_hp = 100
	
	player_max_hp = 100
	
	match enemy_type:
		"drunkard":
			enemy_name = "Пьяный"
			enemy_hp = 40
			enemy_max_hp = 40
		"gopnik":
			enemy_name = "Гопник"
			enemy_hp = 60
			enemy_max_hp = 60
		"thug":
			enemy_name = "Хулиган"
			enemy_hp = 80
			enemy_max_hp = 80
		"bandit":
			enemy_name = "Бандит"
			enemy_hp = 100
			enemy_max_hp = 100
		"guard":
			enemy_name = "Охранник"
			enemy_hp = 120
			enemy_max_hp = 120
		"boss":
			enemy_name = "Главарь"
			enemy_hp = 200
			enemy_max_hp = 200
	
	update_ui()
	
	if is_first_battle:
		add_to_log("⚠️ ПЕРВЫЙ БОЙ - убежать нельзя!")
	add_to_log("⚔️ Бой начался! " + enemy_name + " (HP: " + str(enemy_hp) + ")")

func create_ui():
	var bg = ColorRect.new()
	bg.size = Vector2(700, 900)
	bg.position = Vector2(10, 190)
	bg.color = Color(0.1, 0.05, 0.05, 0.95)
	bg.name = "BattleBG"
	add_child(bg)
	
	var title = Label.new()
	title.text = "⚔️ БОЙ"
	title.position = Vector2(320, 210)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))
	add_child(title)
	
	# HP игрока
	var player_label = Label.new()
	player_label.text = "ВЫ"
	player_label.position = Vector2(50, 280)
	player_label.add_theme_font_size_override("font_size", 24)
	player_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3, 1.0))
	add_child(player_label)
	
	var player_hp_bar = ColorRect.new()
	player_hp_bar.size = Vector2(300, 30)
	player_hp_bar.position = Vector2(50, 320)
	player_hp_bar.color = Color(0.2, 0.2, 0.2, 1.0)
	player_hp_bar.name = "PlayerHPBG"
	add_child(player_hp_bar)
	
	var player_hp_fill = ColorRect.new()
	player_hp_fill.size = Vector2(300, 30)
	player_hp_fill.position = Vector2(50, 320)
	player_hp_fill.color = Color(0.3, 1.0, 0.3, 1.0)
	player_hp_fill.name = "PlayerHPFill"
	add_child(player_hp_fill)
	
	var player_hp_text = Label.new()
	player_hp_text.text = "HP: 100/100"
	player_hp_text.position = Vector2(150, 325)
	player_hp_text.add_theme_font_size_override("font_size", 18)
	player_hp_text.add_theme_color_override("font_color", Color.BLACK)
	player_hp_text.name = "PlayerHPText"
	add_child(player_hp_text)
	
	# HP врага
	var enemy_label = Label.new()
	enemy_label.text = "ВРАГ"
	enemy_label.position = Vector2(400, 280)
	enemy_label.add_theme_font_size_override("font_size", 24)
	enemy_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))
	enemy_label.name = "EnemyLabel"
	add_child(enemy_label)
	
	var enemy_hp_bar = ColorRect.new()
	enemy_hp_bar.size = Vector2(300, 30)
	enemy_hp_bar.position = Vector2(370, 320)
	enemy_hp_bar.color = Color(0.2, 0.2, 0.2, 1.0)
	enemy_hp_bar.name = "EnemyHPBG"
	add_child(enemy_hp_bar)
	
	var enemy_hp_fill = ColorRect.new()
	enemy_hp_fill.size = Vector2(300, 30)
	enemy_hp_fill.position = Vector2(370, 320)
	enemy_hp_fill.color = Color(1.0, 0.3, 0.3, 1.0)
	enemy_hp_fill.name = "EnemyHPFill"
	add_child(enemy_hp_fill)
	
	var enemy_hp_text = Label.new()
	enemy_hp_text.text = "HP: 80/80"
	enemy_hp_text.position = Vector2(470, 325)
	enemy_hp_text.add_theme_font_size_override("font_size", 18)
	enemy_hp_text.add_theme_color_override("font_color", Color.BLACK)
	enemy_hp_text.name = "EnemyHPText"
	add_child(enemy_hp_text)
	
	# Лог боя
	var log_scroll = ScrollContainer.new()
	log_scroll.custom_minimum_size = Vector2(660, 250)
	log_scroll.position = Vector2(30, 380)
	log_scroll.name = "LogScroll"
	log_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(log_scroll)
	
	var log_bg = ColorRect.new()
	log_bg.size = Vector2(660, 250)
	log_bg.position = Vector2(30, 380)
	log_bg.color = Color(0.05, 0.05, 0.05, 1.0)
	log_bg.z_index = -1
	add_child(log_bg)
	
	var log_vbox = VBoxContainer.new()
	log_vbox.name = "LogVBox"
	log_vbox.custom_minimum_size = Vector2(640, 0)
	log_scroll.add_child(log_vbox)
	
	# Кнопки действий
	var attack_btn = Button.new()
	attack_btn.custom_minimum_size = Vector2(200, 60)
	attack_btn.position = Vector2(40, 670)
	attack_btn.text = "⚔️ АТАКА"
	attack_btn.name = "AttackBtn"
	
	var style_attack = StyleBoxFlat.new()
	style_attack.bg_color = Color(0.7, 0.2, 0.2, 1.0)
	attack_btn.add_theme_stylebox_override("normal", style_attack)
	attack_btn.add_theme_font_size_override("font_size", 22)
	attack_btn.pressed.connect(func(): on_attack())
	add_child(attack_btn)
	
	var defend_btn = Button.new()
	defend_btn.custom_minimum_size = Vector2(200, 60)
	defend_btn.position = Vector2(260, 670)
	defend_btn.text = "🛡️ ЗАЩИТА"
	defend_btn.name = "DefendBtn"
	
	var style_defend = StyleBoxFlat.new()
	style_defend.bg_color = Color(0.2, 0.4, 0.7, 1.0)
	defend_btn.add_theme_stylebox_override("normal", style_defend)
	defend_btn.add_theme_font_size_override("font_size", 22)
	defend_btn.pressed.connect(func(): on_defend())
	add_child(defend_btn)
	
	var run_btn = Button.new()
	run_btn.custom_minimum_size = Vector2(200, 60)
	run_btn.position = Vector2(480, 670)
	run_btn.text = "🏃 БЕЖАТЬ"
	run_btn.name = "RunBtn"
	
	var style_run = StyleBoxFlat.new()
	style_run.bg_color = Color(0.5, 0.5, 0.2, 1.0)
	run_btn.add_theme_stylebox_override("normal", style_run)
	run_btn.add_theme_font_size_override("font_size", 22)
	run_btn.pressed.connect(func(): on_run())
	add_child(run_btn)
	
	var info_label = Label.new()
	info_label.text = "Ваш ход"
	info_label.position = Vector2(300, 760)
	info_label.add_theme_font_size_override("font_size", 20)
	info_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3, 1.0))
	info_label.name = "TurnInfo"
	add_child(info_label)

func update_ui():
	var player_hp_fill = get_node_or_null("PlayerHPFill")
	if player_hp_fill:
		var hp_percent = float(player_hp) / float(player_max_hp)
		player_hp_fill.size.x = 300 * hp_percent
	
	var player_hp_text = get_node_or_null("PlayerHPText")
	if player_hp_text:
		player_hp_text.text = "HP: " + str(player_hp) + "/" + str(player_max_hp)
	
	var enemy_hp_fill = get_node_or_null("EnemyHPFill")
	if enemy_hp_fill:
		var hp_percent = float(enemy_hp) / float(enemy_max_hp)
		enemy_hp_fill.size.x = 300 * hp_percent
	
	var enemy_hp_text = get_node_or_null("EnemyHPText")
	if enemy_hp_text:
		enemy_hp_text.text = "HP: " + str(enemy_hp) + "/" + str(enemy_max_hp)
	
	var enemy_label = get_node_or_null("EnemyLabel")
	if enemy_label:
		enemy_label.text = enemy_name
	
	# НОВОЕ: Блокировка кнопок во время хода врага
	lock_buttons(buttons_locked)

# НОВОЕ: Блокировка/разблокировка кнопок
func lock_buttons(locked: bool):
	var attack_btn = get_node_or_null("AttackBtn")
	var defend_btn = get_node_or_null("DefendBtn")
	var run_btn = get_node_or_null("RunBtn")
	
	if attack_btn:
		attack_btn.disabled = locked
	if defend_btn:
		defend_btn.disabled = locked
	if run_btn:
		run_btn.disabled = locked or is_first_battle  # Первый бой - нельзя убежать

func add_to_log(text: String):
	battle_log_lines.insert(0, text)
	if battle_log_lines.size() > 50:
		battle_log_lines.resize(50)
	update_log_display()

func update_log_display():
	var log_scroll = get_node_or_null("LogScroll")
	if not log_scroll:
		return
	var log_vbox = log_scroll.get_node_or_null("LogVBox")
	if not log_vbox:
		return
	
	for child in log_vbox.get_children():
		child.queue_free()
	
	for i in range(min(max_log_lines, battle_log_lines.size())):
		var log_line = Label.new()
		log_line.text = battle_log_lines[i]
		log_line.add_theme_font_size_override("font_size", 16)
		log_line.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
		log_line.autowrap_mode = TextServer.AUTOWRAP_WORD
		log_line.custom_minimum_size = Vector2(620, 0)
		log_vbox.add_child(log_line)

func on_attack():
	if turn != "player" or buttons_locked:
		return
	
	buttons_locked = true
	lock_buttons(true)
	
	var damage = player_stats.calculate_melee_damage() if player_stats else 5
	
	if randf() > 0.85:
		add_to_log("⚔️ Вы промахнулись!")
	else:
		enemy_hp -= damage
		add_to_log("⚔️ Вы нанесли " + str(damage) + " урона!")
		if player_stats:
			player_stats.on_melee_attack()
	
	update_ui()
	
	if enemy_hp <= 0:
		win_battle()
		return
	
	turn = "enemy"
	var turn_info = get_node_or_null("TurnInfo")
	if turn_info:
		turn_info.text = "Ход противника..."
	
	await get_tree().create_timer(1.5).timeout
	enemy_turn()

func on_defend():
	if turn != "player" or buttons_locked:
		return
	
	buttons_locked = true
	lock_buttons(true)
	
	defense = true
	add_to_log("🛡️ Вы приняли защитную стойку")
	turn = "enemy"
	
	var turn_info = get_node_or_null("TurnInfo")
	if turn_info:
		turn_info.text = "Ход противника..."
	
	await get_tree().create_timer(1.5).timeout
	enemy_turn()

func on_run():
	if turn != "player" or buttons_locked or is_first_battle:
		if is_first_battle:
			add_to_log("⚠️ В первом бою убежать нельзя!")
		return
	
	buttons_locked = true
	lock_buttons(true)
	
	var agi = player_stats.get_stat("AGI") if player_stats else 4
	var run_chance = 0.5 + agi * 0.05
	
	if randf() < run_chance:
		add_to_log("🏃 Вы успешно сбежали!")
		if player_stats:
			player_stats.on_dodge_success()
		await get_tree().create_timer(1.5).timeout
		
		if player_data:
			player_data["health"] = player_hp
		
		battle_ended.emit(false)
		queue_free()
	else:
		add_to_log("🏃 Не удалось сбежать!")
		turn = "enemy"
		
		var turn_info = get_node_or_null("TurnInfo")
		if turn_info:
			turn_info.text = "Ход противника..."
		
		await get_tree().create_timer(1.5).timeout
		enemy_turn()

func enemy_turn():
	if turn != "enemy":
		return
	
	var damage = randi_range(8, 15)
	
	if defense:
		damage = int(damage / 2.0)
		defense = false
		add_to_log("🛡️ Вы заблокировали часть урона!")
	
	var evasion = player_stats.calculate_evasion() if player_stats else 8
	if randf() * 100 < evasion:
		add_to_log("🌀 Вы уклонились от атаки!")
		if player_stats:
			player_stats.on_dodge_success()
	else:
		player_hp -= damage
		add_to_log("💢 " + enemy_name + " нанёс вам " + str(damage) + " урона!")
	
	update_ui()
	
	if player_hp <= 0:
		lose_battle()
		return
	
	turn = "player"
	buttons_locked = false
	lock_buttons(false)
	
	var turn_info = get_node_or_null("TurnInfo")
	if turn_info:
		turn_info.text = "Ваш ход"

func win_battle():
	add_to_log("✅ ПОБЕДА! Враг повержен!")
	
	var reward = randi_range(50, 150)
	
	if player_data:
		player_data["balance"] += reward
		player_data["reputation"] += 5
	
	add_to_log("💰 Получено: " + str(reward) + " руб., +5 репутации")
	
	await get_tree().create_timer(2.5).timeout
	
	if player_data:
		player_data["health"] = player_hp
	
	battle_ended.emit(true)
	queue_free()

func lose_battle():
	add_to_log("💀 ПОРАЖЕНИЕ! Вы проиграли бой...")
	
	if player_data:
		player_data["balance"] = max(0, player_data["balance"] - 50)
	
	add_to_log("💸 Потеряно: 50 руб.")
	
	if is_first_battle:
		add_to_log("📖 Вам нужно заработать деньги и пойти в больницу!")
	
	await get_tree().create_timer(2.5).timeout
	
	if player_data:
		player_data["health"] = 20  # После поражения 20 HP
	
	battle_ended.emit(false)
	queue_free()
