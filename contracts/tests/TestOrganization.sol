pragma ton-solidity >= 0.39.0;

import "../Root.sol";
import "../interfaces/root/ICreateServiceCallback.sol";
import "../utils/Wallet.sol";

import "../../node_modules/@broxus/contracts/contracts/libraries/MsgFlag.sol";


contract TestOrganization is Wallet, ICreateServiceCallback {

    address _root;
    address _service;


    constructor(address root) public {
        tvm.accept();
        _root = root;
    }

    function getService() public view returns (address) {
        return _service;
    }

    function createService(
        address owner,
        string title,
        string description,
        string url
    ) public view {
        tvm.accept();
        Root(_root).createService{
            value: Fees.CREATE_SERVICE_VALUE,
            flag: MsgFlag.SENDER_PAYS_FEES
        }(owner, title, description, url);
    }

    function createServiceCallback(address service) public override {
        require(msg.sender == _root, 999);
        tvm.accept();
        _service = service;
    }

}
