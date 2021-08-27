import json

from tonclient.test.helpers import sync_core_client
from tonclient.types import Abi, Signer, CallSet, ParamsOfEncodeMessageBody
from tonos_ts4 import ts4

from utils.utils import random_address


class Wallet(ts4.BaseContract):

    def __init__(self):
        super().__init__(
            'Wallet',
            {},
            nickname='Wallet',
            override_address=random_address(),
            keypair=ts4.make_keypair(),
        )

    def send_call_set(
            self,
            dest: ts4.Address,
            value: int,
            call_set: CallSet,
            abi: dict,
            expect_ec: int = 0,
    ):
        encode_params = ParamsOfEncodeMessageBody(
            abi=Abi.Json(json.dumps(abi)),
            signer=Signer.NoSigner(),
            call_set=call_set,
            is_internal=True,
        )
        message = sync_core_client.abi.encode_message_body(params=encode_params)
        self.send_transaction(dest, value, payload=message.body, expect_ec=expect_ec)

    def send_transaction(
            self,
            dest: ts4.Address,
            value: int,
            bounce: bool = True,
            flags: int = 1,
            payload: str = ts4.EMPTY_CELL,
            expect_ec: int = 0,
    ):
        payload_cell = ts4.Cell(payload)
        self.call_method('sendTransaction', {
            'dest': dest,
            'value': value,
            'bounce': bounce,
            'flags': flags,
            'payload': payload_cell,
        }, private_key=self.private_key_)
        ts4.dispatch_one_message(expect_ec=expect_ec)
        ts4.dispatch_messages()
