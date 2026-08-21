import time

import requests

URL_AWESOMEAPI = "https://economia.awesomeapi.com.br/json/daily/USD-BRL/30"
SEGUNDOS_CACHE = 600  # 10 minutos, para não bater na API externa a cada requisição

_cache = {"expira_em": 0, "dados": None}


class BuscarCotacaoDolarService:
    """Cotação do dólar (USD/BRL) e histórico dos últimos 30 dias, via
    AwesomeAPI (API pública gratuita, sem necessidade de chave). Usada no
    gráfico de dólar da tela Início."""

    def executar(self):
        agora = time.time()
        if _cache["dados"] is not None and agora < _cache["expira_em"]:
            return _cache["dados"]

        resposta = requests.get(URL_AWESOMEAPI, timeout=8)
        resposta.raise_for_status()
        pontos = resposta.json()

        if not pontos:
            raise ValueError("Sem dados de cotação disponíveis.")

        historico = [
            {
                "data": self._formatar_data(ponto["timestamp"]),
                "valor": round(float(ponto["bid"]), 4),
            }
            for ponto in reversed(pontos)
        ]

        mais_recente = pontos[0]
        dados = {
            "atual": round(float(mais_recente["bid"]), 4),
            "variacao_pct": round(float(mais_recente["pctChange"]), 2),
            "atualizado_em": mais_recente["create_date"],
            "historico": historico,
        }

        _cache["dados"] = dados
        _cache["expira_em"] = agora + SEGUNDOS_CACHE
        return dados

    def _formatar_data(self, timestamp_unix):
        return time.strftime("%d/%m", time.localtime(int(timestamp_unix)))
