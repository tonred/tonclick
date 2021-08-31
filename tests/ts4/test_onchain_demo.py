import time
import unittest

from tonclient.types import CallSet
from tonos_ts4 import ts4

from config import EMPTY_CELL
from utils.environment import Environment
from utils.libraries import Fallbacks, Fees
from utils.utils import random_address
from utils.wallet import Wallet


class TestOnchainDemo(unittest.TestCase):
    MIN_EXECUTE_VALUE = 1 * ts4.GRAM

    def setUp(self):
        self.environment = Environment()
        self.subscription_plan_address = self.environment.subscription_plan.address
        self.onchain_demo = ts4.BaseContract('OnchainDemo', {
            'root': self.environment.root.address,
            'service': self.environment.service.address,
            'subscriptionPlans': [self.subscription_plan_address],
            'minValue': self.MIN_EXECUTE_VALUE,
        }, nickname='OnchainDemo', override_address=random_address())
        self.test_wallet = TestOnchainWallet()

    def test_not_enough_tokens(self):
        value = self.MIN_EXECUTE_VALUE // 2
        self.test_wallet.execute(self.onchain_demo, self.subscription_plan_address, value=value)
        self.assertEqual(self.test_wallet.success, False, 'Must not be success')
        self.assertEqual(self.test_wallet.reason, Fallbacks.NOT_ENOUGH_TOKENS, 'Wrong reason')
        self.assertEqual(self.test_wallet.balance, ts4.globals.G_DEFAULT_BALANCE, 'Wrong balance')

    def test_unsupported_subscription_plan(self):
        self.test_wallet.execute(self.onchain_demo, random_address())
        self.assertEqual(self.test_wallet.success, False, 'Must not be success')
        self.assertEqual(self.test_wallet.reason, Fallbacks.UNSUPPORTED_SUBSCRIPTION_PLAN, 'Wrong reason')
        self.assertEqual(self.test_wallet.balance, ts4.globals.G_DEFAULT_BALANCE, 'Wrong balance')

    def test_subscription_is_not_exists(self):
        self.test_wallet.execute(self.onchain_demo, self.subscription_plan_address)
        self.assertEqual(self.test_wallet.success, False, 'Must not be success')
        self.assertEqual(self.test_wallet.reason, Fallbacks.SUBSCRIPTION_IS_NOT_EXISTS, 'Must not be success')
        self.assertEqual(self.test_wallet.balance, ts4.globals.G_DEFAULT_BALANCE, 'Wrong balance')

    def test_subscription_is_expired(self):
        user = self.environment.create_user()
        user.ton_wallet = self.test_wallet
        value = self.environment.SUBSCRIPTION_PLAN_TON_PRICE + Fees.USER_SUBSCRIPTION_EXTEND_VALUE
        self.environment.deploy_user_subscription_via_ton(user, value=value)
        ton_balance = user.ton_balance
        self._increase_time(self.environment.SUBSCRIPTION_PLAN_DURATION + 1)
        self.test_wallet.execute(self.onchain_demo, self.subscription_plan_address)
        self.assertEqual(self.test_wallet.success, False, 'Must not be success')
        self.assertEqual(self.test_wallet.reason, Fallbacks.SUBSCRIPTION_IS_EXPIRED, 'Must not be success')
        self.assertEqual(user.ton_balance, ton_balance, 'Wrong balance')

    def test_success(self):
        user = self.environment.create_user()
        user.ton_wallet = self.test_wallet
        value = self.environment.SUBSCRIPTION_PLAN_TON_PRICE + Fees.USER_SUBSCRIPTION_EXTEND_VALUE
        self.environment.deploy_user_subscription_via_ton(user, value=value)
        ton_balance = user.ton_balance
        gift = self.onchain_demo.call_getter('gift')
        self.test_wallet.execute(self.onchain_demo, self.subscription_plan_address)
        self.assertEqual(self.test_wallet.success, True, 'Must be success')
        self.assertEqual(user.ton_balance, ton_balance + gift, 'Wrong balance')

    @staticmethod
    def _increase_time(seconds: int):
        current_time = int(time.time())
        ts4.core.set_now(current_time + seconds)


class TestOnchainWallet(Wallet):

    def __init__(self):
        super().__init__('TestOnchainWallet')

    @property
    def success(self) -> bool:
        return self.call_getter('_success')

    @property
    def reason(self) -> Fallbacks:
        reason_id = self.call_getter('_reason')
        return Fallbacks(reason_id)

    def execute(
            self,
            onchain_demo: ts4.BaseContract,
            subscription_plan_address: ts4.Address,
            action_payload: ts4.Cell = EMPTY_CELL,
            value: int = TestOnchainDemo.MIN_EXECUTE_VALUE,
    ):
        call_set = CallSet('execute', input={
            'subscriptionPlan': subscription_plan_address.addr_,
            'actionPayload': action_payload.raw_,
        })
        self.send_call_set(onchain_demo, value=value, call_set=call_set)
