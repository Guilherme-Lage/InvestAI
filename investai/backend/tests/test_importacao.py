import base64
import unittest
from datetime import date

from tests.base import TesteComBanco
from criar_conta_demo import criar_conta_demo
from gerar_extrato_exemplo import gerar_extrato_exemplo
from models import Movimentacao, TransacaoImportada
from services.auth_service import AuthService
from services.importacao.analisar_extrato_service import AnalisarExtratoService
from services.importacao.confirmar_importacao_service import ConfirmarImportacaoService
from services.importacao.ler_extrato_ofx_service import LerExtratoOfxService
from services.importacao.limpar_descricao import limpar_descricao
from services.importacao.sugerir_categoria import (
    parece_movimentacao_interna,
    sugerir_categoria,
)

HOJE = date(2026, 4, 15)  # o extrato de exemplo cobre o mês anterior: março


def _ofx(*transacoes, banco="0999", conta="12345-6", saldo=None):
    """Monta um extrato mínimo. Cada transação é (data, valor, memo) ou
    (data, valor, memo, fitid). `saldo` = (valor, data) gera o bloco
    LEDGERBAL, no formato com marcação fechada usado pelo Inter."""
    blocos = []
    for indice, transacao in enumerate(transacoes):
        data, valor, memo = transacao[:3]
        fitid = transacao[3] if len(transacao) > 3 else f"id{indice}"
        blocos.append(
            f"<STMTTRN>\n<TRNTYPE>OTHER\n<DTPOSTED>{data}\n<TRNAMT>{valor}\n"
            + (f"<FITID>{fitid}\n" if fitid else "")
            + f"<MEMO>{memo}\n</STMTTRN>\n"
        )
    return (
        "OFXHEADER:100\n\n<OFX>\n<BANKACCTFROM>\n"
        f"<BANKID>{banco}\n<ACCTID>{conta}\n</BANKACCTFROM>\n"
        "<BANKTRANLIST>\n" + "".join(blocos) + "</BANKTRANLIST>\n"
        + (f"<LEDGERBAL>\n<BALAMT>{saldo[0]}</BALAMT>\n<DTASOF>{saldo[1]}</DTASOF>\n</LEDGERBAL>\n"
           if saldo else "")
        + "</OFX>\n"
    )


class TesteLeituraDoOfx(unittest.TestCase):
    """Só a leitura do arquivo, sem banco de dados."""

    def setUp(self):
        self.ler = LerExtratoOfxService()

    def test_le_as_transacoes_do_extrato_de_exemplo(self):
        extrato = self.ler.executar(gerar_extrato_exemplo(HOJE))

        self.assertEqual(extrato["banco"], "0999")
        self.assertEqual(extrato["conta"], "12345-6")
        self.assertEqual(len(extrato["transacoes"]), 13)
        self.assertEqual(extrato["transacoes"][0], {
            "identificador": "0999:12345-6:202603030001",
            "data": "2026-03-03",
            "descricao": "COMPRA CARTAO - SUPERMERCADO BH",
            "tipo": "gasto",
            "valor": 212.47,
        })

    def test_valor_negativo_e_gasto_e_positivo_e_renda(self):
        extrato = self.ler.executar(_ofx(
            ("20260305", "-45.90", "MERCADO"), ("20260306", "1000.00", "SALARIO"),
        ))

        self.assertEqual(
            [(t["tipo"], t["valor"]) for t in extrato["transacoes"]],
            [("gasto", 45.9), ("renda", 1000.0)],
        )

    def test_aceita_virgula_decimal(self):
        extrato = self.ler.executar(_ofx(("20260305", "-1234,56", "COMPRA")))

        self.assertEqual(extrato["transacoes"][0]["valor"], 1234.56)

    def test_le_arquivo_em_windows_1252_e_em_utf8(self):
        texto = _ofx(("20260305", "-10.00", "PADARIA PÃO QUENTE"))

        for codificacao in ("cp1252", "utf-8"):
            with self.subTest(codificacao=codificacao):
                extrato = self.ler.executar(texto.encode(codificacao))
                self.assertEqual(extrato["transacoes"][0]["descricao"], "PADARIA PÃO QUENTE")

    def test_le_ofx_novo_com_campos_fechados(self):
        xml = (
            '<?xml version="1.0" encoding="UTF-8"?><OFX><BANKID>1</BANKID><ACCTID>2</ACCTID>'
            "<STMTTRN><DTPOSTED>20260305</DTPOSTED><TRNAMT>-9.90</TRNAMT>"
            "<FITID>abc</FITID><MEMO>LOJA &amp; CIA</MEMO></STMTTRN></OFX>"
        )

        transacao = self.ler.executar(xml)["transacoes"][0]

        self.assertEqual(transacao["descricao"], "LOJA & CIA")
        self.assertEqual(transacao["identificador"], "1:2:abc")

    def test_sem_codigo_do_banco_duas_compras_iguais_continuam_distintas(self):
        extrato = self.ler.executar(_ofx(
            ("20260305", "-5.00", "CAFE", None), ("20260305", "-5.00", "CAFE", None),
        ))

        identificadores = [t["identificador"] for t in extrato["transacoes"]]
        self.assertEqual(len(set(identificadores)), 2)
        # E o identificador é o mesmo a cada leitura, senão reimportar duplicaria.
        self.assertEqual(
            identificadores,
            [t["identificador"] for t in self.ler.executar(_ofx(
                ("20260305", "-5.00", "CAFE", None), ("20260305", "-5.00", "CAFE", None),
            ))["transacoes"]],
        )

    def test_pula_linha_sem_data_ou_com_valor_zero(self):
        extrato = self.ler.executar(_ofx(
            ("data-ruim", "-5.00", "A"), ("20260305", "0.00", "B"), ("20260306", "-7.00", "C"),
        ))

        self.assertEqual([t["descricao"] for t in extrato["transacoes"]], ["C"])

    def test_recusa_arquivo_que_nao_e_ofx_ou_esta_vazio(self):
        with self.assertRaises(ValueError):
            self.ler.executar(b"data;descricao;valor\n01/03/2026;Mercado;-10")
        with self.assertRaises(ValueError):
            self.ler.executar("<OFX></OFX>")


class TesteLimpezaDaDescricao(unittest.TestCase):
    """Formatos vistos em extrato real do Inter (com nomes trocados)."""

    def test_tira_os_codigos_internos_do_banco(self):
        casos = {
            'Pix enviado: "Cp :14796606-RD SAUDE"': "Pix enviado: RD SAUDE",
            'Pix enviado: "00019 16897471 FULANO DE TAL"': "Pix enviado: FULANO DE TAL",
            'Pix recebido: "00001 12 34 5 6 BELTRANA SILVA"': "Pix recebido: BELTRANA SILVA",
            'Compra no debito: "No estabelecimento 99* POP 26Set 10h15min"':
                "Compra no debito: 99* POP",
            'Estorno: "Estorno no estabelecimento Uber UBER *TRIP HELP.U"':
                "Estorno: Uber UBER *TRIP HELP.U",
        }
        for bruta, limpa in casos.items():
            with self.subTest(bruta=bruta):
                self.assertEqual(limpar_descricao(bruta), limpa)

    def test_nao_mexe_no_que_ja_esta_legivel(self):
        for descricao in (
            "COMPRA CARTAO - SUPERMERCADO BH",
            "PIX ENVIADO - JOAO PEDRO SILVA",
            "DEB AUT - INTERNET FIBRA",
            "NETFLIX.COM",
        ):
            with self.subTest(descricao=descricao):
                self.assertEqual(limpar_descricao(descricao), descricao)

    def test_a_leitura_do_extrato_ja_entrega_a_descricao_limpa(self):
        extrato = LerExtratoOfxService().executar(
            _ofx(("20260305", "-41.79", 'Pix enviado: "Cp :14796606-RD SAUDE"'))
        )

        self.assertEqual(extrato["transacoes"][0]["descricao"], "Pix enviado: RD SAUDE")


class TesteSaldoDoBanco(unittest.TestCase):
    def setUp(self):
        self.ler = LerExtratoOfxService()

    def test_le_o_saldo_final_informado_pelo_banco(self):
        # Trecho real do fim de um extrato do Inter.
        extrato = self.ler.executar(_ofx(("20261001", "-10.00", "A"), saldo=("389.58", "20261013")))

        self.assertEqual(extrato["saldo_final"], {"valor": 389.58, "data": "2026-10-13"})

    def test_le_o_saldo_no_formato_antigo_sem_fechamento(self):
        texto = _ofx(("20261001", "-10.00", "A")).replace(
            "</OFX>", "<LEDGERBAL>\n<BALAMT>-12,50\n<DTASOF>20261013120000\n</LEDGERBAL>\n</OFX>")

        self.assertEqual(self.ler.executar(texto)["saldo_final"], {"valor": -12.5, "data": "2026-10-13"})

    def test_sem_saldo_no_arquivo_devolve_none(self):
        self.assertIsNone(self.ler.executar(_ofx(("20261001", "-10.00", "A")))["saldo_final"])


class TesteSugestaoDeCategoria(unittest.TestCase):
    def test_reconhece_palavras_comuns_do_extrato(self):
        casos = {
            "COMPRA CARTAO - SUPERMERCADO BH": "alimentacao",
            "IFOOD *RESTAURANTE": "alimentacao",
            "UBER *TRIP": "transporte",
            "Drogaria Araújo": "saude",
            "NETFLIX.COM": "lazer",
            "DEB AUT - INTERNET FIBRA": "contas_fixas",
            "PIX ENVIADO - JOAO PEDRO SILVA": "outros",
        }
        for descricao, esperada in casos.items():
            with self.subTest(descricao=descricao):
                self.assertEqual(sugerir_categoria(descricao, "gasto"), esperada)

    def test_reconhece_o_jeito_do_inter_de_escrever(self):
        casos = {
            "Compra no debito: 99* POP": "transporte",
            "Compra no debito: Uber UBER *TRIP HELP.U": "transporte",
            "Pix enviado: RD SAUDE": "saude",
            "Compra de Giftcard: abc/Sony PlayStation": "lazer",
            "Pix enviado: AUTO ESCOLA ESPERANCA": "educacao",
        }
        for descricao, esperada in casos.items():
            with self.subTest(descricao=descricao):
                self.assertEqual(sugerir_categoria(descricao, "gasto"), esperada)

    def test_palavra_curta_so_vale_inteira(self):
        self.assertEqual(sugerir_categoria("BAR DO ZE", "gasto"), "lazer")
        self.assertEqual(sugerir_categoria("BARBEARIA DO ZE", "gasto"), "outros")
        self.assertEqual(sugerir_categoria("ULTIMO PAGAMENTO", "gasto"), "outros")

    def test_renda_so_distingue_salario(self):
        self.assertEqual(sugerir_categoria("PAGAMENTO DE SALARIO", "renda"), "salario")
        self.assertEqual(sugerir_categoria("PIX RECEBIDO - MARIA", "renda"), "outros")
        # "MERCADO" numa renda não vira alimentação.
        self.assertEqual(sugerir_categoria("ESTORNO MERCADO", "renda"), "outros")

    def test_reconhece_dinheiro_mudando_de_lugar(self):
        self.assertTrue(parece_movimentacao_interna("APLICACAO RDB"))
        self.assertTrue(parece_movimentacao_interna("Pagamento de fatura"))
        self.assertFalse(parece_movimentacao_interna("SUPERMERCADO BH"))


class TesteImportacao(TesteComBanco):
    """Análise e confirmação, com banco de dados."""

    def setUp(self):
        super().setUp()
        self.usuario = self.criar_usuario()
        self.analisar = AnalisarExtratoService()
        self.confirmar = ConfirmarImportacaoService()

    def _situacoes(self, conteudo, usuario=None):
        analise = self.analisar.executar((usuario or self.usuario).id, conteudo)
        return {t["descricao"]: t["situacao"] for t in analise["transacoes"]}

    def _novas(self, conteudo):
        analise = self.analisar.executar(self.usuario.id, conteudo)
        return [t for t in analise["transacoes"] if t["situacao"] == "nova"]

    def test_analisar_nao_grava_nada(self):
        self.analisar.executar(self.usuario.id, gerar_extrato_exemplo(HOJE))

        self.assertEqual(Movimentacao.query.count(), 0)
        self.assertEqual(TransacaoImportada.query.count(), 0)

    def test_analise_traz_periodo_e_categoria_sugerida(self):
        analise = self.analisar.executar(self.usuario.id, gerar_extrato_exemplo(HOJE))

        self.assertEqual(analise["data_inicio"], "2026-03-03")
        self.assertEqual(analise["data_fim"], "2026-03-27")
        categorias = {t["descricao"]: t["categoria"] for t in analise["transacoes"]}
        self.assertEqual(categorias["UBER *TRIP"], "transporte")
        self.assertEqual(categorias["PAGAMENTO DE SALARIO - EMPRESA LTDA"], "salario")

    def test_confirmar_cria_movimentacoes_com_a_categoria_escolhida(self):
        novas = self._novas(_ofx(
            ("20260305", "-45.90", "MERCADO BH"), ("20260306", "1000.00", "PIX RECEBIDO"),
        ))
        novas[0]["categoria"] = "lazer"  # o usuário trocou na revisão

        resultado = self.confirmar.executar(self.usuario.id, novas)

        self.assertEqual(resultado, {"importadas": 2, "ja_existiam": 0})
        gasto = Movimentacao.query.filter_by(tipo="gasto").one()
        self.assertEqual(
            (gasto.descricao, gasto.valor, gasto.data, gasto.categoria, gasto.usuario_id),
            ("MERCADO BH", 45.9, "2026-03-05", "lazer", self.usuario.id),
        )
        self.assertEqual(Movimentacao.query.filter_by(tipo="renda").one().valor, 1000.0)

    def test_importar_o_mesmo_extrato_de_novo_nao_duplica(self):
        extrato = gerar_extrato_exemplo(HOJE)
        self.confirmar.executar(self.usuario.id, self._novas(extrato))
        total = Movimentacao.query.count()

        situacoes = self._situacoes(extrato)
        self.assertEqual(situacoes["UBER *TRIP"], "ja_importada")
        self.assertEqual(self._novas(extrato), [])

        # Mesmo que o app mande tudo de novo, nada entra.
        analise = self.analisar.executar(self.usuario.id, extrato)
        resultado = self.confirmar.executar(self.usuario.id, analise["transacoes"])
        self.assertEqual(resultado["importadas"], 1)  # só a aplicação, que não tinha entrado
        self.assertEqual(Movimentacao.query.count(), total + 1)

    def test_extrato_com_periodo_sobreposto_so_traz_o_que_falta(self):
        primeira = _ofx(("20260301", "-10.00", "A", "x1"), ("20260310", "-20.00", "B", "x2"))
        segunda = _ofx(("20260310", "-20.00", "B", "x2"), ("20260320", "-30.00", "C", "x3"))
        self.confirmar.executar(self.usuario.id, self._novas(primeira))

        self.assertEqual(self._situacoes(segunda), {"B": "ja_importada", "C": "nova"})

    def test_mesmo_codigo_em_outra_conta_e_outra_transacao(self):
        extrato = _ofx(("20260301", "-10.00", "A", "x1"))
        self.confirmar.executar(self.usuario.id, self._novas(extrato))

        outra_conta = _ofx(("20260301", "-99.00", "Z", "x1"), conta="99999-9")

        self.assertEqual(self._situacoes(outra_conta), {"Z": "nova"})

    def test_o_que_um_usuario_importou_nao_afeta_outro(self):
        extrato = _ofx(("20260301", "-10.00", "A", "x1"))
        self.confirmar.executar(self.usuario.id, self._novas(extrato))

        self.assertEqual(self._situacoes(extrato, usuario=self.criar_usuario()), {"A": "nova"})

    def test_aponta_o_que_ja_estava_registrado_a_mao(self):
        Movimentacao(
            descricao="Aluguel", tipo="gasto", valor=1500.0, data="2026-03-10",
            categoria="contas_fixas", usuario_id=self.usuario.id,
        ).salvar()

        analise = self.analisar.executar(self.usuario.id, _ofx(
            ("20260311", "-1500.00", "PIX ENVIADO - IMOBILIARIA"),
            ("20260311", "-80.00", "POSTO"),
        ))

        aluguel, posto = analise["transacoes"]
        self.assertEqual(aluguel["situacao"], "possivel_duplicata")
        self.assertIn("Aluguel", aluguel["aviso"])
        self.assertIn("10/03", aluguel["aviso"])
        self.assertEqual(posto["situacao"], "nova")

    def test_valor_igual_em_data_distante_ou_de_tipo_diferente_nao_e_duplicata(self):
        for data, tipo in (("2026-03-01", "gasto"), ("2026-03-11", "renda")):
            Movimentacao(
                descricao="Outra coisa", tipo=tipo, valor=1500.0, data=data,
                categoria="outros", usuario_id=self.usuario.id,
            ).salvar()

        situacoes = self._situacoes(_ofx(("20260311", "-1500.00", "PIX ENVIADO")))

        self.assertEqual(situacoes, {"PIX ENVIADO": "nova"})

    def test_duas_compras_iguais_no_extrato_e_uma_so_registrada(self):
        Movimentacao(
            descricao="Café", tipo="gasto", valor=5.0, data="2026-03-05",
            categoria="alimentacao", usuario_id=self.usuario.id,
        ).salvar()

        analise = self.analisar.executar(self.usuario.id, _ofx(
            ("20260305", "-5.00", "CAFE 1"), ("20260305", "-5.00", "CAFE 2"),
        ))

        self.assertEqual(
            sorted(t["situacao"] for t in analise["transacoes"]),
            ["nova", "possivel_duplicata"],
        )

    def test_aplicacao_e_fatura_vem_marcadas_como_movimentacao_interna(self):
        situacoes = self._situacoes(_ofx(
            ("20260312", "-800.00", "APLICACAO RDB"), ("20260313", "-900.00", "PAGTO FATURA CARTAO"),
        ))

        self.assertEqual(set(situacoes.values()), {"movimentacao_interna"})

    def test_repete_a_categoria_que_o_usuario_ja_deu_ao_mesmo_nome(self):
        """Pix para uma pessoa não tem como ser adivinhado; mas, depois que
        o usuário diz uma vez que é alimentação, o app não pergunta de novo."""
        primeira = self._novas(_ofx(("20260305", "-30.00", 'Pix enviado: "Cp :111-FULANO DE TAL"')))
        self.assertEqual(primeira[0]["categoria"], "outros")
        primeira[0]["categoria"] = "alimentacao"
        self.confirmar.executar(self.usuario.id, primeira)

        seguinte = self.analisar.executar(self.usuario.id, _ofx(
            # Mesmo nome, outro código de comprovante e outra capitalização.
            ("20260320", "-45.00", 'Pix enviado: "Cp :222-Fulano de Tal"', "novo1"),
            ("20260321", "100.00", 'Pix recebido: "Cp :333-FULANO DE TAL"', "novo2"),
            ("20260322", "-10.00", 'Pix enviado: "Cp :444-OUTRA PESSOA"', "novo3"),
        ))

        categorias = [t["categoria"] for t in seguinte["transacoes"]]
        # O recebido do mesmo nome não herda: é outro tipo de transação.
        self.assertEqual(categorias, ["alimentacao", "outros", "outros"])

    def test_aprende_tambem_com_descricao_gravada_antes_da_limpeza(self):
        Movimentacao(
            descricao='Pix enviado: "Cp :111-FULANO DE TAL"', tipo="gasto", valor=30.0,
            data="2026-01-05", categoria="lazer", usuario_id=self.usuario.id,
        ).salvar()

        novas = self._novas(_ofx(("20260305", "-45.00", 'Pix enviado: "Cp :999-FULANO DE TAL"')))

        self.assertEqual(novas[0]["categoria"], "lazer")

    def test_escolha_mais_recente_do_usuario_e_a_que_vale(self):
        for data, categoria in (("2026-01-05", "lazer"), ("2026-02-05", "alimentacao")):
            Movimentacao(
                descricao="Pix enviado: FULANO DE TAL", tipo="gasto", valor=30.0,
                data=data, categoria=categoria, usuario_id=self.usuario.id,
            ).salvar()

        novas = self._novas(_ofx(("20260305", "-45.00", 'Pix enviado: "Cp :999-FULANO DE TAL"')))

        self.assertEqual(novas[0]["categoria"], "alimentacao")

    def test_categoria_aprendida_de_um_usuario_nao_vale_para_outro(self):
        Movimentacao(
            descricao="Pix enviado: FULANO DE TAL", tipo="gasto", valor=30.0,
            data="2026-01-05", categoria="lazer", usuario_id=self.criar_usuario().id,
        ).salvar()

        novas = self._novas(_ofx(("20260305", "-45.00", "Pix enviado: FULANO DE TAL")))

        self.assertEqual(novas[0]["categoria"], "outros")

    def test_pix_com_o_nome_do_proprio_usuario_e_transferencia_entre_contas(self):
        usuario = self.criar_usuario(nome="Maria Souza Lima")

        analise = self.analisar.executar(usuario.id, _ofx(
            ("20260305", "150.00", 'Pix recebido: "Cp :111-Maria Souza Lima"'),
            ("20260306", "80.00", 'Pix recebido: "Cp :222-Maria Souza Pereira"'),
        ))

        propria, outra = analise["transacoes"]
        self.assertEqual(propria["situacao"], "movimentacao_interna")
        self.assertIn("contas suas", propria["aviso"])
        self.assertEqual(outra["situacao"], "nova")

    def test_nome_de_uma_palavra_so_nao_e_usado_para_reconhecer_transferencia(self):
        usuario = self.criar_usuario(nome="Maria")

        situacoes = self._situacoes(
            _ofx(("20260305", "150.00", "Pix recebido: Maria Souza Lima")), usuario=usuario
        )

        self.assertEqual(situacoes, {"Pix recebido: Maria Souza Lima": "nova"})

    def test_apagar_um_lancamento_importado_libera_a_linha_para_importar_de_novo(self):
        """Importou com a categoria errada, apagou: a linha precisa voltar
        a aparecer como nova, senão o erro fica sem conserto."""
        from services.movimentacao.deletar_movimentacao_service import DeletarMovimentacaoService

        extrato = _ofx(("20261001", "-50.00", "MERCADO"), ("20261002", "-20.00", "UBER"))
        self.confirmar.executar(self.usuario.id, self._novas(extrato))
        mercado = Movimentacao.query.filter_by(descricao="MERCADO").one()
        self.assertEqual(TransacaoImportada.query.filter_by(movimentacao_id=mercado.id).count(), 1)

        self.assertTrue(DeletarMovimentacaoService().executar(mercado.id))

        self.assertEqual(self._situacoes(extrato), {"MERCADO": "nova", "UBER": "ja_importada"})

    def test_rota_de_exclusao_tambem_libera_a_linha(self):
        cliente = self.app.test_client()
        cabecalho = {"Authorization": f"Bearer {AuthService.gerar_token(self.usuario.id)}"}
        extrato = _ofx(("20261001", "-50.00", "MERCADO"))
        self.confirmar.executar(self.usuario.id, self._novas(extrato))
        mercado = Movimentacao.query.one()

        resposta = cliente.delete(f"/api/movimentacoes/{mercado.id}", headers=cabecalho)

        self.assertEqual(resposta.status_code, 200)
        self.assertEqual(TransacaoImportada.query.count(), 0)
        self.assertEqual(self._situacoes(extrato), {"MERCADO": "nova"})

    def test_apagar_lancamento_digitado_nao_mexe_nas_importacoes(self):
        from services.movimentacao.deletar_movimentacao_service import DeletarMovimentacaoService

        self.confirmar.executar(self.usuario.id, self._novas(_ofx(("20261001", "-50.00", "A"))))
        digitado = Movimentacao(
            descricao="Feira", tipo="gasto", valor=30.0, data="2026-10-03",
            categoria="alimentacao", usuario_id=self.usuario.id,
        ).salvar()

        DeletarMovimentacaoService().executar(digitado.id)

        self.assertEqual(TransacaoImportada.query.count(), 1)

    def _importar_como_o_app(self, analise, deixar_de_fora=()):
        """Faz o que a tela de revisão faz: importa as linhas marcadas (menos
        as de `deixar_de_fora`) e, se o ajuste estiver marcado, calcula o
        valor dele com essa seleção e o envia junto."""
        selecionadas = [
            t for t in analise["transacoes"]
            if t["marcada"] and t["descricao"] not in deixar_de_fora
        ]
        enviar = list(selecionadas)
        ajuste = analise["ajuste_saldo"]
        if ajuste and ajuste["marcado_por_padrao"]:
            valor = ajuste["saldo_banco"] - ajuste["saldo_app_ate_data_banco"] - sum(
                t["valor"] if t["tipo"] == "renda" else -t["valor"]
                for t in selecionadas if t["data"] <= ajuste["data_banco"]
            )
            if abs(valor) >= 0.01:
                enviar.append({
                    "identificador": ajuste["identificador"], "data": ajuste["data"],
                    "descricao": ajuste["descricao"], "categoria": ajuste["categoria"],
                    "tipo": "renda" if valor > 0 else "gasto", "valor": round(abs(valor), 2),
                })
        if enviar:
            self.confirmar.executar(self.usuario.id, enviar)

    def _saldo(self):
        from services.movimentacao.calcular_saldo_service import CalcularSaldoService
        return CalcularSaldoService().executar(self.usuario.id)

    def test_conta_nova_fica_com_o_mesmo_saldo_do_banco(self):
        """Sem o dinheiro que já estava na conta, o saldo do app ficava
        negativo mesmo com saldo positivo no banco."""
        extrato = _ofx(
            ("20261001", "150.00", "PIX RECEBIDO"),
            ("20261005", "-600.00", "ALUGUEL"),
            ("20261010", "-40.42", "MERCADO"),
            saldo=("389.58", "20261013"),
        )

        analise = self.analisar.executar(self.usuario.id, extrato)

        ajuste = analise["ajuste_saldo"]
        self.assertEqual(analise["saldo_banco"], {"valor": 389.58, "data": "2026-10-13"})
        # 389,58 - (150 - 600 - 40,42) = 880,00 que já estavam na conta
        self.assertEqual(ajuste["valor_com_marcadas_por_padrao"], 880.0)
        self.assertEqual(ajuste["data"], "2026-09-30")
        self.assertTrue(ajuste["marcado_por_padrao"])

        self._importar_como_o_app(analise)
        self.assertAlmostEqual(self._saldo(), 389.58, places=2)

    def test_linha_deixada_de_fora_nao_desequilibra_o_saldo(self):
        """O caso real: uma aplicação ficou desmarcada na revisão. Ela saiu
        da conta no banco; o saldo do app tem que acompanhar."""
        extrato = _ofx(
            ("20261001", "1000.00", "SALARIO"),
            ("20261003", "-366.38", "APLICACAO RDB"),
            ("20261005", "-200.00", "MERCADO"),
            saldo=("900.00", "20261013"),
        )

        analise = self.analisar.executar(self.usuario.id, extrato)
        self.assertFalse(
            next(t for t in analise["transacoes"] if t["descricao"] == "APLICACAO RDB")["marcada"]
        )
        self._importar_como_o_app(analise)

        self.assertAlmostEqual(self._saldo(), 900.0, places=2)

    def test_desmarcar_qualquer_linha_tambem_mantem_o_saldo_do_banco(self):
        extrato = _ofx(
            ("20261001", "1000.00", "SALARIO"),
            ("20261005", "-200.00", "MERCADO"),
            saldo=("900.00", "20261013"),
        )

        self._importar_como_o_app(
            self.analisar.executar(self.usuario.id, extrato), deixar_de_fora=("MERCADO",))

        self.assertAlmostEqual(self._saldo(), 900.0, places=2)

    def test_nas_importacoes_seguintes_a_diferenca_vem_so_como_aviso(self):
        """Depois da primeira importação, o app não iguala ao banco sozinho:
        uma diferença indica algo que não bate e precisa da pessoa."""
        primeira = _ofx(("20261001", "150.00", "A"), ("20261005", "-600.00", "B"),
                        saldo=("300.00", "20261006"))
        self._importar_como_o_app(self.analisar.executar(self.usuario.id, primeira))
        self.assertAlmostEqual(self._saldo(), 300.0, places=2)
        seguinte = _ofx(("20261001", "150.00", "A"), ("20261005", "-600.00", "B"),
                        ("20261010", "-50.00", "C"), saldo=("100.00", "20261013"))

        analise = self.analisar.executar(self.usuario.id, seguinte)

        ajuste = analise["ajuste_saldo"]
        self.assertFalse(ajuste["primeira_importacao"])
        self.assertFalse(ajuste["marcado_por_padrao"])
        self.assertEqual(ajuste["valor_com_marcadas_por_padrao"], -150.0)  # 100 - 300 - (-50)
        self._importar_como_o_app(analise)
        self.assertAlmostEqual(self._saldo(), 250.0, places=2)  # nada mudou sozinho

    def test_quem_importou_sem_o_ajuste_corrige_importando_de_novo(self):
        """O caso real: as linhas entraram, mas o ajuste não (app antigo em
        cache no navegador). A conta ainda não foi igualada ao banco, então
        reimportar o mesmo arquivo traz o ajuste marcado."""
        extrato = _ofx(("20261001", "150.00", "A"), ("20261005", "-600.00", "B"),
                       saldo=("906.38", "20261013"))
        self.confirmar.executar(self.usuario.id, self._novas(extrato))
        self.assertAlmostEqual(self._saldo(), -450.0, places=2)

        analise = self.analisar.executar(self.usuario.id, extrato)

        self.assertTrue(analise["ajuste_saldo"]["marcado_por_padrao"])
        self._importar_como_o_app(analise)
        self.assertAlmostEqual(self._saldo(), 906.38, places=2)

    def test_ajuste_ja_feito_nao_e_oferecido_de_novo_ate_ser_apagado(self):
        from services.movimentacao.deletar_movimentacao_service import DeletarMovimentacaoService

        extrato = _ofx(("20261001", "-10.00", "A"), saldo=("500.00", "20261013"))
        self._importar_como_o_app(self.analisar.executar(self.usuario.id, extrato))
        self.assertIsNone(self.analisar.executar(self.usuario.id, extrato)["ajuste_saldo"])

        ajuste = Movimentacao.query.filter_by(categoria="saldo_inicial").one()
        DeletarMovimentacaoService().executar(ajuste.id)

        self.assertIsNotNone(self.analisar.executar(self.usuario.id, extrato)["ajuste_saldo"])

    def test_primeira_importacao_iguala_ao_banco_mesmo_com_lancamentos_digitados(self):
        """Na primeira importação de uma conta, o saldo do app passa a ser
        exatamente o do banco, mesmo que já houvesse lançamentos à mão."""
        Movimentacao(
            descricao="Salário", tipo="renda", valor=2000.0, data="2026-09-05",
            categoria="salario", usuario_id=self.usuario.id,
        ).salvar()

        analise = self.analisar.executar(
            self.usuario.id, _ofx(("20261001", "-10.00", "A"), saldo=("500.00", "20261013")))

        ajuste = analise["ajuste_saldo"]
        self.assertTrue(ajuste["primeira_importacao"])
        self.assertTrue(ajuste["marcado_por_padrao"])
        self.assertEqual(ajuste["saldo_app_ate_data_banco"], 2000.0)
        self.assertEqual(ajuste["valor_com_marcadas_por_padrao"], -1490.0)  # 500 - 2000 - (-10)
        self._importar_como_o_app(analise)
        self.assertAlmostEqual(self._saldo(), 500.0, places=2)

    def test_extrato_de_outra_conta_do_banco_tambem_e_primeira_importacao(self):
        self._importar_como_o_app(self.analisar.executar(
            self.usuario.id, _ofx(("20261001", "-10.00", "A"), saldo=("500.00", "20261013"))))

        analise = self.analisar.executar(self.usuario.id, _ofx(
            ("20261001", "-20.00", "Z"), conta="99999-9", saldo=("300.00", "20261013")))

        self.assertTrue(analise["ajuste_saldo"]["primeira_importacao"])

    def test_sem_saldo_no_extrato_nao_ha_ajuste(self):
        analise = self.analisar.executar(self.usuario.id, _ofx(("20261001", "-10.00", "A")))

        self.assertIsNone(analise["ajuste_saldo"])
        self.assertIsNone(analise["saldo_banco"])

    def test_extrato_de_exemplo_na_conta_demo_aponta_as_recorrencias(self):
        """O cenário da apresentação: a conta demo já tem salário, aluguel,
        internet e streaming lançados sozinhos; o extrato traz os mesmos."""
        usuario_id = criar_conta_demo()

        analise = self.analisar.executar(usuario_id, gerar_extrato_exemplo())

        situacoes = {t["descricao"]: t["situacao"] for t in analise["transacoes"]}
        for descricao in (
            "PAGAMENTO DE SALARIO - EMPRESA LTDA",
            "PIX ENVIADO - IMOBILIARIA CENTRAL",
            "DEB AUT - INTERNET FIBRA",
            "NETFLIX.COM",
        ):
            with self.subTest(descricao=descricao):
                self.assertEqual(situacoes[descricao], "possivel_duplicata")
        self.assertEqual(situacoes["APLICACAO RDB"], "movimentacao_interna")
        self.assertEqual(situacoes["PIX ENVIADO - JOAO PEDRO SILVA"], "nova")

    def test_confirmar_recusa_dados_invalidos_sem_gravar_nada(self):
        boa = {"identificador": "a", "descricao": "Ok", "tipo": "gasto",
               "valor": 10, "data": "2026-03-05", "categoria": "outros"}
        invalidas = [
            {**boa, "valor": 0},
            {**boa, "valor": "abc"},
            {**boa, "data": "05/03/2026"},
            {**boa, "tipo": "transferencia"},
            {**boa, "descricao": " "},
            {**boa, "identificador": ""},
        ]
        for ruim in invalidas:
            with self.subTest(ruim=ruim), self.assertRaises(ValueError):
                self.confirmar.executar(self.usuario.id, [boa, ruim])
        for vazio in ([], None, "texto"):
            with self.subTest(vazio=vazio), self.assertRaises(ValueError):
                self.confirmar.executar(self.usuario.id, vazio)

        self.assertEqual(Movimentacao.query.count(), 0)
        self.assertEqual(TransacaoImportada.query.count(), 0)

    def test_mesma_linha_enviada_duas_vezes_entra_uma_so(self):
        linha = {"identificador": "a", "descricao": "Ok", "tipo": "gasto",
                 "valor": 10, "data": "2026-03-05", "categoria": "outros"}

        resultado = self.confirmar.executar(self.usuario.id, [linha, dict(linha)])

        self.assertEqual(resultado, {"importadas": 1, "ja_existiam": 1})
        self.assertEqual(Movimentacao.query.count(), 1)

    def test_rotas_analisam_e_confirmam(self):
        cliente = self.app.test_client()
        cabecalho = {"Authorization": f"Bearer {AuthService.gerar_token(self.usuario.id)}"}
        arquivo = base64.b64encode(gerar_extrato_exemplo(HOJE).encode("cp1252")).decode()

        analise = cliente.post("/api/importacao/analisar", headers=cabecalho,
                               json={"arquivo_base64": arquivo})
        self.assertEqual(analise.status_code, 200)
        transacoes = analise.get_json()["transacoes"]
        self.assertEqual(len(transacoes), 13)

        confirmacao = cliente.post("/api/importacao/confirmar", headers=cabecalho,
                                   json={"transacoes": transacoes[:3]})
        self.assertEqual(confirmacao.status_code, 201)
        self.assertEqual(confirmacao.get_json()["importadas"], 3)
        self.assertEqual(Movimentacao.query.count(), 3)

        erros = [
            cliente.post("/api/importacao/analisar", headers=cabecalho, json={}),
            cliente.post("/api/importacao/analisar", headers=cabecalho,
                         json={"arquivo_base64": "isto não é base64!"}),
            cliente.post("/api/importacao/analisar", headers=cabecalho,
                         json={"arquivo_base64": base64.b64encode(b"nao sou ofx").decode()}),
            cliente.post("/api/importacao/confirmar", headers=cabecalho, json={"transacoes": []}),
        ]
        for resposta in erros:
            self.assertEqual(resposta.status_code, 400)
            self.assertIn("erro", resposta.get_json())

        self.assertEqual(
            cliente.post("/api/importacao/analisar", json={"arquivo_base64": arquivo}).status_code,
            401,
        )


if __name__ == "__main__":
    unittest.main()
