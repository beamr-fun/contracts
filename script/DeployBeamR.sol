// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {BeamR} from "../src/contracts/BeamR.sol";

contract Deploy is Script {
    function run() public {
        // THIS IS FOR TESTNET ONLY

        uint256 deployerPrivateKey = vm.envUint("PRI_K");

        address[] memory admins = new address[](2);
        address[] memory rootAdmins = new address[](1);

        admins[0] = vm.envAddress("PUB_K");
        admins[1] = vm.envAddress("DEV_PUB_K");

        rootAdmins[0] = vm.envAddress("DEV_PUB_K");

        address beamRAddress;
        vm.startBroadcast(deployerPrivateKey);

        BeamR _beamR = new BeamR({_admins: admins, _rootAdmins: rootAdmins});

        beamRAddress = address(_beamR);

        vm.stopBroadcast();

        console2.log("BeamR deployed at:", beamRAddress);
    }
}
