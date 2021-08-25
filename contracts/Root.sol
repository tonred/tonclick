pragma ton-solidity >= 0.48.0;

import "./Service.sol";
import "./SubscriptionPlan.sol";
import "./utils/SafeGasExecution.sol";
import "./interfaces/IServiceDeployedCallback.sol";
import "./interfaces/ISubscriptionsRoot.sol";

import "../node_modules/@broxus/contracts/contracts/libraries/MsgFlag.sol";
import "../node_modules/@broxus/contracts/contracts/utils/RandomNonce.sol";
import "../node_modules/@broxus/contracts/contracts/access/InternalOwner.sol";


contract SubscriptionsRoot is ISubscriptionsRoot, SafeGasExecution,  RandomNonce /*, InternalOwner*/ {

    address _owner;

    uint32 _serviceNonce;
    TvmCell _serviceCode;
    TvmCell _subscriptionPlanCode;
    TvmCell _userSubscriptionCode;


    /*************
     * MODIFIERS *
     *************/

    modifier onlyOwner() {
        require(msg.sender == _owner, Errors.IS_NOT_OWNER);
        _;
    }

    modifier onlyService(uint32 serviceNonce) {
        require(serviceNonce <= _serviceNonce, 999);
        TvmCell serviceStateInit = _buildServiceStateInit(serviceNonce);
        require(msg.sender == _calcAddress(stateInit), 999);
        _;
    }

    /***************
     * CONSTRUCTOR *
     ***************/

    constructor(
        address owner,
        TvmCell serviceCode,
        TvmCell subscriptionPlanCode,
        TvmCell userSubscriptionCode
    ) public onlyOwner {
        tvm.accept();
        _keepBalance = 1 ton;
        _owner = owner;
        _serviceCode = serviceCode;
        _subscriptionPlanCode = subscriptionPlanCode;
        _userSubscriptionCode = userSubscriptionCode;
    }


    /***********
     * GETTERS *
     ***********/


    /***********
     * METHODS *
     ***********/

    function createService(string description, string url) public override {
        // todo checks
        _reserve(0);
        TvmCell stateInit = _buildServiceStateInit(_serviceNonce);
        Service service = new Service{
            stateInit: stateInit,
            value: Balances.SERVICE_BALANCE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false
        }(msg.sender, description, url);
        IServiceDeployedCallback(msg.sender).onServiceDeployed{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED
        }(service, _serviceNonce);
        _serviceNonce++;
    }

    function createSubscriptionPlan(
        uint32 serviceNonce,
        uint64 subscriptionPlanNonce
        /*...*/
    ) public override returnChange onlyService(serviceNonce) {

        TvmCell subscriptionPlanStateInit = _buildSubscriptionPlanStateInit(subscriptionPlanNonce);
        SubscriptionPlan subscriptionPlan = new SubscriptionPlan{
            stateInit : subscriptionPlanStateInit,
            value : Balances.SUBSCRIPTION_PLAN_BALANCE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false
        }(/*...,*/ _userSubscriptionCode);
    }

    function _buildServiceStateInit(uint32 nonce) private view returns (TvmCell) {
        return tvm.buildStateInit({
            contr: Service,
            varInit: {
                _nonce : nonce
            },
            code : _serviceCode
        });
    }

    function _buildSubscriptionPlanStateInit(uint32 nonce) private view returns (TvmCell) {
        return tvm.buildStateInit({
            contr: SubscriptionPlan,
            varInit: {
                _nonce : nonce
            },
            code : _subscriptionPlanCode
        });
    }

    function _calcAddress(TvmCell stateInit) private pure returns (address) {
        return address.makeAddrStd(0, tvm.hash(stateInit));
    }

}
