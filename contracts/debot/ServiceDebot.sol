pragma ton-solidity >= 0.35.0;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "base/Debot.sol";
import "base/Terminal.sol";
import "base/Upgradable.sol";
import "base/Menu.sol";
import "base/AddressInput.sol";
import "base/AmountInput.sol";
import "base/Sdk.sol";
import "base/UserInfo.sol";
import "base/ConfirmInput.sol";


import "../Root.sol";
import "../Service.sol";
import "../SubscriptionPlan.sol";
import "../libraries/Fees.sol";
import "../structs/SubscriptionPlanData.sol";

import "../../node_modules/@broxus/contracts/contracts/utils/RandomNonce.sol";
import "../../node_modules/@broxus/contracts/contracts/utils/CheckPubKey.sol";

interface IMultisig {
    function sendTransaction(
        address dest,
        uint128 value,
        bool bounce,
        uint8 flags,
        TvmCell payload
    ) external;
}

contract ServiceDebot is Debot, Upgradable, RandomNonce, CheckPubKey {
    struct ServiceData {
        bool loggedIn;
        address account;
        uint32 id;
        string name;
        string description;
        string url;
        address[] plans;
        mapping(address => uint128) balances;
        uint32 maxId;
        uint32 planNonce;

    }
    struct SubscriptionData {
        address account;
        string name;
        string description;
        uint32 duration;
        string termUrl;
        mapping(address => uint128) prices;
        uint64 limitCount;
    }
    bytes m_icon;
    optional(uint256) pubkey;

    address m_account;

    address m_root;
    uint32 m_serviceNonce;

    TvmCell m_serviceCode;
    TvmCell m_subscriptionPlanCode;
    TvmCell m_userSubscriptionCode;
    uint m_serviceCodeHash;
    uint m_subscriptionPlanCodeHash;
    uint m_userSubscriptionCodeHash;

    address m_activeRootAddress;
    uint32 m_activeSubscription;

    ServiceData m_serviceData;
    SubscriptionData m_subscriptionData;

    SubscriptionPlanData[] m_subscriptions;

    /************************
     * Base debot functions *
     ************************/

    function getDebotInfo() public functionID(0xDEB) override view returns(
        string name, string version, string publisher, string caption, string author,
        address support, string hello, string language, string dabi, bytes icon
    ) {
        name = "TonClick for Services Debot";
        version = "0.0.1";
        publisher = "TON RED";
        caption = "Subscriptions management for service owners";
        author = "TON RED";
        support = address.makeAddrStd(0, 0);
        hello = "Hello, i am a TonClickService DeBot.";
        language = "en";
        dabi = m_debotAbi.get();
        icon = m_icon;
    }

    function getRequiredInterfaces() public view override returns (uint256[] interfaces) {
        return [Terminal.ID, Menu.ID, AmountInput.ID, Sdk.ID, UserInfo.ID, ConfirmInput.ID];
    }

    function start() public override {
        Terminal.print(0, format("Hello, i am a TonClick Debot for Services.\nConnected to root:\n{} ", m_root));
        UserInfo.getAccount(tvm.functionId(_start));

    }
    function _start(address value) public {
        m_account = value;
        setRootData();
    }

    /********************
     * Main Debot Logic *
     ********************/

    function menu() private {
        MenuItem[] items;
        items.push(MenuItem("Create new Service account", "", tvm.functionId(createServiceAccount)));
        items.push(MenuItem("Login to Service account", "", tvm.functionId(loginToServiceAccountSelectType)));
        items.push(MenuItem("Change root address", "", tvm.functionId(changeRootAddress)));
        Menu.select("Select option:", "", items);
    }

    function menuCallback(uint32 index) public {
        index;
        menu();
    }

    function createServiceAccount(uint32 index) public {
        index;
        Terminal.input(tvm.functionId(storeServiceName), "Input Service Name", false);
    }

    function storeServiceName(string value) public {
        m_serviceData.name = value;
        Terminal.input(tvm.functionId(storeServiceDescription), "Input Service Description", true);

    }

    function storeServiceDescription(string value) public {
        m_serviceData.description = value;
        Terminal.input(tvm.functionId(storeServiceURL), "Input Service URL", false);
    }

    function storeServiceURL(string value) public {
        m_serviceData.url = value;
        ConfirmInput.get(tvm.functionId(deployServiceAccount), "Deploy?");
    }

    function deployServiceAccount(bool value) public {
        if (value){
            TvmCell body = tvm.encodeBody(
                Root.createService,
                m_account,
                m_serviceData.name,
                m_serviceData.description,
                m_serviceData.url
            );
            IMultisig(m_account).sendTransaction{
                abiVer: 2,
                extMsg: true,
                sign: true,
                pubkey: pubkey,
                time: uint64(now),
                expire: 0,
                callbackId: tvm.functionId(onServiceDeploy),
                onErrorId: tvm.functionId(onError)
            }(m_root, Fees.CREATE_SERVICE_VALUE, true, 1, body);
        } else {
            setRootData();
        }
    }

    function onError(uint32 sdkError, uint32 exitCode) public {
        Terminal.print(0, format("Operation failed: {} {}", sdkError, exitCode));
    }

    function onServiceDeploy() public {
        Terminal.print(0, format("Deployed service ID: {}", m_serviceNonce));
        setRootData();
    }


    function changeRootAddress(uint32 index) public {
        index;
        AddressInput.get(tvm.functionId(setRootAddress), "Input new root address");
    }

    function setRootAddress(address value) public {
        m_root = value;
        setRootData();

    }

    function loginToServiceAccountSelectType(uint32 index) public {
        index;
        MenuItem[] items;
        items.push(MenuItem("Service ID", "", tvm.functionId(loginToServiceAccountById)));
        items.push(MenuItem("Service Address", "", tvm.functionId(loginToServiceAccountByAddress)));
        items.push(MenuItem("Back to main menu", "", tvm.functionId(menuCallback)));
        Menu.select("Login with:", "", items);
    }

    function loginToServiceAccountByAddress(uint32 index) public {
        index;
        AddressInput.get(tvm.functionId(loginToServiceAccountByAddressCallback), "Input TonClick Service account address");
    }

    function loginToServiceAccountByAddressCallback(address value) public {
        m_serviceData.account = value;
    }

    function loginToServiceAccountById(uint32 index) public {
        index;
        AmountInput.get(
            tvm.functionId(loginToServiceAccountByIdCallback),
            "Enter TonClick Service account ID:",
            0, 0, m_serviceData.maxId
        );
    }


    function loginToServiceAccountByIdCallback(uint128 value) public {
        m_serviceData.id = uint32(value);
        m_serviceData.account = address(tvm.hash(_buildServiceStateInit(m_serviceData.id)));
        Sdk.getAccountType(tvm.functionId(checkServiceAddressStatus), m_serviceData.account);
    }

    function checkServiceAddressStatus(int8 acc_type) public {
        if (!_checkActiveStatus(acc_type, "Service")) {
            menu();
        } else {
            m_serviceData.loggedIn = true;
            Service(m_serviceData.account).getDetails{
                abiVer: 2,
                extMsg: true,
                sign: false,
                pubkey: pubkey,
                time: 0,
                expire: 0,
                callbackId: tvm.functionId(setServiceData),
                onErrorId: 0
            }();
        }
    }

    function setServiceData(
        address owner,
        string title,
        string description,
        string url,
        uint32 subscriptionPlanNonce,
        address[] subscriptionPlans,
        mapping(address => uint128) virtualBalances
    ) public {
        if (owner != m_account) {
            Terminal.print(0, "Your account address is not owner of this service");
            menu();
        } else {
            Terminal.print(0, format("Owner: {}", owner));
            Terminal.print(0, format("Description: {}", description));
            Terminal.print(0, format("Link: {}", url));
            Terminal.print(0, format("Active subscription plans: {}", subscriptionPlans.length));
            m_serviceData.name = title;
            m_serviceData.description = description;
            m_serviceData.url = url;
            m_serviceData.plans = subscriptionPlans;
            m_serviceData.balances = virtualBalances;
            m_serviceData.planNonce = subscriptionPlanNonce;
            serviceMenu();
        }
    }

    function serviceMenu() private {
        MenuItem[] items;
        items.push(MenuItem("Create new subscription plan", "", tvm.functionId(createSubscription)));
        items.push(MenuItem("Manage active plans", "", tvm.functionId(manageActivePlans)));
        items.push(MenuItem("Show balances", "", tvm.functionId(showBalances)));
        items.push(MenuItem("Go to main menu", "", tvm.functionId(menuCallback)));
        Menu.select("Select option:", "", items);
    }

    function createSubscription(uint32 index) public {
        index;
        Terminal.input(tvm.functionId(subscriptionSetTitle), "Input Subscription Name", false);
    }
    function subscriptionSetTitle(string value) public {
        m_subscriptionData.name = value;
        Terminal.input(tvm.functionId(subscriptionSetDescription), "Input Service Description", true);
    }

    function subscriptionSetDescription(string value) public {
        m_subscriptionData.description = value;
        Terminal.input(tvm.functionId(subscriptionSetTermsUrl), "Input Service Terms URL", true);
    }

    function subscriptionSetTermsUrl(string value) public {
        m_subscriptionData.termUrl = value;
        AmountInput.get(
            tvm.functionId(subscriptionSetDuration),
            "Subscription duration (in days):",
            0, 0, 999999
        );
    }

    function subscriptionSetDuration(uint128 value) public {
        m_subscriptionData.duration = uint32(value * 1 days);
        AmountInput.get(
            tvm.functionId(subscriptionSetLimit),
            "Max subscriptions for plan(set 0 to skip):",
            0, 0, 9999999
        );
    }

    function subscriptionSetLimit(uint128 value) public {
        m_subscriptionData.limitCount = uint64(value);
        AmountInput.get(
            tvm.functionId(subscriptionSetPrice),
            "Price in TON(set 0 to skip):",
            9, 0, 999999 ton
        );
    }

    function subscriptionSetTokenRoot(address value) public {
        m_activeRootAddress = value;
        AmountInput.get(
            tvm.functionId(subscriptionSetPrice),
            "Price (with decimals):",
            0, 0, 999999999 ton
        );
    }

    function subscriptionSetPrice(uint128 value) public {
        if (value > 0) {
            m_subscriptionData.prices[m_activeRootAddress] = value;
        }
        ConfirmInput.get(tvm.functionId(subscriptionAddMorePrice), "Add TIP3 price?");
    }

    function subscriptionAddMorePrice(bool value) public {
        if (value){
            AddressInput.get(tvm.functionId(subscriptionSetTokenRoot), "Token Root address");
        } else {
            ConfirmInput.get(tvm.functionId(deploySubscriptionPlay), "Deploy?");
        }
    }

    function deploySubscriptionPlay(bool value) public {
        if (value) {
            TvmCell body = tvm.encodeBody(
                Service.createSubscriptionPlan,
                m_subscriptionData.prices,
                m_subscriptionData.name,
                m_subscriptionData.duration,
                m_subscriptionData.description,
                m_subscriptionData.termUrl,
                m_subscriptionData.limitCount
            );
            IMultisig(m_account).sendTransaction{
                abiVer: 2,
                extMsg: true,
                sign: true,
                pubkey: pubkey,
                time: uint64(now),
                expire: 0,
                callbackId: tvm.functionId(onPlanDeploy),
                onErrorId: tvm.functionId(onError)
            }(m_serviceData.account, Fees.CREATE_SUBSCRIPTION_PLAN_VALUE, true, 1, body);
        } else {
            serviceMenu();
        }
    }

    function onPlanDeploy() public {
        Terminal.print(0, format("Deployed subscription plan ID: {}", m_serviceData.planNonce + 1));
        Service(m_serviceData.account).getDetails{
            abiVer: 2,
            extMsg: true,
            sign: false,
            pubkey: pubkey,
            time: 0,
            expire: 0,
            callbackId: tvm.functionId(setServiceData),
            onErrorId: 0
        }();
    }

    function manageActivePlans(uint32 index) public {
        index;
        delete m_subscriptions;
        if (m_serviceData.plans.length > 0) {
            loadPlanData(m_serviceData.plans[0]);
        } else {
            Terminal.print(0, "No active subscription plans");
            serviceMenu();
        }
    }

    function loadPlanData(address plan) private view {
        SubscriptionPlan(plan).getInfo{
            abiVer: 2,
            extMsg: true,
            sign: false,
            pubkey: pubkey,
            time: 0,
            expire: 0,
            callbackId: tvm.functionId(onGetPlanData),
            onErrorId: 0
        }();
    }

    function onGetPlanData(SubscriptionPlanData data) public {
        uint index = m_subscriptions.length;
        m_subscriptions.push(data);
        if (m_serviceData.plans.length > index + 1) {
            loadPlanData(m_serviceData.plans[index + 1]);
        } else {
            showPlans();
        }
    }
    function showPlans() public {
        MenuItem[] items;
        for (uint i = 0; i < m_subscriptions.length; ++i){
            items.push(MenuItem(format("#{}: {}", i, m_subscriptions[i].title), "", tvm.functionId(getPlanDetails)));
        }
        Menu.select("Select plan:", "", items);
    }

    function getPlanDetails(uint32 index) public {
        m_activeSubscription = index;
        SubscriptionPlan(m_serviceData.plans[m_activeSubscription]).getDetails{
            abiVer: 2,
            extMsg: true,
            sign: false,
            pubkey: pubkey,
            time: 0,
            expire: 0,
            callbackId: tvm.functionId(showPlanInfo),
            onErrorId: 0
        }();
    }

    function showPlanInfo(
        uint32 /*nonce*/,
        address /*root*/,
        address /*service*/,
        mapping(address /*root*/ => uint128 /*price*/) prices,
        uint64 totalUsersCount,
        uint64 activeUsersCount
    ) public {
        SubscriptionPlanData plan = m_subscriptions[m_activeSubscription];
        Terminal.print(0,
            format("Subscription ID: {}\nAddress: {}\nTitle: {}\nDescription: {}\nTerms URL: {}\nDuration: {} days\nTotal Users: {}\nActive Users: {}\n",
                m_activeSubscription,
                m_serviceData.plans[m_activeSubscription],
                plan.title,
                plan.description,
                plan.termUrl,
                plan.duration / 1 days,
                totalUsersCount,
                activeUsersCount
            )
        );
        Terminal.print(0, "Prices:");
        for ((address root, uint128 price) : prices) {
            if (root.value == 0) {
                Terminal.print(0, format("TON: {:t}", price));
            } else {
                Terminal.print(0, format("{}: {}", root, price));
            }
        }
        planMenu();
    }

    function serviceMenuCallback(uint32 index) public {
        index;
        serviceMenu();
    }

    function showPlansCallback(uint32 index) public {
        index;
        showPlans();
    }

    function planMenu() private {
        MenuItem[] items;
        items.push(MenuItem("Change price", "", tvm.functionId(changePriceMenu)));
        items.push(MenuItem("Activate/Deactivate", "", tvm.functionId(changeActive)));
        items.push(MenuItem("Go to plans", "", tvm.functionId(showPlansCallback)));
        items.push(MenuItem("Go to service menu", "", tvm.functionId(serviceMenuCallback)));
        items.push(MenuItem("Go to main menu", "", tvm.functionId(menuCallback)));
        Menu.select("Select option:", "", items);
    }

    function showBalances(uint32 index) public {
        index;
        optional(address, uint128) balance = m_serviceData.balances.min();
        while (balance.hasValue()) {
            (address root, uint128 value) = balance.get();
            Terminal.print(0, format("{}: {}", root, value));
            balance = m_serviceData.balances.next(root);
        }
        serviceMenu();
    }

    function changeActive(uint32 index) public {
        index;
        planMenu();
    }

    function changePriceMenu(uint32 index) public {
        index;
        planMenu();
    }

    function setRootData() private view {
        Root(m_root).getDetails{
            abiVer: 2,
            extMsg: true,
            sign: false,
            pubkey: pubkey,
            time: 0,
            expire: 0,
            callbackId: tvm.functionId(setRootDetails),
            onErrorId: 0
        }();
    }

    function setRootDetails(
        TvmCell serviceCode,
        TvmCell subscriptionPlanCode,
        TvmCell userSubscriptionCode,
        uint32 serviceNonce
    ) public {
        m_serviceData.maxId = 9999999;
        m_serviceNonce = serviceNonce;
        m_serviceCode = serviceCode;
        m_serviceCodeHash = tvm.hash(m_serviceCode);

        m_subscriptionPlanCode = subscriptionPlanCode;
        m_subscriptionPlanCodeHash = tvm.hash(m_subscriptionPlanCode);

        m_userSubscriptionCode = userSubscriptionCode;
        m_userSubscriptionCodeHash = tvm.hash(m_userSubscriptionCode);

        menu();
    }

    function _checkActiveStatus(int8 acc_type, string obj) private returns (bool) {
        if (acc_type == -1)  {
            Terminal.print(0, obj + " is inactive");
            return false;
        }
        if (acc_type == 0) {
            Terminal.print(0, obj + " is uninitialized");
            return false;
        }
        if (acc_type == 2) {
            Terminal.print(0, obj + " is frozen");
            return false;
        }
        return true;
    }

    function _buildServiceStateInit(uint32 nonce) private view returns (TvmCell) {
        return tvm.buildStateInit({
            contr: Service,
            varInit: {
                _nonce : nonce,
                _root: m_root
            },
            code : m_serviceCode
        });
    }

    /*******************
     * Admin functions *
     *******************/

    function setIcon(bytes icon) public checkPubKey {
        tvm.accept();
        m_icon = icon;
    }

    function setRoot(address root) public checkPubKey {
        tvm.accept();
        m_root = root;
    }

    function onCodeUpgrade() internal override {}


}
