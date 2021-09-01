pragma ton-solidity >= 0.47.0;
import "../node_modules/@broxus/contracts/contracts/utils/RandomNonce.sol";

contract SignChecker is RandomNonce {
    constructor() public {
        tvm.accept();
    }

    function checkSign(bytes signature, string domain, uint256 pubkey, string cid, string sid) public pure returns (bool){
        TvmBuilder payloadBuilder;
        payloadBuilder.store(pubkey);
        payloadBuilder.store(domain);
        payloadBuilder.store(cid);
        payloadBuilder.store(sid);
        TvmCell payload = payloadBuilder.toCell();
        return tvm.checkSign(tvm.hash(payload), signature.toSlice(), pubkey);
    }
}
