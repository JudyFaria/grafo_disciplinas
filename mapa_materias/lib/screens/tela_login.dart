import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/cursos_disponiveis.dart';
import '../services/auth_service.dart';
import '../services/usuario_service.dart';

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _authService = AuthService();
  final _usuarioService = UsuarioService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _nicknameController = TextEditingController();

  bool _modoCadastro = false;
  bool _carregando = false;
  String? _erro;
  String _cursoSelecionado = cursosDisponiveis.first.$1;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      if (_modoCadastro) {
        final nickname = _nicknameController.text.trim();
        if (nickname.isNotEmpty && !await _usuarioService.nicknameDisponivel(nickname)) {
          setState(() => _erro = 'Esse nome de usuário já está em uso.');
          return;
        }
        final credencial =
            await _authService.cadastrar(_emailController.text.trim(), _senhaController.text);
        final uid = credencial.user?.uid;
        if (uid != null) {
          await _usuarioService.salvarPerfil(
            uid,
            curso: _cursoSelecionado,
            nickname: nickname,
            email: _emailController.text.trim(),
          );
        }
      } else {
        final identificador = _emailController.text.trim();
        final email = identificador.contains('@')
            ? identificador
            : await _usuarioService.resolverEmailPorNickname(identificador);
        if (email == null) {
          setState(() => _erro = 'Usuário não encontrado.');
          return;
        }
        await _authService.entrar(email, _senhaController.text);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _erro = _mensagemDeErro(e.code));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _esqueciSenha() async {
    final identificador = _emailController.text.trim();
    if (identificador.isEmpty) {
      setState(() => _erro = 'Digite seu e-mail ou usuário ali em cima primeiro.');
      return;
    }
    final email = identificador.contains('@')
        ? identificador
        : await _usuarioService.resolverEmailPorNickname(identificador);
    if (email == null) {
      setState(() => _erro = 'Usuário não encontrado.');
      return;
    }
    await _authService.redefinirSenha(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Enviamos um link de redefinição de senha pra $email.')),
    );
  }

  String _mensagemDeErro(String codigo) {
    switch (codigo) {
      case 'user-not-found':
        return 'Não existe conta com esse e-mail.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Usuário ou senha incorretos.';
      case 'email-already-in-use':
        return 'Já existe uma conta com esse e-mail.';
      case 'weak-password':
        return 'A senha precisa ter pelo menos 6 caracteres.';
      case 'invalid-email':
        return 'E-mail inválido.';
      default:
        return 'Erro ao autenticar ($codigo).';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _modoCadastro ? 'Criar conta' : 'Entrar',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: _modoCadastro ? TextInputType.emailAddress : TextInputType.text,
                    decoration: InputDecoration(labelText: _modoCadastro ? 'E-mail' : 'E-mail ou usuário'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Obrigatório';
                      if (_modoCadastro && !v.contains('@')) return 'E-mail inválido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _senhaController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Senha'),
                    validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                  ),
                  if (!_modoCadastro)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _carregando ? null : _esqueciSenha,
                        child: const Text('Esqueci minha senha'),
                      ),
                    ),
                  if (_modoCadastro) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nicknameController,
                      decoration: const InputDecoration(labelText: 'NickName'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Escolha um apelido' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _cursoSelecionado,
                      decoration: const InputDecoration(labelText: 'Curso'),
                      items: [
                        for (final (valor, rotulo) in cursosDisponiveis)
                          DropdownMenuItem(value: valor, child: Text(rotulo)),
                      ],
                      onChanged: (v) => setState(() => _cursoSelecionado = v!),
                    ),
                  ],
                  if (_erro != null) ...[
                    const SizedBox(height: 4),
                    Text(_erro!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _carregando ? null : _enviar,
                    child: _carregando
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_modoCadastro ? 'Cadastrar' : 'Entrar'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _carregando ? null : () => setState(() => _modoCadastro = !_modoCadastro),
                    child: Text(_modoCadastro ? 'Já tenho conta — entrar' : 'Não tenho conta — cadastrar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}