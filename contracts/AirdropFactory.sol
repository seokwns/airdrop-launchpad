// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./lib/AccessControl.sol";
import "./Airdrop.sol";

contract AirdropFactory is AccessControl {

    struct AirdropInfo {
        address airdrop;            // 에어드랍 주소
        address token;              // 에어드랍 토큰 주소
        uint256 startTimestamp;     // 에어드랍 시작 시간
        uint256 endTimestamp;       // 에어드랍 종료 시간
        uint256 tgePercent;         // TGE 토큰 비율
        uint256 vestingCount;       // TGE 이후 클레임 횟수
    }

    uint256 public airdropLength;
    mapping(address => uint256) public airdrops;
    mapping(uint256 => AirdropInfo) public airdropInfo;

    address public treasury;

    event AirdropCreated(address indexed airdrop, address indexed token, uint256 startTimestamp, uint256 endTimestamp);

    constructor() {
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function setTreasury(address _treasury) public onlyRole(ADMIN_ROLE) {
        treasury = _treasury;
    }

    function createAirDrop(
        address token,
        uint256 startTimestamp, 
        uint256 endTimestamp,
        uint256 tgePercent,
        uint64 vestingCount
    ) public onlyRole(ADMIN_ROLE) returns (uint256) {
        airdropLength++;

        Airdrop newAirDrop = new Airdrop(token, startTimestamp, endTimestamp, tgePercent, vestingCount);
        newAirDrop.grantRole(ADMIN_ROLE, msg.sender);

        address airdropAddress = address(newAirDrop);
        airdrops[airdropAddress] = airdropLength;
        airdropInfo[airdropLength] = AirdropInfo({
            airdrop: airdropAddress,
            token: token,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp,
            tgePercent: tgePercent,
            vestingCount: vestingCount
        });

        emit AirdropCreated(airdropAddress, token, startTimestamp, endTimestamp);

        return airdropLength;
    }

    function getAllAirdrops() external view returns (AirdropInfo[] memory) {
        AirdropInfo[] memory result = new AirdropInfo[](airdropLength);
        for (uint256 i = 1; i <= airdropLength; i++) {
            result[i - 1] = airdropInfo[i];
        }
        return result;
    }

    function getAirdrop(address airdrop) external view returns (AirdropInfo memory) {
        return airdropInfo[airdrops[airdrop]];
    }
}
