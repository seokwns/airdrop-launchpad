// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./lib/AccessControl.sol";

contract AirdropLock is AccessControl, ReentrancyGuard {
    struct AirdropInfo {
        uint256 amount;
        uint256 instantAmount;
        uint256 claimedAmount;
        uint64 lockupEndTimestamp;
        bool claimed;
    }

    uint16 public constant PERCENT_PRECISION = 1e4;
    address public constant BURNNER_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    IERC20 public token;

    uint64 public startTimestamp;
    uint64 public endTimestamp;
    uint64 public lockupPeriod;

    uint256 public dataLength;
    mapping(uint256 => AirdropInfo) public airdropInfo;
    mapping(address => uint256) public airdropIndex;

    uint256 public totalAirdropAmount;
    uint256 public burnAmount;
    uint256 public lockupAmount;

    event AirdropClaimed(address indexed user, uint256 amount);
    event Lockup(address indexed user, uint256 lockupEndTimestamp);
    event AirdropClosed();
    event Payouted();
    event Burned(uint256 amount);

    constructor() {
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    modifier onlyAirdropOpen() {
        require(block.timestamp >= startTimestamp, "Airdrop: Airdrop not started");
        require(block.timestamp < endTimestamp, "Airdrop: Airdrop ended");
        _;
    }

    function initialize(
        address _token,
        uint64 _startTimestamp,
        uint64 _endTimestamp,
        uint64 _lockupPeriod
    ) external onlyRole(ADMIN_ROLE) {
        require(_token != address(0), "Airdrop: Invalid token address");
        require(_startTimestamp < _endTimestamp, "Airdrop: Invalid start and end timestamp");
        require(_endTimestamp < _startTimestamp + _lockupPeriod, "Airdrop: Invalid lockup period");

        token = IERC20(_token);
        startTimestamp = _startTimestamp;
        endTimestamp = _endTimestamp;
        lockupPeriod = _lockupPeriod;
    }

    function setLockupPeriod(uint64 _lockupPeriod) external onlyRole(ADMIN_ROLE) {
        lockupPeriod = _lockupPeriod;
    }

    function setStartTimestamp(uint64 _startTimestamp) external onlyRole(ADMIN_ROLE) {
        startTimestamp = _startTimestamp;
    }

    function setEndTimestamp(uint64 _endTimestamp) external onlyRole(ADMIN_ROLE) {
        endTimestamp = _endTimestamp;
    }

    function getAirdropInfo() external view returns (AirdropInfo memory) {
        return airdropInfo[airdropIndex[msg.sender]];
    }

    function getAirdropInfo(address account) external view returns (AirdropInfo memory) {
        return airdropInfo[airdropIndex[account]];
    }

    function insertAirdropData(address receiver, uint256 amount, uint256 instantAmount) external onlyRole(ADMIN_ROLE) {
        require(airdropIndex[receiver] == 0, "Airdrop: Airdrop data already exists");

        dataLength++;
        airdropIndex[receiver] = dataLength;
        airdropInfo[dataLength] = AirdropInfo(amount, instantAmount, 0, 0, false);

        totalAirdropAmount += amount;
    }

    function batchInsertAirdropData(
        address[] calldata receivers,
        uint256[] calldata amounts,
        uint256[] calldata instantAmounts
    ) external onlyRole(ADMIN_ROLE) {
        require(receivers.length == amounts.length, "Airdrop: Receivers and amounts length mismatch");
        require(receivers.length == instantAmounts.length, "Airdrop: Receivers and instant amounts length mismatch");

        for (uint256 i = 0; i < receivers.length; i++) {
            address receiver = receivers[i];
            uint256 amount = amounts[i];

            require(airdropIndex[receiver] == 0, "Airdrop: Airdrop data already exists");

            dataLength++;
            airdropIndex[receiver] = dataLength;
            airdropInfo[dataLength] = AirdropInfo(amount, instantAmounts[i], 0, 0, false);

            totalAirdropAmount += amount;
        }
    }

    function updateAirdropData(address receiver, uint256 amount) external onlyRole(ADMIN_ROLE) {
        uint256 index = airdropIndex[receiver];
        require(index > 0, "Airdrop: Airdrop data not found");

        AirdropInfo storage info = airdropInfo[index];
        totalAirdropAmount -= info.amount;
        totalAirdropAmount += amount;

        info.amount = amount;
    }

    function deleteAirdropData(address receiver) external onlyRole(ADMIN_ROLE) {
        uint256 index = airdropIndex[receiver];
        require(index > 0, "Airdrop: Airdrop data not found");

        totalAirdropAmount -= airdropInfo[index].amount;

        delete airdropIndex[receiver];
        delete airdropInfo[index];
    }

    function claim() external onlyAirdropOpen nonReentrant {
        address receiver = msg.sender;
        uint256 index = airdropIndex[receiver];
        require(index > 0, "Airdrop: Airdrop data not found");

        AirdropInfo storage info = airdropInfo[index];
        require(!info.claimed, "Airdrop: Airdrop already claimed");
        require(info.instantAmount > 0, "Airdrop: No airdrop available");
        require(info.lockupEndTimestamp == 0, "Airdrop: Lockup already set");

        token.transfer(receiver, info.instantAmount);
        info.claimed = true;
        info.claimedAmount = info.instantAmount;

        burnAmount += info.amount - info.instantAmount;

        emit AirdropClaimed(receiver, info.instantAmount);
    }

    function lockup() external onlyAirdropOpen nonReentrant {
        address receiver = msg.sender;
        uint256 index = airdropIndex[receiver];
        require(index > 0, "Airdrop: Airdrop data not found");

        AirdropInfo storage info = airdropInfo[index];
        require(!info.claimed, "Airdrop: Airdrop already claimed");
        require(info.amount > 0, "Airdrop: No airdrop available");
        require(info.lockupEndTimestamp == 0, "Airdrop: Lockup already set");

        info.lockupEndTimestamp = uint64(block.timestamp + lockupPeriod);

        lockupAmount += info.amount;

        emit Lockup(receiver, info.lockupEndTimestamp);
    }

    function claimLockup() external nonReentrant {
        address receiver = msg.sender;
        uint256 index = airdropIndex[receiver];
        require(index > 0, "Airdrop: Airdrop data not found");

        AirdropInfo storage info = airdropInfo[index];
        require(!info.claimed, "Airdrop: Airdrop already claimed");
        require(info.amount > 0, "Airdrop: No airdrop available");
        require(
            info.lockupEndTimestamp > 0 && block.timestamp >= info.lockupEndTimestamp,
            "Airdrop: Lockup period not over"
        );

        token.transfer(receiver, info.amount);
        info.claimed = true;
        info.claimedAmount = info.amount;

        emit AirdropClaimed(receiver, info.amount);
    }

    function closeAirdrop() external onlyRole(ADMIN_ROLE) {
        require(block.timestamp >= endTimestamp, "Airdrop: Airdrop not ended");

        burnAmount = totalAirdropAmount - lockupAmount;
        token.transfer(BURNNER_ADDRESS, burnAmount);

        emit AirdropClosed();
    }

    function payout(address receiver) external onlyRole(ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = payable(receiver).call{value: balance}("");
            require(success, "Airdrop: Transfer failed");
        }

        emit Payouted();
    }
}
