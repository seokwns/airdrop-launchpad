// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./lib/AccessControl.sol";

contract Airdrop is AccessControl, ReentrancyGuard{

    struct AirdropData {
        address account;
        uint256 amount;
        uint256 claimedAmount;
        uint64  claimIndex;
    }

    uint256 public constant PRECISION = 1e12;

    address public tokenAddress;
    uint256 public startTimestamp;
    uint256 public endTimestamp;
    uint256 public tgePercent;
    uint64  public vestingCount;
    uint256 public vestingTerm;

    uint256 public totalAirdropAmount;

    uint256 public dataLength;
    mapping(uint256 => AirdropData) public airdropData;
    mapping(address => uint256) public airdropIndex;

    event Claimed(address indexed receiver, uint256 amount, uint256 timestamp);
    event AirdropStartTimeUpdated(uint256 newStartTime);
    event AirdropEndTimeUpdated(uint256 newEndTime);

    /**
     * @notice 생성자
     * @param _tokenAddress 에어드랍 토큰 주소
     * @param _startTimestamp 에어드랍 시작 시간
     * @param _endTimestamp 에어드랍 종료 시간
     * @param _tgePercent TGE 비율 (0 ~ 100)
     * @param _vestingCount tge 이후 클레임 횟수
     */
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
        vestingTerm = (_endTimestamp - _startTimestamp) / (_vestingCount + 1);

        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice 에어드랍이 시작되었는지 확인합니다.
     */
    function isStarted() public view returns (bool) {
        return block.timestamp >= startTimestamp;
    }

    /**
     * @notice 에어드랍이 종료되었는지 확인합니다.
     */
    function isEnded() public view returns (bool) {
        return block.timestamp >= endTimestamp;
    }

    function isValidAirdropId(uint256 index) public view returns (bool) {
        return index > 0 && index <= dataLength;
    }

    function getFullyClaimedAccounts() public view returns (address[] memory accounts, AirdropData[] memory data) {
        uint256 count = 0;
        for (uint256 i = 1; i <= dataLength; i++) {
            if (airdropData[i].claimedAmount == airdropData[i].amount) {
                count++;
            }
        }

        accounts = new address[](count);
        data = new AirdropData[](count);

        uint256 index = 0;
        for (uint256 i = 1; i <= dataLength; i++) {
            if (airdropData[i].claimedAmount == airdropData[i].amount) {
                accounts[index] = airdropData[i].account;
                data[index] = airdropData[i];
                index++;
            }
        }
    }

    /**
     * @notice 호출한 사람의 에어드랍 클레임 가능한 금액을 계산합니다.
     * @param account 클레임 가능한 금액을 계산할 계정
     * @return claimAmount 클레임 가능한 금액
     */
    function getClaimableAmount(address account) public view returns (uint256 claimAmount) {
        uint256 index = airdropIndex[account];
        require(isValidAirdropId(index), "NO_AIRDROP_DATA");

        (, claimAmount) = getClaimAmount(index);
    }

    /**
     * @notice 에어드랍 클레임 가능한 금액을 계산합니다.
     * @param index 에어드랍 데이터 인덱스
     * @return claimIndex 클레임 인덱스
     * @return claimAmount 클레임 가능한 금액
     */
    function getClaimAmount(uint256 index) internal view returns (uint64 claimIndex, uint256 claimAmount) {
        AirdropData memory airdrop = airdropData[index];

        /*
        vestingCount는 tge 이후 보상 횟수이므로, 에어드랍 전체 기간을 vestingCount + 1로 나누어야 합니다.

        예를 들어,
        startTimestamp = 0, endTimestamp = 5, vestingCount = 4 라면 vestingTerm = (5 - 0) / (4 + 1) = 1

        |-----------------|-----------------|-----------------|-----------------|-----------------|
        0                 1                 2                 3                 4                 x
        tge               vesting1          vesting2          vesting3          vesting4          end

        위와 같이 5개의 구간으로 나누어져야 하며, 각 구간의 금액은 totalClaimAmount * (100 - tgePercent) / 100 / vestingCount 입니다.
        */

        uint256 term = block.timestamp - startTimestamp;
        claimIndex = uint64(term / vestingTerm);

        uint256 claimableIndex = claimIndex - airdrop.claimIndex;
        uint256 vestingAmountPerTerm = airdrop.amount * PRECISION * (100 - tgePercent) / 100 / vestingCount;
        claimAmount = vestingAmountPerTerm * claimableIndex / PRECISION;

        // TGE를 클레임하지 않은 경우, TGE 금액 추가
        if (airdrop.claimIndex == 0 && airdrop.claimedAmount == 0) {
            uint256 tgeAmountX12 = airdrop.amount * PRECISION * tgePercent / 100;
            claimAmount += tgeAmountX12 / PRECISION;
        }

        // 마지막 클레임 구간인 경우, 남은 금액 전부를 전송
        if (claimIndex == vestingCount) {
            uint256 remain = airdrop.amount - airdrop.claimedAmount;
            claimAmount = remain;
        }
    }

    /**
     * @notice 에어드랍을 클레임합니다.
     */
    function claim() external nonReentrant {
        require(block.timestamp >= startTimestamp, "AIRDOP_NOT_STARTED");
        require(block.timestamp < endTimestamp, "AIRDROP_ENDED");

        uint256 index = airdropIndex[msg.sender];
        require(isValidAirdropId(index), "NO_AIRDROP_DATA");

        AirdropData storage airdrop = airdropData[index];

        (uint64 claimIndex, uint256 claimAmount) = getClaimAmount(index);
        require(claimAmount > 0, "NO_CLAIMABLE_AMOUNT");

        uint256 balance = IERC20(tokenAddress).balanceOf(address(this));
        require(balance >= claimAmount, "INSUFFICIENT_BALANCE");

        IERC20(tokenAddress).transfer(msg.sender, claimAmount);
        airdrop.claimedAmount += claimAmount;
        airdrop.claimIndex = claimIndex;

        emit Claimed(msg.sender, claimAmount, block.timestamp);
    }

    /**
     * @notice 에어드랍 데이터를 조회합니다.
     * @return totalAmount 총 에어드랍 금액
     * @return claimedAmount 클레임된 금액
     * @return claimableAmount 클레임 가능한 금액
     */
    function getAirdropData() public view returns (uint256 totalAmount, uint256 claimedAmount, uint256 claimableAmount) {
        return getAirdropDataByAddress(msg.sender);
    }

    /**
     * @notice 에어드랍 데이터를 조회합니다.
     * @param _address 조회할 계정 주소
     * @return totalAmount 총 에어드랍 금액
     * @return claimedAmount 클레임된 금액
     * @return claimableAmount 클레임 가능한 금액
     */
    function getAirdropDataByAddress(address _address) public view returns (uint256 totalAmount, uint256 claimedAmount, uint256 claimableAmount) {
        uint256 index = airdropIndex[_address];
        require(isValidAirdropId(index), "NO_AIRDROP_DATA");

        AirdropData memory airdrop = airdropData[index];
        totalAmount = airdrop.amount;
        claimedAmount = airdrop.claimedAmount;

        (, claimableAmount) = getClaimAmount(index);
    }

    /**
     * @notice 에어드랍 데이터를 추가합니다.
     * @param _account 조회할 계정 주소
     * @param _amount 에어드랍 개수
     */
    function insertAirdropData(address _account, uint256 _amount) public onlyRole(ADMIN_ROLE) {
        uint256 index = airdropIndex[_account];
        require(index == 0, "DUPLICATED_DATA");

        dataLength++;
        airdropIndex[_account] = dataLength;

        airdropData[dataLength] = AirdropData({
            account: _account,
            amount: _amount,
            claimedAmount: 0,
            claimIndex: 0
        });

        totalAirdropAmount += _amount;
    }

    /**
     * @notice 에어드랍 데이터를 추가합니다.
     * @param _accounts[] 조회할 계정 주소
     * @param _amounts[] 에어드랍 개수
     */
    function batchInsertAirdropData(address[] memory _accounts, uint256[] memory _amounts) public onlyRole(ADMIN_ROLE) {
        require(_accounts.length == _amounts.length, "INVALID_INPUT_DATA");

        for (uint256 i = 0; i < _accounts.length; i++) {
            insertAirdropData(_accounts[i], _amounts[i]);
        }
    }

    function updateAirdropData(address _address, AirdropData memory _airdropData) public onlyRole(ADMIN_ROLE) {
        uint256 index = airdropIndex[_address];
        require(index > 0, "NO_AIRDROP_DATA");

        airdropData[index] = _airdropData;
    }

    function deleteAirdropData(address _address) public onlyRole(ADMIN_ROLE) {
        uint256 index = airdropIndex[_address];
        require(index > 0, "NO_AIRDROP_DATA");

        delete airdropData[index];
    }

    /**
     * @notice 에어드랍 토큰 잔액 전부를 owner에게 전송합니다. 컨트랙트 owner만 호출 가능.
     */
    function collect() public onlyRole(ADMIN_ROLE) {
        uint256 balance = IERC20(tokenAddress).balanceOf(address(this));
        IERC20(tokenAddress).transfer(msg.sender, balance);
    }

    /**
     * @notice 에어드랍 시작 시간을 업데이트합니다. 컨트랙트 owner만 호출 가능.
     * @param _startTimestamp 새로운 에어드랍 시작 시간
     */
    function updateStartTimestamp(uint256 _startTimestamp) public onlyRole(ADMIN_ROLE) {
        startTimestamp = _startTimestamp;
        vestingTerm = (endTimestamp - startTimestamp) / (vestingCount + 1);
        emit AirdropStartTimeUpdated(_startTimestamp);
    }
    
    /**
     * @notice 에어드랍 종료 시간을 업데이트합니다. 컨트랙트 owner만 호출 가능.
     * @param _endTimestamp 새로운 에어드랍 종료 시간
     */
    function updateEndTimestamp(uint256 _endTimestamp) public onlyRole(ADMIN_ROLE) {
        endTimestamp = _endTimestamp;
        vestingTerm = (endTimestamp - startTimestamp) / (vestingCount + 1);
        emit AirdropEndTimeUpdated(_endTimestamp);
    }
}
