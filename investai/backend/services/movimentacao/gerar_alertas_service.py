from datetime import date, datetime

from repositories import MovimentacaoRepository, LimiteCategoriaRepository
from services.movimentacao.calcular_gastos_por_categoria_service import CalcularGastosPorCategoriaService

DIAS_LIMITE_INATIVIDADE = 3  # RF12


class GerarAlertasService:
    """Consolida os alertas automáticos do usuário:
    - RF12: inatividade de 3+ dias sem registrar gastos;
    - RF13: categorias que ultrapassaram o limite mensal definido.
    """

    def executar(self, usuario_id):
        dias_inatividade = self._dias_sem_registrar_gasto(usuario_id)
        alerta_inatividade = bool(
            dias_inatividade is not None and dias_inatividade >= DIAS_LIMITE_INATIVIDADE
        )

        hoje = date.today()
        inicio_mes = hoje.replace(day=1).isoformat()
        gastos_mes = CalcularGastosPorCategoriaService().executar(
            usuario_id, data_inicio=inicio_mes, data_fim=hoje.isoformat()
        )
        gastos_por_categoria = {g["categoria"]: g["total"] for g in gastos_mes}

        alertas_categoria = []
        for limite in LimiteCategoriaRepository.listar_por_usuario(usuario_id):
            gasto_atual = gastos_por_categoria.get(limite.categoria, 0.0)
            if gasto_atual > limite.valor_limite:
                alertas_categoria.append({
                    "categoria": limite.categoria,
                    "gasto_atual": gasto_atual,
                    "limite": limite.valor_limite,
                })

        return {
            "dias_sem_registrar_gasto": dias_inatividade,
            "alerta_inatividade": alerta_inatividade,
            "alertas_categoria": alertas_categoria,
        }

    def _dias_sem_registrar_gasto(self, usuario_id):
        ultima_data = MovimentacaoRepository.ultima_data_movimentacao(usuario_id, tipo="gasto")
        if not ultima_data:
            return None
        try:
            data_ref = datetime.strptime(ultima_data, "%Y-%m-%d").date()
        except ValueError:
            return None
        return (date.today() - data_ref).days
