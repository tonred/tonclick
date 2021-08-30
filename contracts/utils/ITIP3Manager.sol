pragma ton-solidity >= 0.39.0;

import "../libraries/Errors.sol";
import "../tip3/interfaces/IRootTokenContract.sol";
import "../tip3/interfaces/ITONTokenWallet.sol";
import "../tip3/interfaces/ITokensReceivedCallback.sol";
import "../tip3/interfaces/IExpectedWalletAddressCallback.sol";
import "../tip3/interfaces/ITokenWalletDeployedCallback.sol";

import "../../node_modules/@broxus/contracts/contracts/libraries/MsgFlag.sol";


pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;


abstract contract ITIP3Manager is ITokensReceivedCallback, IExpectedWalletAddressCallback, ITokenWalletDeployedCallback {
    uint128 constant DEPLOY_EMPTY_WALLET_VALUE = 0.2 ton;
    uint128 constant DEPLOY_EMPTY_WALLET_GRAMS = 0.1 ton;
    uint128 constant SEND_EXPECTED_WALLET_VALUE = 0.1 ton;
    uint128 constant TRANSFER_FEE_VALUE = 0.2 ton;
    uint128 constant TIP3_WALLET_DEPLOY_FEE_VALUE = 0.1 ton;

    mapping(address => address) _tip3_wallets;


    function isTip3WalletExists(address tip3_root) public view returns (bool) {
        return _tip3_wallets.exists(tip3_root);
    }

    function _addTip3Wallet(address tip3_root) internal {
        if (isTip3WalletExists(tip3_root)) {
            return;
        }
        _tip3_wallets[tip3_root] = address.makeAddrNone();
        IRootTokenContract(tip3_root)
            .deployEmptyWallet {
                value: DEPLOY_EMPTY_WALLET_VALUE,
                flag: MsgFlag.SENDER_PAYS_FEES
            }(
                DEPLOY_EMPTY_WALLET_GRAMS,  // deploy_grams
                0,                          // wallet_public_key
                address(this),              // owner_address
                address(this)               // gas_back_address
            );
        IRootTokenContract(tip3_root)
            .sendExpectedWalletAddress {
                value: SEND_EXPECTED_WALLET_VALUE,
                flag: MsgFlag.SENDER_PAYS_FEES
            }(
                0,              // wallet_public_key_
                address(this),  // owner_address_
                address(this)   // to
            );
    }

    function getTIP3Wallets() public view returns (mapping(address => address)) {
        return _tip3_wallets;
    }

    // callback for IRootTokenContract(...).sendExpectedWalletAddress
    function expectedWalletAddressCallback(
        address wallet,
        uint256 wallet_public_key,
        address owner_address
    ) override public {
        require(isTip3WalletExists(msg.sender), Errors.IS_NOT_TIP3_ROOT);
        require(wallet_public_key == 0, Errors.IS_NOT_TIP3_OWNER);
        require(owner_address == address(this), Errors.IS_NOT_TIP3_OWNER);

        tvm.accept();
        _tip3_wallets[msg.sender] = wallet;
        ITONTokenWallet(wallet)
            .setReceiveCallback {
                value: 0,
                flag: MsgFlag.REMAINING_GAS
            }(
                address(this),  // receive_callback_
                false           // allow_non_notifiable_
            );
    }

    function notifyWalletDeployed(address /*root*/) public override {
//        tvm.log("notifyWalletDeployed");
    }

    function tokensReceivedCallback(
        address token_wallet,
        address token_root,
        uint128 tokens_amount,
        uint256 /*sender_public_key*/,
        address sender_address,
        address sender_wallet,
        address /*original_gas_to*/,
        uint128 /*updated_balance*/,
        TvmCell payload
    ) override public {
        address tip3_wallet = _tip3_wallets[token_root];
        require(msg.sender == tip3_wallet, Errors.IS_NOT_TIP3_OWNER);
        require(token_wallet == tip3_wallet, Errors.IS_NOT_TIP3_OWNER);
        _onTip3TokensReceived(token_root, tokens_amount, sender_address, sender_wallet, payload);
    }

    function _onTip3TokensReceived(
        address token_root,
        uint128 tokens_amount,
        address sender_address,
        address sender_wallet,
        TvmCell payload
    ) internal virtual;

    function _transferTip3Tokens(address root, address destination, uint128 value) internal view {
        if (value == 0) return;
        address wallet = _tip3_wallets[root];
        TvmCell empty;
        ITONTokenWallet(wallet)
            .transfer {
                value: TRANSFER_FEE_VALUE,
                flag: MsgFlag.SENDER_PAYS_FEES
            }(
                destination,  // to
                value,        // tokens
                0,            // grams,
                wallet,       // send_gas_to,
                true,         // notify_receiver
                empty         // payload
            );
    }

    function _transferTip3TokensWithDeploy(address root, address recipient_address, uint128 value) internal view {
        if (value == 0) return;
        address wallet = _tip3_wallets[root];
        TvmCell empty;
        ITONTokenWallet(wallet)
            .transferToRecipient {
                value: TRANSFER_FEE_VALUE + TIP3_WALLET_DEPLOY_FEE_VALUE,
                flag: MsgFlag.SENDER_PAYS_FEES
            }(
                0,                             // recipient_public_key
                recipient_address,             // recipient_address
                value,                         // tokens
                TIP3_WALLET_DEPLOY_FEE_VALUE,  // deploy_grams
                0,                             // transfer_grams
                recipient_address,             // send_gas_to
                true,                          // notify_receiver
                empty                          // payload
            );
    }

}
