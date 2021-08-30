from tonclient.types import CallSet

from base import BaseTest
from config import INIT_TIP3_VALUE
from utils.libraries import Fees


class SubscriptionPlanTest(BaseTest):

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
        self.assertEqual(user_subscription.auto_renew, False, 'Subscription must be auto renew')
        self.assertEqual(self.subscription_plan.total_user_count, 1, 'Subscription must be calculated')
        self.assertEqual(self.subscription_plan.active_user_count, 0, 'Subscription must not be auto renew')

    def test_unsubscribe(self):
        # subscribe
        user = self.environment.create_user()
        user_subscription = self._deploy_user_subscription(user)

        # unsubscribe
        payload = self.subscription_plan.call_getter('buildUnsubscribePayload', {
            'user': user.ton_wallet.address,
            'pubkey': user.ton_wallet.public_key_,
        })
        call_set = CallSet('unsubscribe', input={'payload': payload.raw_})
        user.ton_wallet.send_call_set(
            self.subscription_plan,
            value=Fees.USER_SUBSCRIPTION_CANCEL_VALUE,
            call_set=call_set,
        )
        self.assertEqual(user_subscription.active, True, 'Subscription must not be activated')
        self.assertEqual(user_subscription.auto_renew, False, 'Subscription must be auto renew')
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
