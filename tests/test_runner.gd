extends Node
## Executa todos os testes em tests/unit e tests/integration.
## Uso: godot --headless res://tests/test_runner.tscn
## Código de saída: 0 = tudo passou, 1 = falhas.

const DIRS := ["res://tests/unit", "res://tests/integration"]


func _ready() -> void:
	await get_tree().process_frame
	var total_tests := 0
	var total_asserts := 0
	var all_failures: Array[String] = []
	for dir in DIRS:
		for file in _list(dir):
			var script: GDScript = load(dir.path_join(file))
			var t: TestCase = script.new()
			var methods: Array = []
			for m in t.get_method_list():
				if String(m.name).begins_with("test_"):
					methods.append(m.name)
			methods.sort()
			for m in methods:
				t.current_test = "%s::%s" % [file.get_basename(), m]
				t.before_each()
				var before := t.failures.size()
				t.call(m)
				total_tests += 1
				var status := "OK " if t.failures.size() == before else "FALHOU"
				print("  [%s] %s" % [status, t.current_test])
			total_asserts += t.asserts
			all_failures.append_array(t.failures)
	print("")
	print("==== %d testes, %d verificações, %d falhas ====" % [total_tests, total_asserts, all_failures.size()])
	for f in all_failures:
		printerr("  ✗ " + f)
	get_tree().quit(0 if all_failures.is_empty() else 1)


func _list(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(f)
	out.sort()
	return out
