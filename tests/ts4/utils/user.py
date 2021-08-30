import json
import os

from tonclient.types import CallSet
from tonos_ts4 import ts4

from config import BUILD_ARTIFACTS_PATH, EMPTY_CELL, INIT_TIP3_VALUE
from utils.tip3 import TIP3Helper
from utils.wallet import Wallet


class User:

    def __init__(self, tip3_helper: TIP3Helper):
        self.ton_wallet = Wallet()
        self.tip3_wallet = self._create_tip3_wallet(self.ton_wallet.address, tip3_helper)

    @staticmethod
    def _create_tip3_wallet(owner: ts4.Address, tip3_helper: TIP3Helper) -> ts4.BaseContract:
        address = tip3_helper.deploy_tip3_wallet(owner, INIT_TIP3_VALUE)
        return ts4.BaseContract('TONTokenWallet', {}, nickname='TONTokenWallet', address=address)

    def transfer_tip3(
            self,
            destination: ts4.Address,
            value: int,
            grams: int,
            payload:
            ts4.Cell = EMPTY_CELL,
            expect_ec: int = 0
    ):
        call_set = CallSet('transferToRecipient', input={
            'recipient_public_key': 0,
            'recipient_address': destination.str(),
            'tokens': value,
            'deploy_grams': 0,
            'transfer_grams': grams,
            'send_gas_to': self.ton_wallet.address.str(),
            'notify_receiver': True,
            'payload': payload.raw_,
        })
        abi = self._load_tip3_wallet_abi()
        self.ton_wallet.send_call_set_custom(
            self.tip3_wallet.address,
            1 * ts4.GRAM,
            call_set=call_set,
            abi=abi,
            expect_ec=expect_ec,
        )

    @staticmethod
    def _load_tip3_wallet_abi() -> dict:
        path = os.path.join(BUILD_ARTIFACTS_PATH, 'TONTokenWallet.abi.json')
        with open(path, 'r') as file:
            content = file.read()
        return json.loads(content)

    @property
    def ton_balance(self) -> int:
        return self.ton_wallet.balance

    @property
    def tip3_balance(self) -> int:
        return self.tip3_wallet.call_getter('balance', {'answerId': 0})
