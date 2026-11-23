# BackupCadence — especificação

App de barra de menus para macOS que agenda os backups do Time Machine. O macOS só deixa escolher a frequência (hora em hora, diário, semanal), nunca o horário nem condições. Inspirado nas funções do TimeMachineEditor, código aberto (MIT).

Nome provisório: **BackupCadence** (evita usar "Time Machine", marca da Apple, no nome).

## Requisitos

- macOS 14 ou superior, Apple Silicon e Intel.
- Sem servidor, sem conta, sem rede. Tudo local.

## Funções (MVP)

### Modos de agendamento (um ativo por vez)
1. **Intervalo:** a cada N horas (1–168). Ex.: a cada 4 h.
2. **Horários:** lista de horários, cada um com dias da semana e hora:minuto. Ex.: seg–sex 02:00, sáb 12:00.
3. **Quando ocioso:** quando o Mac está sem uso há X minutos (5–120), no máximo uma vez a cada N horas.

### Restrições (valem para qualquer modo, exceto "Fazer backup agora")
- Não fazer backup na bateria (ligado por padrão).
- Janela proibida: não iniciar entre HH:MM e HH:MM (pode atravessar meia-noite), opcional.
- Não iniciar se já houver backup rodando.

### Destino
- Todos os destinos (padrão, igual ao Time Machine) ou um destino específico escolhido da lista de `tmutil destinationinfo`.

### Ligar e desligar o agendamento
- Passo único do usuário: em Ajustes do Sistema › Geral › Time Machine › Opções… definir "Frequência de backup" como Manualmente (o plist passa a ter `AutoBackup = 0`). O macOS protege esses ajustes; nenhum app de terceiros consegue mudá-los sem um helper privilegiado assinado, então o app não pede senha de administrador nem tenta.
- Ligar: o app lê `AutoBackup`. Se estiver ligado, não ativa: avisa para definir "Manualmente" e oferece botão que abre os ajustes do Time Machine. Se estiver desligado (ou ilegível, com aviso no log), instala o agente.
- Desligar: remove o agente e avisa que, para o macOS voltar a fazer backup sozinho, é preciso religar o automático nos ajustes do Time Machine.
- Com o agendamento ligado, se o automático voltar, o menu mostra o aviso de backups em dobro e o botão.
- Backups iniciam com `tmutil startbackup`, que não exige permissão especial. Acesso total ao disco é opcional (só para ler a data do último backup).

### Barra de menus
- Ícone com estado: ocioso, rodando backup, pausado, erro.
- Mostra: último backup concluído, próximo backup previsto, modo atual.
- Ações: Fazer backup agora, Pausar por 1 h / até amanhã / retomar, Preferências…, Ver log, Sair.

### Preferências (janela SwiftUI)
- Escolha do modo e seus campos, restrições, destino, interruptor geral, "abrir ao iniciar sessão".

### Log
- Cada decisão do agente (iniciou, pulou e por quê, erro) numa linha com data, guardado em arquivo, últimas 1.000 linhas.

## Arquitetura

Três partes num pacote Swift:

1. **Núcleo (biblioteca):** configuração, estado, regra "devo iniciar agora?" como função pura (recebe agora, config, último backup, se está na bateria, segundos ocioso, se já está rodando, pausa; devolve iniciar ou pular com o motivo), cálculo do próximo backup previsto, leitura do `tmutil` (status, último backup, destinos). Coberto por testes.
2. **Agente (executável de linha de comando):** rodado pelo launchd a cada 5 minutos (LaunchAgent do usuário, `StartInterval` 300; o launchd roda o atrasado depois que o Mac acorda). Lê a config, coleta os sinais (bateria via IOKit, tempo ocioso via CGEventSource, `tmutil status`), aplica a regra e, se for o caso, roda `tmutil startbackup` (com `--destination` quando houver destino escolhido). Grava estado e log. Também aceita `now` (backup imediato) e `--dry-run`.
3. **App de barra de menus (SwiftUI, `MenuBarExtra`):** edita a config, instala/remove o LaunchAgent em `~/Library/LaunchAgents`, lê `AutoBackup` do Time Machine (sem privilégios) e mostra o estado. Sem ícone no Dock.

Arquivos do usuário em `~/Library/Application Support/BackupCadence/`: `config.json`, `state.json`, `agent.log`.

Escolha: um único gatilho (o agente a cada 5 min decide) em vez de traduzir cada modo para horários do launchd. É mais simples, cobre o modo ocioso e as restrições, e funciona com o app fechado.

## Fora do MVP
- Limpeza de backups antigos, notificações, assinatura com Developer ID e notarização, Homebrew cask, outros idiomas além de inglês e português.

## Critérios de aceite
- `swift build` e `swift test` passam; o CI do GitHub compila e testa.
- Um script gera o `.app` assinado localmente (ad hoc) que abre na barra de menus.
- A regra de decisão tem testes para: cada modo, bateria, janela proibida (inclusive atravessando meia-noite), já rodando, pausa, primeiro uso sem backup anterior.
- `agent tick --dry-run` imprime a decisão e o motivo sem iniciar backup.
- README em inglês e português explicando o que faz, instalação, permissões e como desfazer.
