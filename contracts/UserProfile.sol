pragma ton-solidity >= 0.39.0;

import "./libraries/Balances.sol";
import "./libraries/Errors.sol";
import "./utils/SafeGasExecution.sol";

import "../node_modules/@broxus/contracts/contracts/libraries/MsgFlag.sol";


contract UserProfile is SafeGasExecution {

    address static _root;
    address static _user;
    uint256 static _pubkey;


    uint32 _subscriptionsCount;
    mapping(address /*user subscription*/ => bool) _subscriptions;


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

    constructor() public onlyRoot {
        tvm.accept();
        keepBalance(Balances.USER_PROFILE_BALANCE);
    }


    /***********
     * GETTERS *
     ***********/

    function getUser() public view responsible returns (address) {
        return{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} _user;
    }

    function getPubkey() public view responsible returns (uint256) {
        return{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} _pubkey;
    }

    function getSubscriptionsCount() public view responsible returns (uint128) {
        return{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} _subscriptionsCount;
    }

    function getSubscriptions() public view responsible returns (mapping(address /*user subscription*/ => bool)) {
        return{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} _subscriptions;
    }


    /***********
     * METHODS *
     ***********/

    function addSubscription(address userSubscription, address sendGasTo) public onlyRoot {
        _reserve(0);
        if (!_subscriptions.exists(userSubscription)) {
            _subscriptions[userSubscription] = true;
            _subscriptionsCount++;
        }
        sendGasTo.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
    }

}
