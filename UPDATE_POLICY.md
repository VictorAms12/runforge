# RunForge — Política de atualização sem reinstalação

Este arquivo é uma regra de arquitetura do projeto. Novas versões devem ser instaláveis **por cima da versão anterior**, preservando os dados locais sempre que a plataforma permitir.

## Invariantes que não podem mudar

### Android

- `applicationId`: `com.runforge.runforge`
- a chave/certificado usado para assinar builds distribuídos como atualizáveis;
- o `versionCode` deve crescer a cada versão;
- o APK/AAB de release deve usar a chave persistente configurada nos GitHub Actions Secrets.

Trocar o `applicationId` faz o Android tratar o app como outro aplicativo. Trocar a chave de assinatura normalmente impede a instalação por cima da versão já instalada.

### iOS

- Bundle ID: `com.runforge.runforge`
- manter a mesma identidade de distribuição quando a assinatura/App Store for configurada;
- incrementar versão/build de cada release.

O CI atual compila iOS sem assinatura. A política já fixa o Bundle ID para a futura distribuição assinada.

## Versionamento

O `pubspec.yaml` é a fonte de verdade.

Formato obrigatório:

```text
version: MAJOR.MINOR.PATCH+BUILD
```

O BUILD é determinístico:

```text
BUILD = MAJOR * 10000 + MINOR * 100 + PATCH
```

Exemplos:

```text
1.1.1+10101
1.2.0+10200
1.2.3+10203
2.0.0+20000
```

O `tool/release_guard.dart` bloqueia o CI se esta regra for quebrada.

## Banco SQLite

O banco deve continuar se chamando:

```text
runforge.db
```

Toda alteração de schema deve:

1. incrementar `AppDatabase.version`;
2. adicionar uma nova etapa sequencial em `_onUpgrade`;
3. preservar tabelas e dados existentes;
4. criar instalações novas diretamente no schema mais recente;
5. evitar `deleteDatabase()` como estratégia de atualização;
6. quando uma alteração estrutural exigir reconstrução de tabela, copiar os dados antes de remover a estrutura antiga.

Nunca corrigir um problema de migration apagando o banco do usuário.

## Assinatura Android persistente

Os Secrets esperados pelo workflow são:

```text
ANDROID_KEYSTORE_BASE64
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
ANDROID_STORE_PASSWORD
```

Eles podem ser configurados uma única vez executando no Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\setup_android_signing.ps1
```

O script:

- cria uma chave permanente caso ela ainda não exista;
- salva um backup privado em `%USERPROFILE%\.runforge\signing`;
- envia a chave e credenciais para GitHub Actions Secrets usando `gh`;
- nunca adiciona a chave ao repositório.

O backup da chave é crítico. Não gere outra chave para uma versão futura apenas porque a anterior foi perdida.

## Comportamento do GitHub Actions

Quando os Secrets de assinatura existem, o Artifact Android recebe nome semelhante a:

```text
runforge-android-updateable-1.2.0-10200
```

Esse é o APK que deve ser distribuído para instalações que receberão atualizações futuras.

Se os Secrets ainda não estiverem configurados, o CI continua podendo gerar um build de teste, mas o Artifact deixa explícito:

```text
runforge-android-test-NOT-UPDATABLE-...
```

Builds de teste não devem ser usados como base de distribuição.

Tags `v*` são bloqueadas se a assinatura persistente não estiver configurada.

## Checklist obrigatório para toda nova versão

- [ ] Atualizar `version:` no `pubspec.yaml` usando a fórmula de BUILD.
- [ ] Não alterar `com.runforge.runforge`.
- [ ] Não alterar a chave Android persistente.
- [ ] Se houver mudança no SQLite, incrementar a versão do banco e criar migration incremental.
- [ ] Rodar `dart run tool/release_guard.dart`.
- [ ] Rodar `flutter analyze` e `flutter test`.
- [ ] Confirmar o CI Android com `persistentSigning=true` em `update-info.txt`.
- [ ] Instalar o novo APK sobre a versão anterior em um aparelho de teste e confirmar que histórico, perfil, metas e plano continuam presentes.

## Primeira transição para builds atualizáveis

Builds Android antigos gerados antes desta política podem ter sido assinados pela chave de debug temporária do runner. Se uma instalação existente estiver assinada por uma chave diferente da nova chave persistente, será necessário **desinstalar uma última vez** e instalar o primeiro APK `runforge-android-updateable-*`.

Depois dessa transição, as versões seguintes devem atualizar por cima normalmente, desde que esta política seja mantida.
