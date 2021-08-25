pragma ton-solidity >= 0.39.0;

import "./utils/SafeGasExecution.sol";


contract SubscriptionPlan is SafeGasExecution {

    uint64 static _nonce;
    address static _owner;
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
        uint128 _limitCount,
        string _description,
        string _termUrl,
        TvmCell _userSubscriptionCode
    ) public onlyRoot SafeGasExecution(Balances.SUBSCRIPTION_PLAN_BALANCE) {
        _reserve(0);
        _tip3Prices = tip3Prices;
        _duration = duration;
        _limitCount = limitCount;
        _description = description;
        _termUrl = termUrl;
        _userSubscriptionCode = userSubscriptionCode;
        _active = true;
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
        // todo require gas
        _reserve(0);
        Service(_service).addTip3Wallets{value: 0, flag: MsgFlags.ALL_NOT_RESERVED}(tip3Prices);
    }

    function addTip3WalletsCallback() public onlyOwner {
        _reserve(0);
        _owner.transfer({value: 0, flag: MsgFlags.ALL_NOT_RESERVED});
    }

    function canSubscribe() public view returns (bool) {
        return _active && _usersCount < _limitCount;
    }

    function isRightTip3(address root, uint128 amount) public view returns (bool) {
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
        if (canSubscribe() && !isRightTip3(tip3Root, tip3Amount)) {
            uint128 tip3Price = _tip3Prices[tip3Root];
            uint128 extendPeriods = tip3Amount / tip3Price;
            uint32 extendDuration = extendPeriods * _duration;
            _subscribe(isAutoRenew, extendDuration, user, pubkey);
            bool success = true;
            uint128 changeTip3Amount = tip3Amount - extendPeriods * tip3Price;
        } else {
            bool success = false;
            uint128 changeTip3Amount = tip3Amount;
        }
        Service(_service)
            .subscribeCallback {
                value: 0,
                flag: MsgFlags.ALL_NOT_RESERVED
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
            flag: MsgFlags.SENDER_PAYS_FEES,
            bounce: true
        }(isAutoRenew);
        _totalUsersCount++;  // if user already have a subscription, this counter will be decreased in `onBounce` step
        userSubscription.extend{value: Balances.USER_SUBSCRIPTION_BALANCE, bounce: false}(extendDuration);
    }

    function unsubscribe() public {
        _reserve(0);
        address userSubscription = getUserSubscription(msg.sender, msg.pubkey());
        UserSubscription(userSubscription).cancel{value: Balances.USER_SUBSCRIPTION_BALANCE}();
    }

    function getUserSubscription(address user, uint256 pubkey) public pure returns (address) {
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


	onBounce(TvmSlice slice) external {
		uint32 functionId = slice.decode(uint32);
		if (functionId == tvm.functionId(UserSubscription.constructor)) {
            _totalUsersCount--;
		}
	}

}
