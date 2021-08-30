# from 'contracts/libraries' folder

from enum import IntEnum

from tonos_ts4 import ts4


class Balances(IntEnum):
    ROOT_BALANCE = 1 * ts4.GRAM
    SERVICE_BALANCE = 1 * ts4.GRAM
    SUBSCRIPTION_PLAN_BALANCE = 1 * ts4.GRAM
    USER_SUBSCRIPTION_BALANCE = int(0.1 * ts4.GRAM)


class Fees(IntEnum):
    CREATE_SERVICE_VALUE = int(1.5 * ts4.GRAM)
    CREATE_SUBSCRIPTION_PLAN_VALUE = int(1.5 * ts4.GRAM)
    SERVICE_WITHDRAWAL_VALUE = 2 * ts4.GRAM
    USER_SUBSCRIPTION_CHANGE_TIP3_PRICE_VALUE = 1 * ts4.GRAM
    USER_SUBSCRIPTION_EXTEND_VALUE = 1 * ts4.GRAM
    USER_SUBSCRIPTION_CANCEL_VALUE = 1 * ts4.GRAM
