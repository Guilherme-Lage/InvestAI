import base64
import binascii

from flask import Blueprint, g, jsonify, request

from services.importacao.analisar_extrato_service import AnalisarExtratoService
from services.importacao.confirmar_importacao_service import ConfirmarImportacaoService
from .auth_decorators import token_obrigatorio

importacao_bp = Blueprint("importacao", __name__, url_prefix="/api/importacao")

TAMANHO_MAXIMO_ARQUIVO = 2 * 1024 * 1024  # 2 MB; um ano de extrato não chega a isso


class ImportacaoController:
    """Controller da importação de extrato bancário: recebe a requisição
    HTTP, chama a Service correspondente e devolve a resposta. Nenhuma
    regra de negócio é implementada aqui."""

    @token_obrigatorio
    def analisar(self):
        """Lê o extrato OFX e devolve as transações para o usuário
        revisar. Não grava nada.

        Corpo: {"arquivo_base64": "<conteúdo do arquivo .ofx>"}. O arquivo
        vai em base64 dentro do JSON para o app usar a mesma chamada
        autenticada das outras rotas.
        """
        dados = request.get_json(silent=True) or {}
        try:
            conteudo = base64.b64decode(dados.get("arquivo_base64") or "", validate=True)
        except (binascii.Error, ValueError, TypeError):
            return jsonify({"erro": "Não foi possível ler o arquivo enviado."}), 400
        if not conteudo:
            return jsonify({"erro": "Escolha um arquivo de extrato (.ofx)."}), 400
        if len(conteudo) > TAMANHO_MAXIMO_ARQUIVO:
            return jsonify({"erro": "Arquivo grande demais. Exporte um período menor."}), 400

        try:
            analise = AnalisarExtratoService().executar(g.usuario_id, conteudo)
        except ValueError as erro:
            return jsonify({"erro": str(erro)}), 400
        return jsonify(analise)

    @token_obrigatorio
    def confirmar(self):
        """Grava como movimentações as transações que o usuário escolheu
        na revisão. Corpo: {"transacoes": [...]}, no formato devolvido
        por /analisar."""
        dados = request.get_json(silent=True) or {}
        try:
            resultado = ConfirmarImportacaoService().executar(
                g.usuario_id, dados.get("transacoes")
            )
        except ValueError as erro:
            return jsonify({"erro": str(erro)}), 400
        return jsonify(resultado), 201


controller = ImportacaoController()

importacao_bp.add_url_rule("/analisar", view_func=controller.analisar, methods=["POST"])
importacao_bp.add_url_rule("/confirmar", view_func=controller.confirmar, methods=["POST"])
