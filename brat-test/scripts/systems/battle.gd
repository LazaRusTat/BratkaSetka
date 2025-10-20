# battle.gd v3.0 - ПОЛНАЯ СИСТЕМА БОЯ С ПРИЦЕЛИВАНИЕМ
extends CanvasLayer

signal battle_ended(victory: bool)

# Команды
var player_team: Array = []
var enemy_team: Array = []

# Текущий ход
var turn: String = "player"
var current_attacker_index: int = 0
var buttons_locked: bool = false

# Режим выбора
var selecting_target: bool = false
var selecting_bodypart: bool = false
var selected_target = null
var selected_bodypart: String = ""

# Системы
var player_stats
var battle_log_lines: Array = []
var max_log_lines: int = 8

# Части тела
var body_parts = {
	"head": {"name": "Голова/Шея", "damage_mult": 3.0, "crit_effects": ["bleed", "blind_or_stun"]},
	"torso": {"name": "Торс", "damage_mult": 1.0, "crit_effects": ["bleed"]},
	"arms": {"name": "Руки", "damage_mult": 0.5, "crit_effects": ["bleed", "disarm"]},
	"legs": {"name": "Ноги", "damage_mult": 0.75, "crit_effects": ["bleed", "cripple"]}
}

# Шаблоны врагов
var enemy_templates = {
	"drunkard": {"name": "Пьяный", "hp": 40, "damage": 5, "defense": 0, "morale": 30, "accuracy": 0.5, "reward": 20},
	"gopnik": {"name": "Гопник", "hp": 60, "damage": 10, "defense": 2, "morale": 50, "accuracy": 0.65, "reward": 50},
	"thug": {"name": "Хулиган", "hp": 80, "damage": 15, "defense": 5, "morale": 60, "accuracy": 0.70, "reward": 80},
	"bandit": {"name": "Бандит", "hp": 100, "damage": 20, "defense": 8, "morale": 70, "accuracy": 0.75, "reward": 120},
	"guard": {"name": "Охранник", "hp": 120, "damage": 25, "defense": 15, "morale": 80, "accuracy": 0.80, "reward": 150},
	"boss": {"name": "Главарь", "hp": 200, "damage": 35, "defense": 20, "morale": 100, "accuracy": 0.85, "reward": 300}
}

func _ready():
	layer = 200
	player_stats = get_node("/root/PlayerStats")

func setup(p_player_data: Dictionary, enemy_type: String = "gopnik", first_battle: bool = false, gang_members: Array = []):
	# Формируем команду игрока
	player_team = []
	
	var player = {
		"name": "Вы",
		"hp": p_player_data.get("health", 100),
		"max_hp": 100,
		"damage": player_stats.calculate_melee_damage() if player_stats else 10,
		"defense": player_stats.equipment_bonuses.get("defense", 0) if player_stats else 0,
		"morale": 100,
		"accuracy": 0.75,
		"is_player": true,
		"alive": true,
		"status_effects": {},
		"weapon": p_player_data.get("equipment", {}).get("melee", "Кулаки")
	}
	player_team.append(player)
	
	# Члены банды
	for i in range(min(gang_members.size() - 1, 9)):
		var member = gang_members[i + 1]
		var gang_fighter = {
			"name": member.get("name", "Боец"),
			"hp": member.get("health", 80),
			"max_hp": member.get("health", 80),
			"damage": member.get("strength", 5) + 5,
			"defense": 0,
			"morale": 80,
			"accuracy": 0.65,
			"is_player": false,
			"alive": true,
			"status_effects": {},
			"weapon": "Кулаки"
		}
		player_team.append(gang_fighter)
	
	# Формируем команду врагов
	enemy_team = []
	var enemy_count = get_enemy_count(enemy_type, player_team.size())
	
	for i in range(enemy_count):
		var template = enemy_templates[enemy_type]
		var enemy = {
			"name": template["name"] + " " + str(i + 1),
			"hp": template["hp"],
			"max_hp": template["hp"],
			"damage": template["damage"],
			"defense": template["defense"],
			"morale": template["morale"],
			"accuracy": template["accuracy"],
			"reward": template["reward"],
			"alive": true,
			"status_effects": {},
			"weapon": "Кулаки"
		}
		enemy_team.append(enemy)
	
	create_ui()
	add_to_log("⚔️ Бой начался! %d vs %d" % [player_team.size(), enemy_team.size()])

func get_enemy_count(enemy_type: String, player_count: int) -> int:
	match enemy_type:
		"drunkard": return clamp(player_count, 1, 3)
		"gopnik": return clamp(player_count + randi_range(0, 1), 1, 5)
		"thug": return clamp(player_count + randi_range(1, 2), 2, 6)
		"bandit": return clamp(player_count + randi_range(1, 3), 2, 8)
		"guard": return clamp(player_count + randi_range(2, 4), 3, 10)
		"boss": return clamp(player_count + randi_range(3, 5), 4, 12)
	return 1

func create_ui():
	# Фон
	var bg = ColorRect.new()
	bg.size = Vector2(700, 1100)
	bg.position = Vector2(10, 90)
	bg.color = Color(0.05, 0.02, 0.02, 0.98)
	bg.name = "BattleBG"
	add_child(bg)
	
	# Заголовок
	var title = Label.new()
	title.text = "⚔️ ГРУППОВОЙ БОЙ"
	title.position = Vector2(250, 110)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))
	add_child(title)
	
	# === АВАТАРКИ КОМАНД ===
	create_team_avatars()
	
	# === ЛОГ БОЯ ===
	var log_scroll = ScrollContainer.new()
	log_scroll.custom_minimum_size = Vector2(680, 300)
	log_scroll.position = Vector2(20, 500)
	log_scroll.name = "LogScroll"
	log_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(log_scroll)
	
	var log_bg = ColorRect.new()
	log_bg.size = Vector2(680, 300)
	log_bg.position = Vector2(20, 500)
	log_bg.color = Color(0.03, 0.03, 0.03, 1.0)
	log_bg.z_index = -1
	add_child(log_bg)
	
	var log_vbox = VBoxContainer.new()
	log_vbox.name = "LogVBox"
	log_vbox.custom_minimum_size = Vector2(660, 0)
	log_scroll.add_child(log_vbox)
	
	# === ИНФОРМАЦИЯ О ХОДЕ ===
	var turn_info = Label.new()
	turn_info.text = "Ваш ход: Атакующий 1"
	turn_info.position = Vector2(200, 820)
	turn_info.add_theme_font_size_override("font_size", 20)
	turn_info.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3, 1.0))
	turn_info.name = "TurnInfo"
	add_child(turn_info)
	
	# === КНОПКИ ===
	create_battle_buttons()
	
	update_ui()

func create_team_avatars():
	# === КОМАНДА ИГРОКА (слева) ===
	var player_x = 30
	var player_y = 170
	
	for i in range(min(5, player_team.size())):
		create_avatar(player_team[i], Vector2(player_x, player_y), i, true)
		player_y += 65
	
	# Если больше 5, рисуем второй столбец
	if player_team.size() > 5:
		player_x = 100
		player_y = 170
		for i in range(5, player_team.size()):
			create_avatar(player_team[i], Vector2(player_x, player_y), i, true)
			player_y += 65
	
	# === КОМАНДА ВРАГОВ (справа) ===
	var enemy_x = 570
	var enemy_y = 170
	
	for i in range(min(5, enemy_team.size())):
		create_avatar(enemy_team[i], Vector2(enemy_x, enemy_y), i, false)
		enemy_y += 65
	
	if enemy_team.size() > 5:
		enemy_x = 640
		enemy_y = 170
		for i in range(5, enemy_team.size()):
			create_avatar(enemy_team[i], Vector2(enemy_x, enemy_y), i, false)
			enemy_y += 65

func create_avatar(fighter: Dictionary, pos: Vector2, index: int, is_player_side: bool):
	var avatar_container = Control.new()
	avatar_container.custom_minimum_size = Vector2(60, 60)
	avatar_container.position = pos
	avatar_container.name = ("Player" if is_player_side else "Enemy") + "Avatar_" + str(index)
	add_child(avatar_container)
	
	# Фон аватарки
	var avatar_bg = ColorRect.new()
	avatar_bg.size = Vector2(50, 50)
	avatar_bg.color = Color(0.8, 0.3, 0.2, 1.0) if is_player_side else Color(0.3, 0.3, 0.8, 1.0)
	avatar_bg.name = "AvatarBG"
	avatar_container.add_child(avatar_bg)
	
	# HP индикатор (красная полоса снизу вверх)
	var hp_indicator = ColorRect.new()
	var hp_percent = float(fighter["hp"]) / float(fighter["max_hp"])
	hp_indicator.size = Vector2(50, 50 * (1.0 - hp_percent))
	hp_indicator.position = Vector2(0, 0)
	hp_indicator.color = Color(1.0, 0.0, 0.0, 0.6)
	hp_indicator.name = "HPIndicator"
	avatar_container.add_child(hp_indicator)
	
	# Иконка персонажа (эмодзи)
	var icon = Label.new()
	icon.text = "🤵" if is_player_side else "💀"
	icon.position = Vector2(10, 5)
	icon.add_theme_font_size_override("font_size", 30)
	icon.name = "Icon"
	avatar_container.add_child(icon)
	
	# HP текст
	var hp_label = Label.new()
	hp_label.text = "%d/%d" % [fighter["hp"], fighter["max_hp"]]
	hp_label.position = Vector2(55, 5)
	hp_label.add_theme_font_size_override("font_size", 12)
	hp_label.add_theme_color_override("font_color", Color.WHITE)
	hp_label.name = "HPLabel"
	avatar_container.add_child(hp_label)
	
	# Мораль
	var morale_label = Label.new()
	morale_label.text = "💪 %d" % fighter["morale"]
	morale_label.position = Vector2(55, 22)
	morale_label.add_theme_font_size_override("font_size", 10)
	morale_label.add_theme_color_override("font_color", get_morale_color(fighter["morale"]))
	morale_label.name = "MoraleLabel"
	avatar_container.add_child(morale_label)
	
	# Статусы
	var status_label = Label.new()
	status_label.text = get_status_text(fighter)
	status_label.position = Vector2(55, 36)
	status_label.add_theme_font_size_override("font_size", 9)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5, 1.0))
	status_label.name = "StatusLabel"
	avatar_container.add_child(status_label)
	
	# Кнопка просмотра/действия
	var action_btn = Button.new()
	action_btn.custom_minimum_size = Vector2(50, 50)
	action_btn.position = Vector2(0, 0)
	action_btn.text = ""
	action_btn.name = "ActionBtn"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.0)
	action_btn.add_theme_stylebox_override("normal", style)
	
	var idx = index
	var is_player = is_player_side
	action_btn.pressed.connect(func(): 
		if is_player:
			# Свои бойцы - инвентарь + использование карманов
			show_fighter_inventory(fighter, idx, true)
		else:
			# Враги - выбор цели ИЛИ просмотр инвентаря
			if Input.is_action_pressed("ui_select"):  # Shift для просмотра
				show_fighter_inventory(fighter, idx, false)
			else:
				on_target_selected(idx)
	)
	avatar_container.add_child(action_btn)

func create_battle_buttons():
	# Кнопка "Атака"
	var attack_btn = Button.new()
	attack_btn.custom_minimum_size = Vector2(200, 70)
	attack_btn.position = Vector2(40, 1000)
	attack_btn.text = "⚔️ АТАКА"
	attack_btn.name = "AttackBtn"
	
	var style_attack = StyleBoxFlat.new()
	style_attack.bg_color = Color(0.7, 0.2, 0.2, 1.0)
	attack_btn.add_theme_stylebox_override("normal", style_attack)
	attack_btn.add_theme_font_size_override("font_size", 24)
	attack_btn.pressed.connect(func(): on_attack_button())
	add_child(attack_btn)
	
	# Кнопка "Защита"
	var defend_btn = Button.new()
	defend_btn.custom_minimum_size = Vector2(200, 70)
	defend_btn.position = Vector2(260, 1000)
	defend_btn.text = "🛡️ ЗАЩИТА"
	defend_btn.name = "DefendBtn"
	
	var style_defend = StyleBoxFlat.new()
	style_defend.bg_color = Color(0.2, 0.4, 0.7, 1.0)
	defend_btn.add_theme_stylebox_override("normal", style_defend)
	defend_btn.add_theme_font_size_override("font_size", 24)
	defend_btn.pressed.connect(func(): on_defend())
	add_child(defend_btn)
	
	# Кнопка "Бежать"
	var run_btn = Button.new()
	run_btn.custom_minimum_size = Vector2(200, 70)
	run_btn.position = Vector2(480, 1000)
	run_btn.text = "🏃 БЕЖАТЬ"
	run_btn.name = "RunBtn"
	
	var style_run = StyleBoxFlat.new()
	style_run.bg_color = Color(0.5, 0.5, 0.2, 1.0)
	run_btn.add_theme_stylebox_override("normal", style_run)
	run_btn.add_theme_font_size_override("font_size", 24)
	run_btn.pressed.connect(func(): on_run())
	add_child(run_btn)

# === ВЫБОР ЦЕЛИ ===
func on_target_selected(enemy_index: int):
	# Просто выбираем цель, не начинаем атаку
	var target = enemy_team[enemy_index]
	if not target["alive"]:
		add_to_log("⚠️ Эта цель мертва!")
		return
	
	selected_target = target
	add_to_log("🎯 Цель выбрана: %s" % target["name"])
	
	# Подсветка выбранной цели
	highlight_selected_target(enemy_index)

func highlight_selected_target(enemy_index: int):
	# Убираем старую подсветку
	for i in range(enemy_team.size()):
		var avatar_name = "EnemyAvatar_" + str(i)
		var avatar = get_node_or_null(avatar_name)
		if avatar:
			var bg = avatar.get_node_or_null("AvatarBG")
			if bg:
				bg.color = Color(0.3, 0.3, 0.8, 1.0)
	
	# Подсвечиваем новую цель
	var avatar_name = "EnemyAvatar_" + str(enemy_index)
	var avatar = get_node_or_null(avatar_name)
	if avatar:
		var bg = avatar.get_node_or_null("AvatarBG")
		if bg:
			bg.color = Color(0.8, 0.8, 0.2, 1.0)

func on_attack_button():
	if buttons_locked:
		return
	
	# Проверяем, что цель выбрана
	if not selected_target:
		add_to_log("⚠️ Сначала выберите цель!")
		return
	
	if not selected_target["alive"]:
		add_to_log("⚠️ Выбранная цель мертва!")
		selected_target = null
		return
	
	# Показываем меню прицеливания
	selecting_bodypart = true
	lock_buttons(true)
	show_bodypart_menu()

func show_bodypart_menu():
	var bodypart_menu = Control.new()
	bodypart_menu.name = "BodypartMenu"
	bodypart_menu.position = Vector2(200, 850)
	add_child(bodypart_menu)
	
	var bg = ColorRect.new()
	bg.size = Vector2(320, 140)
	bg.color = Color(0.1, 0.1, 0.1, 0.95)
	bodypart_menu.add_child(bg)
	
	var title = Label.new()
	title.text = "🎯 ПРИЦЕЛИТЬСЯ"
	title.position = Vector2(80, 10)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3, 1.0))
	bodypart_menu.add_child(title)
	
	var y = 40
	for part_key in ["head", "torso", "arms", "legs"]:
		var part = body_parts[part_key]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(300, 20)
		btn.position = Vector2(10, y)
		btn.text = part["name"] + " (x%.1f урона)" % part["damage_mult"]
		btn.add_theme_font_size_override("font_size", 14)
		
		var pk = part_key
		btn.pressed.connect(func(): on_bodypart_selected(pk))
		bodypart_menu.add_child(btn)
		y += 25

func on_bodypart_selected(part_key: String):
	selected_bodypart = part_key
	selecting_bodypart = false
	
	var menu = get_node_or_null("BodypartMenu")
	if menu:
		menu.queue_free()
	
	perform_attack()

# === АТАКА ===
func perform_attack():
	if not selected_target or selected_bodypart == "":
		return
	
	var attacker = player_team[current_attacker_index]
	var target = selected_target
	var bodypart = body_parts[selected_bodypart]
	
	# Проверка попадания
	var hit_chance = attacker["accuracy"]
	if randf() > hit_chance:
		add_to_log("🌫 %s промахнулся!" % attacker["name"])
		next_attacker()
		return
	
	# Расчет урона
	var base_damage = attacker["damage"]
	var damage = int(base_damage * bodypart["damage_mult"])
	
	# Критическое попадание
	var is_crit = randf() < 0.2
	if is_crit:
		damage = int(damage * 1.5)
		add_to_log("💥 КРИТИЧЕСКИЙ УДАР!")
		apply_crit_effects(target, bodypart["crit_effects"])
	
	# Применение урона
	var final_damage = max(1, damage - target["defense"])
	target["hp"] -= final_damage
	
	add_to_log("⚔️ %s → %s (%s): -%d HP" % [attacker["name"], target["name"], bodypart["name"], final_damage])
	
	# Снижение морали
	target["morale"] = max(10, target["morale"] - randi_range(5, 15))
	
	# Проверка обморока/смерти
	check_fighter_status(target)
	
	update_ui()
	
	# Следующий атакующий
	selected_target = null
	selected_bodypart = ""
	next_attacker()

func apply_crit_effects(target: Dictionary, effects: Array):
	for effect in effects:
		match effect:
			"bleed":
				if not target["status_effects"].has("bleeding"):
					target["status_effects"]["bleeding"] = randi_range(3, 4)
					add_to_log("🩸 %s начал кровоточить!" % target["name"])
			
			"blind_or_stun":
				if randf() < 0.5:
					target["status_effects"]["blind"] = randi_range(2, 3)
					target["accuracy"] *= 0.1
					add_to_log("👁️ %s ослеплён!" % target["name"])
				else:
					target["status_effects"]["stunned"] = randi_range(1, 2)
					add_to_log("😵 %s оглушён!" % target["name"])
			
			"disarm":
				if randf() < 0.3:
					target["status_effects"]["disarmed"] = true
					target["damage"] = int(target["damage"] * 0.3)
					add_to_log("🔫 %s обезоружен!" % target["name"])
			
			"cripple":
				if randf() < 0.2:
					target["status_effects"]["crippled"] = true
					add_to_log("🦵 %s не может бегать!" % target["name"])

func check_fighter_status(fighter: Dictionary):
	if fighter["hp"] <= 0:
		var excess_damage = abs(fighter["hp"])
		
		# Проверка на обморок vs смерть
		if excess_damage <= (5 if not fighter.get("is_player", false) else 1):
			# Обморок
			fighter["alive"] = false
			fighter["hp"] = 0
			add_to_log("😴 %s потерял сознание!" % fighter["name"])
		else:
			# Смерть
			fighter["alive"] = false
			fighter["hp"] = 0
			add_to_log("💀 %s убит!" % fighter["name"])
		
		# Снижение морали у команды
		var team = player_team if fighter.get("is_player", false) or player_team.has(fighter) else enemy_team
		for member in team:
			if member["alive"]:
				member["morale"] = max(10, member["morale"] - 15)

func next_attacker():
	current_attacker_index += 1
	
	# Пропускаем мертвых/оглушённых
	while current_attacker_index < player_team.size():
		var attacker = player_team[current_attacker_index]
		if attacker["alive"] and not attacker["status_effects"].has("stunned"):
			break
		current_attacker_index += 1
	
	# Конец хода команды
	if current_attacker_index >= player_team.size():
		check_battle_end()
		if get_node_or_null("BattleBG"):
			turn = "enemy"
			current_attacker_index = 0
			update_turn_info()
			await get_tree().create_timer(1.5).timeout
			enemy_turn()
	else:
		update_turn_info()
		lock_buttons(false)

func enemy_turn():
	for i in range(enemy_team.size()):
		var enemy = enemy_team[i]
		if not enemy["alive"] or enemy["status_effects"].has("stunned"):
			continue
		
		# Выбор цели
		var target = get_random_alive_player()
		if not target:
			break
		
		# Выбор части тела (случайно)
		var parts = ["head", "torso", "arms", "legs"]
		var part_key = parts[randi() % parts.size()]
		var bodypart = body_parts[part_key]
		
		# Атака
		if randf() > enemy["accuracy"]:
			add_to_log("🌫 %s промахнулся!" % enemy["name"])
			continue
		
		var damage = int(enemy["damage"] * bodypart["damage_mult"])
		var is_crit = randf() < 0.15
		
		if is_crit:
			damage = int(damage * 1.5)
			add_to_log("💥 КРИТИЧЕСКИЙ УДАР врага!")
			apply_crit_effects(target, bodypart["crit_effects"])
		
		var final_damage = max(1, damage - target["defense"])
		target["hp"] -= final_damage
		
		add_to_log("💢 %s → %s (%s): -%d HP" % [enemy["name"], target["name"], bodypart["name"], final_damage])
		
		target["morale"] = max(10, target["morale"] - randi_range(3, 10))
		check_fighter_status(target)
		
		update_ui()
		await get_tree().create_timer(0.5).timeout
	
	check_battle_end()
	if get_node_or_null("BattleBG"):
		turn = "player"
		current_attacker_index = 0
		update_turn_info()
		lock_buttons(false)

func on_defend():
	if turn != "player" or buttons_locked:
		return
	
	for fighter in player_team:
		if fighter["alive"]:
			fighter["defense"] = fighter.get("defense", 0) + 10
	
	add_to_log("🛡️ Команда приняла защитную стойку!")
	turn = "enemy"
	lock_buttons(true)
	
	await get_tree().create_timer(1.5).timeout
	enemy_turn()

func on_run():
	if turn != "player" or buttons_locked:
		return
	
	var agi = player_stats.get_stat("AGI") if player_stats else 4
	var run_chance = 0.4 + agi * 0.05
	
	if randf() < run_chance:
		add_to_log("🏃 Успешное отступление!")
		await get_tree().create_timer(1.5).timeout
		battle_ended.emit(false)
		queue_free()
	else:
		add_to_log("🏃 Не удалось сбежать!")
		turn = "enemy"
		lock_buttons(true)
		await get_tree().create_timer(1.5).timeout
		enemy_turn()

func check_battle_end():
	var player_alive = count_alive(player_team)
	var enemy_alive = count_alive(enemy_team)
	
	if enemy_alive == 0:
		win_battle()
	elif player_alive == 0:
		lose_battle()

func win_battle():
	add_to_log("✅ ПОБЕДА!")
	
	var total_reward = 0
	for enemy in enemy_team:
		total_reward += enemy.get("reward", 0)
	
	var main_node = get_parent()
	if main_node and main_node.player_data:
		main_node.player_data["balance"] += total_reward
		main_node.player_data["reputation"] += 5 + enemy_team.size()
	
	add_to_log("💰 +%d руб., +%d репутации" % [total_reward, 5 + enemy_team.size()])
	
	await get_tree().create_timer(3.0).timeout
	battle_ended.emit(true)
	queue_free()

func lose_battle():
	add_to_log("💀 ПОРАЖЕНИЕ!")
	
	await get_tree().create_timer(3.0).timeout
	battle_ended.emit(false)
	queue_free()

# === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===
func update_ui():
	# Обновление аватарок
	for i in range(player_team.size()):
		update_avatar_ui(player_team[i], i, true)
	
	for i in range(enemy_team.size()):
		update_avatar_ui(enemy_team[i], i, false)

func update_avatar_ui(fighter: Dictionary, index: int, is_player_side: bool):
	var avatar_name = ("Player" if is_player_side else "Enemy") + "Avatar_" + str(index)
	var avatar = get_node_or_null(avatar_name)
	if not avatar:
		return
	
	# Обновление HP индикатора
	var hp_indicator = avatar.get_node_or_null("HPIndicator")
	if hp_indicator:
		var hp_percent = float(fighter["hp"]) / float(fighter["max_hp"])
		hp_indicator.size = Vector2(50, 50 * (1.0 - hp_percent))
	
	# Обновление HP текста
	var hp_label = avatar.get_node_or_null("HPLabel")
	if hp_label:
		hp_label.text = "%d/%d" % [fighter["hp"], fighter["max_hp"]]
	
	# Обновление морали
	var morale_label = avatar.get_node_or_null("MoraleLabel")
	if morale_label:
		morale_label.text = "💪 %d" % fighter["morale"]
		morale_label.add_theme_color_override("font_color", get_morale_color(fighter["morale"]))
	
	# Обновление статусов
	var status_label = avatar.get_node_or_null("StatusLabel")
	if status_label:
		status_label.text = get_status_text(fighter)
	
	# Эффект попадания
	if fighter.get("just_hit", false):
		fighter["just_hit"] = false
		flash_red(avatar)

func flash_red(avatar: Control):
	var bg = avatar.get_node_or_null("AvatarBG")
	if bg:
		var original_color = bg.color
		bg.color = Color(1.0, 0.3, 0.3, 1.0)
		
		await get_tree().create_timer(0.3).timeout
		if bg and is_instance_valid(bg):
			bg.color = original_color

func get_morale_color(morale: int) -> Color:
	if morale >= 70:
		return Color(0.3, 1.0, 0.3, 1.0)
	elif morale >= 40:
		return Color(1.0, 1.0, 0.3, 1.0)
	else:
		return Color(1.0, 0.3, 0.3, 1.0)

func get_status_text(fighter: Dictionary) -> String:
	var statuses = []
	
	if fighter["status_effects"].has("bleeding"):
		statuses.append("🩸" + str(fighter["status_effects"]["bleeding"]))
	if fighter["status_effects"].has("blind"):
		statuses.append("👁️" + str(fighter["status_effects"]["blind"]))
	if fighter["status_effects"].has("stunned"):
		statuses.append("😵" + str(fighter["status_effects"]["stunned"]))
	if fighter["status_effects"].has("disarmed"):
		statuses.append("🔫")
	if fighter["status_effects"].has("crippled"):
		statuses.append("🦵")
	
	return " ".join(statuses)

func update_turn_info():
	var turn_info = get_node_or_null("TurnInfo")
	if turn_info:
		if turn == "player":
			if current_attacker_index < player_team.size():
				var attacker = player_team[current_attacker_index]
				turn_info.text = "Ваш ход: %s атакует" % attacker["name"]
			else:
				turn_info.text = "Ваш ход завершён"
		else:
			turn_info.text = "Ход врагов..."

func lock_buttons(locked: bool):
	buttons_locked = locked
	
	var attack_btn = get_node_or_null("AttackBtn")
	var defend_btn = get_node_or_null("DefendBtn")
	var run_btn = get_node_or_null("RunBtn")
	
	if attack_btn:
		attack_btn.disabled = locked
	if defend_btn:
		defend_btn.disabled = locked
	if run_btn:
		run_btn.disabled = locked

func count_alive(team: Array) -> int:
	var count = 0
	for fighter in team:
		if fighter["alive"]:
			count += 1
	return count

func get_random_alive_player():
	var alive = []
	for fighter in player_team:
		if fighter["alive"]:
			alive.append(fighter)
	
	if alive.size() == 0:
		return null
	return alive[randi() % alive.size()]

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
		log_line.add_theme_font_size_override("font_size", 14)
		log_line.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1.0))
		log_line.autowrap_mode = TextServer.AUTOWRAP_WORD
		log_line.custom_minimum_size = Vector2(640, 0)
		log_vbox.add_child(log_line)

# === ИНВЕНТАРЬ В БОЮ ===
func show_fighter_inventory(fighter: Dictionary, index: int, is_ally: bool):
	# Закрываем предыдущее окно инвентаря
	var old_inv = get_node_or_null("BattleInventory")
	if old_inv:
		old_inv.queue_free()
	
	var inv_layer = Control.new()
	inv_layer.name = "BattleInventory"
	inv_layer.position = Vector2(0, 0)
	inv_layer.size = Vector2(720, 1280)
	add_child(inv_layer)
	
	# Полупрозрачный фон
	var overlay = ColorRect.new()
	overlay.size = Vector2(720, 1280)
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	inv_layer.add_child(overlay)
	
	# Окно инвентаря
	var inv_bg = ColorRect.new()
	inv_bg.size = Vector2(600, 900)
	inv_bg.position = Vector2(60, 190)
	inv_bg.color = Color(0.05, 0.05, 0.1, 0.98)
	inv_layer.add_child(inv_bg)
	
	# Заголовок
	var title = Label.new()
	title.text = "👤 " + fighter["name"]
	title.position = Vector2(250, 210)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3, 1.0))
	inv_layer.add_child(title)
	
	var y_pos = 260
	
	# === СТАТЫ ===
	var stats_title = Label.new()
	stats_title.text = "═══ ПАРАМЕТРЫ ═══"
	stats_title.position = Vector2(240, y_pos)
	stats_title.add_theme_font_size_override("font_size", 18)
	stats_title.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0, 1.0))
	inv_layer.add_child(stats_title)
	y_pos += 35
	
	var stats = [
		"❤️ HP: %d/%d" % [fighter["hp"], fighter["max_hp"]],
		"⚔️ Урон: %d" % fighter["damage"],
		"🛡️ Защита: %d" % fighter["defense"],
		"🎯 Точность: %.0f%%" % (fighter["accuracy"] * 100),
		"💪 Мораль: %d" % fighter["morale"]
	]
	
	for stat in stats:
		var stat_label = Label.new()
		stat_label.text = stat
		stat_label.position = Vector2(80, y_pos)
		stat_label.add_theme_font_size_override("font_size", 16)
		stat_label.add_theme_color_override("font_color", Color.WHITE)
		inv_layer.add_child(stat_label)
		y_pos += 25
	
	y_pos += 10
	
	# === ЭКИПИРОВКА ===
	var equip_title = Label.new()
	equip_title.text = "═══ ЭКИПИРОВКА ═══"
	equip_title.position = Vector2(230, y_pos)
	equip_title.add_theme_font_size_override("font_size", 18)
	equip_title.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0, 1.0))
	inv_layer.add_child(equip_title)
	y_pos += 35
	
	# Получаем экипировку из главного персонажа/банды
	var equipment = {}
	var inventory = []
	var pockets = []
	
	if is_ally:
		var main_node = get_parent()
		if fighter.get("is_player", false):
			equipment = main_node.player_data.get("equipment", {})
			inventory = main_node.player_data.get("inventory", [])
			pockets = main_node.player_data.get("pockets", [null, null, null])
		else:
			# Член банды
			if index > 0 and index < main_node.gang_members.size():
				var member = main_node.gang_members[index]
				equipment = member.get("equipment", {})
				inventory = member.get("inventory", [])
				pockets = member.get("pockets", [null, null, null])
	
	# Показываем экипировку
	var equip_slots = {
		"helmet": "🧢 Голова",
		"armor": "🦺 Броня",
		"melee": "🔪 Ближний бой",
		"ranged": "🔫 Дальний бой",
		"gadget": "📱 Гаджет"
	}
	
	for slot_key in equip_slots:
		var slot_name = equip_slots[slot_key]
		var equipped = equipment.get(slot_key, null)
		
		var slot_label = Label.new()
		slot_label.text = slot_name + ": " + (equipped if equipped else "—")
		slot_label.position = Vector2(80, y_pos)
		slot_label.add_theme_font_size_override("font_size", 15)
		slot_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0) if equipped else Color(0.5, 0.5, 0.5, 1.0))
		inv_layer.add_child(slot_label)
		y_pos += 25
	
	y_pos += 10
	
	# === КАРМАНЫ (только для союзников) ===
	if is_ally and pockets.size() > 0:
		var pockets_title = Label.new()
		pockets_title.text = "═══ КАРМАНЫ ═══"
		pockets_title.position = Vector2(240, y_pos)
		pockets_title.add_theme_font_size_override("font_size", 18)
		pockets_title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3, 1.0))
		inv_layer.add_child(pockets_title)
		y_pos += 35
		
		for i in range(pockets.size()):
			var pocket_item = pockets[i]
			
			var pocket_container = Control.new()
			pocket_container.position = Vector2(80, y_pos)
			pocket_container.size = Vector2(540, 35)
			inv_layer.add_child(pocket_container)
			
			var pocket_label = Label.new()
			pocket_label.text = "Карман %d: %s" % [i + 1, pocket_item if pocket_item else "пусто"]
			pocket_label.position = Vector2(0, 5)
			pocket_label.add_theme_font_size_override("font_size", 15)
			pocket_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8, 1.0) if pocket_item else Color(0.5, 0.5, 0.5, 1.0))
			pocket_container.add_child(pocket_label)
			
			# Кнопка использования
			if pocket_item:
				var use_btn = Button.new()
				use_btn.custom_minimum_size = Vector2(120, 30)
				use_btn.position = Vector2(420, 0)
				use_btn.text = "ИСПОЛЬЗОВАТЬ"
				use_btn.add_theme_font_size_override("font_size", 12)
				
				var style = StyleBoxFlat.new()
				style.bg_color = Color(0.2, 0.6, 0.2, 1.0)
				use_btn.add_theme_stylebox_override("normal", style)
				
				var item_name = pocket_item
				var fighter_ref = fighter
				use_btn.pressed.connect(func(): 
					use_item_in_battle(item_name, fighter_ref)
					inv_layer.queue_free()
				)
				pocket_container.add_child(use_btn)
			
			y_pos += 40
	
	# === РЮКЗАК (только просмотр) ===
	if is_ally and inventory.size() > 0:
		y_pos += 10
		var inv_title = Label.new()
		inv_title.text = "═══ РЮКЗАК (просмотр) ═══"
		inv_title.position = Vector2(210, y_pos)
		inv_title.add_theme_font_size_override("font_size", 16)
		inv_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
		inv_layer.add_child(inv_title)
		y_pos += 30
		
		for item in inventory:
			var item_label = Label.new()
			item_label.text = "• " + item
			item_label.position = Vector2(90, y_pos)
			item_label.add_theme_font_size_override("font_size", 14)
			item_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
			inv_layer.add_child(item_label)
			y_pos += 22
			
			if y_pos > 1000:  # Ограничение по высоте
				break
	
	# Кнопка закрытия
	var close_btn = Button.new()
	close_btn.custom_minimum_size = Vector2(560, 50)
	close_btn.position = Vector2(80, 1020)
	close_btn.text = "ЗАКРЫТЬ"
	
	var style_close = StyleBoxFlat.new()
	style_close.bg_color = Color(0.5, 0.1, 0.1, 1.0)
	close_btn.add_theme_stylebox_override("normal", style_close)
	close_btn.add_theme_font_size_override("font_size", 20)
	
	close_btn.pressed.connect(func(): inv_layer.queue_free())
	inv_layer.add_child(close_btn)

# Использование предмета в бою
func use_item_in_battle(item_name: String, fighter: Dictionary):
	var items_db = get_node("/root/ItemsDB")
	if not items_db:
		return
	
	var item_data = items_db.get_item(item_name)
	if not item_data or item_data.get("type") != "consumable":
		add_to_log("⚠️ Предмет нельзя использовать!")
		return
	
	# Применяем эффект
	if item_data.get("effect") == "heal":
		var heal_amount = item_data.get("value", 10)
		fighter["hp"] = min(fighter["max_hp"], fighter["hp"] + heal_amount)
		add_to_log("💚 %s использовал %s (+%d HP)" % [fighter["name"], item_name, heal_amount])
	elif item_data.get("effect") == "stress":
		fighter["morale"] = min(100, fighter["morale"] + item_data.get("value", 10))
		add_to_log("💪 %s использовал %s (+%d морали)" % [fighter["name"], item_name, item_data.get("value", 10)])
	
	# Удаляем из карманов
	var main_node = get_parent()
	if fighter.get("is_player", false):
		for i in range(main_node.player_data["pockets"].size()):
			if main_node.player_data["pockets"][i] == item_name:
				main_node.player_data["pockets"][i] = null
				break
	
	update_ui()
	add_to_log("✅ %s восстановлен" % fighter["name"])
