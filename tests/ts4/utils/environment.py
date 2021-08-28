from tonclient.types import CallSet
from tonos_ts4 import ts4

from config import BUILD_ARTIFACTS_PATH, VERBOSE
from utils.tip3 import TIP3Helper
from utils.user import User
from utils.utils import random_address

CREATE_SUBSCRIPTION_PLAN_VALUE = int(1.5 * ts4.GRAM)  # from libraries/Fees.sol
USER_SUBSCRIPTION_EXTEND_VALUE = 1 * ts4.GRAM  # from libraries/Fees.sol

SERVICE_TITLE = 'TON RED'
SERVICE_DESCRIPTION = 'First service ever!'
SERVICE_URL = 'https://ton.red'

SUBSCRIPTION_PLAN_TIP3_PRICE = 5
SUBSCRIPTION_PLAN_TITLE = 'Premium'
SUBSCRIPTION_PLAN_DURATION = 120
SUBSCRIPTION_PLAN_DESCRIPTION = 'Limited 120 second Premium subscription, only today!'
SUBSCRIPTION_PLAN_TERM_URL = 'https://ton.red/terms'
SUBSCRIPTION_PLAN_LIMIT_COUNT = 10


class Environment:

    def __init__(self):
        ts4.init(BUILD_ARTIFACTS_PATH, verbose=VERBOSE)
        self._tip3_helper = TIP3Helper()

        self._root_owner = self.create_user()
        self._root = self._deploy_root()

        self._organization = self._create_organization()
        self._service_owner = self.create_user()
        self._service = self._deploy_service()

        self._subscription_plan = self._deploy_subscription_plan()

        self._user = self.create_user()
        self._user_subscription = self._deploy_user_subscription(self._user, value=SUBSCRIPTION_PLAN_TIP3_PRICE)

    def create_user(self) -> User:
        return User(self._tip3_helper)

    def _deploy_root(self) -> ts4.BaseContract:
        service_code = ts4.load_code_cell(f'Service')
        subscription_plan_code = ts4.load_code_cell(f'SubscriptionPlan')
        user_subscription_code = ts4.load_code_cell(f'UserSubscription')
        return ts4.BaseContract('Root', {
            'owner': self._root_owner.ton_wallet.address,
            'serviceCode': service_code,
            'subscriptionPlanCode': subscription_plan_code,
            'userSubscriptionCode': user_subscription_code,
        }, nickname='Root', override_address=random_address())

    def _create_organization(self) -> ts4.BaseContract:
        return ts4.BaseContract('TestOrganization', {
            'root': self._root.address,
        }, nickname='Organization', override_address=random_address())

    def _deploy_service(self) -> ts4.BaseContract:
        call_set = CallSet('createService', input={
            'owner': self._service_owner.ton_wallet.address.str(),
            'title': SERVICE_TITLE,
            'description': SERVICE_DESCRIPTION,
            'url': SERVICE_URL,
        })
        self._service_owner.ton_wallet.send_call_set(
            self._organization.address,
            value=0,
            call_set=call_set,
            abi=self._organization.abi_,
        )
        address = self._organization.call_getter('getService')
        return ts4.BaseContract('Service', {}, nickname='Service', address=address)

    def _deploy_subscription_plan(self):
        tip3_root = self._tip3_helper.tip3_root.str()
        call_set = CallSet('createSubscriptionPlan', input={
            'tip3Prices': {tip3_root: SUBSCRIPTION_PLAN_TIP3_PRICE},
            'title': SUBSCRIPTION_PLAN_TITLE,
            'duration': SUBSCRIPTION_PLAN_DURATION,
            'description': SUBSCRIPTION_PLAN_DESCRIPTION,
            'termUrl': SUBSCRIPTION_PLAN_TERM_URL,
            'limitCount': SUBSCRIPTION_PLAN_LIMIT_COUNT,
        })
        self._service_owner.ton_wallet.send_call_set(
            self._service.address,
            value=CREATE_SUBSCRIPTION_PLAN_VALUE,
            call_set=call_set,
            abi=self._service.abi_,
        )
        subscription_plans = self._service.call_getter('getSubscriptionPlans', {'answerId': 0})
        address = subscription_plans[0]
        return ts4.BaseContract('SubscriptionPlan', {}, nickname='SubscriptionPlan', address=address)

    def _deploy_user_subscription(self, user: User, is_auto_renew: bool = True, *, value: int) -> ts4.BaseContract:
        payload = self._service.call_getter('buildSubscriptionPayload', {
            'subscriptionPlanNonce': 0,
            'pubkey': user.ton_wallet.public_key_,
            'isAutoRenew': is_auto_renew,
        })
        print(user.tip3_balance)
        user.transfer_tip3(self._service.address, value, USER_SUBSCRIPTION_EXTEND_VALUE, payload=payload)
        address = self._subscription_plan.call_getter('getUserSubscription', {
            'user': user.ton_wallet.address,
            'pubkey': user.ton_wallet.public_key_,
        })
        print(address)
        x = ts4.BaseContract('UserSubscription', {}, nickname='UserSubscription', address=address)
        print(x.call_getter('isActive'))
        return x
