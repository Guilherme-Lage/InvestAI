import json
import os
import time

import requests

# Pasta "instance" do backend (fica fora do Git, junto do banco de dados).
PASTA = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "instance",
)

# Depois de uma falha, quanto esperar antes de consultar a fonte de novo.
# Insistir a cada requisição só piora quando o motivo é limite de uso (429).
SEGUNDOS_ESPERA_APOS_FALHA = 300

ERROS_DE_FONTE = (requests.RequestException, ValueError, KeyError)


def buscar_com_reserva(nome, cache, segundos_cache, buscar):
    """Dado de mercado que continua aparecendo quando a fonte externa cai.

    Ordem de tentativa:
    1. cache em memória ainda válido;
    2. cópia em disco recente (evita baixar de novo a cada vez que o
       backend reinicia - o arquivo do Tesouro tem ~15 MB);
    3. a fonte externa, com `buscar()`. Se der certo, a resposta é gravada
       em disco;
    4. se a fonte falhar, a última cópia em disco, mesmo antiga, marcada
       com "desatualizado": True. Só sem nenhuma cópia o erro chega à tela.

    `cache` é o dicionário de cache em memória do serviço que chama.
    """
    agora = time.time()
    if cache.get("dados") is not None and agora < cache.get("expira_em", 0):
        return cache["dados"]

    guardado = _ler(nome)
    if guardado and agora - guardado["salvo_em"] < segundos_cache:
        return _lembrar(cache, guardado["dados"], guardado["salvo_em"] + segundos_cache)

    if agora >= cache.get("tentar_de_novo_em", 0):
        try:
            dados = buscar()
        except ERROS_DE_FONTE:
            cache["tentar_de_novo_em"] = agora + SEGUNDOS_ESPERA_APOS_FALHA
        else:
            _gravar(nome, dados, agora)
            return _lembrar(cache, dados, agora + segundos_cache)

    if guardado:
        return {**guardado["dados"], "desatualizado": True}
    raise ValueError("Fonte indisponível e sem cópia guardada.")


def _lembrar(cache, dados, expira_em):
    cache["dados"] = dados
    cache["expira_em"] = expira_em
    return dados


def _caminho(nome):
    return os.path.join(PASTA, f"mercado_{nome}.json")


def _ler(nome):
    try:
        with open(_caminho(nome), encoding="utf-8") as arquivo:
            guardado = json.load(arquivo)
        return guardado if "dados" in guardado and "salvo_em" in guardado else None
    except (OSError, ValueError):
        return None


def _gravar(nome, dados, salvo_em):
    try:
        os.makedirs(PASTA, exist_ok=True)
        with open(_caminho(nome), "w", encoding="utf-8") as arquivo:
            json.dump({"salvo_em": salvo_em, "dados": dados}, arquivo, ensure_ascii=False)
    except OSError:
        pass  # sem disco, segue só com o cache em memória
