pragma ton-solidity >= 0.39.0;


contract SafeGasExecution {

    uint128 __keepBalance;

    modifier safeGasModifier() {
        _reserve(0);
        _;
        msg.sender.transfer({value: 0, flag: MsgFlags.ALL_NOT_RESERVED});
    }

    constructor(address keepBalance) public onlyRoot {
        tvm.accept();
        __keepBalance = keepBalance;
    }

    function _reserve(uint128 additional) internal {
        tvm.rawReserve(__keepBalance - msg.value + additional, 2);
    }

}
