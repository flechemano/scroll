// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {L2CustomERC20Gateway} from "../../src/L2/gateways/L2CustomERC20Gateway.sol";
import {L2ERC1155Gateway} from "../../src/L2/gateways/L2ERC1155Gateway.sol";
import {L2ERC721Gateway} from "../../src/L2/gateways/L2ERC721Gateway.sol";
import {L2ETHGateway} from "../../src/L2/gateways/L2ETHGateway.sol";
import {L2GatewayRouter} from "../../src/L2/gateways/L2GatewayRouter.sol";
import {L2ScrollMessenger} from "../../src/L2/L2ScrollMessenger.sol";
import {L2StandardERC20Gateway} from "../../src/L2/gateways/L2StandardERC20Gateway.sol";
import {L2WETHGateway} from "../../src/L2/gateways/L2WETHGateway.sol";
import {L2DAIGateway} from "../../src/L2/gateways/L2DAIGateway.sol";
import {L1GasPriceOracle} from "../../src/L2/predeploys/L1GasPriceOracle.sol";
import {L2MessageQueue} from "../../src/L2/predeploys/L2MessageQueue.sol";
import {L2TxFeeVault} from "../../src/L2/predeploys/L2TxFeeVault.sol";
import {Whitelist} from "../../src/L2/predeploys/Whitelist.sol";
import {ScrollStandardERC20} from "../../src/libraries/token/ScrollStandardERC20.sol";
import {ScrollStandardERC20Factory} from "../../src/libraries/token/ScrollStandardERC20Factory.sol";

contract DeployL2BridgeContracts is Script {
    uint256 L2_DEPLOYER_PRIVATE_KEY = vm.envUint("L2_DEPLOYER_PRIVATE_KEY");

    address L1_TX_FEE_RECIPIENT_ADDR = vm.envAddress("L1_TX_FEE_RECIPIENT_ADDR");
    address L1_WETH_ADDR = vm.envAddress("L1_WETH_ADDR");
    address L2_WETH_ADDR = vm.envAddress("L2_WETH_ADDR");

    L1GasPriceOracle oracle;
    L2MessageQueue queue;
    ProxyAdmin proxyAdmin;

    // predeploy contracts
    address L1_GAS_PRICE_ORACLE_PREDEPLOY_ADDR = vm.envOr("L1_GAS_PRICE_ORACLE_PREDEPLOY_ADDR", address(0));
    address L2_MESSAGE_QUEUE_PREDEPLOY_ADDR = vm.envOr("L2_MESSAGE_QUEUE_PREDEPLOY_ADDR", address(0));
    address L2_TX_FEE_VAULT_PREDEPLOY_ADDR = vm.envOr("L2_TX_FEE_VAULT_PREDEPLOY_ADDR", address(0));
    address L2_WHITELIST_PREDEPLOY_ADDR = vm.envOr("L2_WHITELIST_PREDEPLOY_ADDR", address(0));

    function run() external {
        vm.startBroadcast(L2_DEPLOYER_PRIVATE_KEY);

        // predeploys
        deployL1GasPriceOracle();
        deployL2MessageQueue();
        deployTxFeeVault();
        deployL2Whitelist();

        // upgradable
        deployProxyAdmin();
        deployL2ScrollMessenger();
        deployL2ETHGateway();
        deployL2WETHGateway();
        deployL2StandardERC20Gateway();
        deployL2GatewayRouter();
        deployScrollStandardERC20Factory();
        deployL2CustomERC20Gateway();
        deployL2ERC721Gateway();
        deployL2ERC1155Gateway();
        deployL2DAIGateway();

        vm.stopBroadcast();
    }

    function deployL1GasPriceOracle() internal {
        if (L1_GAS_PRICE_ORACLE_PREDEPLOY_ADDR != address(0)) {
            oracle = L1GasPriceOracle(L1_GAS_PRICE_ORACLE_PREDEPLOY_ADDR);
            logAddress("L1_GAS_PRICE_ORACLE_ADDR", address(L1_GAS_PRICE_ORACLE_PREDEPLOY_ADDR));
            return;
        }

        address owner = vm.addr(L2_DEPLOYER_PRIVATE_KEY);
        oracle = new L1GasPriceOracle(owner);

        logAddress("L1_GAS_PRICE_ORACLE_ADDR", address(oracle));
    }

    function deployL2MessageQueue() internal {
        if (L2_MESSAGE_QUEUE_PREDEPLOY_ADDR != address(0)) {
            queue = L2MessageQueue(L2_MESSAGE_QUEUE_PREDEPLOY_ADDR);
            logAddress("L2_MESSAGE_QUEUE_ADDR", address(L2_MESSAGE_QUEUE_PREDEPLOY_ADDR));
            return;
        }

        address owner = vm.addr(L2_DEPLOYER_PRIVATE_KEY);
        queue = new L2MessageQueue(owner);

        logAddress("L2_MESSAGE_QUEUE_ADDR", address(queue));
    }

    function deployTxFeeVault() internal {
        if (L2_TX_FEE_VAULT_PREDEPLOY_ADDR != address(0)) {
            logAddress("L2_TX_FEE_VAULT_ADDR", address(L2_TX_FEE_VAULT_PREDEPLOY_ADDR));
            return;
        }

        address owner = vm.addr(L2_DEPLOYER_PRIVATE_KEY);
        L2TxFeeVault feeVault = new L2TxFeeVault(address(owner), L1_TX_FEE_RECIPIENT_ADDR);

        logAddress("L2_TX_FEE_VAULT_ADDR", address(feeVault));
    }

    function deployL2Whitelist() internal {
        if (L2_WHITELIST_PREDEPLOY_ADDR != address(0)) {
            logAddress("L2_WHITELIST_ADDR", address(L2_WHITELIST_PREDEPLOY_ADDR));
            return;
        }

        address owner = vm.addr(L2_DEPLOYER_PRIVATE_KEY);
        Whitelist whitelist = new Whitelist(owner);

        logAddress("L2_WHITELIST_ADDR", address(whitelist));
    }

    function deployProxyAdmin() internal {
        proxyAdmin = new ProxyAdmin();

        logAddress("L2_PROXY_ADMIN_ADDR", address(proxyAdmin));
    }

    function deployL2ScrollMessenger() internal {
        L2ScrollMessenger impl = new L2ScrollMessenger(address(queue));
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(proxyAdmin),
            new bytes(0)
        );

        logAddress("L2_SCROLL_MESSENGER_IMPLEMENTATION_ADDR", address(impl));
        logAddress("L2_SCROLL_MESSENGER_PROXY_ADDR", address(proxy));
    }

    function deployL2StandardERC20Gateway() internal {
        L2StandardERC20Gateway impl = new L2StandardERC20Gateway();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(proxyAdmin),
            new bytes(0)
        );

        logAddress("L2_STANDARD_ERC20_GATEWAY_IMPLEMENTATION_ADDR", address(impl));
        logAddress("L2_STANDARD_ERC20_GATEWAY_PROXY_ADDR", address(proxy));
    }

    function deployL2ETHGateway() internal {
        L2ETHGateway impl = new L2ETHGateway();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(proxyAdmin),
            new bytes(0)
        );

        logAddress("L2_ETH_GATEWAY_IMPLEMENTATION_ADDR", address(impl));
        logAddress("L2_ETH_GATEWAY_PROXY_ADDR", address(proxy));
    }

    function deployL2WETHGateway() internal {
        L2WETHGateway impl = new L2WETHGateway(L2_WETH_ADDR, L1_WETH_ADDR);
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(proxyAdmin),
            new bytes(0)
        );

        logAddress("L2_WETH_GATEWAY_IMPLEMENTATION_ADDR", address(impl));
        logAddress("L2_WETH_GATEWAY_PROXY_ADDR", address(proxy));
    }

    function deployL2GatewayRouter() internal {
        L2GatewayRouter impl = new L2GatewayRouter();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(proxyAdmin),
            new bytes(0)
        );

        logAddress("L2_GATEWAY_ROUTER_IMPLEMENTATION_ADDR", address(impl));
        logAddress("L2_GATEWAY_ROUTER_PROXY_ADDR", address(proxy));
    }

    function deployScrollStandardERC20Factory() internal {
        ScrollStandardERC20 tokenImpl = new ScrollStandardERC20();
        ScrollStandardERC20Factory scrollStandardERC20Factory = new ScrollStandardERC20Factory(address(tokenImpl));

        logAddress("L2_SCROLL_STANDARD_ERC20_ADDR", address(tokenImpl));
        logAddress("L2_SCROLL_STANDARD_ERC20_FACTORY_ADDR", address(scrollStandardERC20Factory));
    }

    function deployL2CustomERC20Gateway() internal {
        L2CustomERC20Gateway impl = new L2CustomERC20Gateway();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(proxyAdmin),
            new bytes(0)
        );

        logAddress("L2_CUSTOM_ERC20_GATEWAY_IMPLEMENTATION_ADDR", address(impl));
        logAddress("L2_CUSTOM_ERC20_GATEWAY_PROXY_ADDR", address(proxy));
    }

    function deployL2DAIGateway() internal {
        L2DAIGateway impl = new L2DAIGateway();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(proxyAdmin),
            new bytes(0)
        );

        logAddress("L2_DAI_GATEWAY_IMPLEMENTATION_ADDR", address(impl));
        logAddress("L2_DAI_GATEWAY_PROXY_ADDR", address(proxy));
    }

    function deployL2ERC721Gateway() internal {
        L2ERC721Gateway impl = new L2ERC721Gateway();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(proxyAdmin),
            new bytes(0)
        );

        logAddress("L2_ERC721_GATEWAY_IMPLEMENTATION_ADDR", address(impl));
        logAddress("L2_ERC721_GATEWAY_PROXY_ADDR", address(proxy));
    }

    function deployL2ERC1155Gateway() internal {
        L2ERC1155Gateway impl = new L2ERC1155Gateway();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(proxyAdmin),
            new bytes(0)
        );

        logAddress("L2_ERC1155_GATEWAY_IMPLEMENTATION_ADDR", address(impl));
        logAddress("L2_ERC1155_GATEWAY_PROXY_ADDR", address(proxy));
    }

    function logAddress(string memory name, address addr) internal view {
        console.log(string(abi.encodePacked(name, "=", vm.toString(address(addr)))));
    }
}
