require("dotenv").config();
// const { ethers } = require("ethers");

const READ_ONLY = false;

// Base
const RPC_URL_BASE = `${process.env.RPC_BASE}`;
const TOKEN0_ADDR_BASE = `${process.env.TOKEN0_ADDR_BASE}`;
const TOKEN0_NAME_BASE = `${process.env.TOKEN0_NAME_BASE}`;
const TOKEN0_DECIMALS_BASE = `${process.env.TOKEN0_DECIMALS_BASE}`;
const TOKEN1_ADDR_BASE = `${process.env.TOKEN1_ADDR_BASE}`;
const TOKEN1_NAME_BASE = `${process.env.TOKEN1_NAME_BASE}`;
const TOKEN1_DECIMALS_BASE = `${process.env.TOKEN1_DECIMALS_BASE}`;
const LP_TOKEN_ADDR_BASE = `${process.env.LP_TOKEN_ADDR_BASE}`;
const TOKEN0_IDLE_THRESHOLD_BASE = `${process.env.TOKEN0_IDLE_THRESHOLD_BASE}`;

// Polygon
const RPC_URL_POLYGON = `${process.env.RPC_POLYGON}`;
const TOKEN0_ADDR_POLYGON = `${process.env.TOKEN0_ADDR_POLYGON}`;
const TOKEN0_NAME_POLYGON = `${process.env.TOKEN0_NAME_POLYGON}`;
const TOKEN0_DECIMALS_POLYGON = `${process.env.TOKEN0_DECIMALS_POLYGON}`;
const TOKEN1_ADDR_POLYGON = `${process.env.TOKEN1_ADDR_POLYGON}`;
const TOKEN1_NAME_POLYGON = `${process.env.TOKEN1_NAME_POLYGON}`;
const TOKEN1_DECIMALS_POLYGON = `${process.env.TOKEN1_DECIMALS_POLYGON}`;
const LP_TOKEN_ADDR_POLYGON = `${process.env.LP_TOKEN_ADDR_POLYGON}`;
const TOKEN0_IDLE_THRESHOLD_POLYGON = `${process.env.TOKEN0_IDLE_THRESHOLD_POLYGON}`;

module.exports = {
  apps: [
    {
      name: "base-lp-logger",
      script: "./script/pm2/lp-logger.js",
      env: {
        LOCAL_CHAIN_ID: 8453,
        LOCAL_RPC: RPC_URL_BASE,
        LOCAL_LP_TOKEN_ADDR: LP_TOKEN_ADDR_BASE,
        LOCAL_TOKEN0_ADDR: TOKEN0_ADDR_BASE,
        LOCAL_TOKEN0_NAME: TOKEN0_NAME_BASE,
        LOCAL_TOKEN0_DECIMALS: TOKEN0_DECIMALS_BASE,
        LOCAL_TOKEN1_ADDR: TOKEN1_ADDR_BASE,
        LOCAL_TOKEN1_NAME: TOKEN1_NAME_BASE,
        LOCAL_TOKEN1_DECIMALS: TOKEN1_DECIMALS_BASE,
      },
      cron_restart: "* * * * *", // Every minute
      autorestart: false, // This prevents PM2 from automatically restarting your script if it crashes or stops
    },
    {
      name: "polygon-lp-logger",
      script: "./script/pm2/lp-logger.js",
      env: {
        LOCAL_CHAIN_ID: 137,
        LOCAL_RPC: RPC_URL_POLYGON,
        LOCAL_LP_TOKEN_ADDR: LP_TOKEN_ADDR_POLYGON,
        LOCAL_TOKEN0_ADDR: TOKEN0_ADDR_POLYGON,
        LOCAL_TOKEN0_NAME: TOKEN0_NAME_POLYGON,
        LOCAL_TOKEN0_DECIMALS: TOKEN0_DECIMALS_POLYGON,
        LOCAL_TOKEN1_ADDR: TOKEN1_ADDR_POLYGON,
        LOCAL_TOKEN1_NAME: TOKEN1_NAME_POLYGON,
        LOCAL_TOKEN1_DECIMALS: TOKEN1_DECIMALS_POLYGON,
      },
      cron_restart: "* * * * *", // Every minute
      autorestart: false, // This prevents PM2 from automatically restarting your script if it crashes or stops
    },
    {
      name: "base-lp-rebalance",
      script: "./script/pm2/lp-rebalance.js",
      env: {
        LOCAL_CHAIN_ID: 8453,
        LOCAL_RPC: RPC_URL_BASE,
        LOCAL_LP_TOKEN_ADDR: LP_TOKEN_ADDR_BASE,
        LOCAL_TOKEN0_ADDR: TOKEN0_ADDR_BASE,
        LOCAL_TOKEN0_NAME: TOKEN0_NAME_BASE,
        LOCAL_TOKEN0_DECIMALS: TOKEN0_DECIMALS_BASE,
        LOCAL_TOKEN1_ADDR: TOKEN1_ADDR_BASE,
        LOCAL_TOKEN1_NAME: TOKEN1_NAME_BASE,
        LOCAL_TOKEN1_DECIMALS: TOKEN1_DECIMALS_BASE,
      },
      cron_restart: "* * * * *", // Every minute
      autorestart: false, // This prevents PM2 from automatically restarting your script if it crashes or stops
    },
    {
      name: "polygon-lp-rebalance",
      script: "./script/pm2/lp-rebalance.js",
      env: {
        LOCAL_CHAIN_ID: 137,
        LOCAL_RPC: RPC_URL_POLYGON,
        LOCAL_LP_TOKEN_ADDR: LP_TOKEN_ADDR_POLYGON,
        LOCAL_TOKEN0_ADDR: TOKEN0_ADDR_POLYGON,
        LOCAL_TOKEN0_NAME: TOKEN0_NAME_POLYGON,
        LOCAL_TOKEN0_DECIMALS: TOKEN0_DECIMALS_POLYGON,
        LOCAL_TOKEN1_ADDR: TOKEN1_ADDR_POLYGON,
        LOCAL_TOKEN1_NAME: TOKEN1_NAME_POLYGON,
        LOCAL_TOKEN1_DECIMALS: TOKEN1_DECIMALS_POLYGON,
      },
      cron_restart: "* * * * *", // Every minute
      autorestart: false, // This prevents PM2 from automatically restarting your script if it crashes or stops
    },
  ],
};
