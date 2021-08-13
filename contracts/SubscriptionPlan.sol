pragma ton-solidity >= 0.39.0;

import "./utils/SafeGasExecution.sol";


contract SubscriptionPlan is SafeGasExecution {

    uint64 static _nonce;
    address static _owner;
    address static _service;


    mapping(address => uint128) _tip3Prices;
    uint32 _duration;
    uint32 _maxPeriods;
    uint128 _limitCount;
    string _description;
    string _termUrl;
    TvmCell _userSubscriptionCode;

    bool _active;


    /*************
     * MODIFIERS *
     *************/

    modifier onlyRoot() {
        require(msg.sender == _root, Errors.IS_NOT_ROOT);
        _;
    }


    /***************
     * CONSTRUCTOR *
     ***************/

    constructor(
        mapping(address => uint128) _tip3Prices,
        uint32 _duration,
        uint32 _maxPeriods,
        uint128 _limitCount,
        string _description,
        string _termUrl,
        TvmCell _userSubscriptionCode
    ) public onlyService SafeGasExecution(Balances.SUBSCRIPTION_PLAN_BALANCE) {
        tvm.accept();
        _tip3Prices = tip3Prices;
        _duration = duration;
        _maxPeriods = maxPeriods;
        _limitCount = limitCount;
        _description = description;
        _termUrl = termUrl;
        _userSubscriptionCode = userSubscriptionCode;
        _active = true;
        // todo send message to Service about creation (or send to Root ???)
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

    function changeTip3Prices(mapping(address => uint128) tip3Prices) public onlyOwner safeGasModifier {
        _tip3Prices = tip3Prices;
    }

    function getUserSubscription(address user, uint256 pubkey) public pure returns (address) {
        TvmCell stateInit = _buildUserSubscriptionStateInit(user, pubkey);
        return _calcAddress(stateInit);
    }

    function subscribe() public {
        _subscribe(true);
    }

    function subscribeOnce() public {
        _subscribe(false);
    }

    function _subscribe(bool isAutoRenew) private {
        _reserve(0);
        TvmCell stateInit = _buildUserSubscriptionStateInit(msg.sender, msg.pubkey());
        UserSubscription userSubscription = new UserSubscription{
            stateInit : stateInit,
            value : Balances.USER_SUBSCRIPTION_BALANCE,
            flag: MsgFlags.SENDER_PAYS_FEES,
            bounce: false
        }(isAutoRenew);
        // todo calc using max period TIP3!
        uint32 extendDuration = 1;
        // todo return other tip3 value!
        userSubscription.extend{value: Balances.USER_SUBSCRIPTION_BALANCE, bounce: false}(extendDuration);
        // todo return gas?
    }

    function unsubscribe() public {
        _reserve(0);
        address userSubscription = getUserSubscription(msg.sender, msg.pubkey());
        UserSubscription(userSubscription).cancel{value: Balances.USER_SUBSCRIPTION_BALANCE}();
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
