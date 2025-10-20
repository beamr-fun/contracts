// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {
    PoolConfig,
    PoolERC20Metadata
} from "@superfluid/ethereum-contracts/contracts/interfaces/agreements/gdav1/IGeneralDistributionAgreementV1.sol";
import {
    ISuperfluidPool,
    ISuperToken
} from "@superfluid/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {SuperTokenV1Library} from "@superfluid/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

import {IBeamR} from "../interfaces/IBeamR.sol";

/// @title BeamR – Superfluid pool factory & per-pool admin manager
/// @author Jord
/// @notice Creates Superfluid pools manages pool-specific admin roles.
contract BeamR is IBeamR, AccessControl {
    using SuperTokenV1Library for ISuperToken;

    event MemberUnitsChanged();

    // ------------------------
    // ------ Constants -------
    // ------------------------

    /// @notice Initializes global admin roles.

    /// @dev ROOT_ADMIN_ROLE can grant and revoke ADMIN_ROLE., can resume pool creators
    bytes32 public constant ROOT_ADMIN_ROLE = keccak256("ROOT_ADMIN_ROLE");
    /// @dev ADMIN_ROLE can update member units globally
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // ------------------------
    // -------- Init  ---------
    // ------------------------

    constructor(address[] memory _admins, address[] memory _rootAdmins) {
        // Run event first to ensure indexers can easily match it
        emit Initialized(ADMIN_ROLE, ROOT_ADMIN_ROLE);

        for (uint256 i; i < _admins.length;) {
            _grantRole(ADMIN_ROLE, _admins[i]);
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

    // ------------------------
    // -------  API  ----------
    // ------------------------

    /// @notice Create a new Superfluid pool and optionally seed member units.
    /// @dev Grants the pool-specific admin role (derived via {poolAdminKey}) to `_creator`.
    ///      Emits {PoolCreated} before unit updates to ease indexing.
    /// @param _poolSuperToken The SuperToken used by the pool.
    /// @param _poolConfig GDAv1 pool config.
    /// @param _erc20Metadata Custom ERC20 name/symbol/decimals for the pool wrapper.
    /// @param _members Parallel array of initial member accounts/units to set (entries with 0 are skipped).
    /// @param _creator Address to receive the pool’s admin role (can manage that pool’s units).
    /// @param _metadata Off-chain pointer/schema info emitted in the event.
    /// @return beamPool The newly created GDA pool instance.
    function createPool(
        ISuperToken _poolSuperToken,
        PoolConfig memory _poolConfig,
        PoolERC20Metadata memory _erc20Metadata,
        Member[] memory _members,
        address _creator,
        Metadata memory _metadata
    ) external returns (ISuperfluidPool beamPool) {
        beamPool = SuperTokenV1Library.createPoolWithCustomERC20Metadata(
            _poolSuperToken, address(this), _poolConfig, _erc20Metadata
        );

        // Derive the pool-specific admin role
        bytes32 poolAdminRole = poolAdminKey(address(beamPool));

        // Event is emitted before updating member units to ensure indexer can easily match
        emit PoolCreated(
            address(beamPool), address(_poolSuperToken), _poolConfig, _members, _creator, poolAdminRole, _metadata
        );

        // Grant the creator the pool admin role
        _grantRole(poolAdminRole, _creator);
        // Allows the creator to manage pool admin role grant and revoke
        _setRoleAdmin(poolAdminRole, poolAdminRole);

        for (uint256 i; i < _members.length;) {
            if (_members[i].units > 0) {
                beamPool.updateMemberUnits(_members[i].account, _members[i].units);
            }
            unchecked {
                i++;
            }
        }

        return beamPool;
    }

    /// @notice Update a member’s units for multiple pools in one call.
    /// @dev The i-th entry of `_members` is applied to the i-th entry of `poolAddresses`.
    ///      Caller must have {ADMIN_ROLE} or be the per-pool admin of each target pool.
    /// @param _members Members (account, units) to apply index-wise.
    /// @param _poolAddresses Pools to update, index-aligned with `_members`.
    /// @param _metadata Off-chain pointer/schema info emitted in the event.
    function updateMemberUnits(Member[] memory _members, address[] memory _poolAddresses, Metadata memory _metadata)
        external
    {
        for (uint256 i; i < _poolAddresses.length;) {
            address _poolAddress = _poolAddresses[i];

            if (!hasRole(ADMIN_ROLE, msg.sender) && !hasRole(poolAdminKey(_poolAddress), msg.sender)) {
                revert Unauthorized();
            }

            // prevent underflow

            ISuperfluidPool pool = ISuperfluidPool(_poolAddresses[i]);

            pool.updateMemberUnits(_members[i].account, _members[i].units);

            unchecked {
                i++;
            }
        }

        emit MemberUnitsUpdated(_members, _poolAddresses, Action.Update, _metadata);
    }

    /// @notice Increase a member’s units for multiple pools in one call.
    /// @dev The i-th entry of `_memberAdjustments` is applied to the i-th entry of `_poolAddresses`.
    ///      Caller must have {ADMIN_ROLE} or be the per-pool admin of each target pool.
    /// @param _memberAdjustments Members (account, units) to apply index-wise.
    /// @param _poolAddresses Pools to update, index-aligned with `_memberAdjustments`.
    /// @param _metadata Off-chain pointer/schema info emitted in the event.
    function increaseMemberUnits(
        Member[] memory _memberAdjustments,
        address[] memory _poolAddresses,
        Metadata memory _metadata
    ) external {
        for (uint256 i; i < _poolAddresses.length;) {
            address _poolAddress = _poolAddresses[i];

            if (!hasRole(ADMIN_ROLE, msg.sender) && !hasRole(poolAdminKey(_poolAddress), msg.sender)) {
                revert Unauthorized();
            }

            ISuperfluidPool pool = ISuperfluidPool(_poolAddresses[i]);

            pool.increaseMemberUnits(_memberAdjustments[i].account, _memberAdjustments[i].units);

            unchecked {
                i++;
            }
        }

        emit MemberUnitsUpdated(_memberAdjustments, _poolAddresses, Action.Increase, _metadata);
    }

    /// @notice Decrease a member’s units for multiple pools in one call.
    /// @dev The i-th entry of `_memberAdjustments` is applied to the i-th entry of `_poolAddresses`.
    ///      Caller must have {ADMIN_ROLE} or be the per-pool admin of each target pool.
    /// @param _memberAdjustments Members (account, units) to apply index-wise.
    /// @param _poolAddresses Pools to update, index-aligned with `_memberAdjustments`.
    /// @param _metadata Off-chain pointer/schema info emitted in the event.
    function decreaseMemberUnits(
        Member[] memory _memberAdjustments,
        address[] memory _poolAddresses,
        Metadata memory _metadata
    ) external {
        for (uint256 i; i < _poolAddresses.length;) {
            address _poolAddress = _poolAddresses[i];

            if (!hasRole(ADMIN_ROLE, msg.sender) && !hasRole(poolAdminKey(_poolAddress), msg.sender)) {
                revert Unauthorized();
            }

            ISuperfluidPool pool = ISuperfluidPool(_poolAddresses[i]);

            if (pool.getUnits(_memberAdjustments[i].account) < _memberAdjustments[i].units) {
                revert Underflow();
            }

            pool.decreaseMemberUnits(_memberAdjustments[i].account, _memberAdjustments[i].units);

            unchecked {
                i++;
            }
        }

        emit MemberUnitsUpdated(_memberAdjustments, _poolAddresses, Action.Decrease, _metadata);
    }

    /// @notice Reassign the pool creator/admin role to a new address.
    /// @dev Only callable by {ROOT_ADMIN_ROLE}. Revokes the role from `_currentCreator` and grants to `_newCreator`.
    /// @param _poolAddress Address of the target pool.
    /// @param _newCreator Address to receive the pool admin role.
    /// @param _currentCreator Address currently holding the pool admin role.
    function rescuePoolCreator(address _poolAddress, address _newCreator, address _currentCreator)
        external
        onlyRole(ROOT_ADMIN_ROLE)
    {
        _revokeRole(poolAdminKey(_poolAddress), _currentCreator);

        // Grant the new creator the pool admin role
        _grantRole(poolAdminKey(_poolAddress), _newCreator);
    }

    /// @notice Publish new metadata for a pool via event.
    /// @dev Only callable by the pool’s admin role (see {poolAdminKey}).
    /// @param _poolAddress Pool whose metadata is being updated.
    /// @param _metadata Off-chain pointer/schema info emitted in {PoolMetadataUpdated}.
    function updateMetadata(address _poolAddress, Metadata memory _metadata)
        external
        onlyRole(poolAdminKey(_poolAddress))
    {
        emit PoolMetadataUpdated(_poolAddress, _metadata);
    }

    /// @notice Deterministically derive the role id for a pool’s admin role.
    /// @dev roleId = keccak256(abi.encodePacked(_poolAddress)).
    /// @param _poolAddress Pool address used as the key material.
    /// @return roleId The bytes32 role identifier for that pool.
    function poolAdminKey(address _poolAddress) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("POOL_MANAGER", _poolAddress));
    }
}
