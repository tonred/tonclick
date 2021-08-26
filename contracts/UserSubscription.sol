pragma ton-solidity >= 0.39.0;

import "./libraries/Balances.sol";
import "./libraries/Errors.sol";
import "./utils/SafeGasExecution.sol";


contract UserSubscription is SafeGasExecution {

    address static _subscriptionPlan;
    address static _user;
    uint256 static _pubkey;


    bool _isAutoRenew;
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

    constructor(bool isAutoRenew) public onlySubscriptionPlan {
        tvm.accept();
        _isAutoRenew = isAutoRenew;
        keepBalance(Balances.USER_SUBSCRIPTION_BALANCE);
    }


    /***********
     * GETTERS *
     ***********/


    /***********
     * METHODS *
     ***********/

    function isActive() public view returns (bool) {
        return now <= _finishTime;
    }

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
