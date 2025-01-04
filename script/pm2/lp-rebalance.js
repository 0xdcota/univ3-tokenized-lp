require("dotenv").config();
const { ethers, JsonRpcProvider } = require("ethers");
const { logNewLine, logData } = require("../utils");
const { getPriceDelta, executeAutoRebalance, logPositionInfo } = require("./lp-utils");

const erc20Artifact = require("../../out/ERC20.sol/ERC20.json");
const tokenizedLpArtifact = require("../../out/UniswapV3TokenizedLp.sol/UniswapV3TokenizedLp.json");

/// Main action function
const actionFn = async () => {
    console.log(
        "------------------------------------------------------------------"
    );
    logNewLine("INF", "starting lp-rebalance routine");

    const chain = {
        chainId: process.env.LOCAL_CHAIN_ID.toString(),
        rpc: process.env.LOCAL_RPC,
        lpTokenAddr: process.env.LOCAL_LP_TOKEN_ADDR,
        token0Addr: process.env.LOCAL_TOKEN0_ADDR,
        token0Name: process.env.LOCAL_TOKEN0_NAME,
        token0Decimals: Number(process.env.LOCAL_TOKEN0_DECIMALS),
        token1Addr: process.env.LOCAL_TOKEN1_ADDR,
        token1Name: process.env.LOCAL_TOKEN1_NAME,
        token1Decimals: Number(process.env.LOCAL_TOKEN1_DECIMALS),
    };

    logData(`Chain: ${chain.chainId}`);
    logData(`rpc: ${chain.rpc}`);
    logData(`lpTokenAddr: ${chain.lpTokenAddr}`);
    logData(
        `token0Addr: ${chain.token0Addr}, ${chain.token0Name}, decimals: ${chain.token0Decimals}`
    );
    logData(
        `token1Addr: ${chain.token1Addr}, ${chain.token1Name}, decimals: ${chain.token1Decimals}`
    );

    /// Build contract instances
    if (!chain.chainId)
        throw `Please define LOCAL_CHAIN_ID in pm2-ecosystem.config.js`;
    if (!chain.rpc) throw `Please define LOCAL_RPC in pm2-ecosystem.config.js`;
    if (!process.env.PRIVATE_KEY) throw "Please set PRIVATE_KEY in .env";

    const provider = new JsonRpcProvider(chain.rpc, undefined, {
        staticNetwork: true,
    });
    const wallet = new ethers.Wallet(process.env.PRIVATE_KEY);
    const signer = wallet.connect(provider);
    const tokenizedLp = new ethers.Contract(
        chain.lpTokenAddr,
        tokenizedLpArtifact.abi,
        signer
    );

    const token0Contract = new ethers.Contract(
        chain.token0Addr,
        erc20Artifact.abi,
        signer
    );
    const token1Contract = new ethers.Contract(
        chain.token1Addr,
        erc20Artifact.abi,
        signer
    );

    let success = true;
    const { priceDelta, hysteresis, spotPrice, oraclePrice } = await getPriceDelta(tokenizedLp, chain.token0Addr, chain.token0Decimals, chain.token1Addr, chain.token1Decimals);
    if (priceDelta == undefined || hysteresis == undefined || spotPrice == undefined || oraclePrice == undefined) {
        success = false;
    };

    if (priceDelta > hysteresis) {
        const { amount0, amount1 } = await executeAutoRebalance(
            tokenizedLp,
            true,
            true
        );
        if (amount0 == undefined || amount1 == undefined) {
            success = false;
        }
        const direction0to1 = amount0 < 0;
        const formattedAmount0 = direction0to1 ? ethers.formatUnits(-1n * amount0, chain.token0Decimals) : ethers.formatUnits(amount0, chain.token0Decimals);
        const formattedAmount1 = direction0to1 ? ethers.formatUnits(amount1, chain.token1Decimals) : ethers.formatUnits(-1n * amount1, chain.token1Decimals);
        if (direction0to1) {
            logNewLine("INF", `traded: ${formattedAmount0} ${chain.token0Name}, ${formattedAmount1} ${chain.token1Name}`);
        } else {
            logNewLine("INF", `traded: ${formattedAmount1} ${chain.token1Name}, ${formattedAmount0} ${chain.token0Name}`);
        }

        // Wait 15 seconds
        await new Promise((resolve) => setTimeout(resolve, 15000));

        const innerLogSuccess = await logPositionInfo(
            chain.lpTokenAddr,
            tokenizedLp,
            chain.token0Addr,
            chain.token0Decimals,
            token0Contract,
            chain.token1Addr,
            chain.token1Decimals,
            token1Contract
        );
        if (!innerLogSuccess) {
            logNewLine("ERR", `failed to log position info`);
        }
    }

    if (!success) {
        logNewLine("ERR", `failed execution lp-rebalance`);
    }
    logNewLine("INF", "lp-rebalance routine complete!");
}

// Do not change this.
if (require.main === module) {
    actionFn()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
}

exports.actionFn = actionFn;

