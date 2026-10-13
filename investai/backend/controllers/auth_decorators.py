from functools import wraps

import jwt
from flask import g, jsonify, request

from models import Usuario, db
from repositories import TokenRevogadoRepository
from services.auth_service import AuthService
from services.recorrencia.lancar_recorrencias_pendentes_service import (
    LancarRecorrenciasPendentesService,
)


def token_obrigatorio(funcao):
    """Protege uma rota exigindo um JWT válido no cabeçalho
    'Authorization: Bearer <token>'. Também bloqueia tokens que já
    foram revogados por um logout anterior, ou que pertencem a um
    usuário que não existe mais (ex.: conta excluída depois do login) -
    sem isso, as rotas devolveriam dados vazios/nulos para um usuário
    inexistente em vez de um erro de autenticação claro."""

    @wraps(funcao)
    def decorada(*args, **kwargs):
        cabecalho = request.headers.get("Authorization", "")
        if not cabecalho.startswith("Bearer "):
            return jsonify({"erro": "Token de autenticação ausente"}), 401

        token = cabecalho.split(" ", 1)[1].strip()

        try:
            payload = AuthService.decodificar_token(token)
        except jwt.ExpiredSignatureError:
            return jsonify({"erro": "Sessão expirada. Faça login novamente."}), 401
        except jwt.InvalidTokenError:
            return jsonify({"erro": "Token inválido."}), 401

        if TokenRevogadoRepository.buscar_por_jti(payload["jti"]):
            return jsonify({"erro": "Sessão encerrada. Faça login novamente."}), 401

        usuario_id = int(payload["sub"])
        if not Usuario.buscar_por_id(usuario_id):
            return jsonify({"erro": "Usuário não encontrado. Faça login novamente."}), 401

        g.usuario_id = usuario_id
        g.token_jti = payload["jti"]

        # Lança as contas recorrentes cujo dia já chegou antes de atender a
        # rota: assim saldo, relatório e histórico já saem com elas, seja
        # qual for a primeira tela que o usuário abrir. Uma falha aqui não
        # pode derrubar a requisição - fica para a próxima.
        try:
            LancarRecorrenciasPendentesService().executar(usuario_id)
        except Exception:
            db.session.rollback()

        return funcao(*args, **kwargs)

    return decorada
