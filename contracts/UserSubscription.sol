pragma ton-solidity >= 0.39.0;

import "./utils/SafeGasExecution.sol";


contract UserSubscription is SafeGasExecution {

    address static _subscriptionPlan;
    address static _user;
    uint256 static _pubkey;


    bool _isAutoRenew;
    uint32 _period;
    uint32 _finishTime;


    /*************
     * MODIFIERS *
     *************/

    modifier onlySubscriptionPlan() {
        require(msg.sender == _subscriptionPlan, Errors.IS_NOT_SUBSCRIPTION_PLAN);
        _;
    }


    /***************
     * CONSTRUCTOR *
     ***************/

    constructor(uint32 period, bool isAutoRenew) public onlySubscriptionPlan SafeGasExecution(Balances.USER_SUBSCRIPTION_BALANCE) {
        tvm.accept();
        _period = period;
        _isAutoRenew = isAutoRenew;
    }


    /***********
     * GETTERS *
     ***********/

    function isActive(uint32 extendPeriod) public pure returns (bool) {
        return now <= _finishTime;
    }


    /***********
     * METHODS *
     ***********/

    function extend(uint32 extendDuration) public onlySubscriptionPlan safeGasModifier {
        if (isActive()) {
            _finishTime += extendDuration;
        } else {
            _finishTime = now + extendDuration;
        }
    }

    function cancel() public onlySubscriptionPlan safeGasModifier {
        _isAutoRenew = false;
    }

}
