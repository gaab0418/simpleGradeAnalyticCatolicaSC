# Termos de Uso e Isenção de Responsabilidade — Grade Analytic

Estes Termos de Uso regulam a utilização do repositório, do site e do aplicativo **Grade Analytic** (em conjunto, o **"Sistema"**). Ao acessar, compilar, hospedar ou utilizar qualquer parte do Sistema, você concorda integralmente com os termos abaixo.

## 1. Propósito Educacional — De Estudante para Estudante

Este é um projeto independente desenvolvido **de estudante para estudante**, com o intuito puramente educacional de **aprender a usar, em um caso real, as ferramentas, linguagens, arquiteturas e tecnologias disponíveis e vistas durante as aulas**.

O Sistema não possui fins lucrativos, não exibe anúncios, não comercializa dados e não pretende substituir os canais institucionais oficiais.

## 2. Ausência de Vínculo Oficial

O Sistema **não é oficial** e **não possui qualquer vínculo, patrocínio, aprovação, endosso ou afiliação** com a **instituição de ensino** nem com a **TOTVS S.A.** Todas as marcas eventualmente citadas pertencem aos seus respectivos titulares e são mencionadas apenas de forma descritiva.

## 3. Isenção Total de Responsabilidade (*As-Is*)

O Sistema é disponibilizado **"no estado em que se encontra" (*as-is*)**, sem garantias de qualquer natureza — expressas ou implícitas — quanto à exatidão, disponibilidade contínua, adequação ou confiabilidade das informações exibidas.

**O autor e mantenedor não se responsabiliza por absolutamente nada** relacionado ao uso ou à impossibilidade de uso do Sistema, incluindo, sem limitação:

- Eventuais erros, arredondamentos ou divergências nos cálculos de médias parciais, médias finais, pesos, notas necessárias, substituição de menor nota pela **N4** ou simulações interativas;
- Divergências na contagem de faltas, limites ou mudanças nas regras acadêmicas da instituição;
- Falhas de comunicação, bloqueios, alterações de API ou indisponibilidade do portal acadêmico TOTVS RM;
- Perda de prazos, reprovações, decisões acadêmicas, danos diretos ou indiretos decorrentes da confiança nas informações exibidas pelo Sistema.

> **Atenção:** O **Portal do Aluno oficial da sua instituição de ensino** e os registros da secretaria acadêmica são as **únicas fontes oficiais e definitivas**. Confira sempre suas notas e faltas diretamente no portal oficial antes de tomar qualquer decisão acadêmica.

## 4. Credenciais, Privacidade e Risco do Usuário

O uso do Sistema com suas credenciais do portal acadêmico é **totalmente voluntário e por sua exclusiva conta e risco**:

- **Aplicativo mobile:** comunica-se diretamente com o portal acadêmico; as credenciais e o cache local permanecem apenas no aparelho (e só são salvos se você optar por isso).
- **Site (Next.js):** como navegadores bloqueiam chamadas diretas ao portal (CORS), o servidor do site repassa a autenticação em memória de forma *stateless* (sem banco de dados e sem gravação em log). Caso marque "Manter conectado", usuário e senha são cifrados (`AES-256-GCM`) em cookie *HttpOnly* no seu navegador. Ainda assim, ao utilizar qualquer instância hospedada na internet, você confia no operador responsável por aquela hospedagem.

Para detalhes técnicos sobre privacidade e armazenamento, consulte [docs/SEGURANCA.md](docs/SEGURANCA.md) e [docs/ARQUITETURA.md](docs/ARQUITETURA.md).

## 5. Licença de Software (Uso Não Comercial)

O código-fonte deste projeto é licenciado sob a **[PolyForm Noncommercial License 1.0.0](LICENSE.md)**, permitindo uso pessoal, estudo, modificação e compartilhamento exclusivamente para fins **não comerciais**. Consulte [LICENSE.md](LICENSE.md) para o texto integral e o aviso de direitos autorais obrigatório.
