pragma ton-solidity >= 0.39.0;

import "./UserSubscription.sol";
import "./interfaces/service/IServiceAddTip3Wallets.sol";
import "./interfaces/service/IServiceSubscribeCallback.sol";
import "./interfaces/subscription_plan/ISubscriptionPlanCallbacks.sol";
import "./structs/SubscriptionPlanData.sol";
import "./libraries/Balances.sol";
import "./libraries/Fees.sol";
import "./libraries/Errors.sol";
import "./utils/MinValue.sol";
import "./utils/SafeGasExecution.sol";


contract SubscriptionPlan is ISubscriptionPlanCallbacks, MinValue, SafeGasExecution {

    uint32 static _nonce;
    address static _owner;
    address static _root;
    address static _service;

    SubscriptionPlanData _data;
    mapping(address /*root*/ => uint128 /*price*/) _tip3Prices;
    TvmCell _userSubscriptionCode;

    bool _active;
    uint64 _totalUsersCount;
    uint64 _activeUsersCount;


    /*************
     * MODIFIERS *
     *************/

    modifier onlyOwner() {
        require(msg.sender == _owner, Errors.IS_NOT_OWNER);
        _;
    }

    modifier onlyRoot() {
        require(msg.sender == _root, Errors.IS_NOT_ROOT);
        _;
    }

    modifier onlyService() {
        require(msg.sender == _service, Errors.IS_NOT_SERVICE);
        _;
    }

    modifier onlyUserSubscription(address user, uint256 pubkey) {
        address userSubscription = getUserSubscription(user, pubkey);
        require(msg.sender == userSubscription, Errors.IS_NOT_USER_SUBSCRIPTION);
        _;
    }


    /***************
     * CONSTRUCTOR *
     ***************/

    constructor(
        SubscriptionPlanData data,
        mapping(address /*root*/ => uint128 /*price*/) tip3Prices,
        TvmCell userSubscriptionCode
    ) public onlyRoot {
        _data = data;
        _tip3Prices = tip3Prices;
        _userSubscriptionCode = userSubscriptionCode;
        _active = true;
        keepBalance(Balances.SUBSCRIPTION_PLAN_BALANCE);
    }


    /***********
     * GETTERS *
     ***********/

    function getInfo() public view responsible returns (SubscriptionPlanData) {
        return{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} _data;
    }

    function getTip3Prices() public view responsible returns (mapping(address /*root*/ => uint128 /*price*/)) {
        return{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} _tip3Prices;
    }

    function getTotalUsersCount() public view responsible returns (uint64) {
        return{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} _totalUsersCount;
    }

    function getActiveUsersCount() public view responsible returns (uint64) {
        return{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} _activeUsersCount;
    }


    /***********
     * METHODS *
     ***********/

    function activate() public onlyOwner safeGasModifier {
        _active = true;
    }

    function deactivate() public onlyOwner safeGasModifier {
        _active = false;
    }


    function changeTip3Prices(mapping(address => uint128) tip3Prices) public view onlyOwner minValue(Fees.USER_SUBSCRIPTION_CHANGE_TIP3_PRICE_VALUE) {
        _reserve(0);
        IServiceAddTip3Wallets(_service).addTip3Wallets{value: 0, flag: MsgFlag.ALL_NOT_RESERVED}(_nonce, tip3Prices);
    }

    function addTip3WalletsCallback() public view onlyOwner {
        _reserve(0);
        _owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
    }

    function canSubscribe() public view returns (bool) {
        return _active && _totalUsersCount < _data.limitCount;
    }

    function isAcceptableTip3(address root, uint128 amount) public view returns (bool) {
        return _tip3Prices.exists(root) && amount >= _tip3Prices[root];
    }

    function subscribe(
        address tip3Root,
        uint128 tip3Amount,
        address senderAddress,
        address senderWallet,
        uint256 pubkey,
        bool autoRenew
    ) public view onlyService {
        _reserve(0);
        bool success = false;
        uint128 changeTip3Amount = tip3Amount;
        if (canSubscribe() && isAcceptableTip3(tip3Root, tip3Amount)) {
            uint128 tip3Price = _tip3Prices[tip3Root];
            uint128 extendPeriods = tip3Amount / tip3Price;
            uint32 extendDuration = uint32(extendPeriods * _data.duration);  // todo uint128 max value
            _subscribe(senderAddress, pubkey, autoRenew, extendDuration);
            success = true;
            changeTip3Amount = tip3Amount - extendPeriods * tip3Price;
        }
        IServiceSubscribeCallback(_service)
            .subscribeCallback {
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED
            }(
                _nonce,
                tip3Root,
                senderWallet,
                senderAddress,
                success,
                changeTip3Amount
            );
    }

    function _subscribe(address user, uint256 pubkey, bool autoRenew, uint32 extendDuration) private view {
        TvmCell stateInit = _buildUserSubscriptionStateInit(user, pubkey);
        UserSubscription userSubscription = new UserSubscription{
            stateInit : stateInit,
            value : Balances.USER_SUBSCRIPTION_BALANCE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false
        }(autoRenew);
        userSubscription.extend{value: Balances.USER_SUBSCRIPTION_BALANCE, bounce: false}(extendDuration, autoRenew);
    }

    function subscribeCallback(
        address user,
        uint256 pubkey,
        bool firstCallback,
        bool isActivateAutoRenew
    ) public override onlyUserSubscription(user, pubkey) {
        _reserve(0);
        if (firstCallback) _totalUsersCount++;
        if (isActivateAutoRenew) _activeUsersCount++;
        user.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
    }

    function unsubscribe(TvmCell payload) minValue(Fees.USER_SUBSCRIPTION_CANCEL_VALUE) public view {
        _reserve(0);
        (address user, uint256 pubkey) = payload.toSlice().decodeFunctionParams(buildUnsubscribePayload);
        address userSubscription = getUserSubscription(user, pubkey);
        UserSubscription(userSubscription).cancel{value: Balances.USER_SUBSCRIPTION_BALANCE}();
    }

    function unsubscribeCallback(
        address user,
        uint256 pubkey,
        bool isDeactivateAutoRenew
    ) public override onlyUserSubscription(user, pubkey) {
        _reserve(0);
        if (isDeactivateAutoRenew) _activeUsersCount--;
        user.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
    }

    function buildUnsubscribePayload(address user, uint256 pubkey) public pure returns (TvmCell) {
        TvmBuilder builder;
        builder.store(user, pubkey);
        return builder.toCell();
    }

    function getUserSubscription(address user, uint256 pubkey) public view returns (address) {
        TvmCell stateInit = _buildUserSubscriptionStateInit(user, pubkey);
        return _calcAddress(stateInit);
    }

    function _buildUserSubscriptionStateInit(address user, uint256 pubkey) private view returns (TvmCell) {
        return tvm.buildStateInit({
            contr: UserSubscription,
            varInit: {
                _subscriptionPlan : address(this),
                _user : user,
                _pubkey: pubkey
            },
            code : _userSubscriptionCode
        });
    }

    function _calcAddress(TvmCell stateInit) private pure returns (address) {
        return address.makeAddrStd(0, tvm.hash(stateInit));
    }

}
