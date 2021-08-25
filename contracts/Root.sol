pragma ton-solidity >= 0.48.0;

import "./Service.sol";
import "./SubscriptionPlan.sol";
import "./utils/SafeGasExecution.sol";
import "./interfaces/IServiceDeployedCallback.sol";
import "./interfaces/ISubscriptionsRoot.sol";

import "../node_modules/@broxus/contracts/contracts/libraries/MsgFlag.sol";
import "../node_modules/@broxus/contracts/contracts/utils/RandomNonce.sol";
import "../node_modules/@broxus/contracts/contracts/access/InternalOwner.sol";


contract Root is ISubscriptionsRoot, SafeGasExecution,  RandomNonce /*, InternalOwner*/ {

    address _owner;
    uint32 _serviceNonce;

    uint128 _feeNumerator = Constants.DEFAULT_ROOT_FEE_NUMERATOR;
    uint128 _feeDenominator = Constants.DEFAULT_ROOT_FEE_DENOMINATOR;

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
        _keepBalance = 1 ton;  // todo fix
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
        Service service = new Service {
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
        uint64 serviceNonce,  // todo use TvmCell
        uint64 subscriptionPlanNonce,
        address owner,
        address service,
        mapping(address => uint128) tip3Prices,  // second TvmCell
        uint32 duration,
        uint128 limitCount,
        string description,
        string termUrl
    ) public {
        _reserve(0);
        TvmCell serviceStateInit = _buildServiceStateInit(serviceNonce);
        address serviceExpectedAddress = _calcAddress(stateInit);
        require(msg.sender == serviceExpectedAddress, 6969);  // todo not service

        TvmCell subscriptionPlanStateInit = _buildSubscriptionPlanStateInit(subscriptionPlanNonce, owner, service);
        SubscriptionPlan subscriptionPlan = new SubscriptionPlan {
            stateInit : subscriptionPlanStateInit,
            value : Balances.SUBSCRIPTION_PLAN_BALANCE,
            flag: MsgFlags.SENDER_PAYS_FEES,
            bounce: false
        }(tip3Prices, duration, limitCount, description, termUrl, _userSubscriptionCode);
        Service(service)
            .onSubscriptionPlanCreated {
                value: 0,
                flag: MsgFlags.ALL_NOT_RESERVED,
            }(
                address(subscriptionPlan),
                tip3Prices
            );
    }

    function _buildSubscriptionPlanStateInit(uint64 nonce, address owner, address service) private view returns (TvmCell) {
        return tvm.buildStateInit({
            contr: SubscriptionPlan,
            varInit: {
                _nonce : nonce,
                _owner: owner,
                _service: service
            },
            code : _subscriptionPlanCode
        });
    }

    function _calcAddress(TvmCell stateInit) private pure returns (address) {
        return address.makeAddrStd(0, tvm.hash(stateInit));
    }

    function changeFee(uint128 numerator, uint128 denominator) public onlyOwner safeGasModifier {
        _feeNumerator = numerator;
        _feeDenominator = denominator;
    }

    function getWithdrawalParams(address tip3Root, TvmCell payload) public {
        _reserve(0);
        if (!isTip3WalletExists(tip3Root)) {
            _addTip3Wallet(tip3Root);
        }
        Service(msg.sender)
            .getWithdrawalParamsCallback {
                value: 0,
                flag: MsgFlags.ALL_NOT_RESERVED
            }(
                _feeNumerator,
                _feeDenominator,
                payload
            );
    }

}
