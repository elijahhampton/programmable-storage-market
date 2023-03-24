// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.17;

import {MarketAPI} from "../node_modules/@zondax/filecoin-solidity/contracts/v0.8/MarketAPI.sol";
import {CommonTypes} from "../node_modules/@zondax/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import {MarketTypes} from "../node_modules/@zondax/filecoin-solidity/contracts/v0.8/types/MarketTypes.sol";
import {AccountTypes} from "../node_modules/@zondax/filecoin-solidity/contracts/v0.8/types/AccountTypes.sol";
import {AccountCBOR} from "../node_modules/@zondax/filecoin-solidity/contracts/v0.8/cbor/AccountCbor.sol";
import {MarketCBOR} from "../node_modules/@zondax/filecoin-solidity/contracts/v0.8/cbor/MarketCbor.sol";
import {BytesCBOR} from "../node_modules/@zondax/filecoin-solidity/contracts/v0.8/cbor/BytesCbor.sol";
import {BigNumbers, BigNumber} from "../node_modules/@zondax/solidity-bignumber/src/BigNumbers.sol";
import {FilecoinCBOR} from "../node_modules/@zondax/filecoin-solidity/contracts/v0.8/cbor/FilecoinCbor.sol";
import {Misc} from "../node_modules/@zondax/filecoin-solidity/contracts/v0.8/utils/Misc.sol";
import {FilAddresses} from "../node_modules/@zondax/filecoin-solidity/contracts/v0.8/utils/FilAddresses.sol";
import {Bid, BountyParameters, BountyIndexSet, PieceToBountyIdSet, PieceToProviderSet, BidValiditySet, DealRequest, ExtraParamsV1, MarketDealNotifyParams, deserializeMarketDealNotifyParams, deserializeDealProposal} from "./Types.sol";
import {CBOR} from "../node_modules/solidity-cborutils/contracts/CBOR.sol";
using CBOR for CBOR.CBORBuffer;
using AccountCBOR for bytes;

// bounty identitied by piece_cid
// bid identified by bid_id

contract Ubique {
    uint64 public constant AUTHENTICATE_MESSAGE_METHOD_NUM = 2643134072;
    uint64 public constant DATACAP_RECEIVER_HOOK_METHOD_NUM = 3726118371;
    uint64 public constant MARKET_NOTIFY_DEAL_METHOD_NUM = 4186741094;
    address public constant MARKET_ACTOR_ETH_ADDRESS =
        address(0xff00000000000000000000000000000000000005);
    address public constant DATACAP_ACTOR_ETH_ADDRESS =
        address(0xfF00000000000000000000000000000000000007);

    event BountyCreated(bytes32 indexed bountyId);
    event BidAccepted(bytes32 indexed bountyId, uint256 indexed bidId);
    event BidProposed(bytes32 indexed bountyId, uint256 indexed bidId);

    event BountyClaimed(bytes32 indexed bountyId, uint256 indexed bidId);

    DealRequest[] deals;
    mapping(bytes => bool) public cidSet; //cid to existence
    mapping(bytes => uint) public cidSizes; //cid to size
    mapping(bytes => uint64) public pieceToDealId;

    mapping(bytes32 => BountyIndexSet) private bountyIdToBountyIndexSet;
    mapping(bytes32 => BountyParameters) private bountyIdToBountyParameters;
    mapping(bytes => PieceToProviderSet) private pieceToProviderSet;
    mapping(bytes => PieceToBountyIdSet) private pieceToBountyIdSet;
    mapping(bytes32 => Bid[]) private bountyIdToBids;
    mapping(uint256 => Bid) private bidIdToBid; //
    mapping(bytes => uint256) private pieceIdToAcceptedBidId; //
    mapping(address => BidValiditySet) private providerAddressToBidValiditySet;

    function addBounty(
        DealRequest calldata newBounty,
        BountyParameters memory bountyParameters
    ) public payable {
        // add deal to deal array
        uint256 index = deals.length;
        deals.push(newBounty);

        // calculate unique deal request id
        // creates a unique ID for the deal proposal -- there are many ways to do this
        bytes32 bountyId = keccak256(
            abi.encodePacked(block.timestamp, msg.sender, index)
        );

        storeBounty(bountyId, index, newBounty.piece_cid, newBounty.piece_size, bountyParameters);

        emit BountyCreated(bountyId);
    }

    function storeBounty(
        bytes32 bountyId,
        uint256 index,
        CommonTypes.Cid memory cidraw,
        uint size,
        BountyParameters memory bountyParameters
    ) internal {
        pieceToBountyIdSet[cidraw.data] = PieceToBountyIdSet(bountyId, true);
        // pieceToProviderSet[bountyId] = PieceToProviderSet(bountyId, true); //
        // map bounty id to deal request index
        bountyIdToBountyIndexSet[bountyId] = BountyIndexSet(index, true);
        bountyIdToBountyParameters[bountyId] = bountyParameters;

        cidSizes[cidraw.data] = size;
    }

    function proposeBid(bytes32 bountyId, Bid memory bid) public payable {
        BountyIndexSet memory bountyIndexSet = bountyIdToBountyIndexSet[
            bountyId
        ];
        // using the bountyID, we need the deal request (the bounty)
        // check to see if the bounty exists
        require(bountyIndexSet.valid, "Deal request doesn't exist");

        DealRequest memory dealRequest = deals[bountyIndexSet.idx];

        // maps bountyIDs to array of bids
        // set bidID to length of array before pushing bid into it
        bountyIdToBids[bountyId].push(bid);

        // emit an event indicating that a new bid was proposed
        uint256 bidId = bountyIdToBids[bountyId].length;
        //bid.bid_id = bidId; can't do this here because the struct is stored in memory. I don't think it's necessary anyway
     //   bid.provider = msg.sender;  why is the provider set here? 
        bidIdToBid[bidId] = bid;
        // providerAddressToBidValiditySet[msg.sender] = BidValiditySet(msg.sender, bountyId, false);
        emit BidProposed(bountyId, bidId);
    }

    function acceptBid(bytes32 bountyId, uint256 bidId) public {
        // check if deal request has been verified
        // We need the "DealRequest", we need to access the array
        DealRequest storage dealRequest = deals[
            bountyIdToBountyIndexSet[bountyId].idx
        ];
        require(dealRequest.verified_deal == false, "Deal request is verified");

        // make sure the bid wasn’t already accepted
        Bid storage bid = bidIdToBid[bidId];
        require(bid.accepted == false, "bid is already accepted");
        require(bid.activated == false, "bid is already activated");

        bid.accepted = true; 
        pieceIdToAcceptedBidId[dealRequest.piece_cid.data] = bidId;

        // confirm on filecoin network
        emit BidAccepted(bountyId, bidId);
    }

    function dealNotify(bytes memory params) public {
        MarketDealNotifyParams memory mdnp = deserializeMarketDealNotifyParams(
            params
        );
        DealRequest memory proposal = deserializeDealProposal(
            mdnp.dealProposal
        );

        require(
            pieceToBountyIdSet[proposal.piece_cid.data].valid,
            "piece cid must be added before authorizing"
        );
        require(
            // maps pieceID to provider
            !pieceToProviderSet[proposal.piece_cid.data].valid,
            "deal failed policy check: provider already claimed this cid"
        );

        pieceToProviderSet[proposal.piece_cid.data] = PieceToProviderSet(
            proposal.provider.data,
            true
        );
        // at this point, the deal is settled
        pieceToDealId[proposal.piece_cid.data] = mdnp.dealId;

        // TODO: Need to set dealProposal to verified and bid to activated
        uint256 bidId = pieceIdToAcceptedBidId[proposal.piece_cid.data];
        bidIdToBid[bidId].activated = true;

        bytes32 bountyId = pieceToBountyIdSet[proposal.piece_cid.data].bountyId;
        uint256 indx = bountyIdToBountyIndexSet[bountyId].idx;

        DealRequest storage dR = deals[indx];
        dR.verified_deal = true;
        emit BountyClaimed(bountyId, bidId);
    }

    function fund() public payable {}

    function serializeExtraParamsV1(
        ExtraParamsV1 memory params
    ) internal pure returns (bytes memory) {
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
        DealRequest memory deal = getBountyDealRequestRaw(proposalId);
        return serializeExtraParamsV1(deal.extra_params);
    }

    function getBountyDealRequestRaw(
        bytes32 bountyId
    ) internal view returns (DealRequest memory) {
        BountyIndexSet memory pi = bountyIdToBountyIndexSet[bountyId];
        require(pi.valid, "proposalId not available");

        return deals[pi.idx];
    }

    // function getBountyDealRequest(
    //     bytes32 bountyId
    // ) public view returns (bytes memory) {
    //     // TODO make these array accesses safe.
    //     DealRequest memory deal = getBountyDealRequestRaw(bountyId);

    //     MarketTypes.DealProposal memory ret;
    //     ret.piece_cid = CommonTypes.Cid(deal.piece_cid);
    //     ret.piece_size = deal.piece_size;
    //     ret.verified_deal = deal.verified_deal;
    //     ret.client = getDelegatedAddress(address(this));
    //     // Set a dummy provider. The provider that picks up this deal will need to set its own address.
    //     ret.provider = FilAddresses.fromActorID(0);
    //     ret.label = deal.label;
    //     ret.start_epoch = deal.start_epoch;
    //     ret.end_epoch = deal.end_epoch;
    //     ret.storage_price_per_epoch = uintToBigInt(
    //         deal.storage_price_per_epoch
    //     );
    //     ret.provider_collateral = uintToBigInt(deal.provider_collateral);
    //     ret.client_collateral = uintToBigInt(deal.client_collateral);

    //     return serializeDealProposal(ret);
    // }

    // Below 2 funcs need to go to filecoin.sol
    function uintToBigInt(
        uint256 value
    ) internal view returns (CommonTypes.BigInt memory) {
        BigNumber memory bigNumVal = BigNumbers.init(value, false);
        CommonTypes.BigInt memory bigIntVal = CommonTypes.BigInt(
            bigNumVal.val,
            bigNumVal.neg
        );
        return bigIntVal;
    }

    function bigIntToUint(
        CommonTypes.BigInt memory bigInt
    ) internal view returns (uint256) {
        BigNumber memory bigNumUint = BigNumbers.init(bigInt.val, bigInt.neg);
        uint256 bigNumExtractedUint = uint256(bytes32(bigNumUint.val));
        return bigNumExtractedUint;
    }

    // TODO fix in filecoin-solidity. They're using the wrong hex value.
    function getDelegatedAddress(
        address addr
    ) internal pure returns (CommonTypes.FilAddress memory) {
        return CommonTypes.FilAddress(abi.encodePacked(hex"040a", addr));
    }

    // authenticateMessage is the callback from the market actor into the contract
    // as part of PublishStorageDeals. This message holds the deal proposal from the
    // miner, which needs to be validated by the contract in accordance with the
    // deal requests made and the contract's own policies
    // @params - cbor byte array of AccountTypes.AuthenticateMessageParams
    function authenticateMessage(bytes memory params) internal view {
        require(
            msg.sender == MARKET_ACTOR_ETH_ADDRESS,
            "msg.sender needs to be market actor f05"
        );

        AccountTypes.AuthenticateMessageParams memory amp = params
            .deserializeAuthenticateMessageParams();
        DealRequest memory proposal = deserializeDealProposal(amp.message);

        bytes memory pieceCid = proposal.piece_cid.data;
        PieceToBountyIdSet memory ptBIdSet = pieceToBountyIdSet[pieceCid];
        PieceToProviderSet memory pwrSet = pieceToProviderSet[pieceCid];

        require(ptBIdSet.valid, "piece cid must be added before authorizing");
        require(
            !pwrSet.valid,
            "deal failed policy check: provider already claimed this cid"
        );

        DealRequest memory req = getBountyDealRequestRaw(ptBIdSet.bountyId);
        require(
            proposal.verified_deal == req.verified_deal,
            "verified_deal param mismatch"
        );
        require(
            bigIntToUint(proposal.storage_price_per_epoch) <=
                bigIntToUint(req.storage_price_per_epoch),
            "storage price greater than request amount"
        );
        require(
            bigIntToUint(proposal.client_collateral) <=
                bigIntToUint(req.client_collateral),
            "client collateral greater than request amount"
        );
    }

    // handle_filecoin_method is the universal entry point for any evm based
    // actor for a call coming from a builtin filecoin actor
    // @method - FRC42 method number for the specific method hook
    // @params - CBOR encoded byte array params
    function handle_filecoin_method(
        uint64 method,
        uint64,
        bytes memory params
    ) public returns (uint32, uint64, bytes memory) {
        bytes memory ret;
        uint64 codec;
        // dispatch methods
        if (method == AUTHENTICATE_MESSAGE_METHOD_NUM) {
            authenticateMessage(params);
            // If we haven't reverted, we should return a CBOR true to indicate that verification passed.
            CBOR.CBORBuffer memory buf = CBOR.create(1);
            buf.writeBool(true);
            ret = buf.data();
            codec = Misc.CBOR_CODEC;
        } else if (method == MARKET_NOTIFY_DEAL_METHOD_NUM) {
            dealNotify(params);
        } else if (method == DATACAP_RECEIVER_HOOK_METHOD_NUM) {
            // receiveDataCap(params);
        } else {
            revert("the filecoin method that was called is not handled");
        }
        return (0, codec, ret);
    }
}
