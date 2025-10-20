# battle.gd (РЕФАКТОРИНГ - ГЛАВНЫЙ КОНТРОЛЛЕР)
# Сохранены: аватарки, HP бары, зоны попадания, групповой бой
extends CanvasLayer

signal battle_ended(victory: bool)

# ===== КОМПОНЕНТЫ =====
var ui_manager
var logic_manager
var avatar_manager

# ===== ДАННЫЕ =====
var player_data
var gang_members: Array = []
var is_first_battle: bool = false

# ===== ПОСЛЕДНИЙ ВЫБОР =====
var last_selected_target: int = 0
var last_selected_zone: String = "торс"

func _ready():
	layer = 200
	
	# Создаём компоненты
	ui_manager = preload("res://scripts/battle/battle_ui_full.gd").new()
	logic_manager = preload("res://scripts/battle/battle_logic_full.gd").new()
	avatar_manager = preload("res://scripts/battle/battle_avatars.gd").new()
	
	add_child(ui_manager)
	add_child(logic_manager)
	add_child(avatar_manager)
	
	# Подключаем сигналы
	logic_manager.battle_won.connect(_on_battle_won)
	logic_manager.battle_lost.connect(_on_battle_lost)
	logic_manager.turn_changed.connect(_on_turn_changed)
	logic_manager.damage_dealt.connect(_on_damage_dealt)
	
	ui_manager.action_requested.connect(_on_player_action)

func setup(p_data: Dictionary, enemy_type: String = "gopnik", first_battle: bool = false):
	player_data = p_data
	is_first_battle = first_battle
	
	# Загружаем банду (ТЫ + союзники)
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has("gang_members"):
		gang_members = main_scene.gang_members.duplicate(true)
	else:
		gang_members = [{"name": "Ты", "health": player_data["health"], "max_health": 100}]
	
	# Генерируем врагов
	var enemies_count = 1 + randi() % 2  # 1-2 врага
	
	# Инициализируем логику
	logic_manager.setup(gang_members, enemy_type, enemies_count, is_first_battle)
	
	# Инициализируем аватарки
	avatar_manager.setup(gang_members, logic_manager.enemies)
	
	# Инициализируем UI
	ui_manager.setup(is_first_battle)
	
	# Первое обновление
	update_display()
	
	if is_first_battle:
		ui_manager.add_log("⚠️ ПЕРВЫЙ БОЙ - убежать нельзя!")
	
	ui_manager.add_log("⚔️ Бой начался!")

# ===== ОБНОВЛЕНИЕ ДИСПЛЕЯ =====
func update_display():
	var state = logic_manager.get_battle_state()
	avatar_manager.update_avatars(state)
	ui_manager.update_info(state)

# ===== ДЕЙСТВИЯ ИГРОКА =====
func _on_player_action(action_type: String, target: int = -1, zone: String = ""):
	match action_type:
		"attack":
			# ✅ Сохраняем последний выбор
			if target >= 0:
				last_selected_target = target
			if zone != "":
				last_selected_zone = zone
			
			logic_manager.player_attack(last_selected_target, last_selected_zone)
		"defend":
			logic_manager.player_defend()
		"use_item":
			logic_manager.player_use_item(target)
		"run":
			logic_manager.player_run()
	
	update_display()

# ===== АНИМАЦИЯ УРОНА =====
func _on_damage_dealt(target_type: String, target_index: int, damage: int, zone: String):
	avatar_manager.show_damage_animation(target_type, target_index, damage, zone)

# ===== СМЕНА ХОДА =====
func _on_turn_changed(turn_owner: String):
	if turn_owner == "player":
		ui_manager.set_turn_info("Ваш ход", true)
	elif turn_owner == "allies":
		ui_manager.set_turn_info("Ход союзников...", false)
		await get_tree().create_timer(1.0).timeout
		process_allies_turn()
	else:
		ui_manager.set_turn_info("Ход врагов...", false)
		await get_tree().create_timer(1.5).timeout
		logic_manager.process_enemy_turn()
		update_display()

# ===== ХОДЫ СОЮЗНИКОВ (АВТОМАТИЧЕСКИЕ) =====
func process_allies_turn():
	var allies = logic_manager.get_allies()
	var enemies = logic_manager.get_enemies()
	
	for i in range(1, allies.size()):  # Пропускаем игрока (индекс 0)
		var ally = allies[i]
		
		if ally["health"] <= 0:
			continue
		
		if enemies.size() == 0:
			break
		
		# Выбираем случайную цель
		var target_idx = randi() % enemies.size()
		var zone = ["голова", "торс", "руки", "ноги"][randi() % 4]
		
		ui_manager.add_log("🤝 %s атакует..." % ally["name"])
		await get_tree().create_timer(0.5).timeout
		
		logic_manager.ally_attack(i, target_idx, zone)
		update_display()
		
		await get_tree().create_timer(0.5).timeout
	
	# Переход к врагам
	logic_manager.next_turn()

# ===== ПОБЕДА/ПОРАЖЕНИЕ =====
func _on_battle_won(reward: Dictionary):
	ui_manager.add_log("✅ ПОБЕДА!")
	ui_manager.add_log("💰 Получено: %d руб., +%d репутации" % [reward["money"], reward["reputation"]])
	
	await get_tree().create_timer(2.5).timeout
	
	# Сохраняем HP банды
	if player_data:
		player_data["health"] = logic_manager.get_player_health()
	
	battle_ended.emit(true)
	queue_free()

func _on_battle_lost():
	ui_manager.add_log("💀 ПОРАЖЕНИЕ...")
	
	if is_first_battle:
		ui_manager.add_log("📖 Идите в больницу!")
	
	await get_tree().create_timer(2.5).timeout
	
	if player_data:
		player_data["health"] = 20
	
	battle_ended.emit(false)
	queue_free()

# ===== ВСПОМОГАТЕЛЬНЫЕ =====
func get_last_target() -> Dictionary:
	return {"target": last_selected_target, "zone": last_selected_zone}
