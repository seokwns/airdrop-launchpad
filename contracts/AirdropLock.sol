// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./lib/AccessControl.sol";

contract AirdropLock is AccessControl, ReentrancyGuard {
    struct AirdropInfo {
        uint256 amount;
        uint256 claimedAmount;
        uint64 lockupEndTimestamp;
        bool claimed;
    }

    uint16 public constant PERCENT_PRECISION = 1e4;

    IERC20 public token;

    uint64 public startTimestamp;
    uint64 public endTimestamp;
    uint64 public lockupPeriod;
    uint16 public immediateClaimPercentage;

    uint256 public dataLength;
    mapping(uint256 => AirdropInfo) public airdropInfo;
    mapping(address => uint256) public airdropIndex;

    uint256 public totalAirdropAmount;

    event AirdropClaimed(address indexed user, uint256 amount);
    event Lockup(address indexed user, uint256 lockupEndTimestamp);
    event AirdropClosed();

    constructor(
        address _token,
        uint64 _startTimestamp,
        uint64 _endTimestamp,
        uint64 _lockupPeriod,
        uint16 _immediateClaimPercentage
    ) {
        require(_token != address(0), "Airdrop: Invalid token address");
        require(_startTimestamp < _endTimestamp, "Airdrop: Invalid start and end timestamp");
        require(_endTimestamp < _startTimestamp + _lockupPeriod, "Airdrop: Invalid lockup period");
        require(_immediateClaimPercentage <= PERCENT_PRECISION, "Airdrop: Invalid immediate claim percentage");

        token = IERC20(_token);
        startTimestamp = _startTimestamp;
        endTimestamp = _endTimestamp;
        immediateClaimPercentage = _immediateClaimPercentage;
        lockupPeriod = _lockupPeriod;

        _grantRole(ADMIN_ROLE, msg.sender);
    }

    modifier onlyAirdropOpen() {
        require(block.timestamp >= startTimestamp, "Airdrop: Airdrop not started");
        require(block.timestamp < endTimestamp, "Airdrop: Airdrop ended");
        _;
    }

    function setImmediateClaimPercentage(uint16 _immediateClaimPercentage) external onlyRole(ADMIN_ROLE) {
        immediateClaimPercentage = _immediateClaimPercentage;
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

    function insertAirdropData(address receiver, uint256 amount) external onlyRole(ADMIN_ROLE) {
        require(airdropIndex[receiver] == 0, "Airdrop: Airdrop data already exists");

        dataLength++;
        airdropIndex[receiver] = dataLength;
        airdropInfo[dataLength] = AirdropInfo(amount, 0, 0, false);

        totalAirdropAmount += amount;
    }

    function batchInsertAirdropData(
        address[] calldata receivers,
        uint256[] calldata amounts
    ) external onlyRole(ADMIN_ROLE) {
        require(receivers.length == amounts.length, "Airdrop: Receivers and amounts length mismatch");

        for (uint256 i = 0; i < receivers.length; i++) {
            address receiver = receivers[i];
            uint256 amount = amounts[i];

            require(airdropIndex[receiver] == 0, "Airdrop: Airdrop data already exists");

            dataLength++;
            airdropIndex[receiver] = dataLength;
            airdropInfo[dataLength] = AirdropInfo(amount, 0, 0, false);

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

    function claimAirdrop() external onlyAirdropOpen nonReentrant {
        address receiver = msg.sender;
        uint256 index = airdropIndex[receiver];
        require(index > 0, "Airdrop: Airdrop data not found");

        AirdropInfo storage info = airdropInfo[index];
        require(!info.claimed, "Airdrop: Airdrop already claimed");
        require(info.amount > 0, "Airdrop: No airdrop available");

        uint256 claimAmount = (info.amount * immediateClaimPercentage) / PERCENT_PRECISION;
        uint256 burnAmount = info.amount - claimAmount;
        token.transfer(receiver, claimAmount);
        token.transfer(address(0), burnAmount);

        info.claimed = true;
        info.claimedAmount = claimAmount;

        emit AirdropClaimed(receiver, claimAmount);
    }

    function lockup() external onlyAirdropOpen nonReentrant {
        address receiver = msg.sender;
        uint256 index = airdropIndex[receiver];
        require(index > 0, "Airdrop: Airdrop data not found");

        AirdropInfo storage info = airdropInfo[index];
        require(!info.claimed, "Airdrop: Airdrop already claimed");
        require(info.amount > 0, "Airdrop: No airdrop available");

        info.lockupEndTimestamp = uint64(block.timestamp + lockupPeriod);

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
        token.transfer(msg.sender, token.balanceOf(address(this)));
        emit AirdropClosed();
    }
}
