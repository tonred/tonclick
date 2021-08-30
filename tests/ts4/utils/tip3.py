from tonos_ts4 import ts4

from utils.utils import random_address


class TIP3Helper:

    def __init__(self):
        self._tip3_deployer = self._create_tip3_deployer()
        self._deploy_tip3()

    @staticmethod
    def _create_tip3_deployer() -> ts4.BaseContract:
        root_code = ts4.load_code_cell('RootTokenContract')
        wallet_code = ts4.load_code_cell('TONTokenWallet')
        return ts4.BaseContract('TestTIP3Deployer', {
            'root_code': root_code,
            'wallet_code': wallet_code,
        }, nickname='TIP3Deployer', override_address=random_address())

    def _deploy_tip3(self):
        self._tip3_deployer.call_method('deployRootTIP3')

    @property
    def tip3_root(self) -> ts4.Address:
        return self._tip3_deployer.call_getter('getRoot')

    def deploy_tip3_wallet(self, owner: ts4.Address, init_value: int) -> ts4.Address:
        address = self._tip3_deployer.call_method('deployTIP3Wallet', {
            'owner': owner,
            'initValue': init_value,
        })
        ts4.dispatch_messages()
        return address
