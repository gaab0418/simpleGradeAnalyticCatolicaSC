import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../domain/regras.dart';
import '../state/app_controller.dart';
import 'widgets/componentes.dart';

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
    final c = Paleta.of(context);
    final ocupado = widget.app.sincronizando;

    final formulario = Form(
      key: _form,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Suas notas e faltas, com o que falta para passar.',
                    style: TextStyle(
                      fontSize: 26,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Entre com o mesmo usuário e senha do portal.',
                    style: TextStyle(fontSize: 15, color: c.texto2),
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
                      style: TextStyle(fontSize: 13, color: c.texto2),
                    ),
                  ),
                  if (_erro != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline, size: 18, color: c.critico),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _erro!,
                              style: TextStyle(fontSize: 14, color: c.critico),
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
                ],
              ),
            ),
    );

    const painelDireito = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PreviaEntrada(),
        SizedBox(height: 14),
        _SegurancaEntrada(),
      ],
    );

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 720) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: formulario,
                  ),
                  const SizedBox(width: 28),
                  const Expanded(child: painelDireito),
                ],
              );
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  formulario,
                  const SizedBox(height: 24),
                  painelDireito,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PreviaEntrada extends StatelessWidget {
  const _PreviaEntrada();

  @override
  Widget build(BuildContext context) {
    final c = Paleta.of(context);
    final corLimite = c.tons[Tom.apertado]!.cor;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Compiladores',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.texto,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'CMP · Exemplo de cálculo automático',
                      style: TextStyle(fontSize: 12, color: c.texto2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Selo('Limite de faltas', tom: Tom.apertado),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _CelulaPrevia(
                  rotulo: 'N1',
                  child: Text(
                    '3,5',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: c.texto,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              const Expanded(
                child: _CelulaPrevia(
                  rotulo: 'N2',
                  child: NotaPendenteBadge(7.3),
                ),
              ),
              const Expanded(
                child: _CelulaPrevia(
                  rotulo: 'N3',
                  child: NotaPendenteBadge(7.3),
                ),
              ),
              Expanded(
                child: _CelulaPrevia(
                  rotulo: 'Soma',
                  child: Text.rich(
                    TextSpan(
                      text: '3,5',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: c.texto,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      children: [
                        TextSpan(
                          text: '/18',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: c.texto3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: c.borda),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const BarraDeFaltas(17),
                Text(
                  'resta 1 dia',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: corLimite,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CelulaPrevia extends StatelessWidget {
  const _CelulaPrevia({required this.rotulo, required this.child});

  final String rotulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = Paleta.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotulo,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: c.texto3,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 26,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(fit: BoxFit.scaleDown, child: child),
          ),
        ),
      ],
    );
  }
}

class _SegurancaEntrada extends StatelessWidget {
  const _SegurancaEntrada();

  @override
  Widget build(BuildContext context) {
    final c = Paleta.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.superficie2.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined, size: 18, color: c.acento),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Seus dados ficam com você',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: c.texto,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _PontoSeguranca(
            titulo: 'Conexão direta com o portal',
            texto:
                'O app fala direto com portal.catolicasc.org.br. Sua senha não passa por nenhum outro servidor.',
          ),
          const SizedBox(height: 8),
          const _PontoSeguranca(
            titulo: 'Armazenamento local e opcional',
            texto:
                'Notas e faltas ficam só no seu aparelho. A senha só é salva no cofre do sistema se você ativar.',
          ),
          const SizedBox(height: 8),
          const _PontoSeguranca(
            titulo: 'Consulta apenas de leitura',
            texto:
                'O aplicativo só lê seu boletim acadêmico e nunca envia alterações para a instituição.',
          ),
        ],
      ),
    );
  }
}

class _PontoSeguranca extends StatelessWidget {
  const _PontoSeguranca({required this.titulo, required this.texto});

  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final c = Paleta.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: c.acento, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: '$titulo: ',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: c.texto,
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: texto,
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    color: c.texto2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
