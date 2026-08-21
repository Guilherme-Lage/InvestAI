from models import LimiteCategoria
from repositories import LimiteCategoriaRepository


class DefinirLimiteCategoriaService:
    """RF13 - cria ou atualiza (upsert) o limite de gasto mensal de uma
    categoria para o usuário, já que só faz sentido existir um limite
    por categoria."""

    def executar(self, usuario_id, dados):
        categoria = (dados.get("categoria") or "").strip().lower()
        if not categoria:
            raise ValueError("Informe a categoria.")

        try:
            valor_limite = float(dados.get("valor_limite"))
        except (TypeError, ValueError):
            raise ValueError("Informe um valor de limite válido.")
        if valor_limite <= 0:
            raise ValueError("O limite deve ser maior que zero.")

        limite = LimiteCategoriaRepository.buscar_por_categoria(usuario_id, categoria)
        if limite:
            limite.atualizar(valor_limite=valor_limite)
        else:
            limite = LimiteCategoria(
                usuario_id=usuario_id, categoria=categoria, valor_limite=valor_limite
            )
            limite.salvar()

        return limite.to_dict()
