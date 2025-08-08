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
        address _creator,
        Metadata memory _metadata
    ) external returns (ISuperfluidPool beamPool) {
        beamPool = SuperTokenV1Library.createPoolWithCustomERC20Metadata(
            _poolSuperToken, address(this), _poolConfig, _erc20Metadata
        );

        _grantRole(poolAdminKey(address(beamPool)), _creator);
        // Allows the creator to manage pool admin role grant and revoke
        _setRoleAdmin(poolAdminKey(address(beamPool)), poolAdminKey(address(beamPool)));

        // Event is emitted before updating member units to ensure indexer can easily match
        emit PoolCreated(address(beamPool), address(_poolSuperToken), _poolConfig, _creator, _metadata);

        for (uint256 i; i < _members.length;) {
            if (_members[i].units > 0) {
                beamPool.updateMemberUnits(_members[i].account, _members[i].units);
            }
            unchecked {
                i++;
            }
        }
    }

    function updateMemberUnits(Member[] memory _members, address[] memory poolAddresses) external {
        for (uint256 i; i < poolAddresses.length;) {
            address _poolAddress = poolAddresses[i];

            if (!hasRole(ADMIN_ROLE, msg.sender) && !isPoolAdmin(msg.sender, _poolAddress)) {
                revert Unauthorized();
            }

            ISuperfluidPool pool = ISuperfluidPool(poolAddresses[i]);

            pool.updateMemberUnits(_members[i].account, _members[i].units);

            unchecked {
                i++;
            }
        }
    }

    function rescuePoolCreator(address _poolAddress, address _newCreator, address _currentCreator)
        external
        onlyRole(ROOT_ADMIN_ROLE)
    {
        _revokeRole(poolAdminKey(_poolAddress), _currentCreator);

        // Grant the new creator the pool admin role
        _grantRole(poolAdminKey(_poolAddress), _newCreator);
    }

    function updateMetadata(address _poolAddress, Metadata memory _metadata)
        external
        onlyRole(poolAdminKey(_poolAddress))
    {
        emit PoolMetadataUpdated(_poolAddress, _metadata);
    }

    function isPoolAdmin(address _account, address _poolAddress) public view returns (bool) {
        return hasRole(poolAdminKey(_poolAddress), _account);
    }

    function poolAdminKey(address _poolAddress) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_poolAddress));
    }
}
