// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./lib/AccessControl.sol";
import "./lib/UnstructuredStorage.sol";

contract AirDrop is AccessControl, ReentrancyGuard{
    using UnstructuredStorage for bytes32;

    struct AirdropData {
        uint256 amount;
        uint256 claimedAmount;
        uint64  claimIndex;
    }

    address public tokenAddress;
    uint256 public startTimestamp;
    uint256 public endTimestamp;
    uint256 public tgePercent;
    uint64  public vestingCount;
    mapping(address => AirdropData) private airdrops;

    event Claimed(address indexed receiver, uint256 amount, uint256 timestamp);
    event AirdropStartTimeUpdated(uint256 newStartTime);
    event AirdropEndTimeUpdated(uint256 newEndTime);

    error CannotClaim();
    error AlreadyClaimed();

    constructor(
        address _tokenAddress, 
        uint256 _startTimestamp, 
        uint256 _endTimestamp, 
        uint256 _tgePercent, 
        uint64  _vestingCount 
    ) {
        require(_startTimestamp < _endTimestamp, "INVALID_TIMESTAMP");
        tokenAddress = _tokenAddress;
        startTimestamp = _startTimestamp;
        endTimestamp = _endTimestamp;
        tgePercent = _tgePercent;
        vestingCount = _vestingCount;
    }

    function updateStartTimestamp(uint256 _startTimestamp) public onlyRole(ADMIN_ROLE) {
        startTimestamp = _startTimestamp;
        emit AirdropStartTimeUpdated(_startTimestamp);
    }
    
    function updateEndTimestamp(uint256 _endTimestamp) public onlyRole(ADMIN_ROLE) {
        endTimestamp = _endTimestamp;
        emit AirdropEndTimeUpdated(_endTimestamp);
    }

    function isStarted() public view returns (bool) {
        return block.timestamp >= startTimestamp;
    }

    function isEnded() public view returns (bool) {
        return block.timestamp >= endTimestamp;
    }

    function claim() external nonReentrant {
        require(block.timestamp >= startTimestamp, "AIRDOP_NOT_STARTED");
        require(block.timestamp < endTimestamp, "AIRDROP_ENDED");

        uint256 totalClaimAmount = airdrops[msg.sender].amount;
        uint256 claimedAmount = airdrops[msg.sender].claimedAmount;

        /*
        startTimestamp = 0, endTimestamp = 5, vestingCount = 4 라면
        vestingTerm = (5 - 0) / (4 + 1) = 1

        |-----------------|-----------------|-----------------|-----------------|-----------------|
        0                 1                 2                 3                 4                 x
        tge               vesting1          vesting2          vesting3          vesting4          end
        */
        uint256 term = block.timestamp - startTimestamp;
        uint256 vestingTerm = (endTimestamp - startTimestamp) / (vestingCount + 1);
        uint64 claimIndex = uint64(term / vestingTerm);

        require(claimIndex > airdrops[msg.sender].claimIndex, "CannotClaim");

        uint256 vestingAmountPerTerm = totalClaimAmount * (100 - tgePercent) / 100 / vestingCount;
        uint256 claimAmount;
        
        if (claimIndex == vestingCount) {
            // 마지막 vesting이면 남은 금액 전부를 전송
            claimAmount = totalClaimAmount - claimedAmount;
        } else {
            // 아니면 해당 vesting 금액만 전송
            claimAmount = vestingAmountPerTerm * (claimIndex - airdrops[msg.sender].claimIndex);
        }
        
        // 클레임 횟수가 0 이라면 TGE 금액을 추가로 전송
        if (airdrops[msg.sender].claimIndex == 0) {
            claimAmount += totalClaimAmount * tgePercent / 100;
        }

        uint256 balance = IERC20(tokenAddress).balanceOf(address(this));
        require(balance >= claimAmount, "INSUFFICIENT_BALANCE");

        IERC20(tokenAddress).transfer(msg.sender, claimAmount);
        airdrops[msg.sender].claimedAmount += claimAmount;
        airdrops[msg.sender].claimIndex = claimIndex;

        emit Claimed(msg.sender, claimAmount, block.timestamp);
    }

    function getAirdropData(address _address) public view returns (AirdropData memory) {
        require(airdrops[_address].amount > 0, "NO_DATA");
        return airdrops[_address];
    }

    function insertAirdropData(address _address, uint256 _amount) public onlyRole(ADMIN_ROLE) {
        require(airdrops[_address].amount == 0, "DUPLICATED_DATA");
        airdrops[_address] = AirdropData({
            amount: _amount,
            claimedAmount: 0,
            claimIndex: 0
        });
    }

    function batchInsertAirdropData(
        address[] memory _address,
        uint256[] memory _amount
    ) public onlyRole(ADMIN_ROLE) {
        require(_address.length == _amount.length, "INVALID_INPUT_DATA");

        for (uint256 i = 0; i < _address.length; i++) {
            require(airdrops[_address[i]].amount == 0, "DUPLICATED_DATA");
            airdrops[_address[i]] = AirdropData({
                amount: _amount[i],
                claimedAmount: 0,
                claimIndex: 0
            });
        }
    }

    function updateAirdropData(
        address _address,
        AirdropData memory _airdropData
    ) public onlyRole(ADMIN_ROLE) {
        airdrops[_address] = _airdropData;
    }

    function deleteAirdropData(
        address _address
    ) public onlyRole(ADMIN_ROLE) {
        delete airdrops[_address];
    }

    function transferTokenToOnwer() public onlyRole(ADMIN_ROLE) {
        uint256 balance = IERC20(tokenAddress).balanceOf(address(this));
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "FAILED_TO_TRANSFER");
    }
}
