import time

import requests

URL_SGS = "https://api.bcb.gov.br/dados/serie/bcdata.sgs.{codigo}/dados/ultimos/1?formato=json"
SERIE_SELIC_META = 432   # Taxa de juros - Meta Selic definida pelo Copom (% a.a.)
SERIE_CDI_DIARIO = 12    # Taxa de juros - CDI (% ao dia)
SERIE_IPCA_12M = 13522   # IPCA acumulado nos últimos 12 meses (% a.a.)

SEGUNDOS_CACHE = 3600  # 1 hora - taxas oficiais não mudam a cada minuto

_cache = {"expira_em": 0, "dados": None}


class BuscarTaxasMercadoService:
    """Taxas oficiais atuais (Selic, CDI anualizado e IPCA acumulado em 12
    meses), direto do Banco Central (SGS - Sistema Gerenciador de Séries
    Temporais, API pública e gratuita). Usadas para enriquecer as
    sugestões de investimento do guia financeiro (RF16) com números reais."""

    def executar(self):
        agora = time.time()
        if _cache["dados"] is not None and agora < _cache["expira_em"]:
            return _cache["dados"]

        selic = self._buscar_ultimo_valor(SERIE_SELIC_META)
        cdi_diario = self._buscar_ultimo_valor(SERIE_CDI_DIARIO)
        ipca = self._buscar_ultimo_valor(SERIE_IPCA_12M)

        cdi_anualizado = (((1 + cdi_diario / 100) ** 252) - 1) * 100

        dados = {
            "selic": round(selic, 2),
            "cdi": round(cdi_anualizado, 2),
            "ipca": round(ipca, 2),
            "atualizado_em": time.strftime("%d/%m/%Y"),
        }

        _cache["dados"] = dados
        _cache["expira_em"] = agora + SEGUNDOS_CACHE
        return dados

    def _buscar_ultimo_valor(self, codigo_serie):
        resposta = requests.get(URL_SGS.format(codigo=codigo_serie), timeout=8)
        resposta.raise_for_status()
        pontos = resposta.json()
        if not pontos:
            raise ValueError(f"Sem dados para a série {codigo_serie}.")
        return float(pontos[0]["valor"])
