# battle.gd v4.0 - ПОЛНАЯ ВЕРСИЯ С АВАТАРКАМИ
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
var items_db
var battle_log_lines: Array = []
var max_log_lines: int = 8

# Данные игрока
var player_data

# Аватарки
var avatar_nodes = {}

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
	items_db = get_node("/root/ItemsDB")

func setup(p_player_data: Dictionary, enemy_type: String = "gopnik", first_battle: bool = false, gang_members: Array = []):
	player_data = p_player_data
	
	# Формируем команду игрока
	player_team = []
	
	# ✅ ИСПРАВЛЕНО: Главный персонаж
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
	
	# ✅ ИСПРАВЛЕНО: Члены банды (начинаем с индекса 1, потому что 0 - это главный)
	print("🎯 Добавление банды в бой. Размер gang_members: ", gang_members.size())
	
	if gang_members.size() > 1:  # Если есть члены кроме главного
		for i in range(1, gang_members.size()):  # ✅ Начинаем с 1, не пропускаем первого члена
			var member = gang_members[i]
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
			print("  ✅ Добавлен боец: ", gang_fighter["name"])
	
	print("📊 Команда игрока: ", player_team.size(), " бойцов")
	
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
	create_team_avatars()
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
	var bg = ColorRect.new()
	bg.size = Vector2(700, 1100)
	bg.position = Vector2(10, 90)
	bg.color = Color(0.05, 0.02, 0.02, 0.98)
	bg.name = "BattleBG"
	add_child(bg)
	
	var title = Label.new()
	title.text = "⚔️ ГРУППОВОЙ БОЙ"
	title.position = Vector2(250, 110)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))
	add_child(title)
	
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
	
	var turn_info = Label.new()
	turn_info.text = "Ваш ход: Атакующий 1"
	turn_info.position = Vector2(200, 820)
	turn_info.add_theme_font_size_override("font_size", 20)
	turn_info.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3, 1.0))
	turn_info.name = "TurnInfo"
	add_child(turn_info)
	
	create_battle_buttons()
	update_ui()

func create_battle_buttons():
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

# ========== АВАТАРКИ ==========
func create_team_avatars():
	# ✅ ИСПРАВЛЕНО: Увеличены отступы для новых размеров
	var player_x = 30
	var player_y = 170
	
	for i in range(min(5, player_team.size())):
		create_avatar(player_team[i], Vector2(player_x, player_y), i, true)
		player_y += 75  # ✅ Увеличен отступ (было 65)
	
	if player_team.size() > 5:
		player_x = 180  # ✅ Сдвинут правее (было 100)
		player_y = 170
		for i in range(5, player_team.size()):
			create_avatar(player_team[i], Vector2(player_x, player_y), i, true)
			player_y += 75
	
	# ✅ Враги сдвинуты левее чтобы поместились
	var enemy_x = 490  # ✅ Было 570
	var enemy_y = 170
	
	for i in range(min(5, enemy_team.size())):
		create_avatar(enemy_team[i], Vector2(enemy_x, enemy_y), i, false)
		enemy_y += 75
	
	if enemy_team.size() > 5:
		enemy_x = 560  # ✅ Было 640
		enemy_y = 170
		for i in range(5, enemy_team.size()):
			create_avatar(enemy_team[i], Vector2(enemy_x, enemy_y), i, false)
			enemy_y += 75

func create_avatar(fighter: Dictionary, pos: Vector2, index: int, is_player_side: bool):
	var avatar_container = Control.new()
	avatar_container.custom_minimum_size = Vector2(140, 60)  # ✅ Увеличена ширина для имени
	avatar_container.position = pos
	avatar_container.name = ("Player" if is_player_side else "Enemy") + "Avatar_" + str(index)
	avatar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(avatar_container)
	
	# ✅ ИМЯ БОЙЦА СВЕРХУ
	var name_label = Label.new()
	name_label.text = fighter["name"]
	name_label.position = Vector2(0, -20)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3, 1.0) if is_player_side else Color(1.0, 0.5, 0.5, 1.0))
	name_label.name = "NameLabel"
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_container.add_child(name_label)
	
	var avatar_bg = ColorRect.new()
	avatar_bg.size = Vector2(50, 50)
	avatar_bg.color = Color(0.3, 0.3, 0.3, 1.0)
	avatar_bg.name = "AvatarBG"
	avatar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_container.add_child(avatar_bg)
	
	var hp_indicator = ColorRect.new()
	var hp_percent = float(fighter["hp"]) / float(fighter["max_hp"])
	hp_indicator.size = Vector2(50, 50 * (1.0 - hp_percent))
	hp_indicator.position = Vector2(0, 0)
	hp_indicator.color = Color(1.0, 0.0, 0.0, 0.6)
	hp_indicator.name = "HPIndicator"
	hp_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_container.add_child(hp_indicator)
	
	var icon = Label.new()
	icon.text = "🤵" if is_player_side else "💀"
	icon.position = Vector2(10, 5)
	icon.add_theme_font_size_override("font_size", 30)
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_container.add_child(icon)
	
	# ✅ КНОПКА НА АВАТАРКЕ (только инвентарь)
	var avatar_btn = Button.new()
	avatar_btn.custom_minimum_size = Vector2(50, 50)
	avatar_btn.position = Vector2(0, 0)
	avatar_btn.text = ""
	avatar_btn.name = "AvatarBtn"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.0)
	avatar_btn.add_theme_stylebox_override("normal", style)
	
	var idx = index
	var is_player = is_player_side
	avatar_btn.pressed.connect(func(): 
		# ✅ Клик на аватар = всегда инвентарь
		show_fighter_inventory(fighter, idx, is_player)
	)
	avatar_container.add_child(avatar_btn)
	
	# ✅ HP ТЕКСТ + КНОПКА ВЫБОРА ЦЕЛИ (справа от аватара)
	var stats_container = Control.new()
	stats_container.position = Vector2(55, 0)
	stats_container.size = Vector2(85, 50)
	stats_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_container.add_child(stats_container)
	
	var hp_label = Label.new()
	hp_label.text = "%d/%d" % [fighter["hp"], fighter["max_hp"]]
	hp_label.position = Vector2(0, 5)
	hp_label.add_theme_font_size_override("font_size", 12)
	hp_label.add_theme_color_override("font_color", Color.WHITE)
	hp_label.name = "HPLabel"
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_container.add_child(hp_label)
	
	var morale_label = Label.new()
	morale_label.text = "💪 %d" % fighter["morale"]
	morale_label.position = Vector2(0, 22)
	morale_label.add_theme_font_size_override("font_size", 10)
	morale_label.add_theme_color_override("font_color", get_morale_color(fighter["morale"]))
	morale_label.name = "MoraleLabel"
	morale_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_container.add_child(morale_label)
	
	var status_label = Label.new()
	status_label.text = get_status_text(fighter)
	status_label.position = Vector2(0, 36)
	status_label.add_theme_font_size_override("font_size", 9)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5, 1.0))
	status_label.name = "StatusLabel"
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_container.add_child(status_label)
	
	# ✅ КНОПКА ВЫБОРА ЦЕЛИ (только для врагов, на области статов)
	if not is_player_side:
		var target_btn = Button.new()
		target_btn.custom_minimum_size = Vector2(85, 50)
		target_btn.position = Vector2(0, 0)
		target_btn.text = ""
		target_btn.name = "TargetBtn"
		
		var style_target = StyleBoxFlat.new()
		style_target.bg_color = Color(1, 1, 1, 0.0)
		target_btn.add_theme_stylebox_override("normal", style_target)
		
		target_btn.pressed.connect(func(): 
			# ✅ Клик на статы врага = выбор цели
			if fighter["alive"]:
				on_target_selected(idx)
		)
		stats_container.add_child(target_btn)
	
	var key = ("player" if is_player_side else "enemy") + "_" + str(index)
	avatar_nodes[key] = avatar_container

# ========== ВЫБОР ЦЕЛИ ==========
func on_target_selected(enemy_index: int):
	var target = enemy_team[enemy_index]
	if not target["alive"]:
		add_to_log("⚠️ Эта цель мертва!")
		return
	
	selected_target = target
	add_to_log("🎯 Цель выбрана: %s" % target["name"])
	highlight_selected_target(enemy_index)

func highlight_selected_target(enemy_index: int):
	for i in range(enemy_team.size()):
		var key = "enemy_" + str(i)
		if avatar_nodes.has(key):
			var avatar = avatar_nodes[key]
			var bg = avatar.get_node_or_null("AvatarBG")
			if bg:
				bg.color = Color(0.3, 0.3, 0.3, 1.0)
	
	var key = "enemy_" + str(enemy_index)
	if avatar_nodes.has(key):
		var avatar = avatar_nodes[key]
		var bg = avatar.get_node_or_null("AvatarBG")
		if bg:
			bg.color = Color(0.8, 0.8, 0.2, 1.0)

func on_attack_button():
	if buttons_locked:
		return
	
	if not selected_target:
		add_to_log("⚠️ Сначала выберите цель!")
		return
	
	if not selected_target["alive"]:
		add_to_log("⚠️ Выбранная цель мертва!")
		selected_target = null
		return
	
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

# ========== АТАКА ==========
func perform_attack():
	if not selected_target or selected_bodypart == "":
		return
	
	var attacker = player_team[current_attacker_index]
	var target = selected_target
	var bodypart = body_parts[selected_bodypart]
	
	if randf() > attacker["accuracy"]:
		add_to_log("🌫 %s промахнулся!" % attacker["name"])
		next_attacker()
		return
	
	var base_damage = attacker["damage"]
	var damage = int(base_damage * bodypart["damage_mult"])
	
	var is_crit = randf() < 0.2
	if is_crit:
		damage = int(damage * 1.5)
		add_to_log("💥 КРИТИЧЕСКИЙ УДАР!")
		apply_crit_effects(target, bodypart["crit_effects"])
	
	var final_damage = max(1, damage - target["defense"])
	target["hp"] -= final_damage
	
	add_to_log("⚔️ %s → %s (%s): -%d HP" % [attacker["name"], target["name"], bodypart["name"], final_damage])
	
	target["morale"] = max(10, target["morale"] - randi_range(5, 15))
	check_fighter_status(target)
	
	update_ui()
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
		
		if excess_damage <= (5 if not fighter.get("is_player", false) else 1):
			fighter["alive"] = false
			fighter["hp"] = 0
			add_to_log("😴 %s потерял сознание!" % fighter["name"])
		else:
			fighter["alive"] = false
			fighter["hp"] = 0
			add_to_log("💀 %s убит!" % fighter["name"])
		
		var team = player_team if fighter.get("is_player", false) or player_team.has(fighter) else enemy_team
		for member in team:
			if member["alive"]:
				member["morale"] = max(10, member["morale"] - 15)

func next_attacker():
	current_attacker_index += 1
	
	while current_attacker_index < player_team.size():
		var attacker = player_team[current_attacker_index]
		if attacker["alive"] and not attacker["status_effects"].has("stunned"):
			break
		current_attacker_index += 1
	
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
		
		var target = get_random_alive_player()
		if not target:
			break
		
		var parts = ["head", "torso", "arms", "legs"]
		var part_key = parts[randi() % parts.size()]
		var bodypart = body_parts[part_key]
		
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
	# ✅ ИСПРАВЛЕНО: Используем get() вместо has()
	if main_node and main_node.get("player_data"):
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

# ========== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ==========
func update_ui():
	for i in range(player_team.size()):
		update_avatar_ui(player_team[i], i, true)
	
	for i in range(enemy_team.size()):
		update_avatar_ui(enemy_team[i], i, false)

func update_avatar_ui(fighter: Dictionary, index: int, is_player_side: bool):
	var key = ("player" if is_player_side else "enemy") + "_" + str(index)
	if not avatar_nodes.has(key):
		return
	
	var avatar = avatar_nodes[key]
	
	var hp_indicator = avatar.get_node_or_null("HPIndicator")
	if hp_indicator:
		var hp_percent = float(fighter["hp"]) / float(fighter["max_hp"])
		hp_indicator.size = Vector2(50, 50 * (1.0 - hp_percent))
	
	var hp_label = avatar.get_node_or_null("HPLabel")
	if hp_label:
		hp_label.text = "%d/%d" % [fighter["hp"], fighter["max_hp"]]
	
	var morale_label = avatar.get_node_or_null("MoraleLabel")
	if morale_label:
		morale_label.text = "💪 %d" % fighter["morale"]
		morale_label.add_theme_color_override("font_color", get_morale_color(fighter["morale"]))
	
	var status_label = avatar.get_node_or_null("StatusLabel")
	if status_label:
		status_label.text = get_status_text(fighter)

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

# ========== ИНВЕНТАРЬ В БОЮ ==========
func show_fighter_inventory(fighter: Dictionary, index: int, is_ally: bool):
	var old_inv = get_node_or_null("BattleInventory")
	if old_inv:
		old_inv.queue_free()
	
	var inv_layer = CanvasLayer.new()
	inv_layer.name = "BattleInventory"
	inv_layer.layer = 250
	add_child(inv_layer)
	
	var overlay = ColorRect.new()
	overlay.size = Vector2(720, 1280)
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	inv_layer.add_child(overlay)
	
	var inv_bg = ColorRect.new()
	inv_bg.size = Vector2(600, 900)
	inv_bg.position = Vector2(60, 190)
	inv_bg.color = Color(0.05, 0.05, 0.1, 0.98)
	inv_layer.add_child(inv_bg)
	
	var title = Label.new()
	title.text = "👤 " + fighter["name"]
	title.position = Vector2(250, 210)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3, 1.0))
	inv_layer.add_child(title)
	
	var y_pos = 260
	
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
	
	var equip_title = Label.new()
	equip_title.text = "═══ ЭКИПИРОВКА ═══"
	equip_title.position = Vector2(230, y_pos)
	equip_title.add_theme_font_size_override("font_size", 18)
	equip_title.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0, 1.0))
	inv_layer.add_child(equip_title)
	y_pos += 35
	
	if is_ally:
		var main_node = get_parent()
		var equipment = {}
		var inventory = []
		var pockets = []
		
		# ✅ ИСПРАВЛЕНО: Проверяем существование свойства через get()
		if fighter.get("is_player", false) and main_node.get("player_data"):
			equipment = main_node.player_data.get("equipment", {})
			inventory = main_node.player_data.get("inventory", [])
			pockets = main_node.player_data.get("pockets", [null, null, null])
		elif main_node.get("gang_members"):
			for member in main_node.gang_members:
				if member["name"] == fighter["name"]:
					equipment = member.get("equipment", {})
					inventory = member.get("inventory", [])
					pockets = member.get("pockets", [null, null, null])
					break
		
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
		
		if pockets.size() > 0:
			var pockets_title = Label.new()
			pockets_title.text = "═══ КАРМАНЫ ═══"
			pockets_title.position = Vector2(240, y_pos)
			pockets_title.add_theme_font_size_override("font_size", 18)
			pockets_title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3, 1.0))
			inv_layer.add_child(pockets_title)
			y_pos += 35
			
			for i in range(pockets.size()):
				var pocket_item = pockets[i]
				
				var pocket_label = Label.new()
				pocket_label.text = "Карман %d: %s" % [i + 1, pocket_item if pocket_item else "пусто"]
				pocket_label.position = Vector2(80, y_pos + 5)
				pocket_label.add_theme_font_size_override("font_size", 15)
				pocket_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8, 1.0) if pocket_item else Color(0.5, 0.5, 0.5, 1.0))
				inv_layer.add_child(pocket_label)
				
				if pocket_item:
					var use_btn = Button.new()
					use_btn.custom_minimum_size = Vector2(120, 30)
					use_btn.position = Vector2(500, y_pos)
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
					inv_layer.add_child(use_btn)
				
				y_pos += 40
	else:
		var weapon_label = Label.new()
		weapon_label.text = "Оружие: " + fighter.get("weapon", "Кулаки")
		weapon_label.position = Vector2(80, y_pos)
		weapon_label.add_theme_font_size_override("font_size", 15)
		weapon_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
		inv_layer.add_child(weapon_label)
	
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

func use_item_in_battle(item_name: String, fighter: Dictionary):
	if not items_db:
		return
	
	var item_data = items_db.get_item(item_name)
	if not item_data or item_data.get("type") != "consumable":
		add_to_log("⚠️ Предмет нельзя использовать!")
		return
	
	if item_data.get("effect") == "heal":
		var heal_amount = item_data.get("value", 10)
		fighter["hp"] = min(fighter["max_hp"], fighter["hp"] + heal_amount)
		add_to_log("💚 %s использовал %s (+%d HP)" % [fighter["name"], item_name, heal_amount])
	elif item_data.get("effect") == "stress":
		fighter["morale"] = min(100, fighter["morale"] + item_data.get("value", 10))
		add_to_log("💪 %s использовал %s (+%d морали)" % [fighter["name"], item_name, item_data.get("value", 10)])
	
	# ✅ ИСПРАВЛЕНО: Проверяем через get()
	var main_node = get_parent()
	if fighter.get("is_player", false) and main_node.get("player_data"):
		for i in range(main_node.player_data["pockets"].size()):
			if main_node.player_data["pockets"][i] == item_name:
				main_node.player_data["pockets"][i] = null
				break
	
	update_ui()
	add_to_log("✅ %s восстановлен" % fighter["name"])
