from base import BaseTest


class RootTest(BaseTest):

    def test_set_withdrawal_fee(self):
        fees = (0, 100), (2, 100), (100, 100)
        for numerator, denominator in fees:
            self._set_withdrawal_fee(numerator, denominator)
            fees = self.root.call_getter('getWithdrawalFee', {'answerId': 0})
            self.assertEqual(fees, (numerator, denominator), 'Wrong fees values')
