module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deployer } = await getNamedAccounts();
  const { deploy } = deployments;

  const NuvoLock = await deployments.get("NuvoLockUpgradeable");
  const nuvoLockAddress = await nuvoLock.getAddress();

  console.log("Deploying ParticipantManager with deployer:", deployer);

  await deploy("ParticipantManager", {
    from: deployer,
    args: [nuvoLockAddress, ethers.parseEther("100"), 60 * 24 * 60 * 60],
    log: true,
  });
};

module.exports.tags = ["ParticipantManager"];
