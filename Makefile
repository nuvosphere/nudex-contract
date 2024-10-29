-include .env

# To deploy and verify our contract
deploy:
	forge script --chain sepolia script/Deploy.s.sol:Deploy --rpc-url ${SEPOLIA_RPC_URL} --broadcast --verify -vvvv

deployTest:
	forge script --chain sepolia script/DeployTest.s.sol:DeployTest --rpc-url ${SEPOLIA_RPC_URL} --broadcast --verify -vvvv

