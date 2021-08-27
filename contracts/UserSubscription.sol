pragma ton-solidity >= 0.39.0;

import "./interfaces/subscription_plan/ISubscriptionPlanCallbacks.sol";
import "./libraries/Balances.sol";
import "./libraries/Errors.sol";
import "./utils/SafeGasExecution.sol";


contract UserSubscription is SafeGasExecution {

    address static _subscriptionPlan;
    address static _user;
    uint256 static _pubkey;


    bool _isAutoRenew;
    uint32 _finishTime;
    bool _isFirstCallback;


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
        _isFirstCallback = true;
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

    function extend(uint32 extendDuration, bool isAutoRenew) public onlySubscriptionPlan {
        _reserve(0);
        bool isActivateAutoRenew = (!_isAutoRenew || _isFirstCallback) && isAutoRenew;
        _isAutoRenew = isAutoRenew;
        _extend(extendDuration);
        ISubscriptionPlanCallbacks(_subscriptionPlan)
            .subscribeCallback{
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED
            }(
                _user,
                _pubkey,
                _isFirstCallback,
                isActivateAutoRenew
            );
        _isFirstCallback = false;
    }

    function _extend(uint32 extendDuration) private {
        if (isActive()) {
            _finishTime += extendDuration;
        } else {
            _finishTime = now + extendDuration;
        }
    }

    function cancel() public onlySubscriptionPlan {
        _reserve(0);
        bool isDeactivateAutoRenew = _isAutoRenew;
        _isAutoRenew = false;
        ISubscriptionPlanCallbacks(_subscriptionPlan)
            .unsubscribeCallback{
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED
            }(
                _user,
                _pubkey,
                isDeactivateAutoRenew
            );
    }

}
