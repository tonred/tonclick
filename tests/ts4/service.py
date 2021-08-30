from tonclient.types import CallSet

from base import BaseTest
from config import INIT_TIP3_VALUE
from utils.libraries import Fees


class ServiceTest(BaseTest):

    def test_withdrawal_workflow(self):
        # set root fee value to 2%
        fee_numerator = 2
        fee_denominator = 100
        self.root.set_withdrawal_fee(self.environment.root_owner, fee_numerator, fee_denominator)

        # create 10 subscribers
        users_count = 10
        expected_balance = users_count * self.environment.SUBSCRIPTION_PLAN_TIP3_PRICE
        for _ in range(users_count):
            user = self.environment.create_user()
            self._deploy_user_subscription(user)
        virtual_balances = self.service.get_balances()
        tip3_root, virtual_balance = list(virtual_balances.items())[0]
        self.assertEqual(virtual_balance, expected_balance, 'Wrong virtual balance')

        # withdrawal tip3 income
        call_set = CallSet('withdrawalTip3Income', input={
            'tip3Root': tip3_root.addr_,
        })
        self.environment.service_owner.ton_wallet.send_call_set(
            self.service,
            value=Fees.SERVICE_WITHDRAWAL_VALUE,
            call_set=call_set,
        )

        # check result balances
        virtual_balance = self.service.get_one_balances(tip3_root)
        self.assertEqual(virtual_balance, 0, 'Wrong virtual balance after withdrawal')
        root_income = self.environment.root_owner.tip3_balance - INIT_TIP3_VALUE
        root_income_expected = expected_balance * fee_numerator // fee_denominator
        self.assertEqual(root_income, root_income_expected, 'Wrong root balance after withdrawal')
        service_income = self.environment.service_owner.tip3_balance - INIT_TIP3_VALUE
        service_income_expected = expected_balance * (fee_denominator - fee_numerator) // fee_denominator
        self.assertEqual(service_income, service_income_expected, 'Wrong service balance after withdrawal')
        self._check_balances()
