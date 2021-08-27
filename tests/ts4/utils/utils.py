import random

from tonos_ts4 import ts4


def random_address() -> ts4.Address:
    address = '0:' + ''.join(str(random.randint(0, 9)) for _ in range(64))
    return ts4.Address(address)
