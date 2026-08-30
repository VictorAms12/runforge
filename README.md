# RunForge

Aplicativo mobile Flutter para acompanhamento de corrida com foco em legibilidade durante o treino, progressão guiada, persistência local e UX esportiva premium.

**Versão atual: 1.1.1**  
**Application ID / Bundle ID permanente:** `com.runforge.runforge`

## Stack

- Flutter 3.47.1 no CI (Android/iOS)
- Riverpod para estado e dependências
- SQLite via `sqflite`
- `geolocator` para distância e pace via GPS
- `flutter_animate` + animações nativas para microinterações
- Feature-first + separação `data / domain / presentation`

## Recursos implementados

- Dashboard com volume semanal/mensal e metas em foco.
- Corrida livre com cronômetro, GPS, distância, pace atual, pace médio, calorias e splits.
- Treino intervalado fechado com **aquecimento + corrida + recuperação + quantidade de ciclos + desaquecimento**.
- Templates rápidos de intervalado.
- Ciclo atual/total e progresso completo da sessão.
- Encerramento automático do intervalado.
- Auto-pause e retomada automática.
- Auto Split de 1 km e Split manual.
- Alertas hápticos + som do sistema nas transições.
- Pause/Resume, Finish e trava de tela.
- Perfil corporal e estimativa calórica local.
- Metas diárias, semanais e mensais.
- Checklist pré/pós-treino.
- Histórico com distância, tempo, pace, kcal, RPE, splits e notas.
- Plano **Do zero aos 5 km**, com 8 semanas / 24 sessões e Treino de Hoje.
- Tela Progresso com últimas 8 semanas, RPE e recordes pessoais.
- Dark Mode premium padrão (`#121212` + Neon Lime), Material 3.
- SQLite schema v4 com migrações incrementais.

## Atualização por cima — requisito permanente

O RunForge possui uma política explícita para que novas versões possam substituir a anterior **sem apagar histórico, perfil, metas ou progresso**.

Veja [`UPDATE_POLICY.md`](UPDATE_POLICY.md).

Os invariantes principais são:

```text
Android applicationId = com.runforge.runforge
iOS Bundle ID        = com.runforge.runforge
SQLite database      = runforge.db
```

Além disso:

- a chave de assinatura Android distribuída deve permanecer a mesma;
- toda nova versão precisa de `versionCode` maior;
- mudanças de banco devem usar migrations incrementais;
- o CI executa `tool/release_guard.dart` para detectar quebras dessas regras.

### Versionamento

O `pubspec.yaml` é a fonte de verdade. O BUILD segue:

```text
BUILD = MAJOR * 10000 + MINOR * 100 + PATCH
```

Exemplo:

```text
1.1.1+10101
1.2.0+10200
1.2.3+10203
```

O workflow não usa mais `github.run_number` como `versionCode`, evitando versões inconsistentes entre pipelines.

## Configuração única da assinatura Android

Para que APKs futuros sejam realmente instaláveis por cima uns dos outros, configure uma chave persistente **uma vez**.

No Windows, com JDK 17 e GitHub CLI (`gh`) instalados/autenticados:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\setup_android_signing.ps1
```

O script:

1. cria `runforge-release.jks` fora do repositório;
2. cria um backup privado em `%USERPROFILE%\.runforge\signing`;
3. envia a chave e credenciais para GitHub Actions Secrets;
4. nunca faz commit do `.jks`, senha ou `key.properties`.

Secrets configurados:

```text
ANDROID_KEYSTORE_BASE64
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
ANDROID_STORE_PASSWORD
```

**Não perca o backup da chave.** Ela passa a ser parte da identidade das instalações Android distribuídas diretamente por APK.

> Builds antigos do RunForge podem ter sido assinados com uma chave de debug temporária do runner. Nesse caso poderá ser necessária uma última desinstalação antes de instalar o primeiro Artifact `runforge-android-updateable-*`. Depois dessa transição, mantenha sempre a chave persistente.

## GitHub Actions

Workflow:

```text
.github/workflows/mobile-build.yml
```

Executa em:

- `push` para `main`;
- tags `v*`;
- Pull Requests para `main`;
- execução manual em **Actions → Flutter Mobile CI → Run workflow**.

### Analyze & Test

1. instala Flutter 3.47.1;
2. executa `flutter pub get`;
3. formata fontes;
4. executa `tool/release_guard.dart`;
5. executa `flutter analyze --no-fatal-infos`;
6. executa `flutter test`.

### Android

O CI sempre gera o shell com:

```text
--project-name=runforge --org=com.runforge
```

e valida que o resultado continua sendo `com.runforge.runforge`.

Se os Secrets de assinatura persistente estiverem disponíveis:

```text
runforge-android-updateable-<versão-build>
```

O Artifact contém:

```text
app-release.apk
app-release.aab
update-info.txt
```

`update-info.txt` registra `applicationId`, versão, nome do banco e se a assinatura persistente foi usada.

Se os Secrets ainda não existirem, o CI pode gerar um APK apenas para testes:

```text
runforge-android-test-NOT-UPDATABLE-<versão-build>
```

Não use esse Artifact como base para distribuição contínua. Tags `v*` falham propositalmente quando a assinatura persistente não está configurada.

### iOS

O CI:

- fixa o Bundle ID em `com.runforge.runforge`;
- configura a permissão de localização;
- compila Release com `--no-codesign`;
- publica `runforge-ios-unsigned-*`.

Para instalação/distribuição real no iOS ainda será necessária assinatura Apple/TestFlight/App Store.

## Banco local e migrações

Arquivo:

```text
lib/core/database/app_database.dart
```

Histórico atual:

- **v1:** `users`, `workouts`, `goals`, `checklists`;
- **v2:** `avg_speed_kmh` e `intensity`;
- **v3:** `completed_at` e `position`;
- **v4:** `rpe`, `splits_json`, `plan_session_index`, `template_id` e `auto_paused_seconds`.

Instalações novas criam diretamente o schema atual. Instalações antigas percorrem somente as migrations que faltam.

A regra para versões futuras é: **nunca apagar `runforge.db` para resolver migration**.

## Desenvolvimento local no Windows

Bootstrap:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\bootstrap.ps1
```

O bootstrap:

- gera Android/iOS com identidade fixa;
- aplica permissões;
- executa o release guard;
- se existir o backup criado por `setup_android_signing.ps1`, aplica a mesma chave ao Android local.

Executar:

```powershell
flutter run
```

Gerar APK Release:

```powershell
flutter build apk --release
```

Com a chave persistente já configurada localmente, esse APK mantém a mesma identidade dos builds assinados do GitHub.

## Requisitos importantes

O `geolocator` 14.x requer Flutter moderno. O CI está fixado em Flutter 3.47.1 para reduzir diferenças entre builds.

O app atualmente usa localização enquanto a interface de treino está em uso. Tracking contínuo em background permanece planejado para versão futura.

## Estrutura resumida

```text
.github/workflows/mobile-build.yml
UPDATE_POLICY.md
ROADMAP.md
lib/
├── core/
├── features/
│   ├── home/
│   ├── workout/
│   ├── plans/
│   ├── progress/
│   ├── profile/
│   ├── goals/
│   ├── checklist/
│   └── history/
├── app_shell.dart
└── main.dart
tool/
├── bootstrap.ps1
├── configure_platforms.dart
├── release_guard.dart
└── setup_android_signing.ps1
```

## Próximas versões

As melhorias planejadas estão em [`ROADMAP.md`](ROADMAP.md): mapa/rota, voz, GPX/CSV, check-in de fadiga/dor, Health Connect/Apple Health, wearables, backup, sincronização e tracking em background.

Todas elas devem obedecer à política de atualização sem reinstalação definida em [`UPDATE_POLICY.md`](UPDATE_POLICY.md).
