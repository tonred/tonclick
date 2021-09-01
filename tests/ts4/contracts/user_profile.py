from tonos_ts4 import ts4


class UserProfile(ts4.BaseContract):

    def __init__(self, address: ts4.Address):
        super().__init__('UserProfile', {}, nickname='UserProfile', address=address)

    @property
    def count_subscriptions(self) -> int:
        return self.call_getter('getSubscriptionsCount', {'_answer_id': 0})

    @property
    def subscriptions(self) -> list[ts4.Address]:
        return self.call_getter('getSubscriptions', {'_answer_id': 0})
