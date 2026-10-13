import calendar
from datetime import date

from models import Movimentacao
from repositories import RecorrenciaRepository


class LancarRecorrenciasPendentesService:
    """Gera as movimentações das recorrências cujo dia já chegou.

    Não existe um agendador rodando à meia-noite: o lançamento acontece
    quando o usuário usa o app (ver `token_obrigatorio`). Por isso o
    cálculo cobre todos os meses em aberto, e não só o atual - quem ficar
    dois meses sem abrir o app encontra as duas contas lançadas, cada uma
    na sua data.
    """

    def executar(self, usuario_id, hoje=None):
        hoje = hoje or date.today()
        mes_atual = hoje.strftime("%Y-%m")

        lancadas = 0
        for recorrencia in RecorrenciaRepository.listar_pendentes(usuario_id, mes_atual):
            for data_lancamento in self._datas_pendentes(recorrencia, hoje):
                reservou = RecorrenciaRepository.marcar_mes_lancado(
                    recorrencia["id"], data_lancamento.strftime("%Y-%m")
                )
                if not reservou:
                    continue  # outra requisição já lançou este mês

                # O salvar() faz o commit da marca e da movimentação juntas.
                Movimentacao(
                    descricao=recorrencia["descricao"],
                    tipo=recorrencia["tipo"],
                    valor=recorrencia["valor"],
                    data=data_lancamento.isoformat(),
                    categoria=recorrencia["categoria"],
                    usuario_id=usuario_id,
                ).salvar()
                lancadas += 1

        return lancadas

    def _datas_pendentes(self, recorrencia, hoje):
        """Datas em que a recorrência deveria ter sido lançada e ainda não
        foi, da mais antiga para a mais recente."""
        inicio = date.fromisoformat(recorrencia["data_inicio"])

        if recorrencia["ultimo_mes_lancado"]:
            ano, mes = (int(parte) for parte in recorrencia["ultimo_mes_lancado"].split("-"))
            ano, mes = self._mes_seguinte(ano, mes)
        else:
            ano, mes = inicio.year, inicio.month

        datas = []
        while (ano, mes) <= (hoje.year, hoje.month):
            # Dia 31 em mês de 30 (ou 28) dias cai no último dia do mês.
            dia = min(recorrencia["dia_mes"], calendar.monthrange(ano, mes)[1])
            data_lancamento = date(ano, mes, dia)
            if data_lancamento > hoje:
                break
            if data_lancamento >= inicio:
                datas.append(data_lancamento)
            ano, mes = self._mes_seguinte(ano, mes)
        return datas

    def _mes_seguinte(self, ano, mes):
        return (ano + 1, 1) if mes == 12 else (ano, mes + 1)
