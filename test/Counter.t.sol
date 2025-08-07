// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {BeamR} from "../src/contracts/BeamR.sol";

import {IGeneralDistributionAgreementV1} from
    "@superfluid/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

contract BeamRTest is Test {
    BeamR public counter;

    address constant GDA_V1 = 0xfE6c87BE05feDB2059d2EC41bA0A09826C9FD7aa;
    address constant STREME_ADDRESS = 0x3B3Cd21242BA44e9865B066e5EF5d1cC1030CC58;

    // chose this holder because at block time,
    // it holds a round amount of 200,000,000 STREME
    address constant STREME_WHALE = 0xa47CbAfD56B61188dce9cdD9a9EC7F248F944CC1;

    IGeneralDistributionAgreementV1 public gda;

    BeamR public _beamR;

    function setUp() public {
        vm.createSelectFork({blockNumber: 33903334, urlOrAlias: "base"});

        address[] memory poolAdmins = new address[](1);
        address[] memory rootAdmins = new address[](1);

        poolAdmins[0] = address(1); // Replace with actual pool admin address
        rootAdmins[0] = address(2); // Replace with actual root admin address

        _beamR = new BeamR(poolAdmins, rootAdmins, GDA_V1);

        gda = _beamR.gda();

        assertTrue(_beamR.hasRole(_beamR.POOL_ADMIN_ROLE(), address(1)));
        assertTrue(_beamR.hasRole(_beamR.ROOT_ADMIN_ROLE(), address(2)));

        bytes32 agreementType = gda.agreementType();

        assertEq(agreementType, keccak256("org.superfluid-finance.agreements.GeneralDistributionAgreement.v1"));
    }

    function test_createPool() public {}

    function _createPool() internal {}

    function _setupHolders() internal {}
}
