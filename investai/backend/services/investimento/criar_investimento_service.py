from datetime import date

from models import Investimento
from services.investimento.calcular_rendimento_service import INDEXADORES


class CriarInvestimentoService:
    def executar(self, dados):
        indexador = (dados.get("indexador") or "").lower().strip() or None
        if indexador and indexador not in INDEXADORES:
            raise ValueError("Indexador inválido.")

        investimento = Investimento(
            nome=dados.get("nome"),
            tipo=dados.get("tipo"),
            valor_aplicado=float(dados.get("valor_aplicado") or 0),
            rendimento_atual=float(dados.get("rendimento_atual") or 0),
            liquidez=dados.get("liquidez", "diaria"),
            indexador=indexador,
            percentual_indexador=float(dados.get("percentual_indexador") or 100),
            data_aplicacao=self._data(dados.get("data_aplicacao")),
            usuario_id=int(dados.get("usuario_id")),
        )
        investimento.salvar()
        return investimento.to_dict()

    def _data(self, valor):
        if not valor:
            return date.today()
        try:
            return date.fromisoformat(str(valor)[:10])
        except ValueError:
            raise ValueError("Data de aplicação inválida.")
