// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./lib/AccessControl.sol";

contract ChuruLaunchpad is AccessControl, ReentrancyGuard {
    uint32 public constant PERCENT_PRECISION = 1e8;
    uint256 public constant ACCOUNT_CAP = 200 ether;

    address public churu;
    uint256 public amount;
    uint256 public claimRatio;

    uint64 public startBlock;
    uint64 public endBlock;

    mapping(address account => uint256 amount) public submitAmount;
    mapping(address account => uint256 amount) public claimAmount;

    event Enrolled(uint256 amount, uint256 claimRatio, uint64 startBlock, uint64 endBlock);
    event PeriodUpdated(uint64 startBlock, uint64 endBlock);
    event ClaimRatioUpdated(uint256 claimRatio);
    event LaunchpadAmountUpdated(uint256 amount);
    event Claimed(address indexed user, uint256 amount);
    event ExceedCapRefunded(address indexed user, uint256 amount);
    event InsufficientChuruRefunded(address indexed user, uint256 amount);
    event Closed();
    event Payouted();

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

        emit Enrolled(_amount, _claimRatio, _startBlock, _endBlock);
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

        amount = _amount;

        emit LaunchpadAmountUpdated(_amount);
    }

    function claim() external payable {
        require(block.number >= startBlock, "Launchpad: not started");
        require(block.number <= endBlock, "Launchpad: ended");
        require(IERC20(churu).balanceOf(address(this)) > 0, "Launchpad: no churu");

        uint256 _value = msg.value;
        require(_value > 0 && _value <= ACCOUNT_CAP, "Launchpad: invalid value");

        require(submitAmount[msg.sender] < ACCOUNT_CAP, "Launchpad: exceed cap");

        uint256 value = ACCOUNT_CAP - submitAmount[msg.sender];
        if (_value <= value) {
            value = _value;
        } else {
            uint256 refundAmount = _value - value;
            (bool success, ) = msg.sender.call{value: refundAmount}("");
            require(success, "Launchpad: transfer failed");

            emit ExceedCapRefunded(msg.sender, refundAmount);
        }

        uint256 churuAmount = (value * claimRatio) / 1e18;
        uint256 balance = IERC20(churu).balanceOf(address(this));
        if (balance < churuAmount) {
            uint256 diff = churuAmount - balance;
            uint256 refundAmount = (diff * 1e18) / claimRatio;

            (bool success, ) = msg.sender.call{value: refundAmount}("");
            require(success, "Launchpad: transfer failed");
            churuAmount = balance;

            emit InsufficientChuruRefunded(msg.sender, refundAmount);
        }

        IERC20(churu).transfer(msg.sender, churuAmount);
        claimAmount[msg.sender] += churuAmount;
        submitAmount[msg.sender] += value;

        emit Claimed(msg.sender, churuAmount);
    }

    function getProgress() external view returns (uint256) {
        if (amount == 0) {
            return 0;
        }

        uint256 remain = IERC20(churu).balanceOf(address(this));
        return (remain * PERCENT_PRECISION) / amount;
    }

    function close() external onlyRole(ADMIN_ROLE) {
        endBlock = uint64(block.number);
        emit Closed();
    }

    function payout() external onlyRole(ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = payable(msg.sender).call{value: balance}("");
            require(success, "Launchpad: transfer failed");
        }

        uint256 churuBalance = IERC20(churu).balanceOf(address(this));
        if (churuBalance > 0) {
            IERC20(churu).transfer(msg.sender, churuBalance);
        }

        emit Payouted();
    }
}
