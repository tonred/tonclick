from tonos_ts4 import ts4


class SubscriptionPlan(ts4.BaseContract):

    def __init__(self, address: ts4.Address):
        super().__init__('SubscriptionPlan', {}, nickname='SubscriptionPlan', address=address)

    @property
    def total_user_count(self) -> int:
        return self.call_getter('getTotalUsersCount', {'answerId': 0})

    @property
    def active_user_count(self) -> int:
        return self.call_getter('getActiveUsersCount', {'answerId': 0})

    def get_user_subscription(self, user: ts4.Address, pubkey: int) -> ts4.Address:
        return self.call_getter('getUserSubscription', {
            'user': user,
            'pubkey': pubkey,
        })
