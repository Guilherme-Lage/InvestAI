from datetime import date

from repositories import MetaRepository
from services.movimentacao.calcular_capacidade_economia_service import CalcularCapacidadeEconomiaService


class ListarMetasService:
    """RF07 - lista as metas do usuário já com o percentual de progresso
    e RF17 - o aporte mensal sugerido, ajustado à capacidade de economia
    mensal atual do usuário."""

    def executar(self, usuario_id):
        metas = MetaRepository.listar_por_usuario(usuario_id)
        capacidade = CalcularCapacidadeEconomiaService().executar(usuario_id)

        resultado = []
        for meta in metas:
            faltante = max(meta.valor_alvo - meta.valor_atual, 0.0)
            meses_restantes = self._meses_restantes(meta.prazo)
            aporte_necessario = faltante / meses_restantes

            # O aporte sugerido nunca ultrapassa a capacidade de economia
            # mensal do usuário: se ele economiza menos do que precisaria
            # para cumprir o prazo, sugerimos o máximo que ele consegue.
            aporte_sugerido = aporte_necessario
            if capacidade > 0:
                aporte_sugerido = min(aporte_necessario, capacidade)
            elif capacidade <= 0:
                aporte_sugerido = 0.0

            resultado.append({
                **meta.to_dict(),
                "aporte_sugerido": round(max(aporte_sugerido, 0.0), 2),
                "meses_restantes": meses_restantes,
            })
        return resultado

    def _meses_restantes(self, prazo):
        """Meses entre hoje e o prazo (string 'AAAA-MM-DD'). Mínimo 1 para
        não dividir por zero em metas vencidas/no mês atual."""
        try:
            data_prazo = date.fromisoformat(prazo)
        except (TypeError, ValueError):
            return 1
        hoje = date.today()
        meses = (data_prazo.year - hoje.year) * 12 + (data_prazo.month - hoje.month)
        return max(meses, 1)
