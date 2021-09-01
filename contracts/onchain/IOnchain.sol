pragma ton -solidity >=0.39.0;

import "./Fallbacks.sol";
import "./IOnchainCallbacks.sol";
import "../Service.sol";

import "../../node_modules/@broxus/contracts/contracts/libraries/MsgFlag.sol";


struct UserData {
    address user;
    TvmCell actionPayload;
}


abstract contract IOnchain {

    address _root;
    address _service;
    address[] _subscriptionPlans;
    uint128 _minValue;

    mapping(address /*userSubscription*/ => UserData) _waitingUsers;


    constructor(address root, address service, address[] subscriptionPlans, uint128 minValue) public {
        tvm.accept();
        _root = root;
        _service = service;
        _subscriptionPlans = subscriptionPlans;
        _minValue = minValue;
    }

    function isSupportedSubscriptionPlan(address subscriptionPlans) public view returns (bool) {
        for (uint32 i = 0; i < _subscriptionPlans.length; i++)
            if (_subscriptionPlans[i] == subscriptionPlans)
                return true;
        return false;
    }

    function _checkSubscription(address subscriptionPlan, TvmCell actionPayload) internal view {
        if (msg.value < _minValue) {
            IOnchainCallbacks(msg.sender).onchainFallback{value: 0, flag: MsgFlag.REMAINING_GAS}(Fallbacks.NOT_ENOUGH_TOKENS);
            return;
        }
        if (!isSupportedSubscriptionPlan(subscriptionPlan)) {
            IOnchainCallbacks(msg.sender).onchainFallback{value: 0, flag: MsgFlag.REMAINING_GAS}(Fallbacks.UNSUPPORTED_SUBSCRIPTION_PLAN);
            return;
        }

        address user = msg.sender;
        TvmBuilder builder;
        builder.store(UserData(user, actionPayload));
        TvmCell payload = builder.toCell();
        SubscriptionPlan(subscriptionPlan)
            .getUserSubscriptionWithPayload{
                value: 0,
                flag: MsgFlag.REMAINING_GAS,
                callback: userSubscriptionCallback,
                bounce: false  // cannot be bounced
            }(user, 0, payload);
    }

    function userSubscriptionCallback(address userSubscription, TvmCell payload) public {
        require(isSupportedSubscriptionPlan(msg.sender), 999, 'Hack attempt');
        UserData userData = payload.toSlice().decode(UserData);
        _waitingUsers[userSubscription] = userData;
        UserSubscription(userSubscription)
            .isActive{
                value: 0,
                flag: MsgFlag.REMAINING_GAS,
                callback: isActiveCallback,
                bounce: true  // can be bounced
            }();
    }

    function isActiveCallback(bool active) public {
        require(_waitingUsers.exists(msg.sender), 999, 'Hack attempt');
        UserData userData = _waitingUsers[msg.sender];
        delete _waitingUsers[msg.sender];
        if (active) {
            IOnchainCallbacks(userData.user).onchainSuccess{value: 0, flag: MsgFlag.REMAINING_GAS}();
            _action(userData.user, userData.actionPayload);
        } else {
            IOnchainCallbacks(userData.user).onchainFallback{value: 0, flag: MsgFlag.REMAINING_GAS}(Fallbacks.SUBSCRIPTION_IS_EXPIRED);
        }
    }

    // this method is called after success checking, override it
    function _action(address user, TvmCell payload) internal virtual;


    onBounce(TvmSlice slice) external {
        uint32 functionId = slice.decode(uint32);
        if (functionId == tvm.functionId(UserSubscription.isActive)) {
            UserData userData = _waitingUsers[msg.sender];
            delete _waitingUsers[msg.sender];
            IOnchainCallbacks(userData.user).onchainFallback{value: 0, flag: MsgFlag.REMAINING_GAS}(Fallbacks.SUBSCRIPTION_IS_NOT_EXISTS);
            }
    }

}
