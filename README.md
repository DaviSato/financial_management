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

Gestor Financeiro é um app Flutter de código aberto para controle de gastos e rendimentos pessoais. Ele foi projetado para funcionar completamente offline usando armazenamento local (SharedPreferences), com a opção de ativar sincronização em nuvem via Firebase Firestore — bastando preencher um arquivo `.env` com suas próprias credenciais.

---

## Funcionalidades

### Rendimentos
- Cadastro de rendimentos únicos, mensais (recorrentes) ou por período
- Visualização filtrada por mês

### Gastos
- Cadastro de gastos únicos, mensais ou por período
- Categorias personalizáveis com cores
- Método de pagamento (cartão, pix, dinheiro, etc.)
- **Marcar como pago** por mês — gastos recorrentes são rastreados individualmente
- **Notificação de vencimento** — ative por gasto para receber um aviso no dia que vencer
- Indicador visual de vencimento em atraso (ícone de alerta)
- Ordenação por data, valor, pagamento ou categoria
- Filtro por categoria e por mês

### Dashboard
- Resumo de entradas, saídas e saldo do mês
- Gráfico de pizza por categoria
- Navegação por mês

### Categorias
- Criação e edição com cores personalizadas
- Exclusão com cascade automático nos gastos relacionados

### Notificações locais
- Uma notificação por dia, no horário configurado (padrão 9h)
- Lista apenas os gastos que vencem naquele dia, com notificação ativada e não pagos
- Funciona com o app fechado (via AlarmManager no Android)
- Reagendamento automático ao abrir o app ou ao editar gastos

---

## Firebase (opcional)

> O Firebase é **completamente opcional**. O app funciona de forma integral sem nenhuma configuração de nuvem.

A integração com Firebase adiciona:

- **Autenticação** — login com e-mail e senha (usuários criados manualmente no console)
- **Sincronização via Firestore** — dados salvos localmente são espelhados na nuvem em tempo real
- **Multi-dispositivo** — ao fazer login em outro aparelho, os dados são restaurados automaticamente

### Como funciona a sincronização

```
SharedPreferences  ←→  AppState  →  Firestore (somente se .env configurado)
   (sempre ativo)                      (opcional, fire-and-forget)
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

**Sem Firebase** — deixe o `.env` com os valores vazios (padrão). O app abre diretamente na tela principal com armazenamento local.

**Com Firebase** — preencha com suas credenciais:

```env
FIREBASE_API_KEY=AIza...
FIREBASE_APP_ID=1:123456:android:abc123
FIREBASE_PROJECT_ID=meu-projeto
FIREBASE_MESSAGING_SENDER_ID=123456789
FIREBASE_STORAGE_BUCKET=meu-projeto.appspot.com
```

> ⚠️ O arquivo `.env` está no `.gitignore` e **nunca deve ser commitado**.

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
├── main.dart                     # Inicialização, Firebase opcional, roteamento
├── models/                       # Expense, Income, Category, enums
├── providers/
│   └── app_state.dart            # Estado global, CRUD, sync
├── screens/
│   ├── dashboard/
│   │   ├── dashboard_screen.dart
│   │   └── widgets/              # category_breakdown, hero_card, income_expense_chart, ...
│   ├── expense_screen/
│   │   ├── expense_screen.dart
│   │   └── widgets/              # expense_card, filter_bar, sort_button, ...
│   ├── category_management/
│   │   ├── category_management_screen.dart
│   │   └── widgets/              # category_item, delete_category_dialog
│   ├── income_screen.dart
│   └── login_screen.dart
├── services/
│   ├── storage_service.dart      # SharedPreferences (sempre ativo)
│   ├── firestore_service.dart    # Firestore (opcional)
│   ├── auth_service.dart         # Firebase Auth (opcional)
│   ├── firebase_config.dart      # Leitura do .env
│   └── notification_service.dart # Notificações locais
├── widgets/                      # Componentes reutilizáveis
├── theme/
│   └── app_theme.dart
└── assets/
    └── app_icon.png
```

---

## Licença

MIT — use, modifique e distribua livremente.
