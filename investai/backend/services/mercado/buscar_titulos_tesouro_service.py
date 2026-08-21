import csv
import io
import time
from datetime import datetime

import requests

URL_CSV = (
    "https://www.tesourotransparente.gov.br/ckan/dataset/df56aa42-484a-4a59-8184-7676580c81e3"
    "/resource/796d2059-14e9-44e3-80c9-2d9e30b405c1/download/precotaxatesourodireto.csv"
)
SEGUNDOS_CACHE = 3600  # 1 hora - o arquivo tem ~15MB, não vale a pena buscar toda hora

# Ordem de exibição: do mais simples/conservador ao mais específico.
ORDEM_TIPOS = [
    "Tesouro Selic",
    "Tesouro Prefixado",
    "Tesouro Prefixado com Juros Semestrais",
    "Tesouro IPCA+",
    "Tesouro IPCA+ com Juros Semestrais",
    "Tesouro IGPM+ com Juros Semestrais",
    "Tesouro Renda+ Aposentadoria Extra",
    "Tesouro Educa+",
]

_cache = {"expira_em": 0, "dados": None}


class BuscarTitulosTesouroService:
    """Títulos do Tesouro Direto sendo ofertados agora, com taxa e preço
    reais, direto do Tesouro Transparente (dado público oficial do
    governo federal, sem necessidade de chave). Para cada tipo de título,
    mostra o de vencimento mais próximo (o mais líquido/comum)."""

    def executar(self):
        agora = time.time()
        if _cache["dados"] is not None and agora < _cache["expira_em"]:
            return _cache["dados"]

        # O arquivo é grande (~15MB) e o servidor do Tesouro Transparente é
        # lento para servi-lo (dezenas de segundos); por isso o cache acima
        # e o pré-aquecimento em segundo plano feito em app.py são
        # essenciais para não travar uma requisição de usuário nisso.
        resposta = requests.get(URL_CSV, timeout=60)
        resposta.raise_for_status()
        texto = resposta.content.decode("latin-1")
        linhas = list(csv.DictReader(io.StringIO(texto), delimiter=";"))

        # Descobre a data mais recente convertendo só os valores distintos
        # (milhares, não as ~175 mil linhas) para evitar strptime repetido.
        datas_distintas = {linha["Data Base"] for linha in linhas}
        data_mais_recente = max(datas_distintas, key=self._converter_data)

        hoje = datetime.now()
        ofertados = {}
        for linha in linhas:
            if linha["Data Base"] != data_mais_recente:
                continue
            vencimento = self._converter_data(linha["Data Vencimento"])
            if vencimento <= hoje:
                continue

            tipo = linha["Tipo Titulo"]
            existente = ofertados.get(tipo)
            if existente is None or vencimento < existente["_vencimento_dt"]:
                preco = self._converter_numero(linha["PU Venda Manha"])
                ofertados[tipo] = {
                    "nome": tipo,
                    "vencimento": vencimento.strftime("%Y-%m-%d"),
                    "taxa_ano": self._converter_numero(linha["Taxa Venda Manha"]),
                    "preco_unitario": preco,
                    "investimento_minimo": round(max(preco * 0.01, 30.0), 2),
                    "_vencimento_dt": vencimento,
                }

        titulos = []
        for tipo in ORDEM_TIPOS:
            item = ofertados.get(tipo)
            if item:
                item = dict(item)
                item.pop("_vencimento_dt")
                titulos.append(item)

        dados = {
            "atualizado_em": data_mais_recente,
            "titulos": titulos,
        }

        _cache["dados"] = dados
        _cache["expira_em"] = agora + SEGUNDOS_CACHE
        return dados

    def _converter_data(self, texto):
        return datetime.strptime(texto, "%d/%m/%Y")

    def _converter_numero(self, texto):
        return float(texto.replace(",", "."))
