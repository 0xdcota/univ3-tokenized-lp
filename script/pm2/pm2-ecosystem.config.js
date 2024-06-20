require("dotenv").config();

const XOC_ADDR = "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984";
const LP_ADDRESS_BASE = "0x8250f4aF4B972684F7b336503E2D6dFeDeB1487a";

const PK = process.env.PRIVATE_KEY;
const BASE_RPC = process.env.OPTIMISM_RPC;

module.exports = {
  apps: [
    {
      name: "lp-autorebalancer",
      script: "./scripts/pm2/lp-autorebalancer.js",
      env: {
        LOCAL_CHAIN_ID: 8453,
        LOCAL_LP_ADDR: LP_ADDRESS_BASE,
        LOCAL_RPC: BASE_RPC,
        LOCAL_XOC_ADDR: XOC_ADDR,
      },
      cron_restart: "*/30 * * * *", //  restart every 30 minutes
      autorestart: false, // This prevents PM2 from automatically restarting your script if it crashes or stops
    },
  ],
};
