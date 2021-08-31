from utils.environment import Environment
from utils.libraries import Fees

environment = Environment()
print(environment.service.balance)

user_1 = environment.create_user()
user_subscription_1 = environment.deploy_user_subscription(user_1, environment.SUBSCRIPTION_PLAN_TIP3_PRICE)
print(user_subscription_1.active)

user_2 = environment.create_user()
value = environment.SUBSCRIPTION_PLAN_TON_PRICE + Fees.USER_SUBSCRIPTION_EXTEND_VALUE
user_subscription_2 = environment.deploy_user_subscription_via_ton(user_2, value)
print(user_subscription_2.active)
