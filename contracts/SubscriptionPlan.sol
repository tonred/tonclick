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
    address ZERO_ADDRESS;

    uint32 static _nonce;
    address static _owner;
    address static _root;
    address static _service;


    SubscriptionPlanData _data;
    mapping(address /*root*/ => uint128 /*price*/) _prices;
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
        mapping(address /*root*/ => uint128 /*price*/) prices,
        TvmCell userSubscriptionCode
    ) public onlyRoot {
        _data = data;
        _prices = prices;
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

    function getTonPrice() public view responsible returns (optional(uint128)) {
        optional(uint128) tonPrice;
        if (_prices.exists(ZERO_ADDRESS))
            tonPrice = _prices[ZERO_ADDRESS];
        return{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} tonPrice;
    }

    function getTip3Prices() public view responsible returns (mapping(address /*root*/ => uint128 /*price*/)) {
        if (_prices.exists(ZERO_ADDRESS)) {
            mapping(address => uint128) tip3Prices = _prices;
            delete tip3Prices[ZERO_ADDRESS];
            return{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} tip3Prices;
        } else {
            return{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} _prices;
        }
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

    function changeTonPrice(uint128 price) public onlyOwner safeGasModifier {
        _prices[ZERO_ADDRESS] = price;
    }

    function changeTip3Prices(mapping(address => uint128) tip3Prices) public onlyOwner minValue(Fees.USER_SUBSCRIPTION_CHANGE_TIP3_PRICE_VALUE) {
        _reserve(0);
        optional(uint128) tonPrice = getTonPrice();
        _prices = tip3Prices;
        if (tonPrice.hasValue())
            changeTonPrice(tonPrice.get());
        IServiceAddTip3Wallets(_service).addTip3Wallets{value: 0, flag: MsgFlag.ALL_NOT_RESERVED}(_nonce, tip3Prices);
    }

    function addTip3WalletsCallback() public view onlyOwner {
        _reserve(0);
        _owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
    }

    function canSubscribe() public view returns (bool) {
        return _active && (_data.limitCount == 0 || _totalUsersCount < _data.limitCount);
    }

    function isAcceptableToken(address root, uint128 amount) public view returns (bool) {
        return _prices.exists(root) && _prices[root] != 0 && amount >= _prices[root];
    }

    // called from service
    function subscribe(
        address tip3Root,
        uint128 amount,
        address sender,
        address user,
        uint256 pubkey,
        bool autoRenew
    ) public view onlyService {
        _reserve(0);
        uint128 changeAmount = amount;
        address userSubscription;
        if (canSubscribe() && isAcceptableToken(tip3Root, amount)) {
            uint128 price = _prices[tip3Root];
            uint128 extendPeriods = amount / price;
            uint32 extendDuration = uint32(math.min(2 ** 32 - 1, extendPeriods * _data.duration));
            changeAmount = amount - extendPeriods * price;
            userSubscription = _subscribe(sender, user, pubkey, autoRenew, extendDuration);
        }
        IServiceSubscribeCallback(_service)
            .subscribeCallback {
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED
            }(
                _nonce,
                tip3Root,
                sender,
                user,
                pubkey,
                changeAmount,
                userSubscription
            );
    }

    function _subscribe(
        address sender,
        address user,
        uint256 pubkey,
        bool autoRenew,
        uint32 extendDuration
    ) private view returns (address) {
        TvmCell stateInit = _buildUserSubscriptionStateInit(user, pubkey);
        UserSubscription userSubscription = new UserSubscription{
            stateInit: stateInit,
            value: Balances.USER_SUBSCRIPTION_BALANCE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false
        }(autoRenew);
        userSubscription.extend{value: Balances.USER_SUBSCRIPTION_BALANCE, bounce: false}(sender, extendDuration, autoRenew);
        return userSubscription;
    }

    // called from user subscription
    function subscribeCallback(
        address sender,
        address user,
        uint256 pubkey,
        bool firstCallback,
        bool isActivateAutoRenew
    ) public override onlyUserSubscription(user, pubkey) {
        _reserve(0);
        if (firstCallback) _totalUsersCount++;
        if (isActivateAutoRenew) _activeUsersCount++;
        sender.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
    }

    function unsubscribe(TvmCell payload) minValue(Fees.USER_SUBSCRIPTION_CANCEL_VALUE) public view {
        _reserve(0);
        (address user, uint256 pubkey) = payload.toSlice().decodeFunctionParams(buildUnsubscribePayload);
        address userSubscription = getUserSubscription(user, pubkey);
        UserSubscription(userSubscription).cancel{value: Balances.USER_SUBSCRIPTION_BALANCE}();
    }

    function buildUnsubscribePayload(address user, uint256 pubkey) public pure returns (TvmCell) {
        require(user == address(0) || pubkey == 0);
        TvmBuilder builder;
        builder.store(user, pubkey);
        return builder.toCell();
    }

    // called from user subscription
    function unsubscribeCallback(
        address user,
        uint256 pubkey,
        bool isDeactivateAutoRenew
    ) public override onlyUserSubscription(user, pubkey) {
        _reserve(0);
        if (isDeactivateAutoRenew) _activeUsersCount--;
        user.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
    }

    function getUserSubscription(address user, uint256 pubkey) public view responsible returns (address) {
        TvmCell stateInit = _buildUserSubscriptionStateInit(user, pubkey);
        return{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} _calcAddress(stateInit);
    }

    function getUserSubscriptionWithPayload(address user, uint256 pubkey, TvmCell payload) public view responsible returns (address, TvmCell) {
        address userSubscription = getUserSubscription(user, pubkey);
        return{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} (userSubscription, payload);
    }

    function _buildUserSubscriptionStateInit(address user, uint256 pubkey) private view returns (TvmCell) {
        return tvm.buildStateInit({
            contr: UserSubscription,
            varInit: {
                _subscriptionPlan: address(this),
                _user: user,
                _pubkey: pubkey
            },
            code: _userSubscriptionCode
        });
    }

    function _calcAddress(TvmCell stateInit) private pure returns (address) {
        return address.makeAddrStd(0, tvm.hash(stateInit));
    }

}
