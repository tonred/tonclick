from tonos_ts4 import ts4


class Service(ts4.BaseContract):

    def __init__(self, address: ts4.Address):
        super().__init__('Service', {}, nickname='Service', address=address)

    def get_subscription_plans(self) -> list[ts4.Address]:
        return self.call_getter('getSubscriptionPlans', {'answerId': 0})

    def get_balances(self) -> dict:
        return self.call_getter('getBalances', {'answerId': 0})

    def get_one_balances(self, tip_root: ts4.Address) -> int:
        return self.call_getter('getOneBalance', {
            'answerId': 0,
            'tip3Root': tip_root,
        })

    def build_subscription_payload(self, subscription_plan_nonce: int, pubkey: int, auto_renew: bool) -> ts4.Cell:
        return self.call_getter('buildSubscriptionPayload', {
            'subscriptionPlanNonce': subscription_plan_nonce,
            'pubkey': pubkey,
            'autoRenew': auto_renew,
        })
