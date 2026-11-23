# BackupCadence

A macOS menu-bar app that schedules Time Machine backups on your terms. Inspired by [TimeMachineEditor](https://tclementdev.com/timemachineeditor/).

## What it does

macOS only lets you pick hourly, daily or weekly. BackupCadence adds:

- **Interval** mode: every N hours (1-168).
- **Times** mode: a list of times, each with its weekdays (e.g. Mon-Fri 02:00, Sat 12:00).
- **When idle** mode: after X minutes without use (5-120), at most once every N hours.
- Restrictions: skip on battery (default on), optional forbidden time window (may cross midnight), never start if a backup is already running.
- Destination: all destinations (default) or a specific one.
- Menu bar status, pause (1 hour / until tomorrow), "Back up now", log of every decision (last 1,000 lines).

Everything is local: no server, no account, no network. macOS 14+, Apple Silicon and Intel.

## Why

You want backups at 02:00, or only when the Mac is idle and plugged in, not "sometime this hour".

## How it works

A LaunchAgent runs `backupcadence-agent tick` every 5 minutes. The agent applies a pure rule ("should I start now?") and, if yes, runs `tmutil startbackup`. While scheduling is on, Time Machine's own automatic backup is turned off (`tmutil disable`) so the two do not compete. Files live in `~/Library/Application Support/BackupCadence/` (`config.json`, `state.json`, `agent.log`).

## Install

Download or build `BackupCadence.app`, move it to `/Applications`, open it. Because it is only ad hoc signed, the first launch needs right-click > Open (or approve it in System Settings > Privacy & Security).

## Build from source

```sh
swift build        # debug build
swift test         # run tests
scripts/build-app.sh   # produces build/BackupCadence.app
```

The agent CLI: `backupcadence-agent tick [--dry-run]`, `now`, `status`. `tick --dry-run` prints the decision and reason and never starts a backup.

## Permissions

- **Administrator password**, once each time you turn scheduling on or off, through the standard macOS dialog (needed by `tmutil enable/disable`). The app never sees or stores it.
- **Full Disk Access** for `BackupCadence.app` (`Contents/MacOS/backupcadence-agent`): `tmutil latestbackup` needs it. Without it the agent still works, but "last backup" is unknown and it relies on the last start time it recorded itself.
- A LaunchAgent is written to `~/Library/LaunchAgents/com.backupcadence.agent.plist`. "Open at login" uses the system login-item service.

## How to undo

Turn **Scheduling** off in Preferences: it removes the LaunchAgent and runs `tmutil enable`. To do it by hand:

```sh
launchctl bootout gui/$(id -u)/com.backupcadence.agent
rm ~/Library/LaunchAgents/com.backupcadence.agent.plist
sudo tmutil enable      # restores Time Machine automatic backups
```

You can also toggle "Back Up Automatically" in System Settings > General > Time Machine. Optionally delete `~/Library/Application Support/BackupCadence/`.

## License

MIT, see [LICENSE](LICENSE).

---

# Português

App de barra de menus para macOS que agenda os backups do Time Machine do jeito que você quer. Inspirado no [TimeMachineEditor](https://tclementdev.com/timemachineeditor/).

## O que faz

O macOS só deixa escolher hora em hora, diário ou semanal. O BackupCadence acrescenta:

- Modo **Intervalo**: a cada N horas (1-168).
- Modo **Horários**: lista de horários com dias da semana (ex.: seg-sex 02:00, sáb 12:00).
- Modo **Quando ocioso**: depois de X minutos sem uso (5-120), no máximo uma vez a cada N horas.
- Restrições: não fazer backup na bateria (padrão), janela proibida opcional (pode atravessar a meia-noite), não iniciar se já houver backup rodando.
- Destino: todos (padrão) ou um específico.
- Estado na barra de menus, pausa (1 hora / até amanhã), "Fazer backup agora" e log das decisões (últimas 1.000 linhas).

Tudo local: sem servidor, sem conta, sem rede. macOS 14 ou superior, Apple Silicon e Intel.

## Instalação

Baixe ou compile o `BackupCadence.app`, mova para `/Applications` e abra. Como a assinatura é só local (ad hoc), na primeira vez use botão direito > Abrir (ou libere em Ajustes do Sistema > Privacidade e Segurança).

## Compilar do código-fonte

```sh
swift build
swift test
scripts/build-app.sh   # gera build/BackupCadence.app
```

## Permissões

- **Senha de administrador**, uma vez ao ligar ou desligar o agendamento, no diálogo padrão do macOS (necessário para `tmutil enable/disable`). O app nunca guarda a senha.
- **Acesso total ao disco** para o `backupcadence-agent` dentro do app: `tmutil latestbackup` exige. Sem ele o agente funciona, mas o "último backup" fica desconhecido e usa só o horário de início que ele mesmo registrou.
- Um LaunchAgent é gravado em `~/Library/LaunchAgents/com.backupcadence.agent.plist`.

## Como desfazer

Desligue o **Agendamento** nas Preferências: o app remove o agente e roda `tmutil enable`. Manualmente:

```sh
launchctl bootout gui/$(id -u)/com.backupcadence.agent
rm ~/Library/LaunchAgents/com.backupcadence.agent.plist
sudo tmutil enable      # devolve o backup automático do Time Machine
```

Também dá para ligar "Fazer backup automaticamente" em Ajustes do Sistema > Geral > Time Machine.

## Licença

MIT, veja [LICENSE](LICENSE).
