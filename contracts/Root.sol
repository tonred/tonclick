pragma ton-solidity >= 0.48.0;

import "./Service.sol";
import "./SubscriptionPlan.sol";
import "./libraries/Balances.sol";
import "./libraries/Constants.sol";
import "./libraries/Errors.sol";
import "./utils/MinValue.sol";
import "./utils/SafeGasExecution.sol";
import "./interfaces/root/IRootCreateSubscriptionPlan.sol";
import "./interfaces/root/IRootWithdrawal.sol";

import "../node_modules/@broxus/contracts/contracts/libraries/MsgFlag.sol";
import "../node_modules/@broxus/contracts/contracts/utils/RandomNonce.sol";
import "../node_modules/@broxus/contracts/contracts/access/InternalOwner.sol";


contract Root is IRootCreateSubscriptionPlan, IRootWithdrawal, MinValue, SafeGasExecution,  RandomNonce /*, InternalOwner*/ {

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
        require(serviceNonce < _serviceNonce, Errors.IS_NOT_SERVICE);
        TvmCell serviceStateInit = _buildServiceStateInit(serviceNonce);
        require(msg.sender == _calcAddress(serviceStateInit), Errors.IS_NOT_SERVICE);
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
    ) public {
        tvm.accept();
        _owner = owner;
        _serviceCode = serviceCode;
        _subscriptionPlanCode = subscriptionPlanCode;
        _userSubscriptionCode = userSubscriptionCode;
        keepBalance(Balances.ROOT_BALANCE);
    }


    /***********
     * GETTERS *
     ***********/


    /***********
     * METHODS *
     ***********/

    function createService(
        address owner,
        string description,
        string url
    ) public minValue(Fees.CREATE_SERVICE_VALUE) safeGasModifier {
        TvmCell stateInit = _buildServiceStateInit(_serviceNonce++);
        new Service {
            stateInit : stateInit,
            value : Balances.SERVICE_BALANCE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false
        }(owner, description, url);
        // todo callback that service is created
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

    function createSubscriptionPlan(
        uint32 serviceNonce,  // todo use TvmCell
        uint32 subscriptionPlanNonce,
        address owner,
        address service,
        mapping(address => uint128) tip3Prices,  // todo second TvmCell
        uint32 duration,
        uint128 limitCount,
        string description,
        string termUrl
    ) public override onlyService(serviceNonce) {
        _reserve(0);
        TvmCell subscriptionPlanStateInit = _buildSubscriptionPlanStateInit(subscriptionPlanNonce, owner, service);
        SubscriptionPlan subscriptionPlan = new SubscriptionPlan {
            stateInit : subscriptionPlanStateInit,
            value : Balances.SUBSCRIPTION_PLAN_BALANCE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false
        }(tip3Prices, duration, limitCount, description, termUrl, _userSubscriptionCode);
        Service(service)
            .onSubscriptionPlanCreated {
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED
            }(
                address(subscriptionPlan),
                tip3Prices
            );
    }

    function _buildSubscriptionPlanStateInit(uint32 nonce, address owner, address service) private view returns (TvmCell) {
        return tvm.buildStateInit({
            contr: SubscriptionPlan,
            varInit: {
                _nonce : nonce,
                _owner: owner,
                _root: address(this),
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

    function getWithdrawalParams(TvmCell payload) public override {
        _reserve(0);
        Service(msg.sender)
            .getWithdrawalParamsCallback {
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED
            }(
                _feeNumerator,
                _feeDenominator,
                payload
            );
    }

}
