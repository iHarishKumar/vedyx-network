#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const Mustache = require('mustache');

// Get network from command line argument
const network = process.argv[2];

if (!network) {
  console.error('❌ Error: Network argument required');
  console.log('Usage: node scripts/prepare-subgraph.js <network>');
  console.log('Available networks: unichain-sepolia, lasna-testnet, mainnet');
  process.exit(1);
}

// Load network configuration
const configPath = path.join(__dirname, '../config/networks.json');
const networksConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'));

if (!networksConfig[network]) {
  console.error(`❌ Error: Network "${network}" not found in config`);
  console.log('Available networks:', Object.keys(networksConfig).join(', '));
  process.exit(1);
}

const config = networksConfig[network];

// Try to load deployment info from contracts folder
const deploymentPath = path.join(__dirname, '../../contracts/deployments', network, 'deployment.json');
if (fs.existsSync(deploymentPath)) {
  const deployment = JSON.parse(fs.readFileSync(deploymentPath, 'utf8'));
  
  // Update config with deployment data if available
  if (deployment.contracts && deployment.contracts.votingContract) {
    config.votingContractAddress = deployment.contracts.votingContract;
    console.log(`✅ Loaded voting contract address from deployment: ${config.votingContractAddress}`);
  }
}

// Load template
const templatePath = path.join(__dirname, '../subgraph.template.yaml');
const template = fs.readFileSync(templatePath, 'utf8');

// Render template with config
const rendered = Mustache.render(template, config);

// Write output
const outputPath = path.join(__dirname, '../subgraph.yaml');
fs.writeFileSync(outputPath, rendered);

console.log(`✅ Generated subgraph.yaml for network: ${network}`);
console.log(`   Network: ${config.graphNetwork}`);
console.log(`   Contract: ${config.votingContractAddress}`);
console.log(`   Start Block: ${config.startBlock}`);
