extends Node

## SaveSystem — Singleton autoload pra persistência de estado do Player entre zonas.
##
## Registrado em project.godot na seção [autoload] como "SaveSystem".
## Acesso global: SaveSystem.save(player), SaveSystem.load_into(player), SaveSystem.reset().
##
## RESPONSABILIDADES:
##   - Snapshot em memória de HP, chakra e pergaminhos coletados
##   - Restaurar estado no Player após troca de zona via LevelManager
##
## NÃO RESPONSABILIDADES (por enquanto):
##   - Persistência em disco — só vive em memória, perde ao fechar o jogo
##   - Reset em respawn — PlayerController._respawn() recarrega a cena e o _ready()
##     do novo Player reseta naturalmente via defaults; SaveSystem não interfere
##
## CONTRATO:
##   has_data() vira true após o primeiro save(). Antes disso, load_into() é no-op.
##   _collected_scrolls é tratado com guard (`in player`) porque CollectibleSystem
##   ainda não foi implementado — quando a var aparecer no Player, persiste sozinho.

var _hp: int = -1
var _chakra: float = -1.0
var _scrolls: Array[String] = []

func has_data() -> bool:
	return _hp != -1

func save(player) -> void:
	_hp = player.current_health
	_chakra = player.current_chakra
	if "_collected_scrolls" in player:
		_scrolls = player._collected_scrolls.duplicate()

func load_into(player) -> void:
	if not has_data(): return
	player.current_health = _hp
	player.current_chakra = _chakra
	if "_collected_scrolls" in player:
		player._collected_scrolls = _scrolls.duplicate()

func reset() -> void:
	_hp = -1
	_chakra = -1.0
	_scrolls = []
