<div align="center">
  <img src="lib/assets/app_icon.png" width="120" alt="Gestor Financeiro" />

  <h1>Gestor Financeiro</h1>

  <p>Controle suas finanças pessoais com simplicidade e elegância.<br/>Funciona 100% offline — com sincronização opcional via Firebase.</p>

  ![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter)
  ![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=flat-square&logo=dart)
  ![Firebase](https://img.shields.io/badge/Firebase-opcional-FFCA28?style=flat-square&logo=firebase&logoColor=black)
  ![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey?style=flat-square)
</div>

---

## Sobre

Gestor Financeiro é um app Flutter de código aberto para controle de gastos e rendimentos pessoais. Ele foi projetado para funcionar completamente offline usando armazenamento local (SharedPreferences), com a opção de ativar sincronização em nuvem via Firebase Firestore — configurável tanto por um arquivo `.env` (padrão do build) quanto diretamente pelo app (Perfil → Conectar à nuvem).

---

## Funcionalidades

### Rendimentos
- **Data de recebimento** própria — cadastre recebimentos passados ou futuros
- Tipos: único, recorrente ou por período
- **Intervalo configurável** nos recorrentes — repita a cada _N_ meses: mensal (1), semestral (6) ou anual (12), cobrindo casos como **13º salário** e **saque-aniversário do FGTS**
- **Navegação por mês**, igual à tela de gastos
- **Ocultar valores** — botão de olho que mascara os rendimentos (privacidade), persistente e refletido também no painel

### Gastos
- Tipos: único, mensal (recorrente), **parcelado** (valor total dividido em N parcelas) ou por período
- Categorias personalizáveis com cores
- Método de pagamento (cartão, pix, dinheiro, etc.)
- **Marcar como pago** por mês — gastos recorrentes são rastreados individualmente
- **Notificação de vencimento** — ative por gasto para receber um aviso no dia que vencer
- Indicador visual de vencimento em atraso (ícone de alerta)
- **Indicador de parcela** — parcelados e por período exibem a parcela atual (ex: `2/6`)
- Ordenação por data (crescente por padrão), valor, pagamento ou categoria
- Filtro por categoria e por mês

### Dashboard
- Resumo de entradas, saídas e saldo do mês
- Gráfico de pizza por categoria
- Navegação por mês
- **Ocultar valores** — o mesmo olho mascara rendimento e saldo (mantendo os gastos visíveis)

### Movimentações do banco _(Pluggy)_
- Traz as movimentações dos seus bancos via **Open Finance**, pelo [Meu Pluggy](https://www.pluggy.ai/meu-pluggy) (gratuito para as suas próprias contas)
- **Caixa de entrada** com sino e contador nas abas principais — cada movimentação vira gasto ou rendimento só quando você confirma pelo formulário pré-preenchido (categoria obrigatória); nada é lançado sozinho
- Começa **a partir do dia em que o banco foi conectado** no app — sem importar histórico
- Descrição pela contraparte (estabelecimento ou quem pagou), forma de pagamento (Pix, boleto, transferência, cartão) e parcelas; a primeira parcela sugere o parcelamento inteiro
- **Deslize para descartar** ou "descartar tudo"; o que foi lançado/descartado não volta, nem em outro aparelho conectado à mesma nuvem
- Funciona em Android, iOS e Windows (só HTTP, sem serviço nativo)

### Perfil / Configurações
- Aba própria que reúne conta, notificações, bancos conectados e conexão à nuvem
- Horário do aviso de vencimentos configurável
- Conectar / editar / restaurar a conexão com a nuvem

### Categorias
- Criação e edição com cores personalizadas
- Exclusão com cascade automático nos gastos relacionados

### Notificações locais
- Uma notificação por dia, no horário configurado no Perfil (padrão 9h)
- Lista apenas os gastos que vencem naquele dia, com notificação ativada e não pagos
- Funciona com o app fechado (via AlarmManager no Android)
- Reagendamento automático ao abrir o app ou ao editar gastos

---

## Firebase (opcional)

> O Firebase é **completamente opcional**. O app funciona de forma integral sem nenhuma configuração de nuvem.

> 👉 **Instalou o app e quer sincronizar na nuvem sem saber programar?** Siga o
> passo a passo para iniciantes: [**Usar o seu próprio Firebase**](docs/USAR-SEU-FIREBASE.md) —
> desde criar a conta no Firebase até entrar no app, do zero.

A integração com Firebase adiciona:

- **Autenticação** — login com e-mail e senha (usuários criados manualmente no console)
- **Sincronização via Firestore** — dados salvos localmente são espelhados na nuvem em tempo real
- **Multi-dispositivo** — ao fazer login em outro aparelho, os dados são restaurados automaticamente

### Onde configurar as credenciais

Há dois lugares, com **precedência**:

1. **No app** (Perfil → Conectar à nuvem, ou "Configurar conexão" na tela de login) — sobrepõe o `.env`. Ideal para configurar num build já distribuído, sem recompilar.
2. **No `.env`** — o padrão embutido no build.

A ordem é: se houver config no app, ela vence; senão usa o `.env`; senão o app roda em modo local. "Restaurar padrão" limpa a config do app e volta ao `.env`.

> Trocar a conexão só passa a valer após reiniciar o app (o Firebase é inicializado no boot). Uma config inválida não trava o app: ele cai no modo local, de onde é possível corrigir. As chaves do Firebase são identificadores, não segredos — a segurança vem das regras do Firestore e do Auth.

### Como funciona a sincronização

```
SharedPreferences  ←→  ExpenseState / IncomeState / CategoryState  →  Firestore (só se a nuvem estiver configurada)
   (sempre ativo)                                                         (opcional, fire-and-forget)
```

- O armazenamento local é sempre o primário — operações locais **nunca falham** por causa do Firestore
- Ao fazer login, se o Firestore já tiver dados, eles sobrescrevem o local (Firestore é a fonte de verdade)
- Se o Firestore estiver vazio (conta nova), os dados locais são enviados para a nuvem
- Erros de rede são silenciosos — o app continua funcionando normalmente offline

### Estrutura no Firestore

```
users/
  {uid}/
    incomes/     {id} → { amount, title, recurrenceType, ... }
    expenses/    {id} → { amount, title, category, paidByMonth, ... }
    categories/  {id} → { name, color }
    bank_handled/{id} → { fingerprint, handledAt }   # movimentações da Pluggy já lançadas/descartadas
```

### Regras de segurança recomendadas

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

---

## Pluggy (opcional)

As movimentações dos bancos vêm do **Meu Pluggy**: gratuito, sem prazo, até 5 conexões de contas do mesmo titular, atualizadas a cada 24h. Não serve para contas de outras pessoas.

1. Crie a conta em [meu.pluggy.ai](https://meu.pluggy.ai) e conecte seus bancos (Open Finance).
2. No [Dashboard da Pluggy](https://dashboard.pluggy.ai), vincule essas conexões à aplicação de demonstração e copie o **Client ID** e o **Client Secret** dela.
3. No app: **Perfil → Bancos conectados (Pluggy)** → informe as credenciais e adicione o **Item ID** de cada banco (o Meu Pluggy não permite listar os items pela API, por isso o id é colado à mão).

Notas:

- O **Client Secret** fica no armazenamento seguro do sistema (Keystore / Keychain / Credential Manager), nunca no SharedPreferences. A Pluggy recomenda mantê-lo num servidor; aqui, como as credenciais são suas e só enxergam as suas contas, o app chama a API direto — sem backend.
- O app sincroniza ao abrir e ao voltar ao primeiro plano, no máximo a cada 15 min. Como o Meu Pluggy atualiza uma vez por dia, uma compra de hoje pode só aparecer amanhã.
- A caixa de entrada olha até 60 dias para trás; o que ficar mais tempo sem ser lançado sai dela.
- Compras no cartão aparecem como **pendentes** até a fatura fechar. Se a Pluggy trocar o id ao liquidar, o app reconhece a mesma compra (conta, valor, dia) e não a mostra de novo.

---

## Configuração

### 1. Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.x
- Android SDK / Xcode (para iOS)

### 2. Clone e instale

```bash
git clone https://github.com/seu-usuario/financial_management.git
cd financial_management
flutter pub get
```

### 3. Configuração do `.env`

Copie o arquivo de exemplo:

```bash
cp .env.example .env
```

**Sem Firebase** — deixe o `.env` com os valores vazios (padrão). O app abre diretamente na tela principal com armazenamento local. Você ainda pode conectar à nuvem depois, pelo próprio app (Perfil → Conectar à nuvem).

**Com Firebase** — preencha com suas credenciais para embutir uma conexão padrão no build:

```env
FIREBASE_API_KEY=AIza...
FIREBASE_APP_ID=1:123456:android:abc123
FIREBASE_PROJECT_ID=meu-projeto
FIREBASE_MESSAGING_SENDER_ID=123456789
FIREBASE_STORAGE_BUCKET=meu-projeto.appspot.com
```

**Com Pluggy** — opcionalmente, embuta as credenciais da aplicação (também configuráveis no app, que sobrepõe o `.env`):

```env
PLUGGY_CLIENT_ID=...
PLUGGY_CLIENT_SECRET=...
# bancos: itemId:Nome:domínio-do-logo, separados por vírgula (nome e logo opcionais)
PLUGGY_ITEMS=fc8c9eef-...:Bradesco:bradesco.com.br,1a2b3c4d-...:Nubank:nubank.com.br
```

Bancos do `PLUGGY_ITEMS` aparecem no app como "definido no .env" e se somam aos adicionados pela tela. A data de início de cada um é o dia em que o app o viu pela primeira vez.

> ⚠️ O arquivo `.env` está no `.gitignore` e **nunca deve ser commitado**.
>
> Alternativamente, deixe o `.env` vazio e informe as mesmas credenciais no app (Perfil → Conectar à nuvem) — elas ficam salvas localmente e sobrepõem o `.env`.

### 4. Configuração do Firebase (se desejar sincronização)

1. Acesse [console.firebase.google.com](https://console.firebase.google.com)
2. Crie um projeto e adicione um app Android (package: `com.example.financial_management`)
3. Ative **Authentication → E-mail/senha** e crie os usuários manualmente
4. Ative **Firestore Database** em modo produção e aplique as regras de segurança acima
5. Copie as credenciais do **Configurações do projeto → Seus apps** para o `.env`

> Não é necessário baixar `google-services.json` ou `GoogleService-Info.plist` — as credenciais são carregadas exclusivamente via `.env` em tempo de execução.

### 5. Execute

```bash
flutter run
```

---

## Estrutura do projeto

```
lib/
├── main.dart                     # Inicialização, Firebase opcional, MultiProvider
├── models/                       # Expense, Income, Category, PaymentMethod,
│                                 #   BankTransaction, BankConnection, enums
├── providers/
│   ├── expense_state.dart        # CRUD de gastos, computed helpers por mês
│   ├── income_state.dart         # CRUD de rendimentos, computed helpers por mês
│   ├── category_state.dart       # CRUD de categorias, coordena renomeação/exclusão com ExpenseState
│   └── privacy_state.dart        # Ocultar valores de rendimentos (persistente)
├── screens/
│   ├── dashboard/                # dashboard_screen + widgets (hero_card, income_expense_chart, ...)
│   ├── expense_screen/           # expense_screen + widgets (expense_card, filter_bar, sort_button, ...)
│   ├── income_screen/            # income_screen + widgets (income_card, empty_state)
│   ├── category_management/      # category_management_screen + widgets
│   ├── bank_inbox/               # caixa de entrada das movimentações da Pluggy
│   ├── profile/                  # profile_screen, cloud_config_screen, pluggy_config_screen + widgets
│   └── login_screen.dart
├── services/
│   ├── storage_service.dart              # SharedPreferences (sempre ativo)
│   ├── firestore_service.dart            # Firestore (opcional)
│   ├── auth_service.dart                 # Firebase Auth (opcional)
│   ├── firebase_config.dart              # Config efetiva: app (CloudConfig) → .env
│   ├── cloud_config.dart                 # Config do Firebase informada no app
│   ├── notification_service.dart         # Notificações locais de vencimento
│   ├── pluggy_client.dart                # API da Pluggy (auth, items, contas, transações)
│   ├── pluggy_config.dart                # Credenciais (secret no armazenamento seguro) e bancos
│   ├── bank_sync_service.dart            # Sincroniza e mantém a caixa de entrada
│   └── bank_handled_store.dart           # Lembra o que já foi lançado/descartado
├── utils/                        # currency_formatter, date_utils, brazilian_currency_input_formatter
├── widgets/                      # Componentes reutilizáveis (formulários, month_selector, ...)
├── theme/
│   └── app_theme.dart
└── assets/
    └── app_icon.png
```

---

## Licença

MIT — use, modifique e distribua livremente.
