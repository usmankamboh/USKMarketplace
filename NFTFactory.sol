// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
import "./NFT.sol";

contract NFTFactory is Ownable {
    mapping(address => address[]) public userCollection;
    address[] deployedNFTContracts;
    address feesCollector;
    uint256 fees;
    event NFTContractCreated(address contractAddress);

    constructor() Ownable(msg.sender) {
        setFeesCollector(0x1f78AEC0825C1682D328c859A5a2B194BB862019);
        fees = 2 ether;
    }

    function createNFTCollection(string memory name, string memory symbol)
        public
        payable
    {
        require(msg.value == fees, "Fees should be paid");
        NFT newNFTCollection = new NFT(name, symbol,msg.sender);
        deployedNFTContracts.push(address(newNFTCollection));
        userCollection[msg.sender].push(address(newNFTCollection));
        payable(feesCollector).transfer(msg.value);
        emit NFTContractCreated(address(newNFTCollection));
    }

    function setFeesCollector(address _newAddress) public onlyOwner {
        feesCollector = _newAddress;
    }

    function setFees(uint256 _newfees) public onlyOwner {
        fees = _newfees;
    }

    function getDeployedNFTContracts(address user)
        public
        view
        returns (address[] memory)
    {
        return userCollection[user];
    }

    function getTotalNFT() public view returns (uint256) {
        return deployedNFTContracts.length;
    }

    function getAllNFTsAddress() public view returns (address[] memory) {
        return deployedNFTContracts;
    }
}
