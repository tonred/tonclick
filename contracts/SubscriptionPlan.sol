pragma ton-solidity >= 0.39.0;

import "./utils/SafeGasExecution.sol";
import "./utils/ITIP3Manager.sol";


contract SubscriptionPlan is SafeGasExecution, ITIP3Manager {

    uint64 static _nonce;
    address static _owner;
    address static _service;


    mapping(address => uint128) _tip3Prices;
    uint32 _duration;
    uint32 _maxPeriods;  // may be time limit (finish time)
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
        _deployTip3Wallets();
        // todo send message to Service about creation (or send to Root ???)
    }

    function _deployTip3Wallets() private {
        optional(address, uint128) pair = _tip3Prices.min();
        while (pair.hasValue()) {
            (address root, uint128 price) = pair.get();
            if (price > 0) {
                _addTip3Wallet(root);
            }
            pair = _tip3Prices.next(root);
        }
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

//    function changeTip3Prices(mapping(address => uint128) tip3Prices) public onlyOwner safeGasModifier {
//        _tip3Prices = tip3Prices;
//    }

    function buildSubscriptionPayload(bool isAutoRenew) public returns (TvmCell) {
        TvmBuilder builder;
        builder.store(isAutoRenew);
        return builder.toCell();
    }

    function _onTip3TokensReceived(
        address tip3Root,
        uint128 tip3Amount,
        uint256 senderPubkey,
        address senderAddress,
        address senderWallet,
        TvmCell payload
    ) private override {
        _reserve(0);
        if (!canSubscribe() || !_tip3Prices.exists(tip3Root) || (tip3Amount < _tip3Prices[tip3Root])) {
            _transferTip3Tokens(tip3Root, senderWallet, tip3Amount);
            senderAddress.transfer({value: 0, flag: MsgFlags.ALL_NOT_RESERVED});
            return;
        }
        bool isAutoRenew = payload.toSlice().decodeFunctionParams(buildSubscriptionPayload);
        uint128 tip3Price = _tip3Prices[tip3Root];
        uint128 extendPeriods = tip3Amount / tip3Price;
        uint32 extendDuration = extendPeriods * _duration;
        _subscribe(isAutoRenew, extendDuration, senderAddress, senderPubkey);

        uint128 changeAmount = tip3Amount - extendPeriods * tip3Price;
        _transferTip3Tokens(tip3Root, senderWallet, changeAmount);
        senderAddress.transfer({value: 0, flag: MsgFlags.ALL_NOT_RESERVED});
        // todo transfer TIP3 to Root (problem...)
    }

    function canSubscribe() public view returns (bool) {
        return _active && _usersCount < _limitCount;
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
