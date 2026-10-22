import time
import unittest
from unittest import mock

import requests

from tests.base import TesteComBanco
from services.mercado import buscar_cotacao_dolar_service as modulo_dolar
from services.mercado import reserva_em_disco
from services.mercado.buscar_cotacao_dolar_service import BuscarCotacaoDolarService
from services.mercado.reserva_em_disco import buscar_com_reserva

# Respostas no formato de cada fonte (valores inventados).
AWESOMEAPI = [
    {"bid": "5.10", "pctChange": "0.5", "create_date": "2026-10-22 17:00:00", "timestamp": "1792699200"},
    {"bid": "5.05", "pctChange": "-0.2", "create_date": "2026-10-21 17:00:00", "timestamp": "1792612800"},
]
BANCO_CENTRAL = [
    {"data": "20/10/2026", "valor": "5.0000"},
    {"data": "21/10/2026", "valor": "5.0500"},
]


class _Resposta:
    def __init__(self, corpo, status=200):
        self.corpo, self.status_code = corpo, status

    def json(self):
        return self.corpo

    def raise_for_status(self):
        if self.status_code >= 400:
            raise requests.HTTPError(f"{self.status_code}")


def _internet(**respostas_por_trecho_de_url):
    """Simula a internet: cada trecho de URL responde o que foi combinado.
    O que não foi combinado falha como se a fonte estivesse fora."""
    chamadas = []

    def get(url, timeout=None):
        chamadas.append(url)
        for trecho, resposta in respostas_por_trecho_de_url.items():
            if trecho in url:
                return resposta
        raise requests.ConnectionError("fora do ar")

    return mock.patch("requests.get", side_effect=get), chamadas


class TesteReservaEmDisco(TesteComBanco):
    """Dado de mercado vem de fora e às vezes a fonte cai ou limita o uso.
    O app deve seguir mostrando o último dado bom em vez de "indisponível"."""

    def setUp(self):
        super().setUp()
        self.cache = {"dados": None, "expira_em": 0}
        self.chamadas = 0

    def _fonte(self, resultado):
        def buscar():
            self.chamadas += 1
            if isinstance(resultado, Exception):
                raise resultado
            return resultado
        return buscar

    def test_resposta_boa_fica_em_memoria_e_em_disco(self):
        primeira = buscar_com_reserva("teste", self.cache, 600, self._fonte({"x": 1}))
        segunda = buscar_com_reserva("teste", self.cache, 600, self._fonte({"x": 2}))

        self.assertEqual(primeira, {"x": 1})
        self.assertEqual(segunda, {"x": 1})  # veio do cache, sem nova consulta
        self.assertEqual(self.chamadas, 1)

    def test_fonte_fora_do_ar_devolve_a_ultima_copia_marcada_como_desatualizada(self):
        buscar_com_reserva("teste", self.cache, 600, self._fonte({"x": 1}))
        cache_vencido = {"dados": None, "expira_em": 0}

        with mock.patch("time.time", return_value=time.time() + 3600):
            dados = buscar_com_reserva(
                "teste", cache_vencido, 600, self._fonte(requests.HTTPError("429"))
            )

        self.assertEqual(dados, {"x": 1, "desatualizado": True})

    def test_depois_de_uma_falha_espera_antes_de_consultar_de_novo(self):
        buscar_com_reserva("teste", self.cache, 600, self._fonte({"x": 1}))
        cache_vencido = {"dados": None, "expira_em": 0}
        falha = self._fonte(requests.HTTPError("429"))

        with mock.patch("time.time", return_value=time.time() + 3600):
            for _ in range(5):
                buscar_com_reserva("teste", cache_vencido, 600, falha)

        # Uma consulta boa e uma ruim; as outras quatro nem saíram.
        self.assertEqual(self.chamadas, 2)

    def test_reinicio_do_backend_usa_a_copia_recente_sem_baixar_de_novo(self):
        buscar_com_reserva("teste", self.cache, 600, self._fonte({"x": 1}))

        cache_de_um_backend_novo = {"dados": None, "expira_em": 0}
        dados = buscar_com_reserva("teste", cache_de_um_backend_novo, 600, self._fonte({"x": 2}))

        self.assertEqual(dados, {"x": 1})
        self.assertEqual(self.chamadas, 1)

    def test_sem_copia_guardada_o_erro_chega_a_tela(self):
        with self.assertRaises(ValueError):
            buscar_com_reserva("teste", self.cache, 600, self._fonte(requests.ConnectionError()))

    def test_grava_na_pasta_temporaria_dos_testes(self):
        buscar_com_reserva("teste", self.cache, 600, self._fonte({"x": 1}))

        self.assertTrue(reserva_em_disco._caminho("teste").startswith(reserva_em_disco.PASTA))
        self.assertNotEqual(reserva_em_disco.PASTA, self._pasta_original)


class TesteCotacaoDoDolar(TesteComBanco):
    def setUp(self):
        super().setUp()
        modulo_dolar._cache.clear()
        modulo_dolar._cache.update({"dados": None, "expira_em": 0})

    def tearDown(self):
        modulo_dolar._cache.clear()
        modulo_dolar._cache.update({"dados": None, "expira_em": 0})
        super().tearDown()

    def test_usa_a_awesomeapi_quando_ela_responde(self):
        internet, chamadas = _internet(awesomeapi=_Resposta(AWESOMEAPI))
        with internet:
            dados = BuscarCotacaoDolarService().executar()

        self.assertEqual(dados["fonte"], "AwesomeAPI")
        self.assertEqual(dados["atual"], 5.10)
        self.assertEqual(len(dados["historico"]), 2)

    def test_awesomeapi_sem_cota_cai_para_o_banco_central(self):
        """O caso real: atrás de uma VPN a AwesomeAPI responde 429."""
        internet, chamadas = _internet(
            awesomeapi=_Resposta({"code": "QuotaExceeded"}, status=429),
            **{"api.bcb.gov.br": _Resposta(BANCO_CENTRAL)},
        )
        with internet:
            dados = BuscarCotacaoDolarService().executar()

        self.assertEqual(dados["fonte"], "Banco Central")
        self.assertEqual(dados["atual"], 5.05)
        self.assertEqual(dados["variacao_pct"], 1.0)
        self.assertEqual(dados["historico"], [
            {"data": "20/10", "valor": 5.0},
            {"data": "21/10", "valor": 5.05},
        ])

    def test_rota_responde_503_so_quando_nao_ha_nada_para_mostrar(self):
        from services.auth_service import AuthService

        usuario = self.criar_usuario()
        cabecalho = {"Authorization": f"Bearer {AuthService.gerar_token(usuario.id)}"}
        internet, _ = _internet()  # tudo fora do ar
        with internet:
            resposta = self.app.test_client().get("/api/mercado/dolar", headers=cabecalho)

        self.assertEqual(resposta.status_code, 503)


if __name__ == "__main__":
    unittest.main()
