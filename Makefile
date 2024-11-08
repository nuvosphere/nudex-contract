-include .env


.PHONY: build
build:
	forge build

.PHONY: install
install:
	forge install

# To deploy and verify our contract
deploy:
	forge script --chain sepolia script/Deploy.s.sol:Deploy --rpc-url ${SEPOLIA_RPC_URL} --broadcast --verify -vvvv

deployTest:
	forge script --chain 48815 script/DeployTest.s.sol:DeployTest --rpc-url ${GOAT_TESTNET_RPC_URL} --broadcast -vvvv

deployDev:
	forge script --rpc-url localhost script/DeployTest.s.sol:DeployTest --broadcast -vvvv

participantSetup:
	forge script --rpc-url localhost script/ParticipantSetup.s.sol:ParticipantSetup --broadcast -vvvv

generateSig:
	forge script --rpc-url localhost script/SignatureGenerator.sol --sig "run(address,bytes,uint256,uint256)"

.PHONY: abi
abi:
	mkdir -p abi
	forge inspect  AccountManagerUpgradeable abi > ./abi/AccountManager.json
	forge inspect  AssetManagerUpgradeable abi > ./abi/AssetManager.json
	forge inspect  DepositManagerUpgradeable abi > ./abi/DepositManager.json
	forge inspect  NIP20Upgradeable abi > ./abi/NIP20.json
	forge inspect  NuDexOperationsUpgradeable abi > ./abi/NuDexOperations.json
	forge inspect  NuvoDAOUpgradeable abi > ./abi/NuvoDao.json
	forge inspect  NuvoLockUpgradeable abi > ./abi/NuvoLock.json
	forge inspect  ParticipantManagerUpgradeable abi > ./abi/ParticipantManager.json
	forge inspect  VotingManagerUpgradeable abi > ./abi/VotingManager.json
