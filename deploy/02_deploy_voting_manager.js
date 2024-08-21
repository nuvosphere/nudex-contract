module.exports = async ({ getNamedAccounts, deployments }) => {
	  const { deployer } = await getNamedAccounts();
	  const { deploy } = deployments;

	  const ParticipantManager = await deployments.get("ParticipantManager");
	  const participantManagerAddress = ParticipantManager.address;

	  console.log("Deploying VotingManager with deployer:", deployer);

	  await deploy("VotingManager", {
		      from: deployer,
		      args: [participantManagerAddress],
		      log: true,
		    });
};

module.exports.tags = ["VotingManager"];

