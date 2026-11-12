import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../state/app_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage(this.app, {super.key});
  final AppController app;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _usuario = TextEditingController();
  final _senha = TextEditingController();
  bool _mostrarSenha = false;
  bool _lembrar = true;
  String? _erro;

  @override
  void dispose() {
    _usuario.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (widget.app.sincronizando || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _erro = null);
    final erro = await widget.app.entrar(
      _usuario.text,
      _senha.text,
      lembrar: _lembrar,
    );
    if (!mounted) return;
    if (erro == null) {
      // Avisa o sistema para oferecer salvar no gerenciador de senhas.
      TextInput.finishAutofillContext();
    } else {
      setState(() => _erro = erro);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Caderno.of(context);
    final ocupado = widget.app.sincronizando;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: _form,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Seu boletim da Católica, no bolso.',
                    style: TextStyle(
                      fontSize: 32,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Transform.rotate(
                    angle: -0.01,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'notas, faltas e quanto falta pra passar',
                      style: c.mao.copyWith(
                        fontSize: 21,
                        color: c.canetaVermelha,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _usuario,
                    enabled: !ocupado,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(
                      labelText: 'Usuário do portal',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Informe o usuário do portal'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _senha,
                    enabled: !ocupado,
                    obscureText: !_mostrarSenha,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _entrar(),
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _mostrarSenha
                            ? 'Esconder senha'
                            : 'Mostrar senha',
                        icon: Icon(
                          _mostrarSenha
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _mostrarSenha = !_mostrarSenha),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Informe a senha' : null,
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _lembrar,
                    onChanged: ocupado
                        ? null
                        : (v) => setState(() => _lembrar = v),
                    title: const Text(
                      'Manter conectado neste aparelho',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      _lembrar
                          ? 'A senha fica criptografada no cofre do sistema.'
                          : 'Nada é salvo: ao fechar o app, você entra de novo.',
                      style: TextStyle(fontSize: 13, color: c.lapis),
                    ),
                  ),
                  if (_erro != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 18,
                            color: c.canetaVermelha,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _erro!,
                              style: TextStyle(
                                fontSize: 14,
                                color: c.canetaVermelha,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: ocupado ? null : _entrar,
                    child: ocupado
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(widget.app.progresso ?? 'Entrando…'),
                            ],
                          )
                        : const Text('Entrar'),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: ocupado ? null : widget.app.entrarDemo,
                      child: const Text('Ver uma demonstração sem conta'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined, size: 18, color: c.lapis),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'O app fala direto com portal.catolicasc.org.br. '
                          'Sua senha não passa por nenhum outro servidor.',
                          style: TextStyle(
                            fontSize: 13,
                            color: c.lapis,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
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
