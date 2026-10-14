"""Grava as respostas reais da API para a conta de demonstração, usadas
pelos testes de tela do Flutter (frontend_flutter/test/apoio/).

Uso, a partir da pasta backend:

    python -m tests.gerar_respostas_para_flutter

Os testes do Flutter montam as telas em cima deste arquivo em vez de
respostas escritas à mão. Assim, se o backend mudar o formato de uma
resposta, basta rodar isto de novo e os testes de tela mostram o que
quebrou no app. Rode sempre que alterar o que uma rota devolve.
"""
import base64
import json
import os
import time

from app import criar_app
from criar_conta_demo import criar_conta_demo
from gerar_extrato_exemplo import gerar_extrato_exemplo
from models import db
from services.auth_service import AuthService
from services.mercado import buscar_taxas_mercado_service
from tests.base import TAXAS_FIXAS

DESTINO = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "..", "frontend_flutter", "test", "apoio", "respostas_api.json",
)

# Só rotas que não dependem de internet. Dólar e Tesouro Direto ficam de
# fora: o app já trata a ausência deles, e é isso que os testes exercitam.
ROTAS = [
    "/api/usuarios/me",
    "/api/movimentacoes",
    "/api/movimentacoes/saldo",
    "/api/movimentacoes/capacidade-economia",
    "/api/movimentacoes/sobrevivencia",
    "/api/movimentacoes/relatorio-mensal",
    "/api/movimentacoes/gastos-por-categoria",
    "/api/movimentacoes/alertas",
    "/api/metas",
    "/api/metas/reserva-emergencia",
    "/api/investimentos",
    "/api/investimentos/comparar",
    "/api/limites",
    "/api/recorrencias",
    "/api/orientacao/guia",
    "/api/orientacao/score",
    "/api/orientacao/score/historico",
    "/api/mercado/taxas",
]


def gerar():
    app = criar_app({
        "SQLALCHEMY_DATABASE_URI": "sqlite:///:memory:",
        "TESTING": True,
        "AQUECER_CACHE_MERCADO": False,
    })
    with app.app_context():
        db.create_all()
        # Taxas fixas, como nos testes: o arquivo não deve mudar com o
        # Banco Central nem exigir internet para ser gerado.
        buscar_taxas_mercado_service._cache["dados"] = dict(TAXAS_FIXAS)
        buscar_taxas_mercado_service._cache["expira_em"] = time.time() + 3600

        usuario_id = criar_conta_demo()
        cabecalho = {"Authorization": f"Bearer {AuthService.gerar_token(usuario_id)}"}
        cliente = app.test_client()

        respostas = {}
        for rota in ROTAS:
            resposta = cliente.get(rota, headers=cabecalho)
            if resposta.status_code != 200:
                raise SystemExit(f"{rota} respondeu {resposta.status_code}")
            respostas[rota] = resposta.get_json()

        # Análise do extrato de exemplo: é um POST, então a chave leva o
        # método para não se confundir com as rotas de leitura.
        extrato = base64.b64encode(gerar_extrato_exemplo().encode("cp1252")).decode()
        analise = cliente.post(
            "/api/importacao/analisar", headers=cabecalho, json={"arquivo_base64": extrato}
        )
        if analise.status_code != 200:
            raise SystemExit(f"/api/importacao/analisar respondeu {analise.status_code}")
        respostas["POST /api/importacao/analisar"] = analise.get_json()

    os.makedirs(os.path.dirname(DESTINO), exist_ok=True)
    with open(DESTINO, "w", encoding="utf-8", newline="\n") as arquivo:
        json.dump(respostas, arquivo, ensure_ascii=False, indent=1, sort_keys=True)
        arquivo.write("\n")
    return respostas


if __name__ == "__main__":
    respostas = gerar()
    print(f"{len(respostas)} rotas gravadas em {os.path.normpath(DESTINO)}")
