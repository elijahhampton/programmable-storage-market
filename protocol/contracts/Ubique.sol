pragma solidity ^0.8.0;

import {MarketAPI} from "@zondax/filecoin-solidity/contracts/v0.8/MarketAPI.sol";
import {CommonTypes} from "@zondax/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import {MarketTypes} from "@zondax/filecoin-solidity/contracts/v0.8/types/MarketTypes.sol";
import {AccountTypes} from "@zondax/filecoin-solidity/contracts/v0.8/types/AccountTypes.sol";
import {CommonTypes} from "@zondax/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import {AccountCBOR} from "@zondax/filecoin-solidity/contracts/v0.8/cbor/AccountCbor.sol";
import {MarketCBOR} from "@zondax/filecoin-solidity/contracts/v0.8/cbor/MarketCbor.sol";
import {BytesCBOR} from "@zondax/filecoin-solidity/contracts/v0.8/cbor/BytesCbor.sol";
import {BigNumbers} from "@zondax/filecoin-solidity/contracts/v0.8/external/BigNumbers.sol";
import {CBOR} from "@zondax/filecoin-solidity/contracts/v0.8/external/CBOR.sol";
import {Misc} from "@zondax/filecoin-solidity/contracts/v0.8/utils/Misc.sol";
import {FilAddresses} from "@zondax/filecoin-solidity/contracts/v0.8/utils/FilAddresses.sol";

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

    event BountyAdded();
    event BidAccepted();

    constructor() {}

    function addBounty(DealRequest newBounty) public {
        emit BountyAdded();
    }

    function acceptBid(uint256 bidId) public {
        emit BidAccepted();
    }

    function addCid(bytes calldata cidraw, uint size) internal {
        cidSet[cidraw] = true;
        cidSizes[cidraw] = size;
    }

    function fund() public payable {}

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

    function serializeExtraParamsV1(
        ExtraParamsV1 memory params
    ) pure returns (bytes memory) {
        CBOR.CBORBuffer memory buf = CBOR.create(64);
        buf.startFixedArray(4);
        buf.writeString(params.location_ref);
        buf.writeUInt64(params.car_size);
        buf.writeBool(params.skip_ipni_announce);
        buf.writeBool(params.remove_unsealed_copy);
        return buf.data();
    }

        function getExtraParams(
        bytes32 proposalId
    ) public view returns (bytes memory extra_params) {
        DealRequest memory deal = getDealRequest(proposalId);
        return serializeExtraParamsV1(deal.extra_params);
    }

        function getDealProposal(bytes32 proposalId) view public returns (bytes memory) {
        // TODO make these array accesses safe.
        DealRequest memory deal = getDealRequest(proposalId);

        MarketTypes.DealProposal memory ret;
        ret.piece_cid = CommonTypes.Cid(deal.piece_cid);
        ret.piece_size = deal.piece_size;
        ret.verified_deal = deal.verified_deal;
        ret.client = getDelegatedAddress(address(this));
        // Set a dummy provider. The provider that picks up this deal will need to set its own address.
        ret.provider = FilAddresses.fromActorID(0);
        ret.label = deal.label;
        ret.start_epoch = deal.start_epoch;
        ret.end_epoch = deal.end_epoch;
        ret.storage_price_per_epoch = uintToBigInt(deal.storage_price_per_epoch);
        ret.provider_collateral = uintToBigInt(deal.provider_collateral);
        ret.client_collateral = uintToBigInt(deal.client_collateral);

        return serializeDealProposal(ret);
    }
}
