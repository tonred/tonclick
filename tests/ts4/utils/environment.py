from tonclient.types import CallSet
from tonos_ts4 import ts4

from config import BUILD_ARTIFACTS_PATH, VERBOSE
from contracts.root import Root
from contracts.service import Service
from contracts.subscription_plan import SubscriptionPlan
from contracts.user_subscription import UserSubscription
from utils.libraries import Fees
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

    def _deploy_root(self) -> Root:
        service_code = ts4.load_code_cell(f'Service')
        subscription_plan_code = ts4.load_code_cell(f'SubscriptionPlan')
        user_subscription_code = ts4.load_code_cell(f'UserSubscription')
        return Root({
            'owner': self.root_owner.ton_wallet.address,
            'serviceCode': service_code,
            'subscriptionPlanCode': subscription_plan_code,
            'userSubscriptionCode': user_subscription_code,
        })

    def _create_organization(self) -> ts4.BaseContract:
        return ts4.BaseContract('TestOrganization', {
            'root': self.root.address,
        }, nickname='Organization', override_address=random_address())

    def _deploy_service(self) -> Service:
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
        return Service(address)

    def _deploy_subscription_plan(self) -> SubscriptionPlan:
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
        subscription_plans = self.service.get_subscription_plans()
        address = subscription_plans[0]
        return SubscriptionPlan(address)

    def deploy_user_subscription(self, user: User, value: int, auto_renew: bool = True) -> UserSubscription:
        payload = self.service.build_subscription_payload(
            subscription_plan_nonce=0,
            pubkey=user.ton_wallet.public_key_,
            auto_renew=auto_renew,
        )
        user.transfer_tip3(self.service.address, value, Fees.USER_SUBSCRIPTION_EXTEND_VALUE, payload=payload)
        address = self.subscription_plan.get_user_subscription(
            user=user.ton_wallet.address,
            pubkey=user.ton_wallet.public_key_,
        )
        return UserSubscription(address)
