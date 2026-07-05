import os
import json
import urllib.parse
import base64
from http.server import BaseHTTPRequestHandler, HTTPServer
from datetime import datetime
import requests

def load_env(filepath=".env"):
    """Loads environment variables from a .env file."""
    if not os.path.exists(filepath):
        print(f"Aviso: Arquivo {filepath} nao encontrado.")
        return
    with open(filepath, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            key, val = line.split("=", 1)
            os.environ[key.strip()] = val.strip()

# Carrega as credenciais
load_env()

def get_default_period():
    """
    Retorna o periodo default com base na data:
    Se entre 01/01 e 01/08 do ano atual -> usa o primeiro periodo daquele ano (Ex: 202611)
    Senao -> usa o outro periodo (Ex: 202623)
    """
    now = datetime.now()
    year = now.year
    # Regra: se o mes for ate julho (mes 7) ou dia 1 de agosto (mes 8, dia 1)
    if now.month < 8 or (now.month == 8 and now.day == 1):
        return f"{year}11"
    else:
        return f"{year}23"

def fetch_totvs_data(periodo_alvo):
    """
    Executa a autenticacao e busca notas/faltas para o periodo letivo alvo.
    """
    usuario = os.getenv("USUARIO")
    senha = os.getenv("SENHA")
    
    if not usuario or not senha:
        raise ValueError("Credenciais USUARIO e SENHA nao encontradas no .env")

    session = requests.Session()
    session.headers.update({
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36",
        "accept-language": "pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7,ja;q=0.6",
    })
    
    # 1. GET Inicial no portal
    portal_url = "https://portal.catolicasc.org.br/FrameHTML/web/app/edu/PortalEducacional/"
    session.get(portal_url)
    
    # Forcar cookies se nao definidos
    if "DefaultAlias" not in session.cookies:
        session.cookies.set("DefaultAlias", "CorporeRM", domain="portal.catolicasc.org.br")
    if "EduMascaras" not in session.cookies:
        session.cookies.set("EduMascaras", '{"mascaraTelefone": "(99) 9?9999-9999", "mascaraCEP": ""}', domain="portal.catolicasc.org.br")

    # 2. POST de Login
    login_url = "https://portal.catolicasc.org.br/FrameHTML/RM/API/TOTVSEducacional/Login"
    login_headers = {
        "accept": "application/json, text/plain, */*",
        "content-type": "application/json;charset=UTF-8",
        "origin": "https://portal.catolicasc.org.br",
        "referer": "https://portal.catolicasc.org.br/FrameHTML/web/app/edu/PortalEducacional/login/",
        "priority": "u=1, i",
        "sec-ch-ua": '"Google Chrome";v="149", "Chromium";v="149", "Not)A;Brand";v="24"',
        "sec-ch-ua-mobile": "?0",
        "sec-ch-ua-platform": '"Windows"',
        "sec-fetch-dest": "empty",
        "sec-fetch-mode": "cors",
        "sec-fetch-site": "same-origin"
    }
    
    r_login = session.post(login_url, json={"user": usuario, "password": senha, "alias": "CorporeRM"}, headers=login_headers)
    if r_login.status_code != 200:
        raise Exception(f"Erro no Login POST: {r_login.text}")
        
    res_json = r_login.json()
    b64_val = res_json.get("data", {}).get("value")
    if not b64_val:
        raise Exception("Token de login nao encontrado na resposta.")
        
    # Configura cookie inicial EduContextoAlunoResponsavelAPI
    unquoted_val = urllib.parse.unquote(b64_val)
    contexto_temp = base64.b64decode(unquoted_val).decode("utf-8")
    session.cookies.set("EduContextoAlunoResponsavelAPI", contexto_temp, domain="portal.catolicasc.org.br")

    # 3. GET AutoLoginPortal
    autologin_url = "https://portal.catolicasc.org.br/FrameHTML/RM/API/user/AutoLoginPortal"
    autologin_headers = {
        "accept": "application/json, text/plain, */*",
        "referer": "https://portal.catolicasc.org.br/FrameHTML/web/app/edu/PortalEducacional/",
        "priority": "u=1, i"
    }
    session.get(autologin_url, params={"key": unquoted_val}, headers=autologin_headers)

    # 4. GET Contexto
    context_url = "https://portal.catolicasc.org.br/FrameHTML/RM/API/TOTVSEducacional/Contexto"
    r_context = session.get(context_url, headers=autologin_headers)
    contextos = r_context.json().get("data", [])
    
    contexto_selecionado = None
    contextos_formatados = []
    
    # Mapeia os contextos disponiveis
    for ctx in contextos:
        cod_perlet = str(ctx.get('CODPERLET'))
        contextos_formatados.append({
            "CODPERLET": cod_perlet,
            "NOMECURSO": ctx.get("NOMECURSO"),
            "RA": ctx.get("RA"),
            "SITMATPERLET": ctx.get("SITMATPERLET")
        })
        if cod_perlet == periodo_alvo:
            contexto_selecionado = ctx.get("IDCONTEXTOALUNO")
            
    # Fallback de contexto se o periodo_alvo nao for encontrado
    if not contexto_selecionado and contextos:
        # Se nao achou o alvo, escolhe o primeiro do index correspondente ou o primeiro da lista
        target_idx = 1 if len(contextos) > 1 else 0
        contexto_selecionado = contextos[target_idx].get("IDCONTEXTOALUNO")
        periodo_alvo = str(contextos[target_idx].get("CODPERLET"))

    if contexto_selecionado:
        session.cookies.set("EduContextoAlunoResponsavelAPI", contexto_selecionado, domain="portal.catolicasc.org.br")

    # 5. GET Notas
    notas_url = "https://portal.catolicasc.org.br/FrameHTML/RM/API/TOTVSEducacional/NotaEtapa"
    r_notas = session.get(notas_url, headers=autologin_headers)
    notas_list = r_notas.json().get("data", {}).get("Notas", [])

    # 6. GET Faltas
    faltas_url = "https://portal.catolicasc.org.br/FrameHTML/RM/API/TOTVSEducacional/FaltaEtapa"
    r_faltas = session.get(faltas_url, headers=autologin_headers)
    faltas_list = r_faltas.json().get("data", {}).get("FaltasEtapa", [])

    # Cruzar dados de Notas e Faltas por IDTURMADISC
    faltas_map = {f.get("IDTURMADISC"): f for f in faltas_list if f.get("IDTURMADISC")}
    
    grades_and_absences = []
    for nota in notas_list:
        id_turma_disc = nota.get("IDTURMADISC")
        falta_info = faltas_map.get(id_turma_disc, {})
        
        grades_and_absences.append({
            "CODTURMA": nota.get("CODTURMA"),
            "CODDISC": nota.get("CODDISC"),
            "DISCIPLINA": nota.get("DISCIPLINA"),
            "SITUACAO": nota.get("SITUACAO"),
            "IDTURMADISC": id_turma_disc,
            "nota1": nota.get("1 - Nota 1"),
            "nota2": nota.get("2 - Nota 2"),
            "nota3": nota.get("3 - Nota 3"),
            "media_parcial": nota.get("5 - M\u00e9dia Parcial") or nota.get("5 - M\u00e9dia Parcial"),
            "media_final": nota.get("6 - M\u00e9dia Final") or nota.get("4 - M\u00e9dia Final"),
            "faltas": falta_info.get("1 - Faltas Sala de Aula", "0"),
            "faltas_percentual": falta_info.get("PERCENTUAL", 0.0),
            "situacao_faltas": falta_info.get("SITUACAOFALTAS")
        })

    # Informacoes do aluno (primeiro da lista de contexto)
    aluno_info = {}
    if contextos:
        first_ctx = contextos[0]
        aluno_info = {
            "NOMEALUNO": first_ctx.get("NOMEALUNO"),
            "RA": first_ctx.get("RA"),
            "NOMECURSO": first_ctx.get("NOMECURSO")
        }

    return {
        "aluno": aluno_info,
        "periodo_atual": periodo_alvo,
        "contextos": contextos_formatados,
        "grades": grades_and_absences
    }

class PortalHTTPHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed_url = urllib.parse.urlparse(self.path)
        path = parsed_url.path
        
        # Roteamento de API
        if path == "/api/contextos":
            try:
                # Fazemos uma conexao rapida ao TOTVS para carregar os contextos disponiveis
                default_p = get_default_period()
                data = fetch_totvs_data(default_p)
                
                response_data = {
                    "aluno": data["aluno"],
                    "contextos": data["contextos"],
                    "default_periodo": default_p,
                    "periodo_atual": data["periodo_atual"]
                }
                
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps(response_data).encode("utf-8"))
            except Exception as e:
                self.send_error_response(e)
                
        elif path == "/api/grades":
            query_params = urllib.parse.parse_qs(parsed_url.query)
            periodo = query_params.get("periodo", [None])[0]
            if not periodo:
                periodo = get_default_period()
            
            try:
                data = fetch_totvs_data(periodo)
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps(data).encode("utf-8"))
            except Exception as e:
                self.send_error_response(e)
                
        # Servir index.html
        elif path in ["/", "/index.html"]:
            try:
                filepath = os.path.join(os.path.dirname(__file__), "index.html")
                with open(filepath, "r", encoding="utf-8") as f:
                    content = f.read()
                
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.end_headers()
                self.wfile.write(content.encode("utf-8"))
            except Exception as e:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(f"Erro ao carregar index.html: {e}".encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"Nao encontrado")
            
    def send_error_response(self, error):
        self.send_response(500)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"error": str(error)}).encode("utf-8"))

def run(port=8080):
    server_address = ('', port)
    httpd = HTTPServer(server_address, PortalHTTPHandler)
    print(f"[*] Servidor rodando em http://localhost:{port}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    print("[*] Servidor finalizado.")

if __name__ == "__main__":
    run()
