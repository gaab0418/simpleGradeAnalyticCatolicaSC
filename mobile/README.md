# Boletim Católica SC — app de celular

Versão mobile (Flutter, Android e iOS) do boletim do portal TOTVS RM da Católica SC.
Mesmas regras e o mesmo visual do [site](../site/README.md), mais três coisas que
só fazem sentido no celular:

- **Login salvo no aparelho**, no cofre do sistema (Android Keystore / iOS Keychain).
- **Histórico de todos os semestres guardado localmente**: abre na hora e funciona sem internet.
- **Aba Desempenho**: média geral, evolução por semestre, ritmo N1 → N2 → N3,
  distribuição das médias, faltas por semestre, melhores e piores matérias e
  anotações automáticas ("você costuma crescer ao longo do semestre…").

Extras: aviso de **nota nova** ao sincronizar, **trava por digital/rosto** opcional,
simulador "E se eu tirar…", tema claro/escuro e um **modo demonstração** sem conta.

## Como rodar

Precisa do [Flutter](https://docs.flutter.dev/get-started/install) 3.50 ou mais novo.

```bash
cd mobile
flutter pub get
flutter run                 # com um celular conectado ou emulador aberto
flutter build apk --release # gera build/app/outputs/flutter-apk/app-release.apk
flutter test                # 27 testes
```

Para abrir direto na demonstração (prints, apresentação):
`flutter run --dart-define=DEMO=true`.

> O app fala direto com `portal.catolicasc.org.br`, sem passar por servidor nenhum. O site
> precisa de um repasse no servidor porque navegadores não conseguem chamar o portal (CORS).

## Arquitetura

```
lib/
  domain/   regras puras, sem Flutter: modelos, situação da matéria, resumo, desempenho
  data/     portal TOTVS (HTTP), cofre de credenciais, cache local, biometria, demo
  state/    AppController: sessão, sincronização e preferências (ChangeNotifier)
  ui/       telas e componentes
  core/     tema e formatação pt-BR
```

- `domain/` é onde mora toda regra acadêmica (as mesmas de `site/src/lib/dominio/`).
  As telas só exibem.
- `data/portal.dart` define o contrato `PortalGateway`; `totvs_client_io.dart` é a
  implementação real e os testes usam um portal falso.
- Sincronização incremental: semestres encerrados não mudam mais, então só o
  semestre em andamento é consultado de novo. "Baixar todos os semestres de novo"
  (Ajustes) força a carga completa.

## Segurança

| Decisão | Motivo |
|---|---|
| Senha só em `flutter_secure_storage` | Criptografada com chave do Keystore/Keychain, presa ao aparelho |
| Sem servidor intermediário | A senha só trafega, via HTTPS, para o host do portal |
| Host fixo e redirecionamento manual | Se o portal redirecionar para outro domínio, a requisição é abortada e nenhum cookie/senha é enviado |
| `allowBackup=false` + `dataExtractionRules` | Notas e credenciais não vão para backup na nuvem nem para outro aparelho |
| `usesCleartextTraffic=false` | HTTP sem TLS é bloqueado pelo sistema |
| "Sair" apaga tudo | Credenciais, histórico e a preferência de trava |
| "Manter conectado" desligado | Nada (nem senha nem notas) é gravado em disco |
| Trava biométrica opcional | Pede digital/rosto ao abrir e sempre que o app sai da tela |

Limites conhecidos, para não vender o que não é:

- O histórico de notas fica em `SharedPreferences` (área privada do app), **não**
  criptografado. Em aparelho com root ele é legível. A senha não.
- Não há certificate pinning: a confiança é a da cadeia de CAs do sistema.
- O APK de release usa a chave de debug do template. Para distribuir de verdade,
  crie um keystore próprio e configure `signingConfig` em `android/app/build.gradle.kts`.
- App não oficial. Se a Católica/TOTVS mudar a API do portal, `totvs_client_io.dart`
  é o único arquivo a ajustar.
