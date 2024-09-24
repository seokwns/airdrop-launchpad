// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


contract AccessControl {
    bytes32 public constant ADMIN_ROLE = 0x00;

    mapping(bytes32 => mapping(address => bool)) private roles;

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed admin);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed admin);

    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "AccessControl: sender must have the admin role");
        _;
    }

    function grantRole(bytes32 role, address account) public onlyRole(ADMIN_ROLE) {
        _grantRole(role, account);
    }

    function _grantRole(bytes32 role, address account) internal {
        roles[role][account] = true;
        emit RoleGranted(role, account, msg.sender);
    }

    function revokeRole(bytes32 role, address account) public onlyRole(ADMIN_ROLE) {
        _revokeRole(role, account);   
    }

    function _revokeRole(bytes32 role, address account) internal {
        roles[role][account] = false;
        emit RoleRevoked(role, account, msg.sender);
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return roles[role][account];
    }
}
