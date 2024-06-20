require("dotenv").config();

const XOC_ADDR = "";
const LP_ADDRESS_BASE = "";

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
