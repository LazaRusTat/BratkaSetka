extends Node

signal stats_changed()
signal stat_leveled_up(stat_name: String, new_level: int)

# Базовые характеристики
var base_stats = {
	"STR": 3,      # Сила - урон ближнего боя, перенос
	"AGI": 4,      # Ловкость - уворот, скорость
	"ACC": 2,      # Меткость - точность стрельбы
	"LCK": 1,      # Удача - лут, XP
	"INT": 3,      # Интеллект - XP, обучение
	"ELEC": 1,     # Электроника - взлом электроники
	"PICK": 1,     # Взлом замков
	"CHA": 2,      # Красноречие - переговоры
	"DRV": 2,      # Вождение
	"STEALTH": 2   # Скрытность
}

# Опыт для каждой характеристики
var stat_experience = {
	"STR": 0,
	"AGI": 0,
	"ACC": 0,
	"LCK": 0,
	"INT": 0,
	"ELEC": 0,
	"PICK": 0,
	"CHA": 0,
	"DRV": 0,
	"STEALTH": 0
}

# Сколько XP нужно для следующего уровня
func get_xp_for_next_level(current_level: int) -> int:
	return 100 + (current_level - 1) * 50

# Бонусы от экипировки
var equipment_bonuses = {
	"STR": 0,
	"AGI": 0,
	"ACC": 0,
	"defense": 0,
	"melee_damage": 0,
	"ranged_damage": 0
}

func _ready():
	print("📊 Система характеристик загружена")

# Добавить опыт к характеристике
func add_stat_xp(stat_name: String, amount: int):
	if stat_name not in stat_experience:
		return
	
	stat_experience[stat_name] += amount
	var current_level = base_stats[stat_name]
	var xp_needed = get_xp_for_next_level(current_level)
	
	print("📈 +" + str(amount) + " XP к " + stat_name + " (" + str(stat_experience[stat_name]) + "/" + str(xp_needed) + ")")
	
	# Проверка на повышение уровня
	while stat_experience[stat_name] >= xp_needed:
		stat_experience[stat_name] -= xp_needed
		base_stats[stat_name] += 1
		current_level = base_stats[stat_name]
		xp_needed = get_xp_for_next_level(current_level)
		
		stat_leveled_up.emit(stat_name, base_stats[stat_name])
		print("⭐ " + stat_name + " повышен до " + str(base_stats[stat_name]) + "!")
		
		stats_changed.emit()

# === ДЕЙСТВИЯ ДЛЯ ПРОКАЧКИ ===

# Использование оружия ближнего боя
func on_melee_attack():
	add_stat_xp("STR", 5)

# Использование оружия дальнего боя
func on_ranged_attack():
	add_stat_xp("ACC", 5)

# Успешное уклонение
func on_dodge_success():
	add_stat_xp("AGI", 3)

# Взлом электроники
func on_hack_attempt(success: bool):
	if success:
		add_stat_xp("ELEC", 15)
	else:
		add_stat_xp("ELEC", 3)

# Взлом замка
func on_lockpick_attempt(success: bool):
	if success:
		add_stat_xp("PICK", 15)
	else:
		add_stat_xp("PICK", 3)

# Убеждение в диалоге
func on_persuasion_attempt(success: bool):
	if success:
		add_stat_xp("CHA", 12)
	else:
		add_stat_xp("CHA", 3)

# Вождение
func on_driving(distance: float):
	var xp = floor(distance / 10.0)
	if xp > 0:
		add_stat_xp("DRV", int(xp))

# Скрытные действия
func on_stealth_action(detected: bool):
	if not detected:
		add_stat_xp("STEALTH", 8)
	else:
		add_stat_xp("STEALTH", 2)

# Кража
func on_theft_attempt(detected: bool, value: int):
	if not detected:
		add_stat_xp("STEALTH", 10 + floor(value / 50.0))
	else:
		add_stat_xp("STEALTH", 2)

# Получить итоговую характеристику (база + бонусы)
func get_stat(stat_name: String) -> int:
	var base = base_stats.get(stat_name, 0)
	var bonus = equipment_bonuses.get(stat_name, 0)
	return base + bonus

# Увеличить базовую характеристику
func increase_stat(stat_name: String, amount: int = 1):
	if stat_name in base_stats:
		base_stats[stat_name] += amount
		stats_changed.emit()
		print("📈 " + stat_name + " увеличен до " + str(base_stats[stat_name]))

# Пересчитать бонусы от экипировки
func recalculate_equipment_bonuses(equipment: Dictionary, items_db):
	# Сброс бонусов
	for key in equipment_bonuses.keys():
		equipment_bonuses[key] = 0
	
	# Подсчёт бонусов от каждого предмета
	for slot in equipment.keys():
		var item_name = equipment[slot]
		if item_name:
			var item_data = items_db.get_item(item_name)
			if item_data:
				# Защита
				if "defense" in item_data:
					equipment_bonuses["defense"] += item_data["defense"]
				
				# Урон оружия
				if "damage" in item_data:
					if item_data["type"] == "melee":
						equipment_bonuses["melee_damage"] += item_data["damage"]
					elif item_data["type"] == "ranged":
						equipment_bonuses["ranged_damage"] += item_data["damage"]
	
	stats_changed.emit()
	print("🔄 Бонусы пересчитаны: ", equipment_bonuses)

# === БОЕВЫЕ РАСЧЁТЫ ===

# Урон ближнего боя
func calculate_melee_damage() -> int:
	var str_stat = get_stat("STR")
	var weapon_base = equipment_bonuses["melee_damage"]
	if weapon_base == 0:
		weapon_base = 2  # Голыми руками
	
	var total = weapon_base + floor(str_stat * 0.6)
	return int(total)

# Урон дальнего боя
func calculate_ranged_damage() -> int:
	var acc_stat = get_stat("ACC")
	var weapon_base = equipment_bonuses["ranged_damage"]
	if weapon_base == 0:
		return 0  # Нет оружия
	
	var total = weapon_base * (1.0 + acc_stat * 0.02)
	return int(total)

# Шанс уклонения (%)
func calculate_evasion() -> int:
	var agi = get_stat("AGI")
	var lck = get_stat("LCK")
	var evasion = min(75, agi * 2 + floor(lck * 0.2))
	return int(evasion)

# Скорость передвижения (tiles/sec)
func calculate_move_speed() -> float:
	var agi = get_stat("AGI")
	return 1.0 + agi * 0.05

# Шанс попадания при стрельбе (%)
func calculate_hit_chance(weapon_accuracy: float = 0.85, target_cover: float = 0.0) -> float:
	var acc = get_stat("ACC")
	var hit = weapon_accuracy * (1.0 + acc * 0.03) * (1.0 - target_cover * 0.25)
	return clamp(hit, 0.05, 0.95)

# === НАВЫКИ ===

# Шанс взлома электроники
func calculate_hack_chance(difficulty: float = 0.5) -> float:
	var elec = get_stat("ELEC")
	var success = clamp(difficulty / (1.0 + elec * 0.08), 0.05, 0.95)
	return 1.0 - success  # Инвертируем (выше ELEC = выше шанс)

# Шанс взлома замка
func calculate_lockpick_chance(tool_bonus: float = 0.0) -> float:
	var pick = get_stat("PICK")
	return clamp(0.2 + pick * 0.04 + tool_bonus, 0.0, 0.95)

# Шанс убеждения
func calculate_persuasion_chance(base: float = 0.3) -> float:
	var cha = get_stat("CHA")
	return clamp(base + cha * 0.05, 0.0, 0.95)

# Множитель опыта
func calculate_xp_multiplier() -> float:
	var int_stat = get_stat("INT")
	var lck = get_stat("LCK")
	return 1.0 + int_stat * 0.03 + lck * 0.01

# Радиус обнаружения при скрытности
func calculate_detection_radius(base_radius: float = 100.0, visibility: float = 1.0) -> float:
	var stealth = get_stat("STEALTH")
	return base_radius * (visibility - stealth * 0.04)

# === ПОЛУЧЕНИЕ ИНФОРМАЦИИ ===

# Получить все характеристики для отображения
func get_all_stats() -> Dictionary:
	return {
		"base": base_stats.duplicate(),
		"bonuses": equipment_bonuses.duplicate(),
		"combat": {
			"melee_damage": calculate_melee_damage(),
			"ranged_damage": calculate_ranged_damage(),
			"evasion": calculate_evasion(),
			"defense": equipment_bonuses["defense"]
		},
		"skills": {
			"move_speed": calculate_move_speed(),
			"xp_mult": calculate_xp_multiplier()
		}
	}

# Получить строку со всеми стататми для UI
func get_stats_text() -> String:
	var text = "═══ ХАРАКТЕРИСТИКИ ═══\n"
	text += "💪 Сила: %d | 🤸 Ловкость: %d | 🎯 Меткость: %d\n" % [get_stat("STR"), get_stat("AGI"), get_stat("ACC")]
	text += "🍀 Удача: %d | 🧠 Интеллект: %d | 🗣 Красноречие: %d\n" % [get_stat("LCK"), get_stat("INT"), get_stat("CHA")]
	text += "💻 Электроника: %d | 🔓 Взлом: %d | 🚗 Вождение: %d | 🥷 Скрытность: %d\n" % [get_stat("ELEC"), get_stat("PICK"), get_stat("DRV"), get_stat("STEALTH")]
	text += "\n═══ БОЕВЫЕ ПАРАМЕТРЫ ═══\n"
	text += "⚔ Урон ближний: %d | 🔫 Урон дальний: %d\n" % [calculate_melee_damage(), calculate_ranged_damage()]
	text += "🛡 Защита: %d | 🌀 Уклонение: %d%%\n" % [equipment_bonuses["defense"], calculate_evasion()]
	text += "🏃 Скорость: %.2f tiles/sec\n" % calculate_move_speed()
	return text
