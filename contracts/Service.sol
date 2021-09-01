pragma ton-solidity >= 0.47.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "./SubscriptionPlan.sol";
import "./interfaces/root/IRootCreateSubscriptionPlan.sol";
import "./interfaces/root/IRootOnUserSubscription.sol";
import "./interfaces/root/IRootWithdrawal.sol";
import "./interfaces/service/IServiceAddTip3Wallets.sol";
import "./interfaces/service/IServiceSubscribeCallback.sol";
import "./structs/SubscriptionPlanData.sol";
import "./libraries/Balances.sol";
import "./libraries/Errors.sol";
import "./libraries/Fees.sol";
import "./utils/ITIP3Manager.sol";
import "./utils/MinValue.sol";
import "./utils/SafeGasExecution.sol";

import "../node_modules/@broxus/contracts/contracts/libraries/MsgFlag.sol";


contract Service is IServiceAddTip3Wallets, IServiceSubscribeCallback, MinValue, SafeGasExecution, ITIP3Manager {
    address ZERO_ADDRESS;

    uint32 static _nonce;
    address static _root;


    address _owner;
    string _title;
    string _description;
    string _url;

    uint32 _subscriptionPlanNonce;
    address[] _subscriptionPlans;
    mapping(address /*root*/ => uint128 /*balance*/) _virtualBalances;


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

    modifier onlySubscriptionPlan(uint32 subscriptionPlanNonce) {
        require(subscriptionPlanNonce < _subscriptionPlanNonce, Errors.IS_NOT_SUBSCRIPTION_PLAN);
        require(msg.sender == _subscriptionPlans[subscriptionPlanNonce], Errors.IS_NOT_SUBSCRIPTION_PLAN);
        _;
    }


    /**********
     * EVENTS *
     **********/

    event SubscriptionPlanCreated(address subscriptionPlan, uint32 duration);
    event Subscripted(address subscriptionPlan, address tip3Root, address sender, address user, uint256 pubkey, address userSubscription);
    event Withdrawal(address tip3Root, uint128 feeAmount, uint128 incomeAmount);


    /***************
     * CONSTRUCTOR *
     ***************/

    constructor(address owner, string title, string description, string url) public onlyRoot {
        _owner = owner;
        _title = title;
        _description = description;
        _url = url;
        keepBalance(Balances.SERVICE_BALANCE);
    }


    /***********
     * GETTERS *
     ***********/

    function getDetails() public view responsible returns (
        address owner,
        string title,
        string description,
        string url,
        uint32 subscriptionPlanNonce,
        address[] subscriptionPlans,
        mapping(address => uint128) virtualBalances
    ) {
        return {value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} (
            _owner,
            _title,
            _description,
            _url,
            _subscriptionPlanNonce,
            _subscriptionPlans,
            _virtualBalances
        );
    }

    function getSubscriptionPlanNonce() public view responsible returns (uint32) {
        return{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} _subscriptionPlanNonce;
    }

    function getSubscriptionPlans() public view responsible returns (address[]) {
        return{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} _subscriptionPlans;
    }

    function getSubscriptionPlanByIndex(uint32 index) public view responsible returns (address) {
        require(index < _subscriptionPlans.length, Errors.IS_NOT_SUBSCRIPTION_PLAN);
        return{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} _subscriptionPlans[index];
    }

    function getBalances() public view responsible returns (mapping(address => uint128)) {
        return{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} _virtualBalances;
    }

    function getOneBalance(address tip3Root) public view responsible returns (uint128) {
        uint128 balance = _virtualBalances.exists(tip3Root) ? _virtualBalances[tip3Root] : 0;
        return{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} balance;
    }

    function getTonBalance() public view responsible returns (uint128) {
        return{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} getOneBalance(ZERO_ADDRESS);
    }


    /***********
     * METHODS *
     ***********/

    function createSubscriptionPlan(
        mapping(address => uint128) tip3Prices,
        string title,
        uint32 duration,
        string description,
        string termUrl,
        uint64 limitCount
    ) public onlyOwner minValue(Fees.CREATE_SUBSCRIPTION_PLAN_VALUE) {
        _reserve(getTonBalance());
        SubscriptionPlanData data = SubscriptionPlanData(title, duration, description, termUrl, limitCount);
        uint32 subscriptionPlanNonce = _subscriptionPlanNonce++;
        IRootCreateSubscriptionPlan(_root)
            .createSubscriptionPlan {
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED
            }(
                _nonce,
                subscriptionPlanNonce,
                _owner,
                address(this),
                data,
                tip3Prices
            );
    }

    function onSubscriptionPlanCreated(
        address subscriptionPlan,
        mapping(address => uint128) prices,
        uint32 duration
    ) public onlyRoot {
        _reserve(getTonBalance());
        _deployTip3Wallets(prices);
        _subscriptionPlans.push(subscriptionPlan);
        emit SubscriptionPlanCreated(subscriptionPlan, duration);
        _owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false});
    }

    function _deployTip3Wallets(mapping(address => uint128) prices) private {
        optional(address, uint128) pair = prices.min();
        while (pair.hasValue()) {
            (address root, uint128 price) = pair.get();
            if (root != ZERO_ADDRESS && price > 0) {
                _addTip3Wallet(root);
            }
            pair = prices.next(root);
        }
    }

    function addTip3Wallets(uint32 subscriptionPlanNonce, mapping(address => uint128) tip3Prices) public override onlySubscriptionPlan(subscriptionPlanNonce) {
        _reserve(getTonBalance());
        _deployTip3Wallets(tip3Prices);
        SubscriptionPlan(msg.sender).addTip3WalletsCallback{value: 0, flag: MsgFlag.ALL_NOT_RESERVED}();
    }

    function subscribeNativeTon(TvmCell payload) public minValue(Fees.USER_SUBSCRIPTION_EXTEND_VALUE) {
        _reserve(getTonBalance());
        (uint32 subscriptionPlanNonce, address user, uint256 pubkey, bool autoRenew) = payload.toSlice()
            .decodeFunctionParams(buildSubscriptionPayload);
        require(subscriptionPlanNonce < _subscriptionPlanNonce, Errors.IS_NOT_SUBSCRIPTION_PLAN);
        uint128 amount = msg.value - Fees.USER_SUBSCRIPTION_EXTEND_VALUE;

        _virtualBalances[ZERO_ADDRESS] += amount;
        SubscriptionPlan subscriptionPlan = SubscriptionPlan(_subscriptionPlans[subscriptionPlanNonce]);
        subscriptionPlan.subscribe{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED
        }(ZERO_ADDRESS, amount, msg.sender, user, pubkey, autoRenew);
    }

    function _onTip3TokensReceived(
        address tip3Root,
        uint128 tip3Amount,
        address senderAddress,
        address senderWallet,
        TvmCell payload
    ) internal override {
        _reserve(getTonBalance());
        (uint32 subscriptionPlanNonce, address user, uint256 pubkey, bool autoRenew) = payload.toSlice()
            .decodeFunctionParams(buildSubscriptionPayload);
        if (msg.value < Fees.USER_SUBSCRIPTION_EXTEND_VALUE || subscriptionPlanNonce >= _subscriptionPlanNonce) {
            _transferTip3(tip3Root, senderWallet, tip3Amount);
            senderAddress.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
            return;
        }

        _virtualBalances[tip3Root] += tip3Amount;
        SubscriptionPlan subscriptionPlan = SubscriptionPlan(_subscriptionPlans[subscriptionPlanNonce]);
        subscriptionPlan.subscribe{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED
        }(tip3Root, tip3Amount, senderAddress, user, pubkey, autoRenew);
    }

    function buildSubscriptionPayload(
        uint32 subscriptionPlanNonce,
        address user,
        uint256 pubkey,
        bool autoRenew
    ) public pure returns (TvmCell) {
        require(user == address(0) || pubkey == 0);
        TvmBuilder builder;
        builder.store(subscriptionPlanNonce, user, pubkey, autoRenew);
        return builder.toCell();
    }

    function subscribeCallback(
        uint32 subscriptionPlanNonce,
        address tip3Root,
        address sender,
        address user,
        uint256 pubkey,
        uint128 changeAmount,
        address userSubscription
    ) public override onlySubscriptionPlan(subscriptionPlanNonce) {
        _reserve(getTonBalance());
        if (changeAmount > 0) {
            _virtualBalances[tip3Root] -= changeAmount;
            if (tip3Root == ZERO_ADDRESS) {
                sender.transfer({value: changeAmount, bounce: false});  // ton
            } else {
                _transferTip3ToRecipient(tip3Root, sender, changeAmount);  // tip3
            }
        }
        if (userSubscription != ZERO_ADDRESS) {
            IRootOnUserSubscription(_root)
                .onUserSubscription{
                    value: 2 * Balances.USER_PROFILE_BALANCE,  // for `constructor` and `addSubscription`
                    flag: MsgFlag.SENDER_PAYS_FEES
                }(_nonce, msg.sender, sender, user, pubkey);
        }
        emit Subscripted(_subscriptionPlans[subscriptionPlanNonce], tip3Root, sender, user, pubkey, userSubscription);
        sender.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
    }

    function withdrawalTonIncome() public view onlyOwner minValue(Fees.SERVICE_WITHDRAWAL_VALUE) {
        withdrawalTip3Income(ZERO_ADDRESS);
    }

    function withdrawalTip3Income(address tip3Root) public view onlyOwner minValue(Fees.SERVICE_WITHDRAWAL_VALUE) {
        _reserve(getTonBalance());
        uint128 amount = getOneBalance(tip3Root);
        require(amount > 0, Errors.SERVICE_ZERO_INCOME);
        TvmBuilder builder;
        builder.store(tip3Root, amount);
        TvmCell payload = builder.toCell();
        IRootWithdrawal(_root).getWithdrawalParams{value: 0, flag: MsgFlag.ALL_NOT_RESERVED}(payload);
    }

    function getWithdrawalParamsCallback(
        uint128 numerator,
        uint128 denominator,
        address rootOwner,
        TvmCell payload
    ) public onlyRoot {
        _reserve(getTonBalance());
        (address tip3Root, uint128 amount) = payload.toSlice().decode(address, uint128);
        if (_virtualBalances[tip3Root] < amount) {  // owner tries to make double transfer of income
            _owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false});
            tvm.exit();
        }
        uint128 feeAmount = math.muldiv(amount, numerator, denominator);
        uint128 incomeAmount = amount - feeAmount;
        if (tip3Root == ZERO_ADDRESS) {  // withdrawal ton
            if (feeAmount > 0) rootOwner.transfer({value: feeAmount, bounce: false});
            if (incomeAmount > 0) _owner.transfer({value: incomeAmount, bounce: false});
        } else {  // withdrawal tip3
            _transferTip3ToRecipient(tip3Root, rootOwner, feeAmount);
            _transferTip3ToRecipient(tip3Root, _owner, incomeAmount);
        }
        _virtualBalances[tip3Root] -= amount;
        emit Withdrawal(tip3Root, feeAmount, incomeAmount);
        _owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false});
    }

}
