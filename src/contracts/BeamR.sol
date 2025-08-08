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

// import {GDAv1Forwarder} from "@superfluid/ethereum-contracts/contracts/utils/GDAv1Forwarder.sol";

contract BeamR is IBeamR, AccessControl {
    using SuperTokenV1Library for ISuperToken;

    bytes32 public constant ROOT_ADMIN_ROLE = keccak256("ROOT_ADMIN_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    mapping(address => bytes32) public poolAdminRoles;

    constructor(address[] memory _poolAdmins, address[] memory _rootAdmins) {
        for (uint256 i; i < _poolAdmins.length;) {
            _setupRole(ADMIN_ROLE, _poolAdmins[i]);
            unchecked {
                i++;
            }
        }

        for (uint256 i; i < _rootAdmins.length;) {
            _setupRole(ROOT_ADMIN_ROLE, _rootAdmins[i]);
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
        address _creator
    ) external returns (ISuperfluidPool beamPool) {
        if (!_isValidRole(ADMIN_ROLE, _admin)) {
            revert Unauthorized();
        }

        beamPool = SuperTokenV1Library.createPoolWithCustomERC20Metadata(
            _poolSuperToken, address(this), _poolConfig, _erc20Metadata
        );

        emit PoolCreated(address(beamPool), address(_poolSuperToken), _poolConfig, _creator);

        _updateMembersUnits(beamPool, _members);
    }

    function _updateMembersUnits(ISuperfluidPool _gdaPool, Member[] memory _members) internal {
        for (uint256 i; i < _members.length;) {
            _gdaPool.updateMemberUnits(_members[i].account, _members[i].units);

            unchecked {
                i++;
            }
        }
    }

    function _isValidRole(bytes32 _role, address _account) internal view returns (bool) {
        if (_role != ROOT_ADMIN_ROLE && _role != ADMIN_ROLE) {
            revert Unauthorized();
        }

        return hasRole(_role, _account);
    }
}
