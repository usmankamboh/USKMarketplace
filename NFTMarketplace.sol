// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

abstract contract Ownable is Context {
    address private _owner;
    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IERC721 is IERC165 {
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    function balanceOf(address owner) external view returns (uint256 balance);

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function approve(address to, uint256 tokenId) external;

    function setApprovalForAll(address operator, bool approved) external;

    function getApproved(uint256 tokenId)
        external
        view
        returns (address operator);

    function isApprovedForAll(address owner, address operator)
        external
        view
        returns (bool);
}

contract NFTMarketplace is Ownable {
    struct Listing {
        address seller;
        uint256 price;
        bool isListed;
    }
    mapping(address => mapping(uint256 => Listing)) public listings;
    address feeCollector;
    uint256 FEE_PERCENTAGE = 1;

    event NFTListed(
        address indexed seller,
        address indexed nftContract,
        uint256 indexed tokenId,
        uint256 price
    );
    event NFTUnlisted(
        address indexed seller,
        address indexed nftContract,
        uint256 indexed tokenId
    );
    event NFTBought(
        address indexed buyer,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 price
    );

    constructor() Ownable(msg.sender) {
        feeCollector = 0x1f78AEC0825C1682D328c859A5a2B194BB862019;
    }

    function listNFT(
        address _nftContract,
        uint256 _tokenId,
        uint256 _price
    ) public payable{
        require(_price > 0, "Price must be greater than zero");
        IERC721 nftContract = IERC721(_nftContract);
        require(
            nftContract.ownerOf(_tokenId) == msg.sender,
            "You do not own this NFT"
        );
        require(
            nftContract.isApprovedForAll(msg.sender, address(this)) ||
                nftContract.getApproved(_tokenId) == address(this),
            "Marketplace not approved"
        );
        IERC721(_nftContract).transferFrom(msg.sender, address(this), _tokenId);

        uint256 listingFee = (_price * FEE_PERCENTAGE) / 100;
        require(listingFee > 0, "Listing fee is too low");
        require(msg.value >= listingFee, "Insufficient funds for listing fee");

        (bool success, ) = feeCollector.call{value: msg.value}("");
        require(success, "Payment to seller failed");
        listings[_nftContract][_tokenId] = Listing(msg.sender, _price, true);

        emit NFTListed(msg.sender, _nftContract, _tokenId, _price);
    }

    function unlistNFT(address _nftContract, uint256 _tokenId) external {
        Listing memory listing = listings[_nftContract][_tokenId];
        require(listing.isListed == true, "NFT is not available for sale");
        require(listing.seller == msg.sender, "You are not the seller");
        listing.isListed = false;
        IERC721(_nftContract).safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId
        );
        emit NFTUnlisted(msg.sender, _nftContract, _tokenId);
    }

    function buyNFT(address _nftContract, uint256 _tokenId) public payable {
        Listing storage listing = listings[_nftContract][_tokenId];
        require(listing.price > 0, "NFT is not listed for sale");
        require(msg.value == listing.price, "Incorrect price sent");
        require(listing.seller != address(0), "Invalid seller address");
        (bool success, ) = listing.seller.call{value: msg.value}("");
        require(success, "Payment to seller failed");
        require(
            IERC721(_nftContract).ownerOf(_tokenId) == address(this),
            "Contract does not own the NFT"
        );
        IERC721(_nftContract).safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId
        );
        listing.isListed = false;
        emit NFTBought(
            msg.sender,
            listing.seller,
            _nftContract,
            _tokenId,
            listing.price
        );
    }

    function setFeeCollector(address _newFeeCollector) public onlyOwner {
        require(_newFeeCollector != address(0), "Invalid address");
        feeCollector = _newFeeCollector;
    }

    function getNFTData(address _nftContract, uint256 _tokenId)
        public
        view
        returns (
            address,
            uint256,
            bool
        )
    {
        Listing memory listing = listings[_nftContract][_tokenId];
        return (listing.seller, listing.price, listing.isListed);
    }
}
