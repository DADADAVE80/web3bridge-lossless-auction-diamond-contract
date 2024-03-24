// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.23;

import {LibDiamond} from "./LibDiamond.sol";

struct AuctionListItem {
    uint256 parentAuctionId;
    uint256 auctionId;
    uint256 childAuctionId;
}

struct ERC721Auction {
    uint256 auctionId;
    address seller;
    address erc721TokenAddress;
    uint256 erc721TokenId;
    uint256 priceInWei;
    uint256 timeCreated;
    uint256 timePurchased;
    bool cancelled;
}

struct ERC1155Auction {
    uint256 auctionId;
    address seller;
    address erc1155TokenAddress;
    uint256 erc1155TypeId;
    uint256 quantity;
    uint256 priceInWei;
    uint256 timeCreated;
    uint256 timeLastPurchased;
    uint256 sourceAuctionId;
    bool sold;
    bool cancelled;
}

struct AppStorage {
    // ERC721 Auction
    uint256 nextERC721AuctionId;
    mapping(address => mapping(uint256 => mapping(address => uint256))) erc721TokenToAuctionId;
    mapping(uint256 => ERC721Auction) erc721Auctions;
    // ERC1155 Auction
    uint256 nextERC1155AuctionId;
    mapping(address => mapping(uint256 => mapping(address => uint256))) erc1155TokenToAuctionId;
    mapping(uint256 => ERC1155Auction) erc1155Auctions;

    // ERC20 Facet
    string name;
    string symbol;
    uint8 decimals;
    uint256 totalSupply;
    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowances;

}

library LibAppStorage {
    function diamondStorage() internal pure returns (AppStorage storage ds) {
        assembly {
            ds.slot := 0
        }
    }
}

contract Modifiers {
    AppStorage internal s;
    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }
}
