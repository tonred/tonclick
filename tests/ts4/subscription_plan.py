from tonclient.types import CallSet

from base import BaseTest
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
