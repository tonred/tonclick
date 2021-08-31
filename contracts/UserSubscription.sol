pragma ton-solidity >= 0.39.0;

import "./interfaces/subscription_plan/ISubscriptionPlanCallbacks.sol";
import "./libraries/Balances.sol";
import "./libraries/Errors.sol";
import "./utils/SafeGasExecution.sol";


contract UserSubscription is SafeGasExecution {

    address static _subscriptionPlan;
    address static _user;
    uint256 static _pubkey;


    bool _autoRenew;
    uint32 _finishTime;
    bool _firstCallback;


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

    constructor(bool autoRenew) public onlySubscriptionPlan {
        tvm.accept();
        _autoRenew = autoRenew;
        _firstCallback = true;
        keepBalance(Balances.USER_SUBSCRIPTION_BALANCE);
    }


    /***********
     * GETTERS *
     ***********/

    function getUser() public view responsible returns (address) {
        return{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} _user;
    }

    function getPubkey() public view responsible returns (uint256) {
        return{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} _pubkey;
    }


    /***********
     * METHODS *
     ***********/

    function isAutoRenew() public view responsible returns (bool) {
        return{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} _autoRenew;
    }

    function isActive() public view responsible returns (bool) {
        return{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} now <= _finishTime;
    }

    function getFinishTime() public view responsible returns (uint32) {
        return{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} _finishTime;
    }

    function extend(address sender, uint32 extendDuration, bool autoRenew) public onlySubscriptionPlan {
        _reserve(0);
        bool isActivateAutoRenew = (!_autoRenew || _firstCallback) && autoRenew;
        _autoRenew = autoRenew;
        _extend(extendDuration);
        ISubscriptionPlanCallbacks(_subscriptionPlan)
            .subscribeCallback{
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED
            }(
                sender,
                _user,
                _pubkey,
                _firstCallback,
                isActivateAutoRenew
            );
        _firstCallback = false;
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
        bool isDeactivateAutoRenew = _autoRenew;
        _autoRenew = false;
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
