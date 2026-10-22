import unittest

from services.ia.consultar_ia_service import sem_abertura_de_elogio


class TesteAberturaDeElogio(unittest.TestCase):
    """O assistente às vezes começa com elogio mesmo proibido nas
    instruções; o backend tira essa frase antes de mostrar."""

    def test_tira_o_elogio_e_o_conectivo_que_sobra(self):
        # Respostas reais do agente, com o nome trocado.
        casos = {
            "É ótimo que você esteja pensando em fundos de ações, já que seu perfil é "
            "arrojado. No entanto, como treinador financeiro, não posso recomendar "
            "fundos pelo nome.":
                "Como treinador financeiro, não posso recomendar fundos pelo nome.",
            "Que ótimo que você quer começar a investir, Maria! No entanto, antes de "
            "pensar em ações, complete a reserva.":
                "Antes de pensar em ações, complete a reserva.",
            "Maria, que bom que você perguntou. Faltam R$ 6.500 para a reserva.":
                "Faltam R$ 6.500 para a reserva.",
        }
        for original, esperado in casos.items():
            with self.subTest(original=original[:40]):
                self.assertEqual(sem_abertura_de_elogio(original), esperado)

    def test_nao_mexe_em_resposta_que_comeca_direto(self):
        for texto in (
            "Para o seu perfil, o caminho mais simples é um ETF de índice.",
            "Comprar Tesouro Selic é uma ótima decisão para a sua reserva.",
            "Que tal comparar as taxas na corretora?",
            "Faltam cerca de 6 meses para completar a reserva.",
        ):
            with self.subTest(texto=texto):
                self.assertEqual(sem_abertura_de_elogio(texto), texto)

    def test_resposta_que_e_so_o_elogio_volta_inteira(self):
        texto = "Que bom que você está aqui!"

        self.assertEqual(sem_abertura_de_elogio(texto), texto)

    def test_preserva_as_quebras_de_paragrafo_do_resto(self):
        texto = "É ótimo ver seu interesse! Primeiro parágrafo.\n\nSegundo parágrafo."

        self.assertEqual(sem_abertura_de_elogio(texto), "Primeiro parágrafo.\n\nSegundo parágrafo.")


if __name__ == "__main__":
    unittest.main()
