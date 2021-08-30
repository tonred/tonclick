from tonclient.types import CallSet

from base import BaseTest
from utils.libraries import Fees


class SubscriptionPlanTest(BaseTest):

    def test_subscribe(self):
        user = self.environment.create_user()
        user_subscription = self._deploy_user_subscription(user)
        active = user_subscription.call_getter('isActive')
        auto_renew = user_subscription.call_getter('isActive')
        self.assertEqual(active, True, 'Subscription must be activate')
        self.assertEqual(auto_renew, True, 'Subscription must be auto renew')
        total_user_count = self.subscription_plan.call_getter('getTotalUsersCount', {'answerId': 0})
        active_user_count = self.subscription_plan.call_getter('getActiveUsersCount', {'answerId': 0})
        self.assertEqual(total_user_count, 1, 'Subscription must be calculated')
        self.assertEqual(active_user_count, 1, 'Subscription must be auto renew')

    def test_once_subscribe(self):
        user = self.environment.create_user()
        user_subscription = self._deploy_user_subscription(user, auto_renew=False)
        active = user_subscription.call_getter('isActive')
        auto_renew = user_subscription.call_getter('isAutoRenew')
        self.assertEqual(active, True, 'Subscription must be activate')
        self.assertEqual(auto_renew, False, 'Subscription must be auto renew')
        total_user_count = self.subscription_plan.call_getter('getTotalUsersCount', {'answerId': 0})
        active_user_count = self.subscription_plan.call_getter('getActiveUsersCount', {'answerId': 0})
        self.assertEqual(total_user_count, 1, 'Subscription must be calculated')
        self.assertEqual(active_user_count, 0, 'Subscription must not be auto renew')

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
        active = user_subscription.call_getter('isActive')
        auto_renew = user_subscription.call_getter('isAutoRenew')
        self.assertEqual(active, True, 'Subscription must not be activated')
        self.assertEqual(auto_renew, False, 'Subscription must be auto renew')
        # it is active because user subscribes on certain duration,
        # so user can cancel only auto renew of subscription

    def test_subscription_expire(self):
        user = self.environment.create_user()
        user_subscription = self._deploy_user_subscription(user, auto_renew=False)
        self._increase_time(self.environment.SUBSCRIPTION_PLAN_DURATION + 1)
        active = user_subscription.call_getter('isActive')
        self.assertEqual(active, False, 'Subscription must be expired')
