# GrafoFlow

Um planejador visual de matérias para estudantes da PUC-Rio. Mostra suas disciplinas organizadas por período, com as dependências (pré-requisitos e co-requisitos) desenhadas como setas — dá pra arrastar matérias entre semestres e o app ajusta tudo automaticamente, respeitando as dependências.

## 🚀 Quer só usar o app?

Não precisa instalar nada. Acessa direto pelo navegador (funciona em celular, tablet ou computador):

**👉 https://grafoflow.vercel.app/**

Cria uma conta (e-mail/usuário + senha), escolhe seu curso, e já dá pra começar. Depois de logado, tem uma tela de "Como usar" no menu (ícone ☰ no canto superior esquerdo) explicando cada funcionalidade — vale muito a pena dar uma olhada nela antes de mexer.

Hoje o app só roda como aplicativo Web (funciona liso em qualquer navegador moderno, inclusive no celular) — não é necessário instalar como app nativo.

## 🛠️ Rodando o projeto localmente

Isso só é necessário se você quiser mexer no código-fonte, não pra usar o app normalmente (pra isso, usa o link acima).

### Pré-requisitos

1. **Flutter SDK** — siga o instalador oficial: https://docs.flutter.dev/get-started/install
   Depois de instalar, roda `flutter doctor` no terminal pra conferir se está tudo certo (pode ignorar avisos sobre Android Studio/Xcode se você só for rodar no navegador).
2. Um navegador Chrome ou Edge instalado.

### Passo a passo

```bash
# 1. Clona o repositório
git clone https://github.com/SEU-USUARIO/grafoflow.git
cd grafoflow

# 2. Baixa as dependências do projeto
flutter pub get

# 3. Roda o app no navegador
flutter run -d chrome
```

Se aparecer mais de um dispositivo disponível, escolha a opção do Chrome (ou Edge) quando o terminal perguntar.

### Sobre a conta/dados

O app usa o mesmo backend (Firebase) do link em produção — ou seja, ao rodar localmente você está se conectando ao mesmo banco de dados do app publicado. Pode criar uma conta normalmente pra testar; não precisa configurar Firebase próprio pra só rodar o projeto.

## 🧱 Tecnologias usadas

- **[Flutter](https://flutter.dev)** — framework de interface, roda como app Web (por ora).
- **[Firebase Authentication](https://firebase.google.com/products/auth)** — login (e-mail/senha ou usuário).
- **[Cloud Firestore](https://firebase.google.com/products/firestore)** — armazena o progresso de cada aluno na nuvem, carregado automaticamente ao logar.

## 📋 Como funciona, por cima

1. Você importa a planilha de "matérias que faltam cursar" (baixada do sistema da universidade).
2. O app monta seu grafo pessoal: matérias organizadas por semestre, com setas indicando dependências.
3. Arrasta os cards entre semestres pra planejar — o app empurra automaticamente quem depende de quem, e não deixa soltar num lugar que quebra uma dependência.
4. Marca matérias como concluídas, escolhe optativas (que viram um grupo de opções específicas), e ajusta à vontade.
5. Tudo fica salvo automaticamente na sua conta — sai e volta quando quiser, sem precisar importar a planilha de novo.

## 🐛 Encontrou um problema?

Abre uma [issue](../../issues) descrevendo o que aconteceu — se possível, com um print ou os passos pra reproduzir.
