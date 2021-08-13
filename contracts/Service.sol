pragma ton-solidity >= 0.39.0;

import "./utils/SafeGasExecution.sol";


contract Service is SafeGasExecution {

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


    /***********
     * METHODS *
     ***********/

    function createSubscriptionPlan(...) public onlyOwner safeGasModifier {
        uint64 subscriptionPlanNonce = _subscriptionPlanNonceIndex++;
        Root(_root).createSubscriptionPlan{

        }(
            _nonce,
            subscriptionPlanNonce,
            ...
        );
    }

    function onSubscriptionPlanCreated(...) public {
        // todo check sender (is it possible ?!)
        _subscriptionPlans.push(msg.sender);
    }

}
