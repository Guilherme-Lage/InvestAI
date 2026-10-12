import unittest

from tests.base import TesteComBanco
from services.meta.calcular_status_reserva_emergencia_service import (
    CalcularStatusReservaEmergenciaService,
)


class TesteReservaEmergencia(TesteComBanco):
    """RF14/RF15 - a reserva vale 3x a despesa média mensal, e as sugestões
    de investimento só liberam quando ela está completa."""

    def setUp(self):
        super().setUp()
        self.service = CalcularStatusReservaEmergenciaService()

    def test_meta_e_tres_vezes_a_despesa_media(self):
        usuario = self.criar_usuario()
        # 3 meses de gastos: a média mensal é 1000, logo a meta é 3000.
        self.criar_gasto(usuario, 1000, dias_atras=10)
        self.criar_gasto(usuario, 1000, dias_atras=40)
        self.criar_gasto(usuario, 1000, dias_atras=70)

        status = self.service.executar(usuario.id)

        self.assertAlmostEqual(status["despesa_media_mensal"], 1000.0, places=2)
        self.assertAlmostEqual(status["valor_ideal_reserva"], 3000.0, places=2)

    def test_usa_estimativa_do_cadastro_quando_nao_ha_despesa(self):
        """Sem este fallback a meta nasceria zerada e a trilha ficaria
        travada logo depois do cadastro."""
        usuario = self.criar_usuario(despesa_mensal_estimada=800.0)

        status = self.service.executar(usuario.id)

        self.assertAlmostEqual(status["valor_ideal_reserva"], 2400.0, places=2)

    def test_despesa_real_tem_prioridade_sobre_a_estimativa(self):
        usuario = self.criar_usuario(despesa_mensal_estimada=800.0)
        self.criar_gasto(usuario, 6000, dias_atras=5)  # 6000/3 = 2000 por mês

        status = self.service.executar(usuario.id)

        self.assertAlmostEqual(status["despesa_media_mensal"], 2000.0, places=2)
        self.assertAlmostEqual(status["valor_ideal_reserva"], 6000.0, places=2)

    def test_nao_libera_investimento_com_reserva_incompleta(self):
        usuario = self.criar_usuario(despesa_mensal_estimada=1000.0)
        self.criar_reserva(usuario, valor_atual=2999.0)  # meta é 3000

        status = self.service.executar(usuario.id)

        self.assertFalse(status["sugestoes_investimento_liberadas"])

    def test_libera_investimento_com_reserva_completa(self):
        usuario = self.criar_usuario(despesa_mensal_estimada=1000.0)
        self.criar_reserva(usuario, valor_atual=3000.0)

        status = self.service.executar(usuario.id)

        self.assertTrue(status["sugestoes_investimento_liberadas"])

    def test_nao_libera_quando_nao_ha_como_calcular_a_meta(self):
        """Sem despesa e sem estimativa a meta é zero - e zero não pode
        ser confundido com 'reserva completa'."""
        usuario = self.criar_usuario(despesa_mensal_estimada=0.0)
        self.criar_reserva(usuario, valor_atual=5000.0)

        status = self.service.executar(usuario.id)

        self.assertEqual(status["valor_ideal_reserva"], 0.0)
        self.assertFalse(status["sugestoes_investimento_liberadas"])

    def test_sugere_onde_guardar_enquanto_a_reserva_nao_fecha(self):
        usuario = self.criar_usuario(despesa_mensal_estimada=1000.0)
        self.criar_reserva(usuario, valor_atual=500.0)

        status = self.service.executar(usuario.id)

        self.assertIsNotNone(status.get("onde_guardar"))
        opcoes = status["onde_guardar"]["opcoes"]
        self.assertTrue(opcoes)
        # Só aplicações de resgate diário servem para reserva.
        for opcao in opcoes:
            self.assertEqual(opcao["liquidez"], "diaria")


if __name__ == "__main__":
    unittest.main()
