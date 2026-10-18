extends RefCounted
class_name LoicAIConfig
const PATH := "user://ai_connection.cfg"
static var config: ConfigFile

static func settings() -> ConfigFile:
	if config == null:
		config = ConfigFile.new()
		config.load(PATH)
	return config

static func local_mode() -> bool:
	return OS.get_name() == "Android" or OS.get_environment("LOIC_USE_LOCAL") == "1"

static func enabled() -> bool:
	if OS.get_environment("LOIC_DISABLE_AI") == "1": return false
	return bool(settings().get_value("server","enabled",true))

static func endpoint() -> String:
	var environment := OS.get_environment("LOIC_AI_ENDPOINT")
	if not environment.is_empty(): return environment
	return str(settings().get_value("server","url",ProjectSettings.get_setting("loic/ai_endpoint","http://127.0.0.1:8765/v1/chat/completions")))

static func headers() -> PackedStringArray:
	var result := PackedStringArray(["Content-Type: application/json"])
	var token := OS.get_environment("LOIC_AI_TOKEN")
	if token.is_empty(): token = str(settings().get_value("server","token",""))
	if not token.is_empty(): result.append("Authorization: Bearer " + token)
	return result

static func save_connection(url: String, token: String, active: bool) -> Error:
	if not (url.begins_with("http://") or url.begins_with("https://")) or not url.ends_with("/v1/chat/completions"):
		return ERR_INVALID_PARAMETER
	settings().set_value("server","url",url)
	settings().set_value("server","token",token.strip_edges())
	settings().set_value("server","enabled",active)
	return settings().save(PATH)
