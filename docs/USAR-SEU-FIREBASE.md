# Usar o seu próprio Firebase (guia para iniciantes)

Este guia é para quem **instalou o app** e quer que seus dados fiquem salvos na
nuvem (para não perder nada e poder usar em mais de um aparelho). Você **não
precisa saber programar** e **não precisa de conta no Firebase ainda** — vamos
criar tudo do zero.

> **Precisa mesmo fazer isso?** Não. O app funciona 100% offline, guardando tudo
> no próprio celular. Este guia é só para quem **quer** sincronização na nuvem.
>
> **É pago?** Não para uso pessoal. O plano gratuito do Firebase (Spark) é mais
> que suficiente. Não é preciso cadastrar cartão de crédito.
>
> **Quanto tempo leva?** Cerca de 10 a 15 minutos, uma única vez.

O que você vai fazer, em resumo:

1. Criar uma conta e um projeto no Firebase (de graça)
2. Ligar o login por e-mail e senha e criar o **seu** usuário
3. Ligar o banco de dados (Firestore) e colar uma regra de segurança
4. Copiar as "chaves" do seu projeto
5. Colar essas chaves no app e reiniciar
6. Entrar com seu e-mail e senha — pronto, sincronizando!

---

## Passo 1 — Criar a conta e o projeto no Firebase

1. No computador ou no celular, abra: **https://console.firebase.google.com**
2. Entre com uma **conta Google** (o mesmo login do Gmail). Se não tiver, crie
   uma gratuitamente — qualquer conta Google já serve como conta Firebase.
3. Clique em **Adicionar projeto** (ou *Criar um projeto*).
4. Dê um nome qualquer, por exemplo `minhas-financas`, e clique em **Continuar**.
5. Na tela do **Google Analytics**, pode **desativar** (não é necessário) e
   clicar em **Criar projeto**.
6. Aguarde alguns segundos e clique em **Continuar**.

✅ Pronto: você já tem um projeto Firebase.

---

## Passo 2 — Ligar o login e criar o seu usuário

O app pede e-mail e senha para entrar. Esse login é criado **por você**, aqui no
Firebase (o app não tem tela de cadastro, por segurança).

1. No menu à esquerda, abra **Criação (Build) → Authentication**.
2. Clique em **Vamos começar (Get started)**.
3. Na lista de provedores, escolha **E-mail/senha**.
4. **Ative** a primeira opção (E-mail/senha) e clique em **Salvar**.
5. Vá na aba **Users (Usuários)** e clique em **Adicionar usuário**.
6. Digite um **e-mail** e uma **senha** de sua escolha (guarde bem — é com eles
   que você vai entrar no app) e confirme.

✅ Pronto: esse será o seu login no app.

---

## Passo 3 — Ligar o banco de dados (Firestore)

É aqui que seus dados vão ficar guardados na nuvem.

1. No menu à esquerda, abra **Criação (Build) → Firestore Database**.
2. Clique em **Criar banco de dados**.
3. Escolha o **local (location)**. Para o Brasil, prefira
   **`southamerica-east1` (São Paulo)**.
   > ⚠️ O local **não pode ser alterado depois**, mas isso não tem custo nem
   > problema — qualquer local funciona.
4. Escolha começar em **modo de produção** e finalize.
5. Quando o banco abrir, clique na aba **Regras (Rules)**.
6. **Apague** o que estiver lá e **cole exatamente** isto:

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

7. Clique em **Publicar**.

✅ Pronto: seus dados só poderão ser lidos/gravados por você, depois de logado.

---

## Passo 4 — Copiar as chaves do seu projeto

Agora vamos pegar os 5 dados que o app pede. A forma mais fácil é registrar um
"app da Web" — é só para gerar essas chaves.

1. No topo do menu à esquerda, clique na **engrenagem ⚙️ → Configurações do
   projeto**.
2. Role até **Seus apps (Your apps)**.
3. Clique no ícone de **Web** — o símbolo **`</>`**.
4. Dê um apelido qualquer (ex.: `app`) e clique em **Registrar app**.
   (Pode ignorar a parte de "hospedagem/Hosting".)
5. Vai aparecer um trecho de código com um bloco parecido com este:

   ```js
   const firebaseConfig = {
     apiKey: "AIzaSyD.......",
     authDomain: "minhas-financas.firebaseapp.com",
     projectId: "minhas-financas",
     storageBucket: "minhas-financas.appspot.com",
     messagingSenderId: "123456789012",
     appId: "1:123456789012:web:abc123def456"
   };
   ```

**Deixe essa tela aberta** — você vai copiar esses valores no próximo passo.
(Se fechar, encontra tudo de novo em **Configurações do projeto → Seus apps**.)

> Não se preocupe com o `authDomain` — o app não usa esse campo.

---

## Passo 5 — Colar as chaves no app

1. Abra o app no celular.
2. Vá na aba **Perfil** (ícone de pessoa, no canto inferior direito).
3. Toque em **Conectar à nuvem** e depois em **Continuar**.
4. Preencha cada campo com o valor correspondente do bloco `firebaseConfig`:

   | Campo no app          | Valor no `firebaseConfig`         |
   | --------------------- | --------------------------------- |
   | **API Key**           | `apiKey`                          |
   | **App ID**            | `appId`                           |
   | **Messaging Sender ID** | `messagingSenderId`             |
   | **Project ID**        | `projectId`                       |
   | **Storage Bucket** (opcional) | `storageBucket`           |

   > Dica: copie e cole um por um. O **Storage Bucket** é opcional — pode deixar
   > em branco por enquanto.

5. Toque em **Salvar**.

O app vai avisar que é preciso **reiniciar**. Isso é normal: a conexão com a
nuvem só é ligada quando o app abre.

---

## Passo 6 — Reiniciar e entrar

1. **Feche o app completamente** (remova das aberturas recentes) e **abra de
   novo**.
2. Agora vai aparecer a **tela de login**.
3. Entre com o **e-mail e a senha** que você criou no **Passo 2**.

🎉 Pronto! A partir de agora seus gastos, rendimentos e categorias são salvos no
**seu** Firebase. Se você entrar com o mesmo login em outro aparelho, os dados
aparecem lá também.

---

## Deu algo errado? (soluções rápidas)

- **Depois de reiniciar não apareceu a tela de login.**
  A conexão provavelmente não foi salva ou tem algum valor errado. Volte em
  **Perfil → Conectar à nuvem** e confira se **API Key, App ID, Messaging Sender
  ID e Project ID** estão preenchidos e sem espaços sobrando. Salve e reinicie.

- **"E-mail ou senha incorretos" ao entrar.**
  Confira o usuário no Firebase em **Authentication → Users**. O login precisa
  ser exatamente o e-mail/senha cadastrados ali. Você pode redefinir a senha
  nessa mesma tela.

- **"Sem conexão com a internet."**
  Verifique o Wi-Fi/dados do celular e tente de novo.

- **Entrei, mas os dados não aparecem / não salvam.**
  Confirme que você **publicou as regras** do Passo 3 e que o **Firestore
  Database** foi criado. Sem isso, o app entra mas não consegue gravar.

- **Quero voltar a usar só o celular (sem nuvem).**
  Em **Perfil**, use **Restaurar padrão** (ou apague os campos da conexão) e
  reinicie. O app volta ao modo offline.

---

## Perguntas comuns

**Meus dados ficam seguros?**
Sim. As regras do Passo 3 garantem que **só você**, logado com o seu usuário,
consegue ler e gravar seus dados. As "chaves" que você colou não são senhas —
são apenas identificadores do projeto; a segurança vem do login e das regras.

**Posso usar em vários celulares?**
Pode. Basta repetir o **Passo 5 e 6** (colar as chaves e entrar) em cada
aparelho, sempre com o **mesmo e-mail e senha**.

**Preciso baixar algum arquivo (`google-services.json`)?**
Não. O app usa apenas as chaves que você digitou. Nada de arquivos extras.
