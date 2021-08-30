from utils.environment import Environment

environment = Environment()
user = environment.create_user()
user_subscription = environment.deploy_user_subscription(user, environment.SUBSCRIPTION_PLAN_TIP3_PRICE)
print(user_subscription.call_getter('isActive'))
