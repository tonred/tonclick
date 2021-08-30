import time
import unittest

from tonos_ts4 import ts4

from contracts.user_subscription import UserSubscription
from utils.environment import Environment
from utils.libraries import Balances
from utils.user import User


class BaseTest(unittest.TestCase):

    def setUp(self):
        self.environment = Environment()
        self.root = self.environment.root
        self.service = self.environment.service
        self.subscription_plan = self.environment.subscription_plan

    def _check_balances(self, user_subscriptions: list[ts4.BaseContract] = None):
        self.assertEqual(self.root.balance, Balances.ROOT_BALANCE, 'Wrong ton balance')
        self.assertEqual(self.service.balance, Balances.SERVICE_BALANCE, 'Wrong ton balance')
        self.assertEqual(self.subscription_plan.balance, Balances.SUBSCRIPTION_PLAN_BALANCE, 'Wrong ton balance')
        if user_subscriptions:
            for user_subscription in user_subscriptions:
                self.assertEqual(user_subscription.balance, Balances.USER_SUBSCRIPTION_BALANCE, 'Wrong ton balance')

    def _deploy_user_subscription(self, user: User, value: int = None, auto_renew: bool = True) -> UserSubscription:
        if value is None:
            value = self.environment.SUBSCRIPTION_PLAN_TIP3_PRICE
        return self.environment.deploy_user_subscription(user, value, auto_renew)

    @staticmethod
    def _increase_time(seconds: int):
        current_time = int(time.time())
        ts4.core.set_now(current_time + seconds)
