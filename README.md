# RunForge

Aplicativo mobile Flutter para acompanhamento de corrida com foco em legibilidade durante o treino, progressão guiada, persistência local e UX esportiva premium.

**Versão atual: 1.1.0**

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
- Templates rápidos de intervalado (1/2 iniciante, 2/1 progressão, 5/2 resistência e HIIT curto).
- Ciclo atual/total, progresso da etapa e progresso total do treino.
- Encerramento automático do cronômetro ao concluir todo o intervalado.
- Auto-pause por parada real, com retomada automática ao voltar a se movimentar.
- Auto Split de 1 km e Split manual.
- Alertas hápticos + som do sistema nas transições de intervalo.
- Pause/Resume, Split, Finish e trava de tela por long press.
- Perfil corporal local: nome, peso, altura, idade e sexo.
- Estimativa calórica por MET + componente basal Mifflin-St Jeor.
- Metas diárias, semanais e mensais por km ou dias treinados.
- Progresso automático de metas com anel animado e conquista ao atingir o alvo.
- Checklist pré/pós-treino, itens customizados, reset e swipe para excluir itens próprios.
- Histórico de treinos com distância, tempo, pace, kcal, RPE, splits e notas.
- RPE pós-treino de 1 a 10 para acompanhar esforço percebido.
- Plano **Do zero aos 5 km**: 8 semanas / 24 sessões com treino do dia no Dashboard.
- Tela Progresso com volume das últimas 8 semanas e RPE médio.
- Recordes pessoais: maior distância, maior duração, melhor pace médio, melhor split de 1 km e melhor 5 km.
- Dark Mode premium padrão (`#121212` + Neon Lime), com Material 3.
- SQLite schema v4 com migrações incrementais `onUpgrade`, preservando instalações v1-v3.

## GitHub Actions: compilação automática

O repositório já inclui o workflow:

```text
.github/workflows/mobile-build.yml
```

Ele é executado automaticamente quando:

- há `push` na branch `main`;
- uma tag `v*` é enviada, por exemplo `v1.0.0`;
- um Pull Request é aberto/atualizado contra `main`;
- você inicia manualmente pela aba **Actions** do GitHub.

### O que o workflow faz

**Analyze & Test**

1. Instala Flutter 3.47.1.
2. Executa `flutter pub get`.
3. Normaliza a formatação das fontes com `dart format`.
4. Executa `flutter analyze --no-fatal-infos`: erros e warnings continuam bloqueando o pipeline, enquanto diagnósticos de nível `info` permanecem visíveis sem impedir a compilação.
5. Executa `flutter test`.

**Android** — em `push`, tags e execução manual:

1. Usa JDK 17.
2. Gera o shell Android com `flutter create`.
3. Aplica permissões de localização automaticamente.
4. Compila APK Release.
5. Compila Android App Bundle (AAB).
6. Publica os arquivos como Artifact por 14 dias.

Arquivos produzidos:

```text
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/bundle/release/app-release.aab
```

Artifact no GitHub:

```text
runforge-android-<numero-do-run>
```

**iOS** — em `push`, tags e execução manual:

1. Usa runner macOS.
2. Gera o shell iOS com `flutter create`.
3. Configura `NSLocationWhenInUseUsageDescription`.
4. Compila em Release com `--no-codesign`.
5. Compacta `Runner.app` e publica como Artifact.

Artifact:

```text
runforge-ios-unsigned-<numero-do-run>
```

> O build iOS comprova que o projeto compila, mas não é um IPA assinado para instalação/distribuição. Para TestFlight/App Store é necessário configurar certificado, provisioning profile e assinatura Apple.

### Como baixar o APK pelo GitHub

1. Abra o repositório no GitHub.
2. Entre em **Actions**.
3. Abra **Flutter Mobile CI**.
4. Abra a execução concluída com sucesso.
5. Na seção **Artifacts**, baixe `runforge-android-<numero>`.
6. Extraia o ZIP do Artifact; dentro estará `app-release.apk` e o `.aab`.

### Rodar a compilação manualmente

Na aba **Actions**:

1. Selecione **Flutter Mobile CI**.
2. Clique em **Run workflow**.
3. Selecione `main`.
4. Clique em **Run workflow** novamente.

O workflow também pode ser disparado simplesmente fazendo um novo commit/push em `main`.

## Assinatura Android

O workflow atual produz um build Release de desenvolvimento/teste usando a configuração padrão gerada pelo Flutter. Ele é adequado para baixar o APK e testar o aplicativo.

Para publicar o `.aab` na Google Play, configure uma **keystore de produção** e armazene as credenciais usando **GitHub Actions Secrets**. Não envie `.jks`, senhas ou `key.properties` para o Git.

Uma evolução futura recomendada é adicionar secrets como:

```text
ANDROID_KEYSTORE_BASE64
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
ANDROID_STORE_PASSWORD
```

## Projeto nativo gerado sob demanda

As pastas `android/` e `ios/` não precisam ficar versionadas. O projeto mantém o código Flutter como fonte principal e gera os shells nativos com a versão fixada do Flutter durante o CI.

O script usado para aplicar as customizações é:

```text
tool/configure_platforms.dart
```

Isso evita manter templates Android/iOS antigos no repositório e mantém a geração reproduzível.

## Banco local e migrações

Arquivo: `lib/core/database/app_database.dart`

- **v1:** `users`, `workouts`, `goals`, `checklists`.
- **v2:** adiciona `avg_speed_kmh` e `intensity` em `workouts`.
- **v3:** adiciona `completed_at` em `goals` e `position` em `checklists`.
- **v4 (RunForge 1.1):** adiciona `rpe`, `splits_json`, `plan_session_index`, `template_id` e `auto_paused_seconds` em `workouts`.
- Instalação nova cria diretamente o schema mais recente.
- Upgrade executa somente as etapas ausentes dentro da transação do próprio `sqflite`.

Isso permite atualizar a aplicação instalada sem apagar o banco do usuário.

## Como executar localmente no Windows

Este projeto contém um bootstrap que gera os shells Android/iOS usando a versão do Flutter instalada na máquina.

1. Clone o repositório.
2. Abra PowerShell na pasta `runforge`.
3. Execute:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\bootstrap.ps1
```

4. Com Android conectado ou emulador aberto:

```powershell
flutter run
```

Para gerar APK local:

```powershell
flutter build apk --release
```

> iOS precisa ser compilado em macOS com Xcode.

## Requisitos importantes

O `geolocator` 14.x requer Flutter moderno. O CI está fixado em Flutter 3.47.1 para reduzir diferenças entre builds e evitar que uma atualização futura do canal stable altere o resultado sem revisão.

O app usa localização somente enquanto a interface do treino está em uso. Não há tracking contínuo em background nesta versão.

## Permissões

`tool/configure_platforms.dart` e `tool/bootstrap.ps1` configuram:

- Android: `ACCESS_FINE_LOCATION` e `ACCESS_COARSE_LOCATION`.
- iOS: `NSLocationWhenInUseUsageDescription`.
- iOS/Podfile: `BYPASS_PERMISSION_LOCATION_ALWAYS=1` quando o Podfile permite a configuração.

Os snippets também ficam em `platform_templates/` para referência manual.

## Estrutura

```text
.github/
└── workflows/
    └── mobile-build.yml
lib/
├── core/
│   ├── database/
│   ├── theme/
│   ├── utils/
│   ├── widgets/
│   └── providers.dart
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
└── configure_platforms.dart
```

## Observações de precisão

- GPS de smartphone tem ruído; o app ignora pontos com precisão pior que 50 m e saltos individuais acima de 120 m.
- Pace atual usa a velocidade reportada pelo GPS quando ela é suficientemente alta; pace médio usa tempo/distância acumulados.
- A estimativa de calorias é orientativa. Não substitui calorimetria indireta nem avaliação médica.
- O `Stopwatch` é a fonte do tempo da sessão, reduzindo drift do `Timer` de atualização da UI.

## Próximas versões

As melhorias que ficaram fora da v1.1 estão registradas em [`ROADMAP.md`](ROADMAP.md), organizadas por versão: mapa/rota, voz, exportação GPX/CSV, check-in de fadiga/dor, Health Connect/Apple Health, wearables, backup e tracking em background.
