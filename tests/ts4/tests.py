import time
import unittest

from tonclient.types import CallSet
from tonos_ts4 import ts4

from config import INIT_TIP3_VALUE
from contracts.user_subscription import UserSubscription
from utils.environment import Environment
from utils.libraries import Fees, Balances
from utils.user import User


class Tests(unittest.TestCase):

    def setUp(self):
        self.environment = Environment()
        self.root = self.environment.root
        self.service = self.environment.service
        self.subscription_plan = self.environment.subscription_plan

    def test_subscribe(self):
        user = self.environment.create_user()
        user_subscription = self._deploy_user_subscription(user)
        self.assertEqual(user_subscription.active, True, 'Subscription must be activate')
        self.assertEqual(user_subscription.auto_renew, True, 'Subscription must be auto renew')
        self.assertEqual(self.subscription_plan.total_user_count, 1, 'Subscription must be calculated')
        self.assertEqual(self.subscription_plan.active_user_count, 1, 'Subscription must be auto renew')

    def test_once_subscribe(self):
        user = self.environment.create_user()
        user_subscription = self._deploy_user_subscription(user, auto_renew=False)
        self.assertEqual(user_subscription.active, True, 'Subscription must be activate')
        self.assertEqual(user_subscription.auto_renew, False, 'Subscription must not be auto renew')
        self.assertEqual(self.subscription_plan.total_user_count, 1, 'Subscription must be calculated')
        self.assertEqual(self.subscription_plan.active_user_count, 0, 'Subscription must not be auto renew')

    def test_unsubscribe(self):
        # subscribe
        user = self.environment.create_user()
        user_subscription = self._deploy_user_subscription(user)

        # unsubscribe
        payload = self.subscription_plan.call_getter('buildUnsubscribePayload', {
            'user': user.ton_wallet.address,
            'pubkey': 0,
        })
        call_set = CallSet('unsubscribe', input={'payload': payload.raw_})
        user.ton_wallet.send_call_set(
            self.subscription_plan,
            value=Fees.USER_SUBSCRIPTION_CANCEL_VALUE,
            call_set=call_set,
        )
        self.assertEqual(user_subscription.active, True, 'Subscription must not be activated')
        self.assertEqual(user_subscription.auto_renew, False, 'Subscription must not be auto renew')
        # it is active because user subscribes on certain duration,
        # so user can cancel only auto renew of subscription

    def test_subscription_expire(self):
        user = self.environment.create_user()
        user_subscription = self._deploy_user_subscription(user, auto_renew=False)
        self._increase_time(self.environment.SUBSCRIPTION_PLAN_DURATION + 1)
        self.assertEqual(user_subscription.active, False, 'Subscription must be expired')

    def test_subscription_long_term(self):
        periods_count = 3
        user = self.environment.create_user()
        value = periods_count * self.environment.SUBSCRIPTION_PLAN_TIP3_PRICE
        user_subscription = self._deploy_user_subscription(user, value=value, auto_renew=False)
        self._increase_time(periods_count * self.environment.SUBSCRIPTION_PLAN_DURATION - 1)
        self.assertEqual(user_subscription.active, True, 'Subscription must not be expired')

    def test_subscription_change_return(self):
        """
        it must be calculated as 2 full periods
        and the change must be returned
        """
        user = self.environment.create_user()
        value = int(2.5 * self.environment.SUBSCRIPTION_PLAN_TIP3_PRICE)
        self._deploy_user_subscription(user, value=value, auto_renew=False)
        user_tip3_cost = INIT_TIP3_VALUE - user.tip3_balance
        expected_cost = 2 * self.environment.SUBSCRIPTION_PLAN_TIP3_PRICE
        self.assertEqual(user_tip3_cost, expected_cost, 'Subscription must not be expired')

    def test_extend_after_expire(self):
        user = self.environment.create_user()
        user_subscription = self._deploy_user_subscription(user)
        self._increase_time(10 * self.environment.SUBSCRIPTION_PLAN_DURATION)
        self.assertEqual(user_subscription.active, False, 'Subscription must be expired')
        # after expire extend subscription
        self._deploy_user_subscription(user)
        self.assertEqual(user_subscription.active, True, 'Subscription must not be expired')

    def test_subscription_ton(self):
        user = self.environment.create_user()
        value = self.environment.SUBSCRIPTION_PLAN_TON_PRICE + Fees.USER_SUBSCRIPTION_EXTEND_VALUE
        user_subscription = self.environment.deploy_user_subscription_via_ton(user, value=value)
        self.assertEqual(user_subscription.active, True, 'Subscription must be activate')
        self.assertEqual(user_subscription.auto_renew, True, 'Subscription must be auto renew')
        self.assertEqual(self.subscription_plan.total_user_count, 1, 'Subscription must be calculated')
        self.assertEqual(self.subscription_plan.active_user_count, 1, 'Subscription must be auto renew')

    def test_set_withdrawal_fee(self):
        fees = (0, 100), (2, 100), (100, 100)
        for numerator, denominator in fees:
            self.root.set_withdrawal_fee(self.environment.root_owner, numerator, denominator)
            self.assertEqual(self.root.withdrawal_fee, (numerator, denominator), 'Wrong fee value')

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

    def _check_balances(self):
        self.assertEqual(self.root.balance, Balances.ROOT_BALANCE, 'Wrong ton balance')
        self.assertEqual(self.service.balance, Balances.SERVICE_BALANCE, 'Wrong ton balance')
        self.assertEqual(self.subscription_plan.balance, Balances.SUBSCRIPTION_PLAN_BALANCE, 'Wrong ton balance')

    def _deploy_user_subscription(self, user: User, value: int = None, auto_renew: bool = True) -> UserSubscription:
        if value is None:
            value = self.environment.SUBSCRIPTION_PLAN_TIP3_PRICE
        return self.environment.deploy_user_subscription(user, value, auto_renew)

    @staticmethod
    def _increase_time(seconds: int):
        current_time = int(time.time())
        ts4.core.set_now(current_time + seconds)
