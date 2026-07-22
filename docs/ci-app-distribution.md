# CI — Build e distribuição no Firebase App Distribution

O workflow [`.github/workflows/distribute.yml`](../.github/workflows/distribute.yml)
builda o APK Android e distribui no Firebase App Distribution.

## Quando roda

- **Ao empurrar uma tag `v*`** (ex.: `git tag v0.1.1 && git push origin v0.1.1`).
- **Manualmente** pela aba **Actions → Distribui Android → Run workflow** (permite
  informar notas da release).

O `versionCode` usa o número da execução (`run_number`) para o App Distribution
não rejeitar builds com o mesmo código de versão. O `versionName` continua vindo
do `version:` do `pubspec.yaml` — bump ele quando quiser mudar o nome da versão.

## Configuração (uma vez)

### 1. Token do Firebase CLI

Num terminal **interativo** (fora do Claude Code, que roda sem TTY), rode:

```
npx -y firebase-tools@latest login:ci
```

Autorize no navegador; ao final ele imprime um **token** (`1//0...`). Esse token
vai no secret `FIREBASE_TOKEN`.

> Alternativa mais robusta (não deprecada): uma **service account** com o papel
> *Firebase App Distribution Admin* e auth via `GOOGLE_APPLICATION_CREDENTIALS`.
> O `login:ci` é mais simples, mas o Google marca o token de CI como deprecado.

### 2. App ID

Firebase Console → **Configurações do projeto → Seus apps** → app Android →
copie o **ID do app** (formato `1:NNNNNNNNNNNN:android:XXXXXXXXXXXX`).

> O app Android registrado nesse projeto deve ter o mesmo **package name** do
> APK. Hoje o `applicationId` é `com.example.financial_management` (ainda o
> padrão de exemplo — ver ressalvas abaixo).

### 3. Grupo de testers

Firebase Console → **App Distribution → Testadores e grupos** → crie um grupo
(ex.: `testers`) e adicione os e-mails.

### 4. Secrets e variáveis no GitHub

Repositório → **Settings → Secrets and variables → Actions**:

| Tipo     | Nome              | Valor                                                    |
|----------|-------------------|----------------------------------------------------------|
| Secret   | `FIREBASE_TOKEN`  | Token gerado por `firebase login:ci`                     |
| Secret   | `FIREBASE_APP_ID` | O App ID (`1:NNN:android:XXX`)                           |
| Variable | `FIREBASE_GROUPS` | Alias do(s) grupo(s) de testers (opcional; padrão `testers`) |
| Secret   | `ENV_FILE`        | Conteúdo do `.env` (opcional — ver abaixo)               |

## Sobre o `.env`

O `pubspec.yaml` declara `.env` como asset, mas ele é gitignored — o workflow
**recria** o arquivo antes do build. Sem o secret `ENV_FILE`, ele fica **vazio**,
e a config do Firebase é inserida em runtime pelo próprio app (`CloudConfig`).

Se quiser builds **já pré-configurados** com o seu Firebase (testers não precisam
digitar nada), coloque no secret `ENV_FILE` o conteúdo do `.env`:

```
FIREBASE_API_KEY=...
FIREBASE_APP_ID=...
FIREBASE_MESSAGING_SENDER_ID=...
FIREBASE_PROJECT_ID=...
FIREBASE_STORAGE_BUCKET=...
```

## Ressalvas (não bloqueiam a distribuição, mas vale saber)

- **Assinatura**: o build release ainda assina com a **chave de debug**
  (`android/app/build.gradle.kts`). Funciona para teste interno via App
  Distribution, mas **não** serve para a Play Store. Para um keystore de
  release, dá para injetá-lo por secret e configurar `signingConfig` — posso
  montar isso quando quiser.
- **`applicationId`**: continua `com.example.financial_management`. Se registrar
  o app no Firebase com outro package, alinhe os dois.
- **`google-services.json`**: o commitado é placeholder; o build compila com ele
  normalmente (o package bate). A nuvem real entra em runtime.
