extends Node

## DialogueManager — Singleton autoload pra controle de diálogos do jogo.
##
## Registrado em project.godot na seção [autoload] como "DialogueManager".
## Acesso global: DialogueManager.start_dialogue("jiraiya_intro").
##
## RESPONSABILIDADES:
##   - Manter catálogo de diálogos (const DIALOGUES)
##   - Pausar o jogo durante diálogo (get_tree().paused = true)
##   - Instanciar e gerenciar DialogueBox (UI)
##   - Avançar/encerrar diálogo via API pública chamada por DialogueBox
##   - Emitir signals pra triggers reagirem (kamui_triggered em particular)
##
## NÃO RESPONSABILIDADES:
##   - Renderizar balão (DialogueBox cuida)
##   - Detectar área (DialogueTrigger cuida)
##   - Executar transições visuais (KamuiTrigger cuida)
##
## OBS: Sem class_name pra evitar conflito com nome do autoload (mesmo padrão do
## LevelManager). Acesso é via singleton global "DialogueManager".

const DialogueBoxScene: PackedScene = preload("res://scenes/ui/dialogue_box.tscn")

signal dialogue_started(id: String)
signal dialogue_ended(id: String)
signal kamui_triggered
signal line_advanced(index: int)   ## Emitido em advance() ANTES de show_line(). Permite cutscenes/scripts reagirem a índices específicos (ex: trocar background ao chegar em "Pain: Inesperado.").

## Catálogo central de diálogos. Chave = id logical, valor = Array[Dictionary]
## com {speaker: String, text: String} por linha. Speaker vazio ("") = linha
## sem nome (ex: onomatopeias como "FWOOSH").
const DIALOGUES: Dictionary = {
	"jiraiya_intro": [
		{"speaker": "Jiraiya", "text": "Yo, Naruto! Antes de sair quebrando tudo, aprende a se mover direito!"},
		{"speaker": "Naruto", "text": "Heh! Eu já sei fazer isso, sábio tarado!"},
		{"speaker": "Jiraiya", "text": "Então prova. Usa W, A, S, D pra se mover."},
		{"speaker": "Naruto", "text": "Fácil! Tô voando aqui!"},
		{"speaker": "Jiraiya", "text": "Agora tenta alcançar aquela plataforma alta. Aperta W duas vezes pra dar um Double Jump!"},
		{"speaker": "Naruto", "text": "WOAH! Isso foi irado!! Tô certo!"},
		{"speaker": "Jiraiya", "text": "Inimigo vindo! Pressiona J pra usar o Corte de Kunai."},
		{"speaker": "Naruto", "text": "HYAH! Curtinho… mas rápido!"},
		{"speaker": "Jiraiya", "text": "Tá longe demais? Então usa K pra lançar uma Shuriken!"},
		{"speaker": "Naruto", "text": "Toma essa!! Hahaha! Tô certo!"},
		{"speaker": "Jiraiya", "text": "Agora presta atenção. Dá dois toques rápidos em qualquer direção pra usar o Dash!"},
		{"speaker": "Naruto", "text": "WHOOSH!! Cara… isso é MUITO rápido!"},
		{"speaker": "Jiraiya", "text": "Caiu na parede? Não entra em pânico. Segura na direção dela e você vai deslizar lentamente."},
		{"speaker": "Naruto", "text": "OHHH! Igual ninja de verdade!"},
		{"speaker": "Jiraiya", "text": "E você ainda pode lançar shurikens enquanto escorrega."},
		{"speaker": "Naruto", "text": "Isso ficou estiloso demais!"},
		{"speaker": "Jiraiya", "text": "Chakra baixo já? Sabia… Senta e segura Shift Esquerdo pra meditar e recuperar chakra."},
		{"speaker": "Naruto", "text": "Hmmm… calma… foco… …Ei! Meu chakra voltou! Tô certo!"},
		{"speaker": "Jiraiya", "text": "Hora da técnica especial. Pressiona O."},
		{"speaker": "Naruto", "text": "RASENGANNNNN!!!"},
		{"speaker": "Jiraiya", "text": "Muito bem, Naruto. Agora vai lá e tenta não destruir metade da vila."},
		{"speaker": "Naruto", "text": "Sem promessas, sábio tarado!"},
	],
	"akatsuki_encontro": [
		{"speaker": "Naruto", "text": "Ugh… que lugar estranho é esse…? Uma árvore gigante… por dentro?! Tô certo?"},
		{"speaker": "Konan", "text": "Ele entrou sozinho."},
		{"speaker": "Pain", "text": "Inesperado."},
		{"speaker": "Naruto", "text": "Hã?! Quem são vocês?!"},
		{"speaker": "Tobi", "text": "Hihi… você é bem barulhento."},
		{"speaker": "Naruto", "text": "E você usa uma máscara esquisita! Isso é algum tipo de gangue ninja?"},
		{"speaker": "Pain", "text": "Nós somos a Akatsuki."},
		{"speaker": "Naruto", "text": "Aka… o quê?"},
		{"speaker": "Konan", "text": "Não importa para você."},
		{"speaker": "Naruto", "text": "Importa sim! Eu tô procurando o Pergaminho de Asura. Vocês sabem alguma coisa sobre ele?"},
		{"speaker": "Pain", "text": "Asura…"},
		{"speaker": "Tobi", "text": "Hmm…"},
		{"speaker": "Naruto", "text": "Então vocês sabem! Onde tá?!"},
		{"speaker": "Pain", "text": "Esse nome não deveria existir neste tempo."},
		{"speaker": "Naruto", "text": "Hein? Para de falar complicado! Só responde!"},
		{"speaker": "Konan", "text": "Ele realmente não entende nada…"},
		{"speaker": "Naruto", "text": "Claro que não entendo! Eu literalmente caí num buraco dentro de uma árvore e encontrei três malucos usando a mesma roupa!"},
		{"speaker": "Tobi", "text": "Hahahaha!"},
		{"speaker": "Naruto", "text": "E você para de rir! Você sabe do pergaminho ou não?!"},
		{"speaker": "Pain", "text": "Talvez o pergaminho tenha encontrado você."},
		{"speaker": "Naruto", "text": "…Tá, agora vocês tão falando igual velho sábio. Eu odeio quando fazem isso."},
		{"speaker": "Tobi", "text": "Você faz perguntas demais."},
		{"speaker": "Naruto", "text": "Porque ninguém responde direito!"},
		{"speaker": "Tobi", "text": "…"},
		{"speaker": "Naruto", "text": "Então fala logo!"},
		{"speaker": "Tobi", "text": "Cansei de você… e não precisamos te capturar agora."},
		{"speaker": "Naruto", "text": "Hã?"},
		{"speaker": "Tobi", "text": "Kamui."},
		{"speaker": "Naruto", "text": "NÃO! ESPERAAAAAAAAA..."},
		{"speaker": "", "text": "FWOOOSH"},
	],
	"akatsuki_saida": [
		{"speaker": "Naruto", "text": "Que coisa mais esquisita."},
		{"speaker": "Naruto", "text": "tanto faz..."},
	],
	"ichiraku_encontro": [
		{"speaker": "Naruto", "text": "Ugh… tô morrendo de fome… Mas sem dinheiro de novo…"},
		{"speaker": "Jiraiya", "text": "Entra aí, garoto."},
		{"speaker": "Naruto", "text": "Hã?"},
		{"speaker": "", "text": "Naruto olha para dentro do Ichiraku."},
		{"speaker": "Naruto", "text": "Sábio tarado?!"},
		{"speaker": "Jiraiya", "text": "Yo. Você tá com uma cara horrível."},
		{"speaker": "Naruto", "text": "Claro! Eu passei o dia inteiro andando por aí!"},
		{"speaker": "Jiraiya", "text": "E apostando que não comeu nada."},
		{"speaker": "Naruto", "text": "…Talvez."},
		{"speaker": "Jiraiya", "text": "Hahaha! Senta logo."},
		{"speaker": "Naruto", "text": "Espera… você vai mesmo pagar ramen pra mim?"},
		{"speaker": "Jiraiya", "text": "O velho aqui também precisa comer."},
		{"speaker": "Naruto", "text": "Isso não respondeu minha pergunta."},
		{"speaker": "Jiraiya", "text": "Duas tigelas gigantes!"},
		{"speaker": "Naruto", "text": "YEAAAHHH!!"},
		{"speaker": "", "text": "Naruto devora o ramen."},
		{"speaker": "Naruto", "text": "Cara… isso tá MUITO bom…"},
		{"speaker": "Jiraiya", "text": "Você come como um animal."},
		{"speaker": "Naruto", "text": "Porque eu tava morrendo de fome! Tô certo?!"},
		{"speaker": "Jiraiya", "text": "Hm… continua barulhento igualzinho."},
		{"speaker": "Naruto", "text": "Igualzinho a quem?"},
		{"speaker": "Jiraiya", "text": "…Nada."},
		{"speaker": "Naruto", "text": "Ahhh… agora sim eu voltei à vida."},
		{"speaker": "Jiraiya", "text": "Pode deixar que eu pago. Você é mesmo a criança da profecia."},
		{"speaker": "Naruto", "text": "Hein? Lá vem você falando coisa estranha de novo…"},
	],
	"ichiraku_saida": [
		{"speaker": "Naruto", "text": "…Esse velhote é maluco."},
	],
}

# Estado interno do diálogo ativo.
var _current_lines: Array = []
var _current_index: int = 0
var _current_id: String = ""
var _dialogue_box: Node = null
var _is_kamui_sequence: bool = false   ## Flag pra identificar fim do akatsuki_encontro

## Inicia o diálogo de id especificado. Pausa o jogo, instancia DialogueBox se ainda
## não existir, e exibe a primeira linha. Erro se id não existir em DIALOGUES.
func start_dialogue(id: String) -> void:
	if not DIALOGUES.has(id):
		push_error("DialogueManager.start_dialogue: id '%s' não existe em DIALOGUES." % id)
		return
	_current_lines = DIALOGUES[id]
	_current_index = 0
	_current_id = id
	_is_kamui_sequence = (id == "akatsuki_encontro")

	if _dialogue_box == null or not is_instance_valid(_dialogue_box):
		_dialogue_box = DialogueBoxScene.instantiate()
		get_tree().root.add_child(_dialogue_box)

	get_tree().paused = true
	_dialogue_box.show_line(_current_lines[0])
	dialogue_started.emit(id)

## Avança pra próxima linha. Chamado por DialogueBox._unhandled_input ao receber
## ui_accept/attack_light. Se acabou as linhas, encerra OU dispara Kamui sequence
## (especificamente após akatsuki_encontro).
func advance() -> void:
	_current_index += 1
	if _current_index >= _current_lines.size():
		if _current_id == "akatsuki_encontro":
			_trigger_kamui()
		else:
			end_dialogue()
		return
	line_advanced.emit(_current_index)
	_dialogue_box.show_line(_current_lines[_current_index])

## Encerra o diálogo atual. Despausa o jogo, esconde balão, emit signal.
func end_dialogue() -> void:
	get_tree().paused = false
	if _dialogue_box != null and is_instance_valid(_dialogue_box):
		_dialogue_box.hide_box()
	var finished_id: String = _current_id
	_current_id = ""
	_current_lines = []
	_current_index = 0
	_is_kamui_sequence = false
	dialogue_ended.emit(finished_id)

## Dispara sequence Kamui (fim do akatsuki_encontro). Encerra o diálogo atual e
## emite signal kamui_triggered — KamuiTrigger ouve, executa fade+teleporte, depois
## inicia akatsuki_saida.
func _trigger_kamui() -> void:
	end_dialogue()
	kamui_triggered.emit()

