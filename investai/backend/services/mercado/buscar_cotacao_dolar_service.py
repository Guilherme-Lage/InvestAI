import time
from datetime import datetime

import requests

from services.mercado.reserva_em_disco import ERROS_DE_FONTE, buscar_com_reserva

URL_AWESOMEAPI = "https://economia.awesomeapi.com.br/json/daily/USD-BRL/30"
# Plano B: dólar comercial (venda) no SGS do Banco Central, a mesma API
# pública das taxas Selic/CDI/IPCA. A API aceita no máximo 20 pontos por
# consulta; 20 dias úteis cobrem cerca de um mês, o mesmo período do gráfico.
URL_BANCO_CENTRAL = (
    "https://api.bcb.gov.br/dados/serie/bcdata.sgs.10813/dados/ultimos/20?formato=json"
)
SEGUNDOS_CACHE = 600  # 10 minutos, para não bater na API externa a cada requisição

_cache = {"expira_em": 0, "dados": None}


class BuscarCotacaoDolarService:
    """Cotação do dólar (USD/BRL) e histórico dos últimos 30 dias, para o
    gráfico da tela Início.

    Fonte principal: AwesomeAPI (gratuita, sem chave). Ela limita o número
    de consultas por endereço de internet - atrás de uma VPN, que divide o
    endereço com muita gente, a cota acaba rápido. Nesse caso vale o Banco
    Central, e se os dois falharem, a última cotação guardada.
    """

    def executar(self):
        return buscar_com_reserva("dolar", _cache, SEGUNDOS_CACHE, self._buscar)

    def _buscar(self):
        try:
            return self._buscar_awesomeapi()
        except ERROS_DE_FONTE:
            return self._buscar_banco_central()

    def _buscar_awesomeapi(self):
        resposta = requests.get(URL_AWESOMEAPI, timeout=8)
        resposta.raise_for_status()
        pontos = resposta.json()
        if not pontos:
            raise ValueError("Sem dados de cotação disponíveis.")

        mais_recente = pontos[0]
        return {
            "atual": round(float(mais_recente["bid"]), 4),
            "variacao_pct": round(float(mais_recente["pctChange"]), 2),
            "atualizado_em": mais_recente["create_date"],
            "historico": [
                {
                    "data": time.strftime("%d/%m", time.localtime(int(ponto["timestamp"]))),
                    "valor": round(float(ponto["bid"]), 4),
                }
                for ponto in reversed(pontos)
            ],
            "fonte": "AwesomeAPI",
        }

    def _buscar_banco_central(self):
        resposta = requests.get(URL_BANCO_CENTRAL, timeout=8)
        resposta.raise_for_status()
        pontos = resposta.json()  # do mais antigo para o mais recente
        if len(pontos) < 2:
            raise ValueError("Sem dados de cotação disponíveis.")

        atual = float(pontos[-1]["valor"])
        anterior = float(pontos[-2]["valor"])
        return {
            "atual": round(atual, 4),
            "variacao_pct": round((atual / anterior - 1) * 100, 2),
            "atualizado_em": pontos[-1]["data"],
            "historico": [
                {
                    "data": datetime.strptime(ponto["data"], "%d/%m/%Y").strftime("%d/%m"),
                    "valor": round(float(ponto["valor"]), 4),
                }
                for ponto in pontos
            ],
            "fonte": "Banco Central",
        }
