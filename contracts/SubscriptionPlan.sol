pragma ton-solidity >= 0.39.0;

import "./UserSubscription.sol";
import "./interfaces/service/IServiceAddTip3Wallets.sol";
import "./interfaces/service/IServiceSubscribeCallback.sol";
import "./libraries/Balances.sol";
import "./libraries/Fees.sol";
import "./libraries/Errors.sol";
import "./utils/MinValue.sol";
import "./utils/SafeGasExecution.sol";


contract SubscriptionPlan is MinValue, SafeGasExecution {

    uint32 static _nonce;
    address static _owner;
    address static _root;
    address static _service;


    mapping(address => uint128) _tip3Prices;
    uint32 _duration;
//    uint32 _maxPeriods;  // may be time limit (finish time)
    uint128 _limitCount;
    string _description;
    string _termUrl;
    TvmCell _userSubscriptionCode;

    bool _active;
    uint128 _totalUsersCount;


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


    /***************
     * CONSTRUCTOR *
     ***************/

    constructor(
        mapping(address => uint128) tip3Prices,
        uint32 duration,
        uint128 limitCount,
        string description,
        string termUrl,
        TvmCell userSubscriptionCode
    ) public onlyRoot {
        _tip3Prices = tip3Prices;
        _duration = duration;
        _limitCount = limitCount;
        _description = description;
        _termUrl = termUrl;
        _userSubscriptionCode = userSubscriptionCode;
        _active = true;
        keepBalance(Balances.SUBSCRIPTION_PLAN_BALANCE);
    }


    /***********
     * GETTERS *
     ***********/


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
        return _active && _totalUsersCount < _limitCount;
    }

    function isAcceptableTip3(address root, uint128 amount) public view returns (bool) {
        return _tip3Prices.exists(root) && amount >= _tip3Prices[root];
    }

    function subscribe(
        address tip3Root,
        uint128 tip3Amount,
        uint256 senderPubkey,
        address senderAddress,
        address senderWallet,
        bool isAutoRenew
    ) public onlyService {
        _reserve(0);
        bool success = false;
        uint128 changeTip3Amount = tip3Amount;
        if (canSubscribe() && !isAcceptableTip3(tip3Root, tip3Amount)) {
            uint128 tip3Price = _tip3Prices[tip3Root];
            uint128 extendPeriods = tip3Amount / tip3Price;
            uint32 extendDuration = uint32(extendPeriods * _duration);  // todo uint128 max value
            _subscribe(isAutoRenew, extendDuration, senderAddress, senderPubkey);  // todo user, pubkey
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

    function _subscribe(bool isAutoRenew, uint32 extendDuration, address user, uint256 pubkey) private {
        TvmCell stateInit = _buildUserSubscriptionStateInit(user, pubkey);
        UserSubscription userSubscription = new UserSubscription{
            stateInit : stateInit,
            value : Balances.USER_SUBSCRIPTION_BALANCE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false
        }(isAutoRenew);
        _totalUsersCount++;  // if user already have a subscription, this counter will be decreased in `onBounce` step
        userSubscription.extend{value: Balances.USER_SUBSCRIPTION_BALANCE, bounce: false}(extendDuration);  // todo callback and _totalUsersCount--
    }

    function unsubscribe() public view {
        _reserve(0);
        address userSubscription = getUserSubscription(msg.sender, msg.pubkey());  // todo shit user-pubkey
        UserSubscription(userSubscription).cancel{value: Balances.USER_SUBSCRIPTION_BALANCE}();
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
