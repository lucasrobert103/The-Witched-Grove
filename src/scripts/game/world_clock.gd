class_name WorldClock
extends RefCounted
## Ciclos temporais: dia/noite, estações, fases lunares e clima.
## 30 min reais = 1 dia de jogo; 5 dias por estação; ciclo lunar de 8 dias.
## O clima é DETERMINÍSTICO por dia (sem aleatoriedade desnecessária).

const REAL_SECONDS_PER_DAY := 1800.0
const MINUTES_PER_DAY := 1440.0
const DAYS_PER_SEASON := 5
const MOON_CYCLE := 8
const MOON_NAMES := ["nova", "crescente", "quarto crescente", "gibosa crescente", "cheia", "gibosa minguante", "quarto minguante", "minguante"]
const WEATHER_NAMES := {"limpo": "Céu limpo", "chuva": "Chuva", "bruma": "Bruma", "neve": "Neve"}
## Probabilidades (%) por estação: [chuva, bruma, neve]; o resto é céu limpo.
const WEATHER_TABLE := {
	"primavera": [30, 15, 0],
	"verao": [12, 5, 0],
	"outono": [25, 30, 0],
	"inverno": [10, 15, 40],
}

var total_minutes: float = 7.0 * 60.0   # começa no dia 1, 07:00


func minutes_per_real_second() -> float:
	return MINUTES_PER_DAY / REAL_SECONDS_PER_DAY


func advance_real(delta: float) -> float:
	var m := delta * minutes_per_real_second()
	total_minutes += m
	return m


func advance_minutes(m: float) -> void:
	total_minutes += maxf(0.0, m)


func day() -> int:
	return int(floor(total_minutes / MINUTES_PER_DAY)) + 1


func hour() -> float:
	return fmod(total_minutes, MINUTES_PER_DAY) / 60.0


func season_for_day(d: int) -> String:
	var seasons := ["primavera", "verao", "outono", "inverno"]
	return seasons[int(floor(float(d - 1) / DAYS_PER_SEASON)) % 4]


func season() -> String:
	return season_for_day(day())


func day_of_season() -> int:
	return ((day() - 1) % DAYS_PER_SEASON) + 1


func moon_phase() -> int:
	return (day() - 1) % MOON_CYCLE


func moon_name() -> String:
	return MOON_NAMES[moon_phase()]


func is_full_moon() -> bool:
	return moon_phase() == 4


func is_night() -> bool:
	var h := hour()
	return h >= 19.5 or h < 5.5


func is_dusk() -> bool:
	var h := hour()
	return h >= 17.0 and h < 19.5


## 0 = dia pleno, 1 = noite plena (transições suaves no amanhecer e anoitecer).
func night_factor() -> float:
	var h := hour()
	if h >= 7.0 and h <= 17.5:
		return 0.0
	if h > 17.5 and h < 20.0:
		return (h - 17.5) / 2.5
	if h >= 5.0 and h < 7.0:
		return 1.0 - (h - 5.0) / 2.0
	return 1.0


func weather_for_day(d: int) -> String:
	var roll := ((d * 1103515245 + 12345) >> 8) % 100
	var t: Array = WEATHER_TABLE[season_for_day(d)]
	if roll < t[0]:
		return "chuva"
	if roll < t[0] + t[1]:
		return "bruma"
	if roll < t[0] + t[1] + t[2]:
		return "neve"
	return "limpo"


func weather() -> String:
	if day() == 1:
		return "limpo"   # primeiro dia sempre bonito
	return weather_for_day(day())


func weather_name() -> String:
	return WEATHER_NAMES.get(weather(), weather())


func time_string() -> String:
	var h := hour()
	return "%02d:%02d" % [int(h), int(fmod(h * 60.0, 60.0))]


func to_dict() -> Dictionary:
	return {"total_minutes": total_minutes}


func from_dict(d: Dictionary) -> void:
	total_minutes = float(d.get("total_minutes", 7.0 * 60.0))
