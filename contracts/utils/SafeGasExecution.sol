pragma ton-solidity >= 0.39.0;

import "../../node_modules/@broxus/contracts/contracts/libraries/MsgFlag.sol";

abstract contract SafeGasExecution {

    uint128 __keepBalance;

    modifier safeGasModifier() {
        _reserve(0);
        _;
        msg.sender.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
    }

    function keepBalance(uint128 value) internal {
        __keepBalance = value;
    }

    function _reserve(uint128 additional) internal view {
        tvm.rawReserve(__keepBalance - msg.value + additional, 2);
    }

}
