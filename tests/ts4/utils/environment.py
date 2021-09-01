from tonclient.types import CallSet
from tonos_ts4 import ts4

from config import BUILD_ARTIFACTS_PATH, VERBOSE
from contracts.root import Root
from contracts.service import Service
from contracts.subscription_plan import SubscriptionPlan
from contracts.user_profile import UserProfile
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
    SUBSCRIPTION_PLAN_TON_PRICE = 5 * ts4.GRAM
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
        self.service = self.deploy_service()

        self.subscription_plan = self.deploy_subscription_plan()

    def create_user(self) -> User:
        return User(self.tip3_helper)

    def _deploy_root(self) -> Root:
        service_code = ts4.load_code_cell(f'Service')
        subscription_plan_code = ts4.load_code_cell(f'SubscriptionPlan')
        user_subscription_code = ts4.load_code_cell(f'UserSubscription')
        user_profile_code = ts4.load_code_cell(f'UserProfile')
        return Root({
            'owner': self.root_owner.ton_wallet.address,
            'serviceCode': service_code,
            'subscriptionPlanCode': subscription_plan_code,
            'userSubscriptionCode': user_subscription_code,
            'userProfileCode': user_profile_code,
        })

    def _create_organization(self) -> ts4.BaseContract:
        return ts4.BaseContract('TestOrganization', {
            'root': self.root.address,
        }, nickname='Organization', override_address=random_address())

    def deploy_service(self, service_owner: User = None) -> Service:
        service_owner = service_owner or self.service_owner
        call_set = CallSet('createService', input={
            'owner': service_owner.ton_wallet.address.str(),
            'title': self.SERVICE_TITLE,
            'description': self.SERVICE_DESCRIPTION,
            'url': self.SERVICE_URL,
        })
        service_owner.ton_wallet.send_call_set(
            self.organization,
            value=0,
            call_set=call_set,
        )
        address = self.organization.call_getter('getService')
        return Service(address)

    def deploy_subscription_plan(self, service_owner: User = None, service: Service = None) -> SubscriptionPlan:
        service_owner = service_owner or self.service_owner
        service = service or self.service
        tip3_root = self.tip3_helper.tip3_root.str()
        call_set = CallSet('createSubscriptionPlan', input={
            'tonPrice': self.SUBSCRIPTION_PLAN_TON_PRICE,
            'tip3Prices': {tip3_root: self.SUBSCRIPTION_PLAN_TIP3_PRICE},
            'title': self.SUBSCRIPTION_PLAN_TITLE,
            'duration': self.SUBSCRIPTION_PLAN_DURATION,
            'description': self.SUBSCRIPTION_PLAN_DESCRIPTION,
            'termUrl': self.SUBSCRIPTION_PLAN_TERM_URL,
            'limitCount': self.SUBSCRIPTION_PLAN_LIMIT_COUNT,
        })
        service_owner.ton_wallet.send_call_set(
            service,
            value=Fees.CREATE_SUBSCRIPTION_PLAN_VALUE,
            call_set=call_set,
        )
        subscription_plans = service.get_subscription_plans()
        address = subscription_plans[0]
        return SubscriptionPlan(address)

    def deploy_user_subscription(
            self,
            user: User,
            value: int,
            auto_renew: bool = True,
            service: Service = None,
            subscription_plan: SubscriptionPlan = None,
    ) -> UserSubscription:
        service = service or self.service
        subscription_plan = subscription_plan or self.subscription_plan
        payload = service.build_subscription_payload(
            subscription_plan_nonce=0,
            user=user.ton_wallet.address,
            pubkey=0,
            auto_renew=auto_renew,
        )
        user.transfer_tip3(service.address, value, Fees.USER_SUBSCRIPTION_EXTEND_VALUE, payload=payload)
        address = subscription_plan.get_user_subscription(
            user=user.ton_wallet.address,
            pubkey=0,
        )
        return UserSubscription(address)

    # dont forget about `fee` when pass a value
    def deploy_user_subscription_via_ton(self, user: User, value: int, auto_renew: bool = True) -> UserSubscription:
        payload = self.service.build_subscription_payload(
            subscription_plan_nonce=0,
            user=user.ton_wallet.address,
            pubkey=0,
            auto_renew=auto_renew,
        )
        call_set = CallSet('subscribeNativeTon', input={'payload': payload.raw_})
        user.ton_wallet.send_call_set(self.service, value, call_set)
        address = self.subscription_plan.get_user_subscription(
            user=user.ton_wallet.address,
            pubkey=0,
        )
        return UserSubscription(address)

    def get_user_profile(self, user: User) -> UserProfile:
        address = self.root.call_getter('getUserProfile', {
            'user': user.ton_wallet.address,
            'pubkey': 0,
            'answerId': 0,
        })
        return UserProfile(address)
