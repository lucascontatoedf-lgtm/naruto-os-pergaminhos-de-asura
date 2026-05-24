extends Node

## LevelManager — Singleton autoload pra orquestração de transições entre zonas.
##
## Registrado em project.godot na seção [autoload] como "LevelManager".
## Acesso global de qualquer script: LevelManager.change_scene("zona_2"),
## LevelManager.restart_zone(), LevelManager.current_zone, etc.
##
## RESPONSABILIDADES (Fase atual — Semana 2 Bloco C):
##   - Trocar de zona via get_tree().change_scene_to_file()
##   - Manter referência logical à zona atual (current_zone)
##   - Reiniciar na zona de respawn padrão (RESPAWN_ZONE = pós-tutorial)
##
## NÃO RESPONSABILIDADES (delegadas pra sistemas futuros):
##   - Persistir HP/chakra/pergaminhos/posição → SaveSystem (autoload futuro)
##   - Salvar progresso em disco → SaveSystem
##   - Time scale safeguard (anti-hitstop travado) → vive em PlayerController._respawn()
##     pra cobrir o caso específico de morte com hitstop ativo. Mover pra cá quando
##     LevelManager.change_scene virar entry point universal de transição.
##
## CONVENÇÃO DE NOMES DE ZONA:
##   "zona_N" como chave logical (zona_1, zona_2, ...) mapeada pra res://levels/*.tscn.
##   Adicionar novas entradas em ZONE_PATHS conforme zonas forem criadas.

## Zona padrão de respawn após morte. Pós-tutorial — Zona 1 é first-run sem respawn.
## Se player morre em qualquer zona (incluindo Zona 5/Floresta), retorna pra cá.
## Decisão de game design: Zona 2 é "checkpoint global" simplificado pro MVP.
const RESPAWN_ZONE: String = "zona_2"

## Mapa zone_name (string logical) → caminho .tscn. Adicionar entradas conforme as
## zonas forem criadas em res://levels/. Convenção: zona_N_descricao.tscn.
##
## AVISO: zona_2 (RESPAWN_ZONE) ainda NÃO existe como arquivo. Até ser criada,
## restart_zone() vai dar push_error e a transição falha silenciosamente. Player
## trava em State.DEATH ou na kill zone. Criar zona_2_casa_central.tscn é a
## próxima task crítica.
const ZONE_PATHS: Dictionary = {
	"zona_2": "res://levels/zona_2_casa_central.tscn",
}

## Rastreia zona atual. Vazio até a primeira chamada bem-sucedida de change_scene().
## Útil pra UI ("Você está em: Vila da Folha"), debug, save futuro.
var current_zone: String = ""

## Troca pra cena correspondente à zone_name. Se a chave não existir em ZONE_PATHS,
## faz push_error e não troca. Não trava o jogo — quem chamou continua executando.
func change_scene(zone_name: String) -> void:
	if not ZONE_PATHS.has(zone_name):
		push_error("LevelManager.change_scene: zona '%s' não registrada em ZONE_PATHS. Adicione a entrada antes de chamar." % zone_name)
		return
	current_zone = zone_name
	get_tree().change_scene_to_file(ZONE_PATHS[zone_name])

## Reinicia na zona de respawn padrão (RESPAWN_ZONE). Chamado por
## PlayerController._respawn() após morte ou queda na kill zone.
func restart_zone() -> void:
	change_scene(RESPAWN_ZONE)
