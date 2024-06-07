// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@klaytn/contracts/KIP/token/KIP7/IKIP7.sol";
import "./Ownable.sol";

contract AirDrop is Ownable {
    // This declares a state variable that would store the contract address
    IKIP7 public tokenInstance;

    struct AirdropData {
        bool claimable;
        uint256 amount;
    }

    uint256 public startTimestamp;
    uint256 public endTimestamp;
    mapping(address => AirdropData) private airdrops;

    event Claimed(address indexed receiver, uint256 amount);

    /*
    constructor function to set token address
   */
    constructor(address _tokenAddress, uint256 _startTimestamp, uint256 _endTimestamp) {
        tokenInstance = IKIP7(_tokenAddress);
        startTimestamp = _startTimestamp;
        endTimestamp = _endTimestamp;
    }

    function updateStartTimestamp(
        uint256 _startTimestamp
    ) public onlyOwner {
        startTimestamp = _startTimestamp;
    }
    
    function updateEndTimestamp(
        uint256 _endTimestamp
    ) public onlyOwner {
        endTimestamp = _endTimestamp;
    }

    function claim() external {
        require(block.timestamp >= startTimestamp, "AIRDOP_NOT_STARTED");
        require(block.timestamp <= endTimestamp, "AIRDROP_ENDED");
        require(airdrops[msg.sender].claimable, "CANNOT_CLAIM");

        uint256 airdropAmount = airdrops[msg.sender].amount;
        require(airdropAmount > 0, "ALREADY_CLAIMED");

        uint256 balance = tokenInstance.balanceOf(address(this));
        require(balance >= airdropAmount, "INSUFFICIENT_BALANCE");

        tokenInstance.transfer(msg.sender, airdropAmount);
        airdrops[msg.sender].amount = 0;

        emit Claimed(msg.sender, airdropAmount);
    }

    function getAirdropData(
        address _address
    ) public view returns (AirdropData memory) {
        require(airdrops[_address].claimable, "NO_DATA");
        return airdrops[_address];
    }

    function insertAirdropData(
        address _address,
        uint256 _amount
    ) public onlyOwner {
        if (airdrops[_address].claimable) {
            return;
        }
        airdrops[_address] = AirdropData({
            claimable: true,
            amount: _amount
        });
    }

    function batchInsertAirdropData(
        address[] memory _address,
        uint256[] memory _amount
    ) public onlyOwner {
        require(_address.length == _amount.length, "INVALID_INPUT_DATA");

        for (uint256 i = 0; i < _address.length; i++) {
            if (airdrops[_address[i]].claimable) {
                continue;
            }
            airdrops[_address[i]] = AirdropData({
                claimable: true,
                amount: _amount[i]
            });
        }
    }

    function updateAirdropData(
        address _address,
        AirdropData memory _airdropData
    ) public onlyOwner {
        airdrops[_address] = _airdropData;
    }

    function deleteAirdropData(
        address _address
    ) public onlyOwner {
        airdrops[_address].claimable = false;
        airdrops[_address].amount = 0;
    }

    function transferTokenToOnwer() public onlyOwner {
        uint256 balance = tokenInstance.balanceOf(address(this));
        (bool success, ) = owner.call{value: balance}("");
        require(success, "FAILED_TO_TRANSFER");
    }
}
