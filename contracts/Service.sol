pragma ton-solidity >= 0.39.0;

import "./utils/SafeGasExecution.sol";
import "./utils/ITIP3Manager.sol";


contract Service is SafeGasExecution, ITIP3Manager {

    static uint64 _nonce;
    static uint64 _root;


    address _owner;
    string _description;
    string _url;

    address[] _subscriptionPlans;
    uint64 _subscriptionPlanNonceIndex;
    mapping(address => uint128) _virtualBalances;


    /*************
     * MODIFIERS *
     *************/

    modifier onlyRoot() {
        require(msg.sender == _root, Errors.IS_NOT_ROOT);
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, Errors.IS_NOT_OWNER);
        _;
    }


    /***************
     * CONSTRUCTOR *
     ***************/

    constructor(address owner, string description, string url) public onlyRoot {
        tvm.accept();
        _owner = owner;
        _description = description;
        _url = url;
    }


    /***********
     * GETTERS *
     ***********/

    function getTip3Balances() public returns(mapping(address => uint128)) {
        return _virtualBalances;
    }

    function getTip3Balance(address root) public returns(uint128) {
        if (_virtualBalances.exists(root)) {
            return _virtualBalances[root];
        } else {
            return 0;
        }
    }


    /***********
     * METHODS *
     ***********/

    function createSubscriptionPlan(
        mapping(address => uint128) _tip3Prices,
        uint32 _duration,
        uint128 _limitCount,
        string _description,
        string _termUrl
    ) public onlyOwner {
        _reserve(0);
        uint64 subscriptionPlanNonce = _subscriptionPlanNonceIndex++;
        Root(_root)
            .createSubscriptionPlan {
                value: 0,
                flag: MsgFlags.ALL_NOT_RESERVED
            }(
                _nonce,
                subscriptionPlanNonce,
                _owner,
                address(this),
                _tip3Prices,
                _duration,
                _limitCount,
                _description,
                _termUrl
            );
    }

    function onSubscriptionPlanCreated(
        address subscriptionPlan,
        mapping(address => uint128) tip3Prices
    ) public {
        _reverse(0);
        require(msg.sender == _root, Errors.IS_NOT_ROOT);
        _deployTip3Wallets(tip3Prices);
        _subscriptionPlans.push(subscriptionPlan);
        _owner.transfer({value: 0, flag: MsgFlags.ALL_NOT_RESERVED, bounce: false});
    }

    function isSubscriptionPlan(address sender, uint64 subscriptionPlanNonce) public returns (bool) {
        return sender == _subscriptionPlans[subscriptionPlanNonce];
    }

    function _deployTip3Wallets(mapping(address => uint128) tip3Prices) private {
        optional(address, uint128) pair = tip3Prices.min();
        while (pair.hasValue()) {
            (address root, uint128 price) = pair.get();
            _addTip3Wallet(root);
            pair = _tip3Prices.next(root);
        }
    }

    function addTip3Wallets(mapping(address => uint128) tip3Prices) public {
        _reverse(0);
        require(isSubscriptionPlan(msg.sender, subscriptionPlanNonce), Errors.IS_NOT_SUBSCRIPTION_PLAN);
        _deployTip3Wallets(tip3Prices);
        SubscriptionPlans(msg.sender).addTip3WalletsCallback{value: 0, flag: MsgFlags.ALL_NOT_RESERVED}();
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
        // todo require gas
        (uint64 subscriptionPlanNonce, bool isAutoRenew) = payload.toSlice().decodeFunctionParams(buildSubscriptionPayload);
        if (subscriptionPlanNonce >= _subscriptionPlanNonceIndex) {  // wrong nonce
            _transferTip3Tokens(tip3Root, senderWallet, tip3Amount);
            senderAddress.transfer({value: 0, flag: MsgFlags.ALL_NOT_RESERVED});
            return;
        }

        _virtualBalances[tip3Root] += tip3Amount;
        SubscriptionPlan subscriptionPlan = SubscriptionPlan(_subscriptionPlans[subscriptionPlanNonce]);
        subscriptionPlan.subscribe{
            value: 0,
            flag: MsgFlags.ALL_NOT_RESERVED
        }(tip3Root, tip3Amount, senderPubkey, senderAddress, senderWallet, isAutoRenew);
    }

    function buildSubscriptionPayload(uint64 subscriptionPlanNonce, bool isAutoRenew) public returns (TvmCell) {
        TvmBuilder builder;
        builder.store(planNonce, isAutoRenew);
        return builder.toCell();
    }

    function subscribeCallback(
        uint64 subscriptionPlanNonce,
        address tip3Root,
        address senderWallet,
        address senderAddress,
        bool success,
        uint128 changeTip3Amount
    ) public {
        require(isSubscriptionPlan(msg.sender, subscriptionPlanNonce), Errors.IS_NOT_SUBSCRIPTION_PLAN);
        _reserve(0);
        _virtualBalances[tip3Root] -= changeTip3Amount;
        _transferTip3Tokens(tip3Root, senderWallet, changeTip3Amount);
        senderAddress.transfer({value: 0, flag: MsgFlags.ALL_NOT_RESERVED});
    }

    function withdrawalTip3Income(address tip3Root) public onlyOwner {
        // todo min gas 2
        _reserve(0);
        uint128 tip3Amount = getTip3Balance(root);
        require(tip3Amount > 0, Errors.SERVICE_ZERO_TIP3_TOKENS);
        TvmBuilder builder;
        builder.store(tip3Root, tip3Amount);
        TvmCell payload = builder.toCell();
        Root(_root).getWithdrawalParams{value: 0, flag: MsgFlags.ALL_NOT_RESERVED}(tip3Root, payload);
    }

    function getWithdrawalParamsCallback(
        uint128 numerator,
        uint128 denominator,
        TvmCell payload
    ) public onlyRoot {
        _reserve(0);
        (address tip3Root, uint128 tip3Amount) = payload.toSlice().decode();
        if (_virtualBalances[tip3Root] < tip3Amount) {  // owner tries to make double transfer of income
            _owner.transfer({value: 0, flag: MsgFlags.ALL_NOT_RESERVED, bounce: false});
            tvm.exit();
        }
        uint128 feeTip3Amount = math.muldiv(tip3Amount, numerator, denominator);
        uint128 incomeTip3Amount = tip3Amount - feeTip3Amount;
        _transferTip3TokensWithDeploy(tip3Root, _root, feeTip3Amount);
        _transferTip3TokensWithDeploy(tip3Root, _owner, incomeTip3Amount);
        _virtualBalances[tip3Root] -= tip3Amount;
        _owner.transfer({value: 0, flag: MsgFlags.ALL_NOT_RESERVED, bounce: false});
    }

}
