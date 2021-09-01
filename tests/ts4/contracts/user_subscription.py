from tonos_ts4 import ts4


class UserSubscription(ts4.BaseContract):

    def __init__(self, address: ts4.Address):
        super().__init__('UserSubscription', {}, nickname='UserSubscription', address=address)

    @property
    def active(self) -> bool:
        return self.call_getter('isActive', {'_answer_id': 0})

    @property
    def auto_renew(self) -> bool:
        return self.call_getter('isAutoRenew', {'_answer_id': 0})
