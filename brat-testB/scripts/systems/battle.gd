# battle.gd (ИСПРАВЛЕННЫЙ - правильный доступ к банде)
extends CanvasLayer

signal battle_ended(victory: bool)

# Команды
var player_team: Array = []
var enemy_team: Array = []
var current_turn: String = "player"  # "player" или "enemy"
var current_attacker_index: int = 0
var current_target_index: int = 0
var buttons_locked: bool = false
var is_first_battle: bool = false

# Статистика
var player_stats
var player_data
var battle_log_lines: Array = []
var max_log_lines: int = 15

func _ready():
	layer = 200
	player_stats = get_node("/root/PlayerStats")
	create_ui()

func setup(p_data: Dictionary, enemy_type: String = "gopnik", first_battle: bool = false, p_gang_members: Array = []):
	player_data = p_data
	is_first_battle = first_battle
	
	# Инициализация команды игрока (главный + банда)
	player_team = []
	
	# Главный герой
	player_team.append({
		"name": "Главный (ты)",
		"health": player_data.get("health", 100),
		"max_health": 100,
		"strength": player_stats.get_stat("STR") if player_stats else 10,
		"agility": player_stats.get_stat("AGI") if player_stats else 5,
		"equipment": player_data.get("equipment", {})
	})
	
	# Добавляем банду из переданного массива
	for i in range(min(3, p_gang_members.size())):  # Максимум 3 члена банды в бою
		var member = p_gang_members[i]
		if member["name"] != "Главный (ты)":  # Не дублируем главного
			var team_member = {
				"name": member["name"],
				"health": member.get("health", 80),
				"max_health": member.get("max_health", 80),
				"strength": member.get("strength", 5),
				"agility": member.get("agility", 5),
				"equipment": member.get("equipment", {})
			}
			player_team.append(team_member)
	
	# Инициализация вражеской команды (МАССОВЫЕ БОИ)
	enemy_team = []
	match enemy_type:
		"drunkard":
			create_enemy_team("Пьяный", 2, 30, 3)  # 2 пьяных
		"gopnik":
			if is_first_battle:
				create_enemy_team("Гопник", 2, 50, 4)  # 2 гопника для первого боя
			else:
				create_enemy_team("Гопник", 3, 50, 4)  # 3 гопника обычно
		"thug":
			create_enemy_team("Хулиган", 3, 70, 6)  # 3 хулигана
		"bandit":
			create_enemy_team("Бандит", 4, 80, 8)   # 4 бандита
		"guard":
			create_enemy_team("Охранник", 2, 100, 10) # 2 охранника (сильные)
		"boss":
			create_enemy_team("Главарь", 1, 200, 15)  # Босс
			create_enemy_team("Телохранитель", 2, 80, 8) # + охрана
	
	print("🎯 Создана вражеская команда: " + str(enemy_team.size()) + " врагов")
	
	update_ui()
	add_to_log("⚔️ МАССОВЫЙ БОЙ НАЧАЛСЯ!")
	add_to_log("👥 Ваша команда: " + str(player_team.size()) + " бойцов")
	add_to_log("👹 Врагов: " + str(enemy_team.size()))
	
	if is_first_battle:
		add_to_log("⚠️ ПЕРВЫЙ БОЙ - убежать нельзя!")
	
	start_player_turn()

func create_enemy_team(enemy_name: String, count: int, health: int, strength: int):
	for i in range(count):
		enemy_team.append({
			"name": enemy_name + " " + str(i + 1),
			"health": health,
			"max_health": health,
			"strength": strength,
			"agility": 4
		})

func create_ui():
	var bg = ColorRect.new()
	bg.size = Vector2(700, 900)
	bg.position = Vector2(10, 190)
	bg.color = Color(0.1, 0.05, 0.05, 0.95)
	bg.name = "BattleBG"
	add_child(bg)
	
	var title = Label.new()
	title.text = "⚔️ МАССОВЫЙ БОЙ"
	title.position = Vector2(280, 210)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))
	add_child(title)
	
	# Команда игрока
	var player_title = Label.new()
	player_title.text = "ВАША КОМАНДА:"
	player_title.position = Vector2(50, 260)
	player_title.add_theme_font_size_override("font_size", 20)
	player_title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3, 1.0))
	add_child(player_title)
	
	# Команда врага
	var enemy_title = Label.new()
	enemy_title.text = "ПРОТИВНИКИ:"
	enemy_title.position = Vector2(400, 260)
	enemy_title.add_theme_font_size_override("font_size", 20)
	enemy_title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))
	add_child(enemy_title)
	
	# Лог боя
	var log_scroll = ScrollContainer.new()
	log_scroll.custom_minimum_size = Vector2(660, 200)
	log_scroll.position = Vector2(30, 500)
	log_scroll.name = "LogScroll"
	log_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(log_scroll)
	
	var log_bg = ColorRect.new()
	log_bg.size = Vector2(660, 200)
	log_bg.position = Vector2(30, 500)
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
	attack_btn.position = Vector2(40, 730)
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
	defend_btn.position = Vector2(260, 730)
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
	run_btn.position = Vector2(480, 730)
	run_btn.text = "🏃 БЕЖАТЬ"
	run_btn.name = "RunBtn"
	
	var style_run = StyleBoxFlat.new()
	style_run.bg_color = Color(0.5, 0.5, 0.2, 1.0)
	run_btn.add_theme_stylebox_override("normal", style_run)
	run_btn.add_theme_font_size_override("font_size", 22)
	run_btn.pressed.connect(func(): on_run())
	add_child(run_btn)
	
	var info_label = Label.new()
	info_label.text = "Выберите действие"
	info_label.position = Vector2(280, 820)
	info_label.add_theme_font_size_override("font_size", 20)
	info_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3, 1.0))
	info_label.name = "TurnInfo"
	add_child(info_label)
	
	# Текущий боец
	var current_fighter = Label.new()
	current_fighter.text = "Текущий: -"
	current_fighter.position = Vector2(280, 850)
	current_fighter.add_theme_font_size_override("font_size", 16)
	current_fighter.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3, 1.0))
	current_fighter.name = "CurrentFighter"
	add_child(current_fighter)

func update_ui():
	# Очищаем старые отображения бойцов
	for child in get_children():
		if child.name.begins_with("PlayerFighter_") or child.name.begins_with("EnemyFighter_"):
			child.queue_free()
	
	# Отображаем команду игрока
	var player_y = 300
	for i in range(player_team.size()):
		var fighter = player_team[i]
		create_fighter_ui(fighter, "player", i, player_y)
		player_y += 50
	
	# Отображаем команду врага
	var enemy_y = 300
	for i in range(enemy_team.size()):
		var fighter = enemy_team[i]
		create_fighter_ui(fighter, "enemy", i, enemy_y)
		enemy_y += 50
	
	# Обновляем информацию о ходе
	var turn_info = get_node_or_null("TurnInfo")
	if turn_info:
		if current_turn == "player":
			var current_fighter = player_team[current_attacker_index]
			turn_info.text = "Ваш ход - выберите цель"
		else:
			turn_info.text = "Ход противника..."
	
	var current_fighter_label = get_node_or_null("CurrentFighter")
	if current_fighter_label:
		if current_turn == "player":
			var fighter = player_team[current_attacker_index]
			current_fighter_label.text = "Текущий: " + fighter["name"]
		else:
			current_fighter_label.text = "Ход врага"
	
	# Блокируем кнопки если не наш ход
	lock_buttons(current_turn != "player" or buttons_locked)
	
	update_log_display()

func create_fighter_ui(fighter: Dictionary, team: String, index: int, y_pos: int):
	var is_player = (team == "player")
	var x_pos = 50 if is_player else 400
	var color = Color(0.3, 1.0, 0.3, 1.0) if is_player else Color(1.0, 0.3, 0.3, 1.0)
	var prefix = "PlayerFighter_" if is_player else "EnemyFighter_"
	
	# Фон бойца
	var bg = ColorRect.new()
	bg.size = Vector2(250, 40)
	bg.position = Vector2(x_pos, y_pos)
	bg.color = Color(0.2, 0.2, 0.2, 0.8)
	bg.name = prefix + "BG_" + str(index)
	add_child(bg)
	
	# Имя и HP
	var name_label = Label.new()
	name_label.text = fighter["name"] + " (" + str(fighter["health"]) + "/" + str(fighter["max_health"]) + ")"
	name_label.position = Vector2(x_pos + 5, y_pos + 5)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", color)
	name_label.name = prefix + "Name_" + str(index)
	add_child(name_label)
	
	# Прогресс-бар HP
	var hp_bg = ColorRect.new()
	hp_bg.size = Vector2(240, 8)
	hp_bg.position = Vector2(x_pos + 5, y_pos + 25)
	hp_bg.color = Color(0.1, 0.1, 0.1, 1.0)
	hp_bg.name = prefix + "HPBG_" + str(index)
	add_child(hp_bg)
	
	var hp_fill = ColorRect.new()
	var hp_percent = float(fighter["health"]) / float(fighter["max_health"])
	hp_fill.size = Vector2(240 * hp_percent, 8)
	hp_fill.position = Vector2(x_pos + 5, y_pos + 25)
	hp_fill.color = color
	hp_fill.name = prefix + "HPFill_" + str(index)
	add_child(hp_fill)
	
	# Выделение текущего бойца
	if current_turn == "player" and is_player and index == current_attacker_index:
		var highlight = ColorRect.new()
		highlight.size = Vector2(250, 40)
		highlight.position = Vector2(x_pos, y_pos)
		highlight.color = Color(1.0, 1.0, 0.0, 0.3)
		highlight.name = prefix + "Highlight_" + str(index)
		add_child(highlight)
	
	# Выделение цели
	if current_turn == "player" and not is_player and index == current_target_index:
		var target_highlight = ColorRect.new()
		target_highlight.size = Vector2(250, 40)
		target_highlight.position = Vector2(x_pos, y_pos)
		target_highlight.color = Color(1.0, 0.5, 0.0, 0.3)
		target_highlight.name = prefix + "Target_" + str(index)
		add_child(target_highlight)

func lock_buttons(locked: bool):
	var attack_btn = get_node_or_null("AttackBtn")
	var defend_btn = get_node_or_null("DefendBtn")
	var run_btn = get_node_or_null("RunBtn")
	
	if attack_btn:
		attack_btn.disabled = locked
	if defend_btn:
		defend_btn.disabled = locked
	if run_btn:
		run_btn.disabled = locked or is_first_battle

func add_to_log(text: String):
	battle_log_lines.insert(0, text)
	if battle_log_lines.size() > max_log_lines:
		battle_log_lines.resize(max_log_lines)
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
		log_line.add_theme_font_size_override("font_size", 14)
		log_line.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
		log_line.autowrap_mode = TextServer.AUTOWRAP_WORD
		log_line.custom_minimum_size = Vector2(620, 0)
		log_vbox.add_child(log_line)

# ========== ХОД ИГРОКА ==========

func start_player_turn():
	current_turn = "player"
	current_attacker_index = 0
	current_target_index = 0
	buttons_locked = false
	
	# Находим первого живого бойца
	while current_attacker_index < player_team.size() and player_team[current_attacker_index]["health"] <= 0:
		current_attacker_index += 1
	
	if current_attacker_index >= player_team.size():
		# Все бойцы мертвы - ход врага
		start_enemy_turn()
		return
	
	add_to_log("🎯 Ваш ход: " + player_team[current_attacker_index]["name"])
	update_ui()

func on_attack():
	if current_turn != "player" or buttons_locked:
		return
	
	# Проверяем что есть враги
	if enemy_team.size() == 0:
		add_to_log("❌ Нет врагов для атаки!")
		return
	
	buttons_locked = true
	lock_buttons(true)
	
	var attacker = player_team[current_attacker_index]
	var target = enemy_team[current_target_index]
	
	if attacker["health"] <= 0:
		add_to_log("💀 " + attacker["name"] + " не может атаковать - мёртв!")
		next_player_fighter()
		return
	
	if target["health"] <= 0:
		add_to_log("🎯 Цель уже мертва, выберите другую")
		buttons_locked = false
		lock_buttons(false)
		return
	
	# Расчет урона
	var damage = calculate_damage(attacker, target)
	target["health"] -= damage
	
	add_to_log("⚔️ " + attacker["name"] + " атакует " + target["name"] + " (-" + str(damage) + " HP)")
	
	if target["health"] <= 0:
		add_to_log("💀 " + target["name"] + " повержен!")
		target["health"] = 0
	
	update_ui()
	
	# Прокачка статов
	if player_stats:
		player_stats.on_melee_attack()
	
	await get_tree().create_timer(1.5).timeout
	
	# Проверяем победу
	if check_victory():
		return
	
	# Следующий боец
	next_player_fighter()

func on_defend():
	if current_turn != "player" or buttons_locked:
		return
	
	buttons_locked = true
	lock_buttons(true)
	
	var attacker = player_team[current_attacker_index]
	
	if attacker["health"] <= 0:
		add_to_log("💀 " + attacker["name"] + " не может защищаться - мёртв!")
		next_player_fighter()
		return
	
	add_to_log("🛡️ " + attacker["name"] + " защищается (следующая атака -50% урона)")
	
	# Временный бонус защиты
	attacker["defending"] = true
	
	await get_tree().create_timer(1.0).timeout
	
	next_player_fighter()

func on_run():
	if current_turn != "player" or buttons_locked or is_first_battle:
		if is_first_battle:
			add_to_log("⚠️ В первом бою убежать нельзя!")
		return
	
	buttons_locked = true
	lock_buttons(true)
	
	var total_agi = 0
	for fighter in player_team:
		if fighter["health"] > 0:
			total_agi += fighter.get("agility", 5)
	
	var run_chance = 0.3 + (total_agi * 0.02)
	
	if randf() < run_chance:
		add_to_log("🏃 Успешно сбежали!")
		if player_stats:
			player_stats.on_dodge_success()
		await get_tree().create_timer(1.5).timeout
		
		# Сохраняем HP команды
		save_team_health()
		
		battle_ended.emit(false)
		queue_free()
	else:
		add_to_log("🏃 Не удалось сбежать!")
		await get_tree().create_timer(1.0).timeout
		next_player_fighter()

func next_player_fighter():
	current_attacker_index += 1
	
	# Ищем следующего живого бойца
	while current_attacker_index < player_team.size() and player_team[current_attacker_index]["health"] <= 0:
		current_attacker_index += 1
	
	if current_attacker_index >= player_team.size():
		# Все бойцы походили - ход врага
		start_enemy_turn()
	else:
		# Следующий боец игрока
		current_target_index = 0
		buttons_locked = false
		update_ui()
		add_to_log("🎯 Ход: " + player_team[current_attacker_index]["name"])

# ========== ХОД ВРАГА ==========

func start_enemy_turn():
	current_turn = "enemy"
	current_attacker_index = 0
	buttons_locked = true
	
	add_to_log("👹 Ход противника!")
	update_ui()
	
	await get_tree().create_timer(1.0).timeout
	enemy_attack_sequence()

func enemy_attack_sequence():
	# Находим первого живого врага
	while current_attacker_index < enemy_team.size() and enemy_team[current_attacker_index]["health"] <= 0:
		current_attacker_index += 1
	
	if current_attacker_index >= enemy_team.size():
		# Все враги походили - снова ход игрока
		start_player_turn()
		return
	
	var attacker = enemy_team[current_attacker_index]
	
	# Ищем живую цель
	var target_index = find_alive_player_target()
	if target_index == -1:
		# Все игроки мертвы - поражение
		lose_battle()
		return
	
	var target = player_team[target_index]
	
	# Атака
	var damage = calculate_damage(attacker, target)
	
	# Учет защиты
	if target.get("defending", false):
		damage = int(damage * 0.5)
		add_to_log("🛡️ " + target["name"] + " блокирует часть урона!")
		target["defending"] = false
	
	target["health"] -= damage
	
	add_to_log("💢 " + attacker["name"] + " атакует " + target["name"] + " (-" + str(damage) + " HP)")
	
	if target["health"] <= 0:
		add_to_log("💀 " + target["name"] + " повержен!")
		target["health"] = 0
	
	update_ui()
	
	await get_tree().create_timer(1.5).timeout
	
	# Проверяем поражение
	if check_defeat():
		return
	
	# Следующий враг
	current_attacker_index += 1
	enemy_attack_sequence()

func find_alive_player_target() -> int:
	for i in range(player_team.size()):
		if player_team[i]["health"] > 0:
			return i
	return -1

# ========== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ==========

func calculate_damage(attacker: Dictionary, target: Dictionary) -> int:
	var base_damage = attacker["strength"]
	
	# Случайный разброс ±20%
	var variance = randf_range(0.8, 1.2)
	var damage = int(base_damage * variance)
	
	# Учет брони (если есть)
	var armor_bonus = 0
	if target.get("equipment", {}).get("armor"):
		var armor_data = get_node("/root/ItemsDB").get_item(target["equipment"]["armor"])
		if armor_data and armor_data.has("defense"):
			armor_bonus = armor_data["defense"]
	
	damage = max(1, damage - armor_bonus)
	
	return damage

func check_victory() -> bool:
	for enemy in enemy_team:
		if enemy["health"] > 0:
			return false
	
	win_battle()
	return true

func check_defeat() -> bool:
	for fighter in player_team:
		if fighter["health"] > 0:
			return false
	
	lose_battle()
	return true

func win_battle():
	add_to_log("🎉 ПОБЕДА! Все враги повержены!")
	
	var reward = 0
	for enemy in enemy_team:
		reward += enemy["strength"] * 15  # Увеличил награду за массовый бой
	
	if player_data:
		player_data["balance"] += reward
		player_data["reputation"] += 15
	
	add_to_log("💰 Получено: " + str(reward) + " руб., +15 репутации")
	
	await get_tree().create_timer(2.5).timeout
	
	# Сохраняем HP команды
	save_team_health()
	
	battle_ended.emit(true)
	queue_free()

func lose_battle():
	add_to_log("💀 ПОРАЖЕНИЕ! Ваша команда уничтожена...")
	
	if player_data:
		player_data["balance"] = max(0, player_data["balance"] - 100)
	
	add_to_log("💸 Потеряно: 100 руб.")
	
	if is_first_battle:
		add_to_log("📖 Вам нужно заработать деньги и пойти в больницу!")
	
	await get_tree().create_timer(2.5).timeout
	
	# Восстанавливаем немного HP для продолжения игры
	for fighter in player_team:
		fighter["health"] = max(1, int(fighter["max_health"] * 0.2))
	
	save_team_health()
	
	battle_ended.emit(false)
	queue_free()

func save_team_health():
	if player_data and player_team.size() > 0:
		player_data["health"] = player_team[0]["health"]
	
	# Сохраняем HP банды через main_node (если нужно)
	# Банда уже передана в setup и сохраняется в основной системе
