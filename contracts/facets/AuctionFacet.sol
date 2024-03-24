// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.23;

import {IERC721} from "../interfaces/IERC721.sol";
import {IERC1155} from "../interfaces/IERC1155.sol";
import {LibMeta} from "../libraries/LibMeta.sol";
import {Modifiers, ERC721Auction, ERC1155Auction} from "../libraries/LibAppStorage.sol";
import {LibERC1155Marketplace} from "../libraries/LibERC1155Marketplace.sol";

contract AuctionFacet is Modifiers {
    // Events
    // ERC721
    event ERC721AuctionAdd(
        uint256 indexed auctionId,
        address indexed seller,
        address erc721TokenAddress,
        uint256 erc721TokenId,
        uint256 priceInWei,
        uint256 time
    );

    // ERC1155
    event ERC1155AuctionAdd(
        uint256 indexed auctionId,
        address indexed seller,
        address erc1155TokenAddress,
        uint256 erc1155TypeId,
        uint256 quantity,
        uint256 priceInWei,
        uint256 time
    );

    event UpdateERC1155Auction(
        uint256 indexed auctionId,
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

        s.nextERC721AuctionId++;
        uint256 auctionId = s.nextERC721AuctionId;

        uint256 oldAuctionId = s.erc721TokenToAuctionId[_erc721TokenAddress][
            _erc721TokenId
        ][msgSender];
        if (oldAuctionId != 0) {
            s.erc721Auctions[oldAuctionId] = ERC721Auction({
                auctionId: 0,
                seller: address(0),
                erc721TokenAddress: address(0),
                erc721TokenId: 0,
                priceInWei: 0,
                timeCreated: 0,
                timePurchased: 0,
                cancelled: true
            });
        }

        s.erc721Auctions[auctionId] = ERC721Auction({
            auctionId: auctionId,
            seller: msgSender,
            erc721TokenAddress: _erc721TokenAddress,
            erc721TokenId: _erc721TokenId,
            priceInWei: _priceInWei,
            timeCreated: block.timestamp,
            timePurchased: 0,
            cancelled: false
        });

        emit ERC721AuctionAdd(
            auctionId,
            msgSender,
            _erc721TokenAddress,
            _erc721TokenId,
            _priceInWei,
            block.timestamp
        );
    }

    function cancelERC721Auction(uint256 _auctionId) internal {
        ERC721Auction storage auction = s.erc721Auctions[_auctionId];
        require(auction.auctionId != 0, "ERC721Auction: Invalid auctionId");
        require(
            auction.seller == LibMeta.msgSender(),
            "ERC721Auction: Not seller"
        );
        require(auction.timePurchased == 0, "ERC721Auction: Already purchased");
        require(auction.cancelled == false, "ERC721Auction: Already cancelled");

        auction.cancelled = true;
    }

    function bidERC721Auction(
        uint256 _auctionId,
        uint256 _bidAmount
    ) internal {}

    function getERC721Auction(
        uint256 _auctionId
    ) internal view returns (ERC721Auction memory auction) {
        auction = s.erc721Auctions[_auctionId];
        require(auction.auctionId != 0, "ERC721Auction: Invalid auctionId");
    }

    function getERC721Auctions()
        internal
        view
        returns (ERC721Auction[] memory auctions)
    {
        uint256 auctionCount = s.nextERC721AuctionId;
        auctions = new ERC721Auction[](auctionCount);
        for (uint256 i; i < auctionCount; i++) {
            ERC721Auction storage auction = s.erc721Auctions[i + 1];
            if (auction.auctionId != 0) {
                auctions[i] = auction;
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

        s.nextERC1155AuctionId++;
        uint256 auctionId = s.nextERC1155AuctionId;
        if (auctionId == 0) {
            s.nextERC1155AuctionId++;
            auctionId = s.nextERC1155AuctionId;
            s.erc1155TokenToAuctionId[_erc1155TokenAddress][_erc1155TypeId][
                    seller
                ] = auctionId;
            s.erc1155Auctions[auctionId] = ERC1155Auction({
                auctionId: auctionId,
                seller: seller,
                erc1155TokenAddress: _erc1155TokenAddress,
                erc1155TypeId: _erc1155TypeId,
                quantity: _quantity,
                priceInWei: _priceInWei,
                timeCreated: block.timestamp,
                timeLastPurchased: 0,
                sourceAuctionId: 0,
                sold: false,
                cancelled: false
            });
            LibERC1155Marketplace.addERC1155AuctionItem(
                seller,
                "listed",
                auctionId
            );

            emit ERC1155AuctionAdd(
                auctionId,
                seller,
                _erc1155TokenAddress,
                _erc1155TypeId,
                _quantity,
                _priceInWei,
                block.timestamp
            );
        } else {
            ERC1155Auction storage auction = s.erc1155Auctions[auctionId];
            auction.quantity = _quantity;
            emit UpdateERC1155Auction(
                auctionId,
                _quantity,
                auction.priceInWei,
                block.timestamp
            );
        }
    }

    function cancelERC1155Auction(uint256 _auctionId) internal {
        ERC1155Auction storage auction = s.erc1155Auctions[_auctionId];
        require(auction.auctionId != 0, "ERC1155Auction: Invalid auctionId");
        require(
            auction.seller == LibMeta.msgSender(),
            "ERC1155Auction: Not seller"
        );
        require(
            auction.timeLastPurchased == 0,
            "ERC1155Auction: Already purchased"
        );
        require(
            auction.cancelled == false,
            "ERC1155Auction: Already cancelled"
        );

        auction.cancelled = true;
    }
}
