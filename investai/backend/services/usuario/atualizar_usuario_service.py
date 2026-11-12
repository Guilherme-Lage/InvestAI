from models import Usuario


class AtualizarUsuarioService:
    """Atualiza nome, e-mail e renda mensal do usuário.

    O perfil de investidor (RF18) não é alterado aqui: ele só muda pelo
    questionário de suitability (ResponderSuitabilityService), para não
    ser escolhido sem análise."""

    def executar(self, usuario_id, dados):
        usuario = Usuario.buscar_por_id(usuario_id)
        if usuario is None:
            return None

        renda_mensal = dados.get("renda_mensal")
        despesa_estimada = dados.get("despesa_mensal_estimada")
        usuario.atualizar(
            nome=dados.get("nome"),
            email=dados.get("email"),
            renda_mensal=float(renda_mensal) if renda_mensal is not None else None,
            despesa_mensal_estimada=(
                float(despesa_estimada) if despesa_estimada is not None else None
            ),
        )
        return usuario.to_dict()
