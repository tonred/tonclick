pragma ton-solidity >=0.39.0;

import "../tip3/RootTokenContract.sol";


contract TestTIP3Deployer {
    uint128 DEFAULT_TIP3_ROOT_VALUE = 3 ton;
    uint128 DEFAULT_TIP3_WALLET_VALUE = 1 ton;

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

    function deployRootTIP3() public {
        tvm.accept();
        TvmCell stateInit = tvm.buildStateInit({
            contr: RootTokenContract,
            varInit: {
                name: "TestToken",
                symbol: "TEST",
                decimals: 9,
                wallet_code: _wallet_code
            },
            code: _root_code
        });
        _root = new RootTokenContract{
            stateInit: stateInit,
            value: DEFAULT_TIP3_ROOT_VALUE
        }(0, address(this));
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
        address tip_wallet = new TONTokenWallet{
            stateInit: stateInit,
            value: DEFAULT_TIP3_WALLET_VALUE
        }();
        RootTokenContract(_root).mint(initValue, tip_wallet);
        return tip_wallet;
    }

}
