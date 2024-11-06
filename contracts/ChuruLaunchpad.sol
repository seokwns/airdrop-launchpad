// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./lib/AccessControl.sol";

contract ChuruLaunchpad is AccessControl, ReentrancyGuard {
    address public churu;
    uint256 public amount;
    uint256 public claimRatio;

    uint64 public startBlock;
    uint64 public endBlock;

    event Enrolled(uint256 amount, uint256 claimRatio);
    event PeriodUpdated(uint64 startBlock, uint64 endBlock);
    event ClaimRatioUpdated(uint256 claimRatio);
    event LaunchpadAmountUpdated(uint256 amount);
    event Claimed(address indexed user, uint256 amount);
    event Closed(uint256 amount);

    constructor(address _churu) {
        churu = _churu;
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function enroll(
        uint256 _amount,
        uint256 _claimRatio,
        uint64 _startBlock,
        uint64 _endBlock
    ) external onlyRole(ADMIN_ROLE) {
        require(_startBlock > block.number, "Launchpad: invalid start block");
        require(_endBlock > _startBlock, "Launchpad: invalid end block");

        amount = _amount;
        claimRatio = _claimRatio;
        startBlock = _startBlock;
        endBlock = _endBlock;

        IERC20(churu).transferFrom(msg.sender, address(this), _amount);

        emit Enrolled(_amount, _claimRatio);
    }

    function updatePeriod(uint64 _startBlock, uint64 _endBlock) external onlyRole(ADMIN_ROLE) {
        require(_endBlock > _startBlock, "Launchpad: invalid period");

        startBlock = _startBlock;
        endBlock = _endBlock;

        emit PeriodUpdated(_startBlock, _endBlock);
    }

    function updateChuruPerAce(uint256 _claimRatio) external onlyRole(ADMIN_ROLE) {
        claimRatio = _claimRatio;

        emit ClaimRatioUpdated(_claimRatio);
    }

    function updateLaunchpadAmount(uint256 _amount) external onlyRole(ADMIN_ROLE) {
        if (amount > _amount) {
            uint256 diff = amount - _amount;
            IERC20(churu).transfer(msg.sender, diff);
        } else if (amount < _amount) {
            uint256 diff = _amount - amount;
            IERC20(churu).transferFrom(msg.sender, address(this), diff);
        }

        emit LaunchpadAmountUpdated(_amount);
    }

    function claim() external payable {
        require(block.number >= startBlock, "Launchpad: not started");
        require(block.number <= endBlock, "Launchpad: ended");

        uint256 value = msg.value;
        require(value > 0, "Launchpad: invalid value");

        uint256 churuAmount = (value * claimRatio) / 1e18;
        IERC20(churu).transfer(msg.sender, churuAmount);

        emit Claimed(msg.sender, churuAmount);
    }

    function close() external onlyRole(ADMIN_ROLE) {
        uint256 balance = IERC20(churu).balanceOf(address(this));
        IERC20(churu).transfer(msg.sender, balance);

        endBlock = uint64(block.number);

        emit Closed(balance);
    }
}
