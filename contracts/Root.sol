pragma ton-solidity >= 0.39.0;

import "./Service.sol";
import "./SubscriptionPlan.sol";
import "./utils/SafeGasExecution.sol";


contract Root is SafeGasExecution {

    address _owner;

    uint64 _serviceNonceIndex;
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


    /***************
     * CONSTRUCTOR *
     ***************/

    constructor(address owner, TvmCell serviceCode, TvmCell subscriptionPlanCode, TvmCell userSubscriptionCode) public onlyOwner {
        tvm.accept();
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

    function createService(address owner, string description, string url) public safeGasModifier {
        TvmCell stateInit = _buildServiceStateInit(_serviceNonceIndex++);
        Service service = new Service{
            stateInit : stateInit,
            value : Balances.SERVICE_BALANCE,
            flag: MsgFlags.SENDER_PAYS_FEES,
            bounce: false
        }(owner, description, url);
    }

    function _buildServiceStateInit(uint64 nonce) private view returns (TvmCell) {
        return tvm.buildStateInit({
            contr: Service,
            varInit: {
                _nonce : nonce
            },
            code : _serviceCode
        });
    }

    function createSubscriptionPlan(
        uint64 serviceNonce,
        uint64 subscriptionPlanNonce,
        ...
    ) public safeGasModifier {
        TvmCell serviceStateInit = _buildServiceStateInit(serviceNonce);
        address serviceExpectedAddress = _calcAddress(stateInit);
        require(msg.sender == serviceExpectedAddress, 6969);

        TvmCell subscriptionPlanStateInit = _buildSubscriptionPlanStateInit(subscriptionPlanNonce);
        SubscriptionPlan subscriptionPlan = new SubscriptionPlan{
            stateInit : subscriptionPlanStateInit,
            value : Balances.SUBSCRIPTION_PLAN_BALANCE,
            flag: MsgFlags.SENDER_PAYS_FEES,
            bounce: false
        }(..., _userSubscriptionCode);
    }

    function _buildSubscriptionPlanStateInit(uint64 nonce) private view returns (TvmCell) {
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
