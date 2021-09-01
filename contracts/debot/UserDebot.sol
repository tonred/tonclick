pragma ton-solidity >= 0.35.0;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "base/Debot.sol";
import "base/Menu.sol";
import "base/Terminal.sol";
import "base/Upgradable.sol";
import "base/Menu.sol";
import "base/Network.sol";
import "base/Sdk.sol";
import "base/QRCode.sol";
import "base/SigningBoxInput.sol";
import "base/UserInfo.sol";
import "base/Base64.sol";
import "base/ConfirmInput.sol";
import "base/AddressInput.sol";

import "../SubscriptionPlan.sol";
import "../Service.sol";
import "../Root.sol";
import "../UserProfile.sol";

import "../tip3/TONTokenWallet.sol";
import "../tip3/RootTokenContract.sol";
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

contract HelloDebot is Debot, Upgradable, RandomNonce, CheckPubKey {
    bytes m_icon;
    optional(uint256) pubkey;

    address m_root;
    address m_account;

    string m_domain;
    string m_sid;
    string m_cid;
    TvmCell m_payload;

    address m_plan;
    address m_service;
    uint32 m_planNonce;
    mapping(address /*root*/ => uint128 /*price*/) m_planPrices;
    address m_selectedCurrency;
    address[] m_priceRoots;
    SubscriptionPlanData m_planData;

    uint256 m_subPubkey;
    address m_subAddress;

    address m_profileOn;
    address m_profileOff;
    bool m_profilesLoaded;
    address[] m_subs;
    SubscriptionPlanData[] m_subsData;
    uint m_subLoadIndex;
    address m_activeUser;

    /************************
     * Base debot functions *
     ************************/

    function getDebotInfo() public functionID(0xDEB) override view returns(
        string name, string version, string publisher, string caption, string author,
        address support, string hello, string language, string dabi, bytes icon
    ) {
        name = "TonClick for Users Debot";
        version = "0.0.1";
        publisher = "TON RED";
        caption = "Subscriptions management for users";
        author = "TON RED";
        support = address.makeAddrStd(0, 0);
        hello = "Hello, i am a TonClickUser DeBot.";
        language = "en";
        dabi = m_debotAbi.get();
        icon = m_icon;
    }

    function getRequiredInterfaces() public view override returns (uint256[] interfaces) {
        return [Terminal.ID, Menu.ID, Network.ID,
                QRCode.ID, Sdk.ID, SigningBoxInput.ID,
                UserInfo.ID, ConfirmInput.ID, Base64.ID, AddressInput.ID];
    }

    function start() public override {
        Terminal.print(0, format("Hello, i am a TonClick Debot for Users.\n Connected to root:\n{} ", m_root));
        UserInfo.getAccount(tvm.functionId(setAddress));
    }

    function setAddress(address value) public {
        m_account = value;
        UserInfo.getPublicKey(tvm.functionId(setPubkey));
    }

    function setPubkey(uint value) public {
        m_subPubkey = value;
        menu();
    }
    /********************
     * Main Debot Logic *
     ********************/

    function menu() private {
        MenuItem[] items;
        items.push(MenuItem("Login to site", "", tvm.functionId(loginToSite)));
        items.push(MenuItem("Subscribe", "", tvm.functionId(subscribe)));
        items.push(MenuItem("My subscriptions", "", tvm.functionId(manageSubscriptions)));
        Menu.select("Select option:", "", items);
    }

    function menuCallback() public {
        menu();
    }

    function manageSubscriptions() public {
        m_profilesLoaded = false;
        m_subLoadIndex = 0;
        delete m_subsData;
        delete m_subs;
        Root(m_root).getUserProfile{
            abiVer: 2,
            extMsg: true,
            sign: false,
            pubkey: pubkey,
            time: 0,
            expire: 0,
            callbackId: tvm.functionId(setProfileOff),
            onErrorId: 0
        }(address(0), m_subPubkey);
    }

    function setProfileOff(address value) public {
        m_profileOff = value;
        Root(m_root).getUserProfile{
            abiVer: 2,
            extMsg: true,
            sign: false,
            pubkey: pubkey,
            time: 0,
            expire: 0,
            callbackId: tvm.functionId(setProfileOn),
            onErrorId: 0
        }(m_account, 0);
    }

    function setProfileOn(address value) public {
        m_profileOn = value;
        loadProfile(m_profileOff);
    }

    function loadProfile(address user) private {
        m_activeUser = user;
        Sdk.getAccountType(tvm.functionId(checkProfile), user);
    }

    function checkProfile(int8 acc_type) public {
        if (acc_type == 1) {
            UserProfile(m_activeUser).getSubscriptions{
                abiVer: 2,
                extMsg: true,
                sign: false,
                pubkey: pubkey,
                time: 0,
                expire: 0,
                callbackId: tvm.functionId(setProfile),
                onErrorId: tvm.functionId(errorProfile)
            }();
        } else {
            errorProfile(0, 0);
        }
    }

    function loadSubs() private {
        if (m_subs.length > 0) {
            SubscriptionPlan(m_subs[m_subLoadIndex]).getInfo{
                abiVer: 2,
                extMsg: true,
                sign: false,
                pubkey: pubkey,
                time: 0,
                expire: 0,
                callbackId: tvm.functionId(setSubData),
                onErrorId: tvm.functionId(onError)
            }();
        } else {
            Terminal.print(0, "Subscriptions not found");
            menu();
        }
    }

    function setSubData(SubscriptionPlanData data) public {
        m_subsData.push(data);
        m_subLoadIndex++;
        if (m_subLoadIndex < m_subs.length){
            loadSubs();
        } else {
            MenuItem[] items;
            for (uint i = 0; i < m_subsData.length; ++i){
                items.push(MenuItem(format("#{}: {}", i, m_subsData[i].title), "", tvm.functionId(showPlan)));
            }
            items.push(MenuItem("Back to menu", "", tvm.functionId(menuCallback)));
            Menu.select("Select plan", "", items);
        }
    }

    function showPlan(uint32 index) public {
        SubscriptionPlanData plan = m_subsData[index];
        Terminal.print(0,
            format("Title: {}\nDescription: {}\nTerms URL: {}\nDuration: {} days\n",
                plan.title,
                plan.description,
                plan.termUrl,
                plan.duration / 1 days
            )
        );
        MenuItem[] items;
        items.push(MenuItem("Extend", "", tvm.functionId(menuCallback)));
        items.push(MenuItem("Unsubscribe", "", tvm.functionId(menuCallback)));
        Menu.select("Select option:", "", items);
    }

    function errorProfile(uint32 /*sdkError*/, uint32 /*exitCode*/) public {
        if(m_profilesLoaded) {
            loadSubs();
        } else {
            m_profilesLoaded = true;
            loadProfile(m_profileOn);
        }
    }

    function setProfile(address[] subs) public {
        for ((address sub) : subs) {
            m_subs.push(sub);
        }
        if(m_profilesLoaded) {
            loadSubs();
        } else {
            m_profilesLoaded = true;
            loadProfile(m_profileOn);
        }
    }


    function subscribe() public {
       MenuItem[] items;
        items.push(MenuItem("Scan QR Code", "", tvm.functionId(scanQrCodeSub)));
        items.push(MenuItem("Manual input", "", tvm.functionId(manualInputSub)));
        Menu.select("Select subscription address:", "", items);
    }

    function loginToSite() public {
       MenuItem[] items;
        items.push(MenuItem("Scan QR Code", "", tvm.functionId(scanQrCode)));
        items.push(MenuItem("Manual input", "", tvm.functionId(manualInputLogin)));
        Menu.select("Select login option:", "", items);
    }

    function scanQrCode() public {
        QRCode.scan(tvm.functionId(onScanCode));
    }

    function scanQrCodeSub() public {
        QRCode.scan(tvm.functionId(onScanCodeSub));
    }

    function manualInputLogin() public {
        Terminal.input(tvm.functionId(onScanCode), "Input site login string", false);
    }

    function manualInputSub() public {
        AddressInput.get(tvm.functionId(setPlanAddress), "Enter subscription plan address");
    }

    function setPlanAddress(address value) public {
        m_plan = value;
        loadPlanData();
    }

    function onScanCode(string value) public {
        (m_domain, m_cid, m_sid) = parseLogin(value);
        ConfirmInput.get(tvm.functionId(confirmLogin), format("You are trying login to: {}\nContinue?", m_domain));
    }

    function onScanCodeSub(string value) public {
        (uint result, bool status) = stoi(value);
        if (status) {
            m_plan = address(result);
            loadPlanData();
        } else {
            Terminal.print(0, "Wrong QR code");
            menu();
        }
    }

    function loadPlanData() public view {
        SubscriptionPlan(m_plan).getInfo{
            abiVer: 2,
            extMsg: true,
            sign: false,
            pubkey: pubkey,
            time: 0,
            expire: 0,
            callbackId: tvm.functionId(setPlanData),
            onErrorId: 0
        }();
    }

    function setPlanData(SubscriptionPlanData data) public {
        m_planData = data;
        SubscriptionPlan(m_plan).getDetails{
            abiVer: 2,
            extMsg: true,
            sign: false,
            pubkey: pubkey,
            time: 0,
            expire: 0,
            callbackId: tvm.functionId(setPlanDetails),
            onErrorId: 0
        }();
    }

    function setPlanDetails(
        uint32 nonce,
        address root,
        address service,
        mapping(address /*root*/ => uint128 /*price*/) prices,
        uint64 /*totalUsersCount*/,
        uint64 /*activeUsersCount*/
    ) public {
        if (root != m_root){
            Terminal.print(0, "Wrong Subscription plan, deployed from another root");
            menu();
        } else {
            m_planPrices = prices;
            m_planNonce = nonce;
            m_service = service;
            delete m_priceRoots;
            Terminal.print(0, format("Service address: {}", m_service));
            Terminal.print(0, format("#{} {}", nonce, m_planData.title));
            Terminal.print(0, m_planData.description);
            Terminal.print(0, format("Terms: {}", m_planData.termUrl));
            Terminal.print(0, format("Duration: {} days", m_planData.duration / 1 days));
           MenuItem[] items;

            for ((address root, uint128 price) : m_planPrices) {
                if (root.value == 0) {
                    items.push(MenuItem(format("TON: {:t}", price), "", tvm.functionId(selectPrice)));
                } else {
                    items.push(MenuItem(format("{}: {}", price, root), "", tvm.functionId(selectPrice)));
                }
                m_priceRoots.push(root);
            }
            items.push(MenuItem("Back to menu", "", tvm.functionId(menuCallback)));
            Menu.select("Select currency", "", items);
        }

    }
    function selectPrice(uint32 index) public {
        m_selectedCurrency = m_priceRoots[index];
        if (m_selectedCurrency == address(0)) {
            Terminal.print(0, format("Price: {:t} TON", m_planPrices[m_selectedCurrency]));
        } else {
            Terminal.print(0, format("Selected root: {}", m_selectedCurrency));
            Terminal.print(0, format("Price: {}", m_planPrices[m_selectedCurrency]));
        }
        MenuItem[] items;
        m_subAddress = address(0);
        items.push(MenuItem("Subscribe by public key", "", tvm.functionId(subByKey)));
        items.push(MenuItem("Subscribe by address", "", tvm.functionId(manualInputSub)));
        Menu.select("Select option:", "", items);
    }

    function subByKey() public {
        ConfirmInput.get(tvm.functionId(doSubscribe), "Auto Renew?");
    }

    function subByAddress() public {
        AddressInput.get(tvm.functionId(setSubByAddress), "Enter address for which subscription will be");
    }

    function setSubByAddress(address value) public {
        m_subAddress = value;
        ConfirmInput.get(tvm.functionId(doSubscribe), "Auto Renew?");
    }

    function doSubscribe(bool value) public {
        m_payload = buildSubscriptionPayload(m_planNonce, m_subAddress, m_subPubkey, value);
        if (m_selectedCurrency == address(0)){
            TvmCell body = tvm.encodeBody(Service.subscribeNativeTon, m_payload);
            IMultisig(m_account).sendTransaction{
                abiVer: 2,
                extMsg: true,
                sign: true,
                pubkey: pubkey,
                time: uint64(now),
                expire: 0,
                callbackId: tvm.functionId(onServiceDeploy),
                onErrorId: tvm.functionId(onError)
            }(m_service, Fees.USER_SUBSCRIPTION_EXTEND_VALUE + m_planPrices[m_selectedCurrency] + 0.1 ton, true, 1, body);
        } else {
            RootTokenContract(m_selectedCurrency).getWalletAddress{
                abiVer: 2,
                extMsg: true,
                sign: false,
                pubkey: pubkey,
                time: 0,
                expire: 0,
                callbackId: tvm.functionId(onExpectedWalletAddress),
                onErrorId: 0
            }(0, m_account);

        }
    }

    function onExpectedWalletAddress(address wallet) public view {
        TvmCell body = tvm.encodeBody(
            TONTokenWallet.transferToRecipient,
            0,
            m_service,
            m_planPrices[m_selectedCurrency],
            0,
            0,
            m_account,
            true,
            m_payload
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
        }(wallet, Fees.USER_SUBSCRIPTION_EXTEND_VALUE + 0.5 ton, true, 1, body);
    }
    function onError(uint32 sdkError, uint32 exitCode) public {
        Terminal.print(0, format("Operation failed: {} {}", sdkError, exitCode));
    }

    function onServiceDeploy() public {
        Terminal.print(0, "Ok");
        menu();
    }

    function confirmLogin(bool value) public {
        if (value) {
            uint256[] possiblePublicKeys = [m_subPubkey];
            SigningBoxInput.get(tvm.functionId(onGetSigningBox), "Select key for login", possiblePublicKeys);
        } else {
            menu();
        }
    }

    function onGetSigningBox(uint32 handle) public {
        TvmBuilder builder;
        builder.store(m_subPubkey);
        builder.store(m_domain);
        builder.store(m_cid);
        builder.store(m_sid);
        m_payload = builder.toCell();
        Sdk.signHash(tvm.functionId(onSignPayload), handle, tvm.hash(m_payload));
    }

    function onSignPayload(bytes signature) public {
        Base64.encode(tvm.functionId(onSignEncoded), signature);
    }

    function onSignEncoded(string base64) public {
        string[] headers;
        string url = format("https://{}/login/{}/{}", m_domain, m_cid, m_sid);
        headers.push("Content-Type: text/plain");
        string body = format("{:X}|{}", m_subPubkey, base64);
        Network.post(tvm.functionId(loginResponse), url, headers, body);
    }

    function loginResponse(int32 /*statusCode*/, string[] /*retHeaders*/, string content) public {
        if (content == "ok") {
            Terminal.print(0, format("Login Successful"));
        } else if (content == "fail") {
            Terminal.print(0, format("Login Failed"));
        } else {

        }
        menu();
    }

    function parseLogin(string value) private pure returns(string domain, string cid, string sid) {
        (domain, value) = splitBySlash(value);
        (cid, value) = splitBySlash(value);
        (sid, value) = splitBySlash(value);
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

    function splitBySlash(string value) private pure returns (string, string){
        byte separator = 0x2F;

        TvmBuilder bFirstHalf;
        TvmBuilder bSecondHalf;
        bool isSlashFound = false;
        bytes stringBytes = bytes(value);
        uint256 stringLength = stringBytes.length;
        for (uint8 i = 0; i < stringLength; i++) {
            byte char = stringBytes[i];
            if (!isSlashFound) {
                if (char == separator) isSlashFound = true;
                else bFirstHalf.store(char);
            }
            else bSecondHalf.store(char);
        }
        TvmBuilder bFirstHalf_;
        TvmBuilder bSecondHalf_;
        bFirstHalf_.storeRef(bFirstHalf);
        bSecondHalf_.storeRef(bSecondHalf);
        TvmSlice sFirstHalf = bFirstHalf_.toSlice();
        TvmSlice sSecondHalf_ = bSecondHalf_.toSlice();
        return (string(sFirstHalf.decode(bytes)), string(sSecondHalf_.decode(bytes)));
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
