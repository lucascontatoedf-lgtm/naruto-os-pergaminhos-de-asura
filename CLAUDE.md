# CLAUDE.md — Regras Permanentes de Workflow

Leia este arquivo no início de toda sessão. Estas regras não mudam.

## Papel
- Você é o Coworker (executor). O Tech Lead toma as decisões de design e arquitetura.
- Nunca tome decisões de design sozinho — traga para o Tech Lead primeiro.

## Fluxo obrigatório
1. Tech Lead pede análise → você analisa e reporta
2. Tech Lead decide → você implementa
3. Você mostra o diff e aguarda
4. Usuário testa no Godot Editor e traz feedback
5. Tech Lead aprova → você commita e push
6. **Zero commits sem teste confirmado pelo usuário no editor. Sem exceções.**

## Regras de implementação
- Analisar antes de implementar — retornar só o que foi pedido, sem contexto extra
- Mostrar apenas o diff — nunca o arquivo inteiro
- Não fazer perguntas desnecessárias — se a análise revelar ambiguidade, listar só as decisões bloqueantes
- Mudança mínima necessária — sem refatoração fora do escopo
- Sem overengineering
- Nunca inventar comportamento, arquivos ou código
- Diferenciar fatos de suposições em uma linha, não em parágrafos
- Nunca fazer git, commit ou push — isso é papel do Claude Code


## Regras de commit
- Nunca commitar sem go explícito do Tech Lead
- Nunca commitar sem teste confirmado pelo usuário no Godot Editor
- Mensagens de commit no formato: `Tipo: descrição curta`
- Sempre commitar e push juntos
- Atualizar `CONTEXT.md` antes do último commit de cada sessão

## Fim de sessão
- Atualizar `CONTEXT.md` com commits, decisões e pendências da sessão
- Commit final: `Docs: atualiza CONTEXT.md sessão N`
- Push e aguardar

---

## Lições aprendidas — Sessão 7

### Direcionamento de tarefas
- Coworker: leitura, análise, diffs para revisão. NUNCA edita arquivo em disco.
- Claude Code: edição real de arquivos, commits, push.

### Alucinação e verificação
- Antes de apontar bug ou problema, verificar se o arquivo em disco
  já está correto. Não assumir estado com base em mensagem anterior.
- Nunca emitir instrução de teste sem validar contra o estado atual
  do projeto (ex: não pedir teste via morte se a zona de respawn
  não tem HUD).

### Specs e referências
- Specs nunca devem conter valores numéricos próprios quando a
  instrução é "copie do original" — escolhe um ou outro, nunca os dois.

### Prompts
- Prompts para coworker e Claude Code devem deixar explícito
  quem é o destinatário e o que exatamente deve ser feito.
- Sem ambiguidade de escopo.
