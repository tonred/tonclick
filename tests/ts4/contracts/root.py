from tonclient.types import CallSet
from tonos_ts4 import ts4

from utils.libraries import Balances
from utils.user import User
from utils.utils import random_address


class Root(ts4.BaseContract):

    def __init__(self, ctor_params: dict):
        super().__init__(
            'Root',
            ctor_params,
            nickname='Root',
            override_address=random_address(),
            balance=Balances.ROOT_BALANCE,
        )

    @property
    def withdrawal_fee(self) -> (int, int):
        return self.call_getter('getWithdrawalFee', {'answerId': 0})

    def set_withdrawal_fee(self, root_owner: User, numerator: int, denominator: int):
        call_set = CallSet('setWithdrawalFee', input={
            'numerator': numerator,
            'denominator': denominator,
        })
        root_owner.ton_wallet.send_call_set(
            self,
            value=1 * ts4.GRAM,
            call_set=call_set,
        )
