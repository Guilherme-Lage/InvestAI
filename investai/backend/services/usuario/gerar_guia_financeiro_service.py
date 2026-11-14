from models import Usuario
from services.movimentacao.calcular_saldo_service import CalcularSaldoService
from services.meta.calcular_status_reserva_emergencia_service import (
    CalcularStatusReservaEmergenciaService,
    MULTIPLICADOR_RESERVA_EMERGENCIA,
)
from services.mercado.buscar_taxas_mercado_service import BuscarTaxasMercadoService
from services.movimentacao.analisar_composicao_gastos_service import (
    AnalisarComposicaoGastosService,
)

ROTULOS_CATEGORIA = {
    "alimentacao": "alimentação",
    "lazer": "lazer",
    "contas_fixas": "contas fixas",
    "transporte": "transporte",
    "saude": "saúde",
    "educacao": "educação",
    "outros": "outros",
}

# RF16 - sugestões de investimento adaptadas ao perfil de investidor do
# usuário (RF18). São educativas e fixas (sem recomendar um banco ou
# corretora específica), mas o rendimento das de renda fixa é enriquecido
# com a taxa oficial (Selic/CDI/IPCA) do Banco Central quando disponível
# (ver "indexador" e BuscarTaxasMercadoService).
#
# A primeira de cada perfil é a de entrada, mostrada em destaque. Cada uma
# traz o motivo em linguagem comum, o nível de risco e o prazo para o qual
# faz sentido: o mesmo produto pode ser ótimo para 5 anos e ruim para 6 meses.
SUGESTOES_POR_PERFIL = {
    "conservador": [
        {"nome": "Tesouro Selic", "tipo": "Renda fixa", "risco": "baixo", "prazo": "curto",
         "liquidez": "diaria", "indexador": "selic",
         "motivo": "Seu perfil é conservador, e este é o investimento mais "
                   "previsível do país: o valor não cai, e você pode sacar em "
                   "qualquer dia útil sem susto.",
         "descricao_base": "Título do governo que acompanha a Selic. Bom para objetivos de curto prazo."},
        {"nome": "CDB com liquidez diária (100% do CDI)", "tipo": "Renda fixa", "risco": "baixo",
         "prazo": "curto", "liquidez": "diaria", "indexador": "cdi",
         "motivo": "Rende parecido com o Tesouro Selic e tem a proteção do FGC "
                   "até R$ 250 mil por banco. Muitos bancos digitais oferecem.",
         "descricao_base": "Empréstimo ao banco com resgate a qualquer momento."},
        {"nome": "LCI e LCA", "tipo": "Renda fixa", "risco": "baixo", "prazo": "medio",
         "liquidez": "carencia", "indexador": "cdi",
         "motivo": "São isentas de Imposto de Renda, então mesmo pagando um "
                   "pouco menos que um CDB podem render mais no fim. Também têm FGC.",
         "descricao_base": "Letras de crédito imobiliário e do agronegócio. Costumam ter carência."},
        {"nome": "Tesouro Prefixado (curto)", "tipo": "Renda fixa", "risco": "baixo", "prazo": "medio",
         "liquidez": "no vencimento", "indexador": None,
         "motivo": "Você sabe hoje exatamente quanto vai receber no vencimento. "
                   "Bom para um objetivo com data marcada, como uma viagem.",
         "descricao_base": "Taxa fixa combinada na compra. Leve até o vencimento para garantir a taxa."},
        {"nome": "Tesouro IPCA+ (curto)", "tipo": "Renda fixa", "risco": "baixo", "prazo": "medio",
         "liquidez": "no vencimento", "indexador": "ipca",
         "motivo": "Protege seu dinheiro da inflação. Escolhendo um vencimento "
                   "de poucos anos, as oscilações no caminho são pequenas.",
         "descricao_base": "Paga a inflação mais um juro fixo."},
        {"nome": "Fundo de renda fixa simples (DI)", "tipo": "Fundo", "risco": "baixo", "prazo": "curto",
         "liquidez": "diaria", "indexador": "cdi",
         "motivo": "Um gestor cuida da aplicação por você. Prefira os de taxa de "
                   "administração baixa (até 0,5% ao ano), senão ela come o rendimento.",
         "descricao_base": "Fundo que investe em títulos atrelados ao CDI."},
    ],
    "moderado": [
        {"nome": "Tesouro IPCA+", "tipo": "Renda fixa", "risco": "baixo", "prazo": "longo",
         "liquidez": "no vencimento", "indexador": "ipca",
         "motivo": "Garante que seu dinheiro cresça acima da inflação: daqui a "
                   "alguns anos ele ainda vai comprar mais do que compra hoje. "
                   "Em troca, o ideal é deixar até o vencimento.",
         "descricao_base": "Protege da inflação. Bom para metas de médio e longo prazo."},
        {"nome": "CDB, LCI e LCA de bancos médios", "tipo": "Renda fixa", "risco": "baixo",
         "prazo": "medio", "liquidez": "carencia", "indexador": "cdi",
         "motivo": "Pagam mais que os grandes bancos (110% a 120% do CDI) e "
                   "seguem com a proteção do FGC até R$ 250 mil por banco.",
         "descricao_base": "Rendimento acima da média mantendo baixo risco."},
        {"nome": "Debêntures incentivadas", "tipo": "Renda fixa", "risco": "medio", "prazo": "longo",
         "liquidez": "no vencimento", "indexador": "ipca",
         "motivo": "Você empresta para empresas de infraestrutura e não paga "
                   "Imposto de Renda. Rendem mais que títulos do governo, mas "
                   "não têm FGC: escolha empresas sólidas.",
         "descricao_base": "Títulos de dívida de empresas, geralmente atrelados à inflação."},
        {"nome": "Fundos multimercado", "tipo": "Fundo", "risco": "medio", "prazo": "medio",
         "liquidez": "carencia", "indexador": None,
         "motivo": "O gestor mistura renda fixa, ações, câmbio e juros. Um "
                   "jeito de diversificar sem precisar escolher cada ativo.",
         "descricao_base": "Diversificação entre várias classes. Compare a taxa de administração."},
        {"nome": "Fundos imobiliários (FIIs)", "tipo": "Renda variável", "risco": "medio",
         "prazo": "longo", "liquidez": "diaria", "indexador": None,
         "motivo": "Pagam aluguéis todo mês, isentos de IR para pessoa física. "
                   "As cotas oscilam na bolsa, então pense em anos, não meses.",
         "descricao_base": "Cotas de imóveis como shoppings, galpões e escritórios."},
        {"nome": "ETF de índice (ex.: Ibovespa)", "tipo": "Renda variável", "risco": "alto",
         "prazo": "longo", "liquidez": "diaria", "indexador": None,
         "motivo": "Uma parcela pequena em bolsa ajuda o patrimônio a crescer "
                   "no longo prazo. O ETF compra várias empresas de uma vez.",
         "descricao_base": "Um único ativo que replica um índice da bolsa."},
    ],
    "arrojado": [
        {"nome": "ETF de índice (ex.: Ibovespa)", "tipo": "Renda variável", "risco": "alto",
         "prazo": "longo", "liquidez": "diaria", "indexador": None,
         "motivo": "Você aceita oscilação em troca de retorno maior. Com um só "
                   "ativo você fica dono de um pedaço das maiores empresas do "
                   "país, sem precisar escolher uma por uma.",
         "descricao_base": "Diversificação em bolsa com custo baixo."},
        {"nome": "Ações de empresas sólidas", "tipo": "Renda variável", "risco": "alto",
         "prazo": "longo", "liquidez": "diaria", "indexador": None,
         "motivo": "Para quem quer escolher as empresas. Diversifique em setores "
                   "diferentes e não coloque muito dinheiro em uma só.",
         "descricao_base": "Participação direta em empresas listadas na bolsa."},
        {"nome": "ETF internacional (ex.: S&P 500)", "tipo": "Renda variável", "risco": "alto",
         "prazo": "longo", "liquidez": "diaria", "indexador": None,
         "motivo": "Coloca parte do seu dinheiro em empresas de fora e em dólar, "
                   "o que protege se a economia brasileira for mal.",
         "descricao_base": "Exposição a outros países sem abrir conta no exterior."},
        {"nome": "Fundos imobiliários (FIIs)", "tipo": "Renda variável", "risco": "medio",
         "prazo": "longo", "liquidez": "diaria", "indexador": None,
         "motivo": "Geram renda mensal com aluguéis, isenta de IR, e equilibram "
                   "uma carteira com muitas ações.",
         "descricao_base": "Cotas de imóveis negociadas na bolsa."},
        {"nome": "Fundos de ações", "tipo": "Fundo", "risco": "alto", "prazo": "longo",
         "liquidez": "carencia", "indexador": None,
         "motivo": "Um gestor profissional escolhe as ações por você. Confira o "
                   "histórico de vários anos e a taxa de performance.",
         "descricao_base": "Maior potencial de retorno no longo prazo, com mais volatilidade."},
        {"nome": "Fundos multimercado agressivos", "tipo": "Fundo", "risco": "alto",
         "prazo": "medio", "liquidez": "carencia", "indexador": None,
         "motivo": "Apostam em juros, câmbio e bolsa ao mesmo tempo, buscando "
                   "ganhar em cenários diferentes.",
         "descricao_base": "Maior exposição a risco em busca de retorno superior."},
        {"nome": "Tesouro IPCA+ (longo)", "tipo": "Renda fixa", "risco": "medio", "prazo": "longo",
         "liquidez": "no vencimento", "indexador": "ipca",
         "motivo": "Mesmo arrojado, ter uma base que vence a inflação dá "
                   "estabilidade. Os vencimentos longos pagam as maiores taxas.",
         "descricao_base": "Protege da inflação por muitos anos; oscila se vendido antes."},
    ],
}

# Como dividir o dinheiro investido (fora a reserva de emergência) entre as
# classes, por perfil. São referências educativas, não uma regra: o ponto é
# mostrar que nenhum perfil coloca tudo num lugar só.
CARTEIRA_POR_PERFIL = {
    "conservador": [
        {"classe": "Renda fixa pós-fixada (Selic/CDI)", "percentual": 60},
        {"classe": "Renda fixa atrelada à inflação", "percentual": 25},
        {"classe": "Renda fixa prefixada", "percentual": 15},
    ],
    "moderado": [
        {"classe": "Renda fixa", "percentual": 60},
        {"classe": "Fundos imobiliários e multimercado", "percentual": 25},
        {"classe": "Ações e ETFs", "percentual": 15},
    ],
    "arrojado": [
        {"classe": "Renda fixa", "percentual": 30},
        {"classe": "Fundos imobiliários e multimercado", "percentual": 20},
        {"classe": "Ações e ETFs no Brasil", "percentual": 35},
        {"classe": "Investimentos no exterior", "percentual": 15},
    ],
}

def _reais(valor):
    """Valor em reais no formato brasileiro: R$ 3.887,80."""
    numero = f"{abs(valor):,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
    return f"{'-' if valor < 0 else ''}R$ {numero}"


RESUMO_INDEXADOR = {
    "selic": "Rende hoje ~{taxa}% ao ano (Taxa Selic).",
    "cdi": "Rende hoje ~{taxa}% ao ano (100% do CDI).",
    "ipca": "Rende IPCA + prêmio; a inflação (IPCA) acumulada em 12 meses está em ~{taxa}%.",
}


class GerarGuiaFinanceiroService:
    """RF16 - guia financeiro passo a passo, adaptado à situação atual
    do usuário: saldo negativo, construção de reserva, ou pronto para
    investir. Também aplica RF14/RF15 (reserva antes de investimento)."""

    def executar(self, usuario_id):
        usuario = Usuario.buscar_por_id(usuario_id)
        if not usuario:
            return None

        saldo = CalcularSaldoService().executar(usuario_id)
        reserva = CalcularStatusReservaEmergenciaService().executar(usuario_id)
        composicao = None
        faltante = 0.0

        if saldo < 0:
            passo = "saldo_negativo"
            titulo = "Organize suas contas primeiro"
            mensagem = (
                "Seus gastos estão maiores que suas receitas. Antes de pensar em "
                "reserva ou investimentos, ajuste o orçamento: registre todas as "
                "despesas por categoria e corte o que for possível."
            )
        elif not reserva["sugestoes_investimento_liberadas"]:
            passo = "construir_reserva"
            titulo = "Construa sua reserva de emergência"
            faltante = max(reserva["valor_ideal_reserva"] - reserva["valor_guardado"], 0.0)
            composicao = AnalisarComposicaoGastosService().executar(usuario_id)
            mensagem = self._mensagem_reserva(reserva, faltante, composicao)
        else:
            passo = "pronto_para_investir"
            titulo = "Você está pronto para investir"
            mensagem = (
                "Sua reserva de emergência está completa. Veja sugestões de "
                "investimento de acordo com o seu perfil."
            )

        resultado = {
            "passo": passo,
            "titulo": titulo,
            "mensagem": mensagem,
            "saldo": saldo,
            "reserva": reserva,
        }

        if passo == "construir_reserva":
            resultado["composicao_gastos"] = composicao
            resultado["meses_estimados"] = self._meses_para_juntar(faltante, composicao)

        if passo == "pronto_para_investir":
            perfil = usuario.perfil_risco if usuario.perfil_risco in SUGESTOES_POR_PERFIL else "conservador"
            resultado["perfil_risco"] = perfil
            resultado["sugestoes_investimento"] = self._montar_sugestoes(perfil)
            resultado["carteira_sugerida"] = self._montar_carteira(perfil)

        return resultado

    def _meses_para_juntar(self, faltante, composicao):
        """Quantos meses faltam no ritmo atual. None quando não sobra nada -
        aí não existe previsão honesta a dar."""
        if not composicao or composicao["capacidade_mensal"] <= 0:
            return None
        return max(1, round(faltante / composicao["capacidade_mensal"]))

    def _mensagem_reserva(self, reserva, faltante, composicao):
        """A meta continua sendo 3x a despesa (RF14/RF15), mas o conselho
        muda conforme o motivo de a sobra ser pequena: quem tem gasto
        flexível consegue cortar, quem só tem gasto fixo não - e nesse caso
        insistir em corte seria inútil."""
        base = (
            f"Antes de investir, junte uma reserva equivalente a "
            f"{MULTIPLICADOR_RESERVA_EMERGENCIA}x sua despesa média mensal "
            f"({_reais(reserva['valor_ideal_reserva'])}). "
            f"Faltam {_reais(faltante)}."
        )

        if not composicao:
            return base

        capacidade = composicao["capacidade_mensal"]
        foco = composicao["foco"]

        if foco == "reduzir_flexivel":
            maior = composicao["maior_gasto_flexivel"]
            # Só aponta a categoria quando existe histórico real; pela
            # estimativa do cadastro sabemos o quanto é flexível, mas não onde.
            if maior:
                onde = (
                    f" Seu maior gasto ajustável é "
                    f"{ROTULOS_CATEGORIA.get(maior['categoria'], maior['categoria'])} "
                    f"({_reais(maior['total'])} por mês) - reduzir aí é o que mais acelera "
                    f"sua reserva."
                )
            else:
                onde = (
                    f" Mas {_reais(composicao['despesa_flexivel'])} dos seus gastos não "
                    f"são fixos: é aí que dá para ganhar tempo. Registre suas despesas "
                    f"por categoria que eu te mostro onde cortar."
                )
            if capacidade < 0:
                # "Sobram R$ -562,60" não faz sentido para ninguém.
                situacao = (
                    f" Hoje seus gastos passam da sua renda em {_reais(-capacidade)} "
                    f"por mês, então ainda não sobra nada para guardar."
                )
            elif capacidade == 0:
                situacao = " Hoje sua renda fica toda nos gastos do mês, sem sobra para guardar."
            else:
                situacao = (
                    f" Hoje sobram {_reais(capacidade)} por mês "
                    f"({composicao['percentual_capacidade']:.0f}% da sua renda), o que é "
                    f"pouco para essa meta."
                )
            return f"{base}{situacao}{onde}"

        if foco == "aumentar_renda":
            return (
                f"{base} Das suas despesas, {_reais(composicao['despesa_obrigatoria'])} "
                f"são fixas (moradia, transporte, saúde, educação) - ou seja, quase "
                f"não há o que cortar, e tentar cortar não vai resolver. Sua reserva "
                f"vai ser construída devagar mesmo, e tudo bem: guarde o que der, no "
                f"seu ritmo. O que realmente muda esse cenário é aumentar a renda."
            )

        meses = self._meses_para_juntar(faltante, composicao)
        if meses:
            return (
                f"{base} Guardando os {_reais(capacidade)} que sobram por mês, você "
                f"chega lá em cerca de {meses} "
                f"{'mês' if meses == 1 else 'meses'}."
            )
        return base

    def _montar_sugestoes(self, perfil_risco):
        base = SUGESTOES_POR_PERFIL.get(perfil_risco, SUGESTOES_POR_PERFIL["conservador"])

        try:
            taxas = BuscarTaxasMercadoService().executar()
        except Exception:
            # Sem taxas oficiais no momento (API do Banco Central fora do ar):
            # mantém as sugestões com a descrição educativa, sem o número real.
            taxas = None

        sugestoes = []
        for item in base:
            indexador = item.get("indexador")
            descricao = item["descricao_base"]
            if indexador and taxas and taxas.get(indexador) is not None:
                descricao = f"{descricao} {RESUMO_INDEXADOR[indexador].format(taxa=f"{taxas[indexador]:.2f}".replace(".", ","))}"
            sugestoes.append({
                "nome": item["nome"],
                "tipo": item["tipo"],
                "risco": item["risco"],
                "prazo": item["prazo"],
                "liquidez": item["liquidez"],
                "descricao": descricao,
                "motivo": item["motivo"],
            })
        return sugestoes

    def _montar_carteira(self, perfil_risco):
        return [dict(c) for c in CARTEIRA_POR_PERFIL.get(
            perfil_risco, CARTEIRA_POR_PERFIL["conservador"])]
