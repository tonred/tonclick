from tonclient.types import CallSet
from tonos_ts4 import ts4

from config import BUILD_ARTIFACTS_PATH, VERBOSE
from utils.libraries import Balances, Fees
from utils.tip3 import TIP3Helper
from utils.user import User
from utils.utils import random_address


class Environment:
    SERVICE_TITLE = 'TON RED'
    SERVICE_DESCRIPTION = 'First service ever!'
    SERVICE_URL = 'https://ton.red'

    SUBSCRIPTION_PLAN_TIP3_PRICE = 5
    SUBSCRIPTION_PLAN_TITLE = 'Premium'
    SUBSCRIPTION_PLAN_DURATION = 120
    SUBSCRIPTION_PLAN_DESCRIPTION = 'Limited 120 second Premium subscription, only today!'
    SUBSCRIPTION_PLAN_TERM_URL = 'https://ton.red/terms'
    SUBSCRIPTION_PLAN_LIMIT_COUNT = 10

    def __init__(self):
        ts4.reset_all()
        ts4.init(BUILD_ARTIFACTS_PATH, verbose=VERBOSE)
        self.tip3_helper = TIP3Helper()

        self.root_owner = self.create_user()
        self.root = self._deploy_root()

        self.organization = self._create_organization()
        self.service_owner = self.create_user()
        self.service = self._deploy_service()

        self.subscription_plan = self._deploy_subscription_plan()

    def create_user(self) -> User:
        return User(self.tip3_helper)

    def _deploy_root(self) -> ts4.BaseContract:
        service_code = ts4.load_code_cell(f'Service')
        subscription_plan_code = ts4.load_code_cell(f'SubscriptionPlan')
        user_subscription_code = ts4.load_code_cell(f'UserSubscription')
        return ts4.BaseContract('Root', {
            'owner': self.root_owner.ton_wallet.address,
            'serviceCode': service_code,
            'subscriptionPlanCode': subscription_plan_code,
            'userSubscriptionCode': user_subscription_code,
        }, nickname='Root', override_address=random_address(), balance=Balances.ROOT_BALANCE)

    def _create_organization(self) -> ts4.BaseContract:
        return ts4.BaseContract('TestOrganization', {
            'root': self.root.address,
        }, nickname='Organization', override_address=random_address())

    def _deploy_service(self) -> ts4.BaseContract:
        call_set = CallSet('createService', input={
            'owner': self.service_owner.ton_wallet.address.str(),
            'title': self.SERVICE_TITLE,
            'description': self.SERVICE_DESCRIPTION,
            'url': self.SERVICE_URL,
        })
        self.service_owner.ton_wallet.send_call_set(
            self.organization,
            value=0,
            call_set=call_set,
        )
        address = self.organization.call_getter('getService')
        return ts4.BaseContract('Service', {}, nickname='Service', address=address)

    def _deploy_subscription_plan(self):
        tip3_root = self.tip3_helper.tip3_root.str()
        call_set = CallSet('createSubscriptionPlan', input={
            'tip3Prices': {tip3_root: self.SUBSCRIPTION_PLAN_TIP3_PRICE},
            'title': self.SUBSCRIPTION_PLAN_TITLE,
            'duration': self.SUBSCRIPTION_PLAN_DURATION,
            'description': self.SUBSCRIPTION_PLAN_DESCRIPTION,
            'termUrl': self.SUBSCRIPTION_PLAN_TERM_URL,
            'limitCount': self.SUBSCRIPTION_PLAN_LIMIT_COUNT,
        })
        self.service_owner.ton_wallet.send_call_set(
            self.service,
            value=Fees.CREATE_SUBSCRIPTION_PLAN_VALUE,
            call_set=call_set,
        )
        subscription_plans = self.service.call_getter('getSubscriptionPlans', {'answerId': 0})
        address = subscription_plans[0]
        return ts4.BaseContract('SubscriptionPlan', {}, nickname='SubscriptionPlan', address=address)

    def deploy_user_subscription(self, user: User, value: int, auto_renew: bool = True) -> ts4.BaseContract:
        payload = self.service.call_getter('buildSubscriptionPayload', {
            'subscriptionPlanNonce': 0,
            'pubkey': user.ton_wallet.public_key_,
            'autoRenew': auto_renew,
        })
        user.transfer_tip3(self.service.address, value, Fees.USER_SUBSCRIPTION_EXTEND_VALUE, payload=payload)
        address = self.subscription_plan.call_getter('getUserSubscription', {
            'user': user.ton_wallet.address,
            'pubkey': user.ton_wallet.public_key_,
        })
        return ts4.BaseContract('UserSubscription', {}, nickname='UserSubscription', address=address)
