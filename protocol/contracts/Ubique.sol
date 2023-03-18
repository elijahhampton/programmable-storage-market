pragma solidity ^0.8.0;

import { MarketAPI } from "@zondax/filecoin-solidity/contracts/v0.8/MarketAPI.sol";
import { CommonTypes } from "@zondax/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import { MarketTypes } from "@zondax/filecoin-solidity/contracts/v0.8/types/MarketTypes.sol";
import { AccountTypes } from "@zondax/filecoin-solidity/contracts/v0.8/types/AccountTypes.sol";
import { CommonTypes } from "@zondax/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import { AccountCBOR } from "@zondax/filecoin-solidity/contracts/v0.8/cbor/AccountCbor.sol";
import { MarketCBOR } from "@zondax/filecoin-solidity/contracts/v0.8/cbor/MarketCbor.sol";
import { BytesCBOR } from "@zondax/filecoin-solidity/contracts/v0.8/cbor/BytesCbor.sol";
import { BigNumbers } from "@zondax/filecoin-solidity/contracts/v0.8/external/BigNumbers.sol";
import { CBOR } from "@zondax/filecoin-solidity/contracts/v0.8/external/CBOR.sol";
import { Misc } from "@zondax/filecoin-solidity/contracts/v0.8/utils/Misc.sol";
import { FilAddresses } from "@zondax/filecoin-solidity/contracts/v0.8/utils/FilAddresses.sol";

using CBOR for CBOR.CBORBuffer;

contract Ubique {
    mapping(bytes => bool) public cidSet;
    mapping(bytes => uint) public cidSizes;
    mapping(bytes => mapping(uint64 => bool)) public cidProviders;

    // User request for this contract to make a deal. This structure is modelled after Filecoin's Deal
    // Proposal, but leaves out the provider, since any provider can pick up a deal broadcast by this
    // contract.
    struct DealRequest {
        // To be cast to a CommonTypes.Cid
        bytes piece_cid;
        uint64 piece_size;
        bool verified_deal;
        // To be cast to a CommonTypes.FilAddress
        // bytes client_addr;
        // CommonTypes.FilAddress provider;
        string label;
        int64 start_epoch;
        int64 end_epoch;
        uint256 storage_price_per_epoch;
        uint256 provider_collateral;
        uint256 client_collateral;
        uint64 extra_params_version;
        ExtraParamsV1 extra_params;
    }

    // Extra parameters associated with the deal request. These are off-protocol flags that
    // the storage provider will need.
    struct ExtraParamsV1 {
        string location_ref;
        uint64 car_size;
        bool skip_ipni_announce;
        bool remove_unsealed_copy;
    }

    struct Bid {
        string path;
    }

    constructor() {}

    function addBounty(DealRequest newBounty) public {}

    function acceptBid(uint256 bidId) public {}

    function addCid(bytes calldata cidraw, uint size) internal {
        cidSet[cidraw] = true;
        cidSizes[cidraw] = size;
    }

    function fund() public {}

    function bountyIsStored(
        bytes memory cidraw,
        uint64 provider
    ) internal view returns (bool) {
        bool isAlreadStored = cidProviders[cidraw][provider];
        return !isAlreadStored;
    }

    function authorizeData(
        bytes memory cidraw,
        uint64 provider,
        uint size
    ) public {
        require(cidSet[cidraw], "cid must be added before authorizing");
        require(cidSizes[cidraw] == size, "data size must match expected");
        require(
            bountyIsStored(cidraw, provider),
            "deal failed policy check: has provider already claimed this cid?"
        );

        cidProviders[cidraw][provider] = true;
    }

    function serializeExtraParamsV1(ExtraParamsV1 memory params) pure returns (bytes memory) {
    CBOR.CBORBuffer memory buf = CBOR.create(64);
    buf.startFixedArray(4);
    buf.writeString(params.location_ref);
    buf.writeUInt64(params.car_size);
    buf.writeBool(params.skip_ipni_announce);
    buf.writeBool(params.remove_unsealed_copy);
    return buf.data();
}
}
