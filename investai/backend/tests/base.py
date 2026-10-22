import os
import sys
import tempfile
import time
import unittest
from datetime import date, timedelta

# Permite rodar com `python -m unittest` a partir da pasta backend.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import criar_app  # noqa: E402
from models import db, Usuario, Movimentacao, Meta, Investimento  # noqa: E402
from services.mercado import buscar_taxas_mercado_service, reserva_em_disco  # noqa: E402

# Taxas fixas para os testes. Usar as taxas reais faria o resultado mudar
# conforme o Banco Central - um teste que falha sozinho em outro dia não
# serve para nada.
TAXAS_FIXAS = {
    "selic": 10.0,
    "cdi": 9.0,
    "ipca": 5.0,
    "atualizado_em": "01/01/2026",
}


class TesteComBanco(unittest.TestCase):
    """Base dos testes: app com banco em memória, sem rede.

    Cada teste roda num banco limpo e com taxas de mercado fixas, para o
    resultado depender só do código - nunca da internet ou do dia.
    """

    def setUp(self):
        self.app = criar_app({
            "SQLALCHEMY_DATABASE_URI": "sqlite:///:memory:",
            "TESTING": True,
            "AQUECER_CACHE_MERCADO": False,
        })
        self.contexto = self.app.app_context()
        self.contexto.push()
        db.create_all()

        # Preenche o cache do serviço de taxas: assim nenhuma chamada sai
        # para a API do Banco Central durante os testes.
        buscar_taxas_mercado_service._cache["dados"] = dict(TAXAS_FIXAS)
        buscar_taxas_mercado_service._cache["expira_em"] = time.time() + 3600

        # Cópias de dados de mercado vão para uma pasta temporária, nunca
        # para a pasta instance de verdade.
        self._pasta_mercado = tempfile.TemporaryDirectory()
        self._pasta_original = reserva_em_disco.PASTA
        reserva_em_disco.PASTA = self._pasta_mercado.name

    def tearDown(self):
        db.session.remove()
        db.drop_all()
        self.contexto.pop()
        buscar_taxas_mercado_service._cache.clear()
        buscar_taxas_mercado_service._cache.update({"dados": None, "expira_em": 0})
        reserva_em_disco.PASTA = self._pasta_original
        self._pasta_mercado.cleanup()

    # ── Atalhos para montar cenários ──────────────────────────────────

    def criar_usuario(self, **campos):
        dados = {
            "nome": "Teste",
            "email": f"teste{Usuario.query.count()}@exemplo.com",
            "perfil_risco": "moderado",
            "renda_mensal": 5000.0,
        }
        dados.update(campos)
        usuario = Usuario(**dados)
        usuario.definir_senha("senha123")
        usuario.salvar()
        return usuario

    def criar_gasto(self, usuario, valor, categoria="outros", dias_atras=0):
        movimentacao = Movimentacao(
            descricao="gasto de teste",
            tipo="gasto",
            valor=valor,
            categoria=categoria,
            data=date.today() - timedelta(days=dias_atras),
            usuario_id=usuario.id,
        )
        movimentacao.salvar()
        return movimentacao

    def criar_renda(self, usuario, valor, dias_atras=0):
        movimentacao = Movimentacao(
            descricao="renda de teste",
            tipo="renda",
            valor=valor,
            categoria="salario",
            data=date.today() - timedelta(days=dias_atras),
            usuario_id=usuario.id,
        )
        movimentacao.salvar()
        return movimentacao

    def criar_reserva(self, usuario, valor_atual, valor_alvo=10000.0):
        meta = Meta(
            titulo="Reserva de emergência",
            valor_alvo=valor_alvo,
            valor_atual=valor_atual,
            prazo=(date.today() + timedelta(days=365)).isoformat(),
            tipo="reserva_emergencia",
            usuario_id=usuario.id,
        )
        meta.salvar()
        return meta

    def criar_investimento(self, usuario, valor, indexador=None, dias_atras=0, **campos):
        dados = {
            "nome": "Investimento de teste",
            "tipo": "Renda fixa",
            "valor_aplicado": valor,
            "rendimento_atual": 0.0,
            "liquidez": "diaria",
            "indexador": indexador,
            "percentual_indexador": 100.0,
            "data_aplicacao": date.today() - timedelta(days=dias_atras),
            "usuario_id": usuario.id,
        }
        dados.update(campos)
        investimento = Investimento(**dados)
        investimento.salvar()
        return investimento
