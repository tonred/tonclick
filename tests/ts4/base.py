import time
import unittest

from tonclient.types import CallSet
from tonos_ts4 import ts4

from utils.environment import Environment
from utils.libraries import Balances
from utils.user import User


class BaseTest(unittest.TestCase):

    def setUp(self):

        self.environment = Environment()
        self.root = self.environment.root
        self.service = self.environment.service
        self.subscription_plan = self.environment.subscription_plan

    # @classmethod
    # def setUpClass(cls):
    #     cls.environment = Environment()
    #     cls.root = cls.environment.root
    #     cls.service = cls.environment.service
    #     cls.subscription_plan = cls.environment.subscription_plan

    def _check_balances(self, user_subscriptions: list[ts4.BaseContract] = None):
        self.assertEqual(self.root.balance, Balances.ROOT_BALANCE, 'Wrong ton balance')
        self.assertEqual(self.service.balance, Balances.SERVICE_BALANCE, 'Wrong ton balance')
        self.assertEqual(self.subscription_plan.balance, Balances.SUBSCRIPTION_PLAN_BALANCE, 'Wrong ton balance')
        if user_subscriptions:
            for user_subscription in user_subscriptions:
                self.assertEqual(user_subscription.balance, Balances.USER_SUBSCRIPTION_BALANCE, 'Wrong ton balance')

    def _set_withdrawal_fee(self, numerator: int, denominator: int):
        call_set = CallSet('setWithdrawalFee', input={
            'numerator': numerator,
            'denominator': denominator,
        })
        self.environment.root_owner.ton_wallet.send_call_set(
            self.root,
            value=1 * ts4.GRAM,
            call_set=call_set,
        )

    def _deploy_user_subscription(self, user: User, value: int = None, auto_renew: bool = True) -> ts4.BaseContract:
        if value is None:
            value = self.environment.SUBSCRIPTION_PLAN_TIP3_PRICE
        return self.environment.deploy_user_subscription(user, value, auto_renew)

    @staticmethod
    def _increase_time(seconds: int):
        current_time = int(time.time())
        ts4.core.set_now(current_time + seconds)
