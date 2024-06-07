// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@klaytn/contracts/KIP/token/KIP7/IKIP7.sol";
import "./Ownable.sol";

contract AirDrop is Ownable {
    // This declares a state variable that would store the contract address
    IKIP7 public tokenInstance;

    enum ClaimStatus {
        CANNOT_CLAIM,
        CLAIMABLE,
        CLAIMED
    }

    struct AirdropData {
        ClaimStatus status;
        uint256 amount;
    }

    uint256 public startTimestamp;
    uint256 public endTimestamp;
    mapping(address => AirdropData) private airdrops;

    event Claimed(address indexed receiver, uint256 amount);
    event AirdropStartTimeUpdated(uint256 newStartTime);
    event AirdropEndTimeUpdated(uint256 newEndTime);

    constructor(address _tokenAddress, uint256 _startTimestamp, uint256 _endTimestamp) {
        tokenInstance = IKIP7(_tokenAddress);
        startTimestamp = _startTimestamp;
        endTimestamp = _endTimestamp;
    }

    function updateStartTimestamp(
        uint256 _startTimestamp
    ) public onlyOwner {
        startTimestamp = _startTimestamp;
        emit AirdropStartTimeUpdated(_startTimestamp);
    }
    
    function updateEndTimestamp(
        uint256 _endTimestamp
    ) public onlyOwner {
        endTimestamp = _endTimestamp;
        emit AirdropEndTimeUpdated(_endTimestamp);
    }

    function isStarted() public view returns (bool) {
        return block.timestamp >= startTimestamp;
    }

    function isEnded() public view returns (bool) {
        return block.timestamp > endTimestamp;
    }

    function claim() external {
        require(block.timestamp >= startTimestamp, "AIRDOP_NOT_STARTED");
        require(block.timestamp <= endTimestamp, "AIRDROP_ENDED");
        
        ClaimStatus status = airdrops[msg.sender].status;

        if (status == ClaimStatus.CANNOT_CLAIM) {
            revert("CANNOT_CLAIM");
        }
        else if (status == ClaimStatus.CLAIMED) {
            revert("ALREADY_CLAIMED");
        }

        uint256 airdropAmount = airdrops[msg.sender].amount;
        uint256 balance = tokenInstance.balanceOf(address(this));
        require(balance >= airdropAmount, "INSUFFICIENT_BALANCE");

        tokenInstance.transfer(msg.sender, airdropAmount);
        airdrops[msg.sender].amount = 0;
        airdrops[msg.sender].status = ClaimStatus.CLAIMED;

        emit Claimed(msg.sender, airdropAmount);
    }

    function getAirdropData(
        address _address
    ) public view returns (AirdropData memory) {
        require(airdrops[_address].status != ClaimStatus.CANNOT_CLAIM, "NO_DATA");
        return airdrops[_address];
    }

    function insertAirdropData(
        address _address,
        uint256 _amount
    ) public onlyOwner {
        if (airdrops[_address].status == ClaimStatus.CLAIMABLE) {
            return;
        }
        airdrops[_address] = AirdropData({
            status: ClaimStatus.CLAIMABLE,
            amount: _amount
        });
    }

    function batchInsertAirdropData(
        address[] memory _address,
        uint256[] memory _amount
    ) public onlyOwner {
        require(_address.length == _amount.length, "INVALID_INPUT_DATA");

        for (uint256 i = 0; i < _address.length; i++) {
            if (airdrops[_address[i]].status == ClaimStatus.CLAIMABLE) {
                continue;
            }
            airdrops[_address[i]] = AirdropData({
                status: ClaimStatus.CLAIMABLE,
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
        airdrops[_address].status = ClaimStatus.CANNOT_CLAIM;
        airdrops[_address].amount = 0;
    }

    function transferTokenToOnwer() public onlyOwner {
        uint256 balance = tokenInstance.balanceOf(address(this));
        (bool success, ) = owner.call{value: balance}("");
        require(success, "FAILED_TO_TRANSFER");
    }
}
