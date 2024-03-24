// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.23;

import {IERC721} from "../interfaces/IERC721.sol";
import {IERC1155} from "../interfaces/IERC1155.sol";
import {LibMeta} from "../libraries/LibMeta.sol";
import {Modifiers, ERC721Listing, ERC1155Listing} from "../libraries/LibAppStorage.sol";
import {LibERC1155Marketplace} from "../libraries/LibERC1155Marketplace.sol";

contract AuctionFacet is Modifiers {
    // Events
    // ERC721
    event ERC721ListingAdd(
        uint256 indexed listingId,
        address indexed seller,
        address erc721TokenAddress,
        uint256 erc721TokenId,
        uint256 priceInWei,
        uint256 time
    );

    // ERC1155
    event ERC1155ListingAdd(
        uint256 indexed listingId,
        address indexed seller,
        address erc1155TokenAddress,
        uint256 erc1155TypeId,
        uint256 quantity,
        uint256 priceInWei,
        uint256 time
    );

    // ERC721
    function createERC721Auction(
        address _erc721TokenAddress,
        uint256 _erc721TokenId,
        uint256 _priceInWei,
        uint256 _duration
    ) internal {
        IERC721 erc721Token = IERC721(_erc721TokenAddress);
        address msgSender = LibMeta.msgSender();
        require(
            erc721Token.ownerOf(_erc721TokenId) == msgSender,
            "ERC721Auction: Not owner of ERC721 token"
        );
        require(
            _erc721TokenAddress == address(this) ||
                erc721Token.isApprovedForAll(msgSender, address(this)) ||
                erc721Token.getApproved(_erc721TokenId) == address(this),
            "ERC721Auction: Not approved for transfer"
        );
        require(
            _priceInWei >= 1e18,
            "ERC721Auction: price should be 1 Token or larger"
        );
        require(
            _duration > block.timestamp + 600,
            "ERC721Auction: duration should be higher than ten minutes"
        );

        s.nextERC721ListingId++;
        uint256 listingId = s.nextERC721ListingId;

        uint256 oldListingId = s.erc721TokenToListingId[_erc721TokenAddress][
            _erc721TokenId
        ][msgSender];
        if (oldListingId != 0) {
            s.erc721Listings[oldListingId] = ERC721Listing({
                listingId: 0,
                seller: address(0),
                erc721TokenAddress: address(0),
                erc721TokenId: 0,
                priceInWei: 0,
                timeCreated: 0,
                timePurchased: 0,
                cancelled: true
            });
        }

        s.erc721Listings[listingId] = ERC721Listing({
            listingId: listingId,
            seller: msgSender,
            erc721TokenAddress: _erc721TokenAddress,
            erc721TokenId: _erc721TokenId,
            priceInWei: _priceInWei,
            timeCreated: block.timestamp,
            timePurchased: 0,
            cancelled: false
        });

        emit ERC721ListingAdd(
            listingId,
            msgSender,
            _erc721TokenAddress,
            _erc721TokenId,
            _priceInWei,
            block.timestamp
        );
    }

    function cancelERC721Auction(uint256 _listingId) internal {
        ERC721Listing storage listing = s.erc721Listings[_listingId];
        require(listing.listingId != 0, "ERC721Auction: Invalid listingId");
        require(
            listing.seller == LibMeta.msgSender(),
            "ERC721Auction: Not seller"
        );
        require(listing.timePurchased == 0, "ERC721Auction: Already purchased");
        require(listing.cancelled == false, "ERC721Auction: Already cancelled");

        listing.cancelled = true;
    }

    function bidERC721Auction(uint256 _listingId, uint256 _bidAmount) internal {
        
    }

    function getERC721Listing(
        uint256 _listingId
    ) internal view returns (ERC721Listing memory listing) {
        listing = s.erc721Listings[_listingId];
        require(listing.listingId != 0, "ERC721Auction: Invalid listingId");
    }

    function getERC721Listings()
        internal
        view
        returns (ERC721Listing[] memory listings)
    {
        uint256 listingCount = s.nextERC721ListingId;
        listings = new ERC721Listing[](listingCount);
        for (uint256 i; i < listingCount; i++) {
            ERC721Listing storage listing = s.erc721Listings[i + 1];
            if (listing.listingId != 0) {
                listings[i] = listing;
            }
        }
    }

    // ERC1155
    function createERC1155Auction(
        address _erc1155TokenAddress,
        uint256 _erc1155TypeId,
        uint256 _quantity,
        uint256 _priceInWei
    ) internal {
        address seller = LibMeta.msgSender();
        IERC1155 erc1155Token = IERC1155(_erc1155TokenAddress);
        require(
            erc1155Token.balanceOf(seller, _erc1155TypeId) >= _quantity,
            "ERC1155Auction: Not enough ERC1155 token"
        );
        require(
            _erc1155TokenAddress == address(this) ||
                erc1155Token.isApprovedForAll(seller, address(this)),
            "ERC1155Auction: Not approved for transfer"
        );
        uint256 cost = _quantity * _priceInWei;
        require(
            cost >= 1e18,
            "ERC1155Auction: cost should be 1 Token or larger"
        );

        s.nextERC1155ListingId++;
        uint256 listingId = s.nextERC1155ListingId;
        if (listingId == 0) {
            s.nextERC1155ListingId++;
            listingId = s.nextERC1155ListingId;
            s.erc1155TokenToListingId[_erc1155TokenAddress][_erc1155TypeId][
                    seller
                ] = listingId;
            s.erc1155Listings[listingId] = ERC1155Listing({
                listingId: listingId,
                seller: seller,
                erc1155TokenAddress: _erc1155TokenAddress,
                erc1155TypeId: _erc1155TypeId,
                quantity: _quantity,
                priceInWei: _priceInWei,
                timeCreated: block.timestamp,
                timeLastPurchased: 0,
                sourceListingId: 0,
                sold: false,
                cancelled: false
            });
            LibERC1155Marketplace.addERC1155ListingItem(
                seller,
                "listed",
                listingId
            );

            emit ERC1155ListingAdd(
                listingId,
                seller,
                _erc1155TokenAddress,
                _erc1155TypeId,
                _quantity,
                _priceInWei,
                block.timestamp
            );
        } else {
            ERC1155Listing storage listing = s.erc1155Listings[listingId];
            listing.quantity = _quantity;
            emit LibERC1155Marketplace.UpdateERC1155Listing(
                listingId,
                _quantity,
                listing.priceInWei,
                block.timestamp
            );
        }
    }

    function cancelERC1155Auction(uint256 _listingId) internal {
        ERC1155Listing storage listing = s.erc1155Listings[_listingId];
        require(listing.listingId != 0, "ERC1155Auction: Invalid listingId");
        require(
            listing.seller == LibMeta.msgSender(),
            "ERC1155Auction: Not seller"
        );
        require(
            listing.timeLastPurchased == 0,
            "ERC1155Auction: Already purchased"
        );
        require(
            listing.cancelled == false,
            "ERC1155Auction: Already cancelled"
        );

        listing.cancelled = true;
    }


}
