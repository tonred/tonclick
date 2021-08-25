pragma ton-solidity >= 0.48.0;

import "./utils/SafeGasExecution.sol";
import "./libraries/Errors.sol";
import "./libraries/Fees.sol";
import "./interfaces/ISubscriptionsRoot.sol";

import "../node_modules/@broxus/contracts/contracts/libraries/MsgFlag.sol";


contract Service is SafeGasExecution {

    uint32 static _nonce;
    address static _root;


    address _owner;
    string _description;
    string _url;

    uint32 _subscriptionPlanNonce;
    address[] _subscriptionPlans;
    mapping(address /*root*/ => address /*wallet*/) _wallets;
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
        _owner = owner;
        _description = description;
        _url = url;
        keepBalance(address(this).balance);
    }


    /***********
     * GETTERS *
     ***********/

    function getSubscriptionPlanNonce() public responsible returns (uint32){
        return{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} _subscriptionPlanNonce;
    }

    function getSubscriptionPlans() public responsible returns (address[]){
        return{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} _subscriptionPlans;
    }

    function getBalances() public responsible returns (mapping(address => uint128)){
        return{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} _virtualBalances;
    }

    function getWallets() public responsible returns (mapping(address => address)){
        return{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} _wallets;
    }


    /***********
     * METHODS *
     ***********/

    function createSubscriptionPlan(
        mapping(address => uint128) prices
    ) public onlyOwner safeGasModifier {
        require(msg.value >= Fees.CREATE_SUBSCRIPTION_PLAN_VALUE, 999);
        require(!prices.empty(), 999);
        _reserve(0);

        optional(address, uint128) price = prices.min();
        while (price.hasValue()) {
            (address token, uint128 priceValue) = price.get();
            if (!_wallets.exists(token)){
//                _createWallets(token);
                _wallets[token] = address(0);
                _virtualBalances[token] = 0;
            }
            price = prices.next(token);
        }
        ISubscriptionsRoot(_root).createSubscriptionPlan(
            _nonce,
            _subscriptionPlanNonce
//            prices
            /*...*/
        );
        _subscriptionPlanNonce++;
    }

    function onSubscriptionPlanCreated(/*...*/) public {
        // todo check sender (is it possible ?!)
        _subscriptionPlans.push(msg.sender);
    }

}
