pragma ton-solidity >=0.39.0;

import "../tip3/RootTokenContract.sol";
import "../../node_modules/@broxus/contracts/contracts/utils/RandomNonce.sol";


contract TestTIP3Deployer is RandomNonce {
    uint128 DEFAULT_TIP3_ROOT_VALUE = 1 ton;
    uint128 DEFAULT_TIP3_WALLET_VALUE = 0.5 ton;

    address _root;
    TvmCell _root_code;
    TvmCell _wallet_code;


    constructor(TvmCell root_code, TvmCell wallet_code) public {
        tvm.accept();
        _root_code = root_code;
        _wallet_code = wallet_code;
    }

    function getRoot() public view returns (address) {
        return _root;
    }

    function deployRootTIP3() public returns (address) {
        tvm.accept();
        TvmCell stateInit = tvm.buildStateInit({
            contr: RootTokenContract,
            varInit: {
                name: "TestToken",
                symbol: "TEST",
                decimals: 9,
                wallet_code: _wallet_code,
                _randomNonce: now
            },
            code: _root_code
        });
        _root = new RootTokenContract{
            stateInit: stateInit,
            value: DEFAULT_TIP3_ROOT_VALUE
        }(0, address(this));
        return _root;
    }

    function deployTIP3Wallet(address owner, uint128 initValue) public view returns (address) {
        tvm.accept();
        TvmCell stateInit = tvm.buildStateInit({
            contr: TONTokenWallet,
            varInit: {
                root_address: _root,
                code: _wallet_code,
                wallet_public_key: 0,
                owner_address: owner
            },
            code: _wallet_code
        });
        address wallet = address(tvm.hash(stateInit));
        RootTokenContract(_root).deployWallet{value: 0.5 ton}(initValue, 0.1 ton, 0, owner, address(this));
        return wallet;
    }

}
