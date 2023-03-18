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

// bounty identitied by piece_cid
// bid identified by bid_id

contract Ubique {
    struct DealRequest {
        // To be cast to a CommonTypes.Cid
        bytes piece_cid;
        uint64 piece_size;
        bool verified_deal;
        // To be cast to a CommonTypes.FilAddress
        //bytes client_addr;
        CommonTypes.FilAddress provider;
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
        uint256 bid_id;
        string path;
        CommonTypes.FilAddress providerFilAddress;
        address provider;
        bool activated;
        bool accepted;
        string region;
        uint256 storageCapacity;
        uint256 minReliability;
        uint256 price;
        uint256 expiry; //deal duration
        uint256 collateralSupplied;
    }

    struct BountyParameters {
        string region;
        uint256 storageCapacity;
        uint256 minReliability;
        uint256 maxPrice;
        uint256 expiry; //deal duration
        uint256 collateralSupplied;
    }

    struct BountyIndexSet {
        uint256 idx;
        bool valid;
    }

    struct PieceToBountyIdSet {
        bytes32 bountyId;
        bool valid;
    }

    struct BountyProviderSet {
        bytes provider;
        bool valid;
    }

    event BountyCreated();
    event BidAccepted();
    event BidProposed(
        uint64 indexed bountyId,
        uint256 indexed bidId,
        uint256 indexed price
    );
    event BountyClamed(
        uint64 indexed bountyId,
        uint256 indexed bidId,
        uint256 indexed price
    );

    DealRequest[] deals;
    mapping(bytes => bool) public cidSet; //cid to existence
    mapping(bytes => uint) public cidSizes; //cid to size

    mapping(bytes => BountyIndexSet) bountyIdToBountyIndexSet;
    mapping(bytes => BountyParameters) bountyIdToParameters;
    mapping(bytes => PieceToProviderSet) pieceToProviderSet;
    mapping(bytes => PieceToBountyIdSet) pieceToBountyIdSet;

    constructor() {}

    function addBounty(
        DealRequest newBounty,
        BountyParameters memory bountyParameters
    ) public payable {
        // add deal to deal array
        uint256 index = deals.length;
        deals.push(deal);

        // calculate unique deal request id
        // creates a unique ID for the deal proposal -- there are many ways to do this
        bytes32 bountyId = keccak256(
            abi.encodePacked(block.timestamp, msg.sender, index)
        );

        storeBounty(bountyid, index, newBounty.piece_cid, newBounty.piece_size);

        emit BountyCreated(bountyId);
    }

    function storeBounty(
        bytes32 bountyId,
        uint256 index,
        bytes calldata cidraw,
        uint size,
        BountyParameters memory bountyParameters
    ) internal {
        pieceToBountyIdSet[cidraw] = PieceToBountyIdSet(bountyId, true);
        pieceToProviderSet[bountyId] = PieceToProviderSet(bountyId, true);
        // map bounty id to deal request index
        bountyIdToProposalIndex[bountyId] = BountyIndexSet(index, true);
        bountyIdToBountyParameters[bountyId] = bountyParameters;

        cidSizes[cidraw] = size;
    }

    function proposeBid(uint256 bountyId, uint256 price) public payable {
        uint256 bidId = 0;

        emit BidProposed(bountyId, bidId, price);
    }

    function acceptBid(uint256 bountyId, uint256 bidId) public {
        // assign deal request to bid id

        //change provider of bounty

        //send money to storage provider

        //confirm on filecoin network
        emit BidAccepted();
    }

    function claimBounty() public {
        emit BountyClaimed(0, 0, 0);
    }

    function dealNotify(bytes memory params) public {
        MarketDealNotifyParams memory mdnp = deserializeMarketDealNotifyParams(
            params
        );
        MarketTypes.DealProposal memory proposal = deserializeDealProposal(
            mdnp.dealProposal
        );

        require(
            pieceToBountyIdSet[proposal.piece_cid.data].valid,
            "piece cid must be added before authorizing"
        );
        require(
            !pieceToProviderSet[proposal.piece_cid.data].valid,
            "deal failed policy check: provider already claimed this cid"
        );

        pieceToProviderSet[proposal.piece_cid.data] = ProviderSet(
            proposal.provider.data,
            true
        );
        //  pieceDeals[proposal.piece_cid.data] = mdnp.dealId;
    }

    function fund() public payable {}

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

    function getBountyDealRequestRaw(
        bytes32 bountyId
    ) internal view returns (DealRequest memory) {
        ProposalIdx memory pi = dealProposals[proposalId];
        require(pi.valid, "proposalId not available");

        return deals[pi.idx];
    }

    function getBountyDealRequest(
        bytes32 bountyId
    ) public view returns (bytes memory) {
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
        ret.storage_price_per_epoch = uintToBigInt(
            deal.storage_price_per_epoch
        );
        ret.provider_collateral = uintToBigInt(deal.provider_collateral);
        ret.client_collateral = uintToBigInt(deal.client_collateral);

        return serializeDealProposal(ret);
    }

    // Below 2 funcs need to go to filecoin.sol
    function uintToBigInt(
        uint256 value
    ) internal view returns (CommonTypes.BigInt memory) {
        BigNumbers.BigNumber memory bigNumVal = BigNumbers.init(value, false);
        CommonTypes.BigInt memory bigIntVal = CommonTypes.BigInt(
            bigNumVal.val,
            bigNumVal.neg
        );
        return bigIntVal;
    }

    function bigIntToUint(
        CommonTypes.BigInt memory bigInt
    ) internal view returns (uint256) {
        BigNumbers.BigNumber memory bigNumUint = BigNumbers.init(
            bigInt.val,
            bigInt.neg
        );
        uint256 bigNumExtractedUint = uint256(bytes32(bigNumUint.val));
        return bigNumExtractedUint;
    }
}
