"""Regras próprias da conta de demonstração (criada por criar_conta_demo.py).

Ela existe para apresentar o app, e a apresentação precisa poder ser
repetida. Por isso, toda vez que uma sessão da demo começa (no login e
quando o app é reaberto com a sessão salva), duas coisas voltam ao estado
original:

- o questionário de suitability (RF18) fica pendente de novo, para o
  aviso aparecer e o questionário poder ser respondido outra vez;
- a reserva de emergência volta para a metade do caminho, com os
  investimentos bloqueados (RF14/RF15), desfazendo aportes de testes.

Contas reais não passam por aqui.
"""

from datetime import date, timedelta

from models import Meta, Usuario

EMAIL_DEMO = "demo@investai.com"
SENHA_DEMO = "Demo@1234"

# Reserva pela metade do caminho: mantém as sugestões de investimento
# bloqueadas, que é a regra central do app (RF14/RF15).
RESERVA_DEMO = {
    "titulo": "Reserva de emergência",
    "valor_alvo": 10500.00,
    "valor_atual": 6800.00,
    "dias_ate_prazo": 240,
}


def iniciar_sessao_demo(usuario_id):
    """Chamada a cada início de sessão. Na conta demo, devolve o
    questionário e a reserva ao estado original; em qualquer outra conta,
    não faz nada. Devolve True se era a conta demo."""
    usuario = Usuario.buscar_por_id(usuario_id)
    if usuario is None or usuario.email != EMAIL_DEMO:
        return False

    _reabrir_questionario(usuario)
    restaurar_reserva_demo(usuario_id)
    return True


def _reabrir_questionario(usuario):
    """Pendente de novo, com o perfil padrão (conservador), igual a quem
    pulou o questionário no cadastro."""
    usuario.perfil_risco = "conservador"
    usuario.suitability_respondido = False
    usuario.suitability_pontuacao = None
    usuario.suitability_versao = None
    usuario.suitability_em = None
    usuario.salvar()


def restaurar_reserva_demo(usuario_id):
    """Põe a meta da reserva de emergência no valor original. Se ela foi
    apagada durante a apresentação, cria de novo."""
    reserva = Meta.query.filter_by(usuario_id=usuario_id, tipo="reserva_emergencia").first()
    prazo = (date.today() + timedelta(days=RESERVA_DEMO["dias_ate_prazo"])).isoformat()
    if reserva is None:
        Meta(
            titulo=RESERVA_DEMO["titulo"],
            valor_alvo=RESERVA_DEMO["valor_alvo"],
            valor_atual=RESERVA_DEMO["valor_atual"],
            prazo=prazo,
            tipo="reserva_emergencia",
            usuario_id=usuario_id,
        ).salvar()
        return
    reserva.atualizar(
        titulo=RESERVA_DEMO["titulo"],
        valor_alvo=RESERVA_DEMO["valor_alvo"],
        valor_atual=RESERVA_DEMO["valor_atual"],
        prazo=prazo,
    )
