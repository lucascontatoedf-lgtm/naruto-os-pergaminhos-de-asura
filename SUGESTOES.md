# Sugestões Futuras

| # | Sugestão | Zona | Tipo |
|---|---|---|---|
| 01 | Animação de Chakra Charge ✅ | — | Polish |
| 02 | Espadas dos 6 Espadachins da Névoa | Zona 5 | Easter egg |
| 03 | Ichiraku Ramen — mini fase | Zona 4 | Easter egg |
| 04 | Cobra branca do Orochimaru | Zona 2 | Easter egg |
| 05 | Esconderijo Akatsuki | Zona 2 | Easter egg |
| 06 | Jiraiya no tutorial (substitui Neji) | Zona 1 | Design |

---

## Detalhes

### #02 — Espadas dos Espadachins (Zona 5)
- 6 espadas escondidas no mapa da batalha final
- Apenas visuais/interativas
- Zabuza fica com a Kubikiribocho

### #03 — Ichiraku Ramen (Zona 4)
- Easter egg opcional, entrada pela aldeia
- Mini fase só de diálogos
- Animação de entrada → Naruto de costas comendo → Kakashi paga → poster de procurado do Itachi na parede
- Sem combate, puro fan service

### #04 — Cobra do Orochimaru (Zona 2)
- Cobra branca escondida em árvore
- Só a cabeça se move, rastreando o player com o olhar
- Sem diálogo, sem combate

### #05 — Esconderijo Akatsuki (Zona 2)
- Camada 1 (ambiental): player passa em frente ao prédio, vê ninjas em combate nos telhados — referência ao Exame Chunin, puramente visual
- Camada 2 (acesso escondido): árvore específica sem indicador visual. Player atira shuriken (K) → parte da árvore quebra (objeto destrutível, componente genérico destructible.gd) → revela entrada
- Camada 3 (esconderijo): Gedo Mazo + Pain no trono + Konan à esquerda + Obito (máscara laranja) à direita. Naruto pergunta sobre o Pergaminho de Asura. Akatsuki dispensam sem se apresentar. Tobi usa Kamui para ejetar o player.

### #06 — Jiraiya no Tutorial (Zona 1)
- Substitui Neji completamente
- Jiraiya apresenta cada golpe no estilo mestre→aluno
- Trigger automático (player entra na área, diálogo inicia sozinho)

---

### #07 — Tutorial interativo — Zona 2 (JiraiyaTrigger)

| Campo | Valor |
|---|---|
| Zona | 2 |
| Tipo | Gameplay / Tutorial |

#### Problema atual
- JiraiyaTrigger AUTO dispara o diálogo completo na entrada da Zona 2
- Jogador avança tudo com J sem executar nenhum input
- Iniciante não aprende nada

#### Design fechado
- Criar TutorialTrigger — sistema independente do DialogueSystem
- Exibe uma instrução por vez ("Pressione D para mover direita")
- Aguarda o input correto do jogador antes de avançar
- Só então exibe a próxima instrução
- Inputs mínimos a cobrir: movimento (D), pulo (W), Rasengan (O)
