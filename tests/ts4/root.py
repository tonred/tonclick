from base import BaseTest


class RootTest(BaseTest):

    def test_set_withdrawal_fee(self):
        fees = (0, 100), (2, 100), (100, 100)
        for numerator, denominator in fees:
            self.root.set_withdrawal_fee(self.environment.root_owner, numerator, denominator)
            self.assertEqual(self.root.withdrawal_fee, (numerator, denominator), 'Wrong fee value')
