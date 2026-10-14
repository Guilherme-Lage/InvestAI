"""Cria (ou recria) uma conta de demonstração já com três meses de uso.

Uso, a partir da pasta backend:

    python criar_conta_demo.py

Serve para apresentar o app sem precisar digitar dezenas de transações
antes: gráficos, alertas, metas e score já aparecem preenchidos. Todos os
dados são fictícios. Rodar de novo apaga só esta conta e a refaz com as
datas atualizadas - as outras contas do banco não são tocadas.
"""
import calendar
import sys
from datetime import date, timedelta

from models import Investimento, Meta, Movimentacao, ScoreHistorico
from repositories import UsuarioRepository
from services.limite_categoria.definir_limite_categoria_service import (
    DefinirLimiteCategoriaService,
)
from services.recorrencia.criar_recorrencia_service import CriarRecorrenciaService
from services.usuario.calcular_score_financeiro_service import CalcularScoreFinanceiroService
from services.usuario.criar_usuario_service import CriarUsuarioService
from services.usuario.deletar_usuario_service import DeletarUsuarioService

EMAIL_DEMO = "demo@investai.com"
SENHA_DEMO = "demo1234"

# Contas que se repetem: (descrição, tipo, valor, categoria, dia do mês).
# São cadastradas como recorrências, então os lançamentos dos meses
# anteriores são gerados pelo próprio sistema.
RECORRENCIAS = [
    ("Salário", "renda", 5200.00, "salario", 5),
    ("Aluguel", "gasto", 1500.00, "contas_fixas", 10),
    ("Internet", "gasto", 120.00, "contas_fixas", 15),
    ("Streaming", "gasto", 39.90, "lazer", 20),
]

# Gastos do dia a dia, repetidos em cada mês: (dia, descrição, valor, categoria).
GASTOS_DO_MES = [
    (3, "Supermercado", 380.00, "alimentacao"),
    (6, "Combustível", 95.00, "transporte"),
    (7, "Cinema e lanche", 120.00, "lazer"),
    (8, "Farmácia", 140.00, "saude"),
    (12, "Feira e padaria", 290.00, "alimentacao"),
    (14, "Curso online", 200.00, "educacao"),
    (19, "Aplicativo de transporte", 110.00, "transporte"),
    (21, "Jantar fora", 150.00, "lazer"),
    (24, "Supermercado", 340.00, "alimentacao"),
]

LIMITES = [("lazer", 400.00), ("alimentacao", 1200.00)]

# Retratos antigos do score: (dias atrás, pontos abaixo do score de hoje).
# O score real não pode ser recalculado para o passado, então a subida é
# inventada - só para o gráfico de evolução não nascer vazio na demonstração.
SCORE_PASSADO = [(56, 170), (42, 130), (28, 90), (14, 50), (7, 20)]


def criar_conta_demo():
    """Precisa de um app context ativo. Devolve o id do usuário criado."""
    hoje = date.today()

    existente = UsuarioRepository.buscar_por_email(EMAIL_DEMO)
    if existente:
        DeletarUsuarioService().executar(existente["id"])

    usuario_id = CriarUsuarioService().executar({
        "nome": "Marina Demonstração",
        "email": EMAIL_DEMO,
        "senha": SENHA_DEMO,
        "perfil_risco": "moderado",
        "renda_mensal": 5200.00,
        "despesa_mensal_estimada": 3500.00,
        "despesa_fixa_estimada": 1660.00,
        "consentimento_aceito": True,
    })["usuario"]["id"]

    # Começam no dia 1 de dois meses atrás: ao cadastrar, o sistema já
    # lança tudo o que venceu de lá até hoje.
    inicio = _dia(hoje, meses_atras=2, dia=1)
    for descricao, tipo, valor, categoria, dia_mes in RECORRENCIAS:
        CriarRecorrenciaService().executar(usuario_id, {
            "descricao": descricao, "tipo": tipo, "valor": valor,
            "categoria": categoria, "dia_mes": dia_mes,
            "data_inicio": inicio.isoformat(),
        })

    for meses_atras in (2, 1, 0):
        for dia, descricao, valor, categoria in GASTOS_DO_MES:
            data = _dia(hoje, meses_atras, dia)
            if data <= hoje:  # no mês atual, só o que já aconteceu
                _movimentacao(usuario_id, descricao, "gasto", valor, data, categoria)

    _movimentacao(usuario_id, "Freela de design", "renda", 600.00,
                  _dia(hoje, meses_atras=1, dia=18), "freelance")
    # Lançado hoje de propósito: estoura o limite de lazer do mês (RF13)
    # em qualquer dia em que o script rode, e evita o alerta de inatividade.
    _movimentacao(usuario_id, "Ingresso de show", "gasto", 480.00, hoje, "lazer")

    for categoria, valor_limite in LIMITES:
        DefinirLimiteCategoriaService().executar(
            usuario_id, {"categoria": categoria, "valor_limite": valor_limite}
        )

    # Reserva pela metade do caminho: mantém as sugestões de investimento
    # bloqueadas, que é a regra central do app (RF14/RF15).
    _meta(usuario_id, "Reserva de emergência", 10500.00, 6800.00,
          hoje + timedelta(days=240), tipo="reserva_emergencia")
    _meta(usuario_id, "Viagem para o Nordeste", 4000.00, 1400.00, hoje + timedelta(days=300))
    _meta(usuario_id, "Notebook novo", 3500.00, 3500.00, hoje + timedelta(days=30))

    # Dinheiro parado na poupança: alimenta a comparação de carteira.
    Investimento(
        nome="Poupança", tipo="Poupança", valor_aplicado=2000.00, rendimento_atual=0.0,
        liquidez="diaria", indexador="poupanca", percentual_indexador=100.0,
        data_aplicacao=hoje - timedelta(days=200), usuario_id=usuario_id,
    ).salvar()

    score_hoje = CalcularScoreFinanceiroService().executar(usuario_id)["score"]
    for dias_atras, pontos_abaixo in SCORE_PASSADO:
        ScoreHistorico(
            usuario_id=usuario_id,
            data=(hoje - timedelta(days=dias_atras)).isoformat(),
            score=max(score_hoje - pontos_abaixo, 0),
        ).salvar()

    return usuario_id


def _dia(hoje, meses_atras, dia):
    """Data no mês que fica `meses_atras` antes do atual. Dias que não
    existem no mês (31 em abril) caem no último dia."""
    indice = hoje.year * 12 + (hoje.month - 1) - meses_atras
    ano, mes = divmod(indice, 12)
    mes += 1
    return date(ano, mes, min(dia, calendar.monthrange(ano, mes)[1]))


def _movimentacao(usuario_id, descricao, tipo, valor, data, categoria):
    Movimentacao(
        descricao=descricao, tipo=tipo, valor=valor, data=data.isoformat(),
        categoria=categoria, usuario_id=usuario_id,
    ).salvar()


def _meta(usuario_id, titulo, valor_alvo, valor_atual, prazo, tipo="geral"):
    Meta(
        titulo=titulo, valor_alvo=valor_alvo, valor_atual=valor_atual,
        prazo=prazo.isoformat(), tipo=tipo, usuario_id=usuario_id,
    ).salvar()


if __name__ == "__main__":
    from app import criar_app

    # Sem aquecer o cache de mercado: o script só mexe no banco e termina.
    app = criar_app({"AQUECER_CACHE_MERCADO": False})
    with app.app_context():
        criar_conta_demo()

    print("Conta de demonstração pronta.")
    print(f"  E-mail: {EMAIL_DEMO}")
    print(f"  Senha:  {SENHA_DEMO}")
    sys.exit(0)
