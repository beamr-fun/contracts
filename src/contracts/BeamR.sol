// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {
    PoolConfig,
    PoolERC20Metadata
} from "@superfluid/ethereum-contracts/contracts/interfaces/agreements/gdav1/IGeneralDistributionAgreementV1.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {SuperTokenV1Library} from "@superfluid/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {IBeamR} from "../interfaces/IBeamR.sol";
import {
    ISuperfluidPool,
    ISuperToken
} from "@superfluid/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

contract BeamR is IBeamR, AccessControl {
    using SuperTokenV1Library for ISuperToken;

    bytes32 public constant ROOT_ADMIN_ROLE = keccak256("ROOT_ADMIN_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    constructor(address[] memory _poolAdmins, address[] memory _rootAdmins) {
        for (uint256 i; i < _poolAdmins.length;) {
            _grantRole(ADMIN_ROLE, _poolAdmins[i]);
            unchecked {
                i++;
            }
        }

        // Allows ROOT_ADMIN_ROLE to revoke and grant ADMIN_ROLE
        _setRoleAdmin(ADMIN_ROLE, ROOT_ADMIN_ROLE);

        for (uint256 i; i < _rootAdmins.length;) {
            _grantRole(ROOT_ADMIN_ROLE, _rootAdmins[i]);
            unchecked {
                i++;
            }
        }
    }

    function createPool(
        ISuperToken _poolSuperToken,
        PoolConfig memory _poolConfig,
        PoolERC20Metadata memory _erc20Metadata,
        Member[] memory _members,
        address _admin,
        address _creator,
        Metadata memory _metadata
    ) external returns (ISuperfluidPool beamPool) {
        if (!hasRole(ADMIN_ROLE, _admin)) {
            revert Unauthorized();
        }

        beamPool = SuperTokenV1Library.createPoolWithCustomERC20Metadata(
            _poolSuperToken, address(this), _poolConfig, _erc20Metadata
        );

        _grantRole(poolAdminKey(address(beamPool)), _creator);
        // Allows the creator to manage pool admin role grant and revoke
        _setRoleAdmin(poolAdminKey(address(beamPool)), poolAdminKey(address(beamPool)));

        emit PoolCreated(address(beamPool), address(_poolSuperToken), _poolConfig, _creator, _metadata);

        _updateMembersUnits(beamPool, _members);
    }

    function updateMemberUnits(Member[] memory _members, address _poolAddress) external {
        if (!hasRole(ADMIN_ROLE, msg.sender) && !isPoolAdmin(msg.sender, _poolAddress)) {
            revert Unauthorized();
        }

        ISuperfluidPool gdaPool = ISuperfluidPool(_poolAddress);

        _updateMembersUnits(gdaPool, _members);
    }

    function _updateMembersUnits(ISuperfluidPool _gdaPool, Member[] memory _members) internal {
        for (uint256 i; i < _members.length;) {
            _gdaPool.updateMemberUnits(_members[i].account, _members[i].units);

            unchecked {
                i++;
            }
        }
    }

    function isPoolAdmin(address _account, address _poolAddress) public view returns (bool) {
        return hasRole(poolAdminKey(_poolAddress), _account);
    }

    function poolAdminKey(address _poolAddress) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_poolAddress));
    }
}
