// SPDX-License-Identifier: UNLICENSED
//pragma solidity ^0.8.17;
pragma solidity ^0.8.17;

import {MarketTypes} from "../node_modules/@zondax/filecoin-solidity/contracts/v0.8/types/MarketTypes.sol";
import {CBOR} from "../node_modules/solidity-cborutils/contracts/CBOR.sol";
import {FilecoinCBOR} from "../node_modules/@zondax/filecoin-solidity/contracts/v0.8/cbor/FilecoinCbor.sol";
import {CBORDecoder} from "../node_modules/@zondax/filecoin-solidity/contracts/v0.8/utils/CborDecode.sol";
import {CommonTypes} from "../node_modules/@zondax/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import {BigIntCBOR} from "../node_modules/@zondax/filecoin-solidity/contracts/v0.8/cbor/BigIntCbor.sol";
//import { Buffer } from "./Buffer.sol";

using CBOR for CBOR.CBORBuffer;
using CBORDecoder for bytes;
using BigIntCBOR for CommonTypes.BigInt;
using BigIntCBOR for bytes;
using FilecoinCBOR for CBOR.CBORBuffer;

struct MarketDealNotifyParams {
    bytes dealProposal;
    uint64 dealId;
}

    struct Bid {
        uint256 bid_id;
        string path;
        CommonTypes.FilAddress providerFilAddress;
        address provider;
        bool activated;
        bool accepted;
        BountyParameters bountyParams;
    }

    struct BountyParameters {
        // represents specifics reagrdeing bid
        string region;
        uint256 storageCapacity;
        uint256 minReliability;
        uint256 maxPrice;
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

    struct PieceToProviderSet {
        bytes provider;
        bool valid;
    }

    struct BidValiditySet {
        address bidder;
        bytes32 bounty_id;
        bool bidIsAccepted;
    }

/// @param piece_cid PieceCID.
/// @param piece_size the size of the piece.
/// @param verified_deal if the deal is verified or not.
/// @param client the address of the storage client.
/// @param provider the address of the storage provider.
/// @param label any label that client choose for the deal.
/// @param start_epoch the chain epoch to start the deal.
/// @param end_epoch the chain epoch to end the deal.
/// @param storage_price_per_epoch the token amount to pay to provider per epoch.
/// @param provider_collateral the token amount as collateral paid by the provider.
/// @param client_collateral the token amount as collateral paid by the client.
struct DealRequest {
    uint64 piece_size;
    bool verified_deal;
    CommonTypes.Cid piece_cid;
    CommonTypes.DealLabel label;
    CommonTypes.FilAddress client;
    CommonTypes.FilAddress provider;
    int64 start_epoch;
    int64 end_epoch;
    CommonTypes.BigInt storage_price_per_epoch;
    CommonTypes.BigInt provider_collateral;
    CommonTypes.BigInt client_collateral;
    ExtraParamsV1 extra_params;
}

struct ExtraParamsV1 {
    string location_ref; // where the prov can find the file
    uint64 car_size; // size of file
    bool skip_ipni_announce;
    bool remove_unsealed_copy;
}

function deserializeMarketDealNotifyParams(
    bytes memory rawResp
) pure returns (MarketDealNotifyParams memory ret) {
    uint byteIdx = 0;
    uint len;

    (len, byteIdx) = rawResp.readFixedArray(byteIdx);
    assert(len == 2);

    (ret.dealProposal, byteIdx) = rawResp.readBytes(byteIdx);
    (ret.dealId, byteIdx) = rawResp.readUInt64(byteIdx);
}

// function serializeDealProposal(MarketTypes.DealProposal memory dealProposal) pure returns (bytes memory) {
//     // FIXME what should the max length be on the buffer?
//     Buffer.buffer memory buf = Buffer.init(64);

//     buf.startFixedArray(11);

//     // TODO writeCid is buggy because it does not set the expected 0x00 prefix as per
//     // https://ipld.io/specs/codecs/dag-cbor/spec/#links. We do it here, and will submit
//     // a bugfix upstream.
//     buf.writeCid(bytes.concat(hex'00', dealProposal.piece_cid.data));
//     buf.writeUInt64(dealProposal.piece_size);
//     buf.writeBool(dealProposal.verified_deal);
//     buf.writeBytes(dealProposal.client.data);
//     buf.writeBytes(dealProposal.provider.data);
//     buf.writeString(dealProposal.label);
//     buf.writeInt64(dealProposal.start_epoch);
//     buf.writeInt64(dealProposal.end_epoch);
//     buf.writeBytes(dealProposal.storage_price_per_epoch.serializeBigInt());
//     buf.writeBytes(dealProposal.provider_collateral.serializeBigInt());
//     buf.writeBytes(dealProposal.client_collateral.serializeBigInt());

//     return buf.data();
// }

function deserializeDealProposal(
    bytes memory rawResp
) pure returns (DealRequest memory ret) {
    uint byteIdx = 0;
    uint len;

    (len, byteIdx) = rawResp.readFixedArray(byteIdx);
    assert(len == 11);

    bytes memory piece_cid;
    (piece_cid, byteIdx) = rawResp.readBytes(byteIdx);
    assert(piece_cid[0] == 0x00);

    // Pop off the first byte, which corresponds to the historical multibase 0x00 byte.
    // https://ipld.io/specs/codecs/dag-cbor/spec/#links
    ret.piece_cid.data = new bytes(piece_cid.length - 1);
    for (uint256 i = 1; i < piece_cid.length; i++) {
        ret.piece_cid.data[i - 1] = piece_cid[i];
    }

    (ret.piece_size, byteIdx) = rawResp.readUInt64(byteIdx);
    (ret.verified_deal, byteIdx) = rawResp.readBool(byteIdx);
    (ret.client.data, byteIdx) = rawResp.readBytes(byteIdx);
    (ret.provider.data, byteIdx) = rawResp.readBytes(byteIdx);

    (ret.label.data, byteIdx) = rawResp.readBytes(byteIdx);
    (ret.start_epoch, byteIdx) = rawResp.readInt64(byteIdx);
    (ret.end_epoch, byteIdx) = rawResp.readInt64(byteIdx);

    bytes memory storage_price_per_epoch_bytes;
    (storage_price_per_epoch_bytes, byteIdx) = rawResp.readBytes(byteIdx);
    ret.storage_price_per_epoch = storage_price_per_epoch_bytes
        .deserializeBigInt();

    bytes memory provider_collateral_bytes;
    (provider_collateral_bytes, byteIdx) = rawResp.readBytes(byteIdx);
    ret.provider_collateral = provider_collateral_bytes.deserializeBigInt();

    bytes memory client_collateral_bytes;
    (client_collateral_bytes, byteIdx) = rawResp.readBytes(byteIdx);
    ret.client_collateral = client_collateral_bytes.deserializeBigInt();
}
