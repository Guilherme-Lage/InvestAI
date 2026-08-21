import requests
from flask import Blueprint, jsonify

from services.mercado.buscar_cotacao_dolar_service import BuscarCotacaoDolarService
from services.mercado.buscar_taxas_mercado_service import BuscarTaxasMercadoService
from services.mercado.buscar_titulos_tesouro_service import BuscarTitulosTesouroService
from .auth_decorators import token_obrigatorio

mercado_bp = Blueprint("mercado", __name__, url_prefix="/api/mercado")


class MercadoController:
    """Controller de dados de mercado (dólar, taxas oficiais, Tesouro
    Direto): recebe a requisição HTTP, chama a Service correspondente
    (que encapsula a chamada à API externa) e devolve a resposta."""

    @token_obrigatorio
    def dolar(self):
        """Cotação do dólar (USD/BRL) e histórico dos últimos 30 dias, para
        o gráfico da tela Início."""
        try:
            dados = BuscarCotacaoDolarService().executar()
        except (requests.RequestException, ValueError):
            return jsonify({"erro": "Serviço de cotação indisponível no momento."}), 503
        return jsonify(dados)

    @token_obrigatorio
    def taxas(self):
        """Taxas oficiais atuais (Selic, CDI, IPCA), direto do Banco Central."""
        try:
            dados = BuscarTaxasMercadoService().executar()
        except (requests.RequestException, ValueError):
            return jsonify({"erro": "Serviço de taxas indisponível no momento."}), 503
        return jsonify(dados)

    @token_obrigatorio
    def tesouro(self):
        """Títulos do Tesouro Direto ofertados agora, com taxa e preço reais
        (Tesouro Transparente - dado público oficial do governo federal)."""
        try:
            dados = BuscarTitulosTesouroService().executar()
        except (requests.RequestException, ValueError):
            return jsonify({"erro": "Serviço do Tesouro Direto indisponível no momento."}), 503
        return jsonify(dados)


controller = MercadoController()

mercado_bp.add_url_rule("/dolar", view_func=controller.dolar, methods=["GET"])
mercado_bp.add_url_rule("/taxas", view_func=controller.taxas, methods=["GET"])
mercado_bp.add_url_rule("/tesouro", view_func=controller.tesouro, methods=["GET"])
