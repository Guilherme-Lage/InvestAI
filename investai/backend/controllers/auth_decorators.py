from functools import wraps

import jwt
from flask import g, jsonify, request

from models import TokenRevogado, Usuario
from services.auth_service import AuthService


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

        if TokenRevogado.query.filter_by(jti=payload["jti"]).first():
            return jsonify({"erro": "Sessão encerrada. Faça login novamente."}), 401

        usuario_id = int(payload["sub"])
        if not Usuario.buscar_por_id(usuario_id):
            return jsonify({"erro": "Usuário não encontrado. Faça login novamente."}), 401

        g.usuario_id = usuario_id
        g.token_jti = payload["jti"]
        return funcao(*args, **kwargs)

    return decorada
