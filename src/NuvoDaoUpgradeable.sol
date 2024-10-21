// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/INuvoLock.sol";
import "./interfaces/IProxy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract NuvoDAOUpgradeable is OwnableUpgradeable {
    event ProposalCreated(
        uint256 id,
        address proposer,
        string description,
        ProposalType proposalType,
        ProposalCategory proposalCategory
    );
    event Voted(uint256 proposalId, address voter, uint256 weight, uint256 quadraticVotes);
    event ProposalExecuted(uint256 id, bool passed);
    event FundingProposalExecuted(
        uint256 id,
        address recipient,
        uint256 amount,
        address token,
        string purpose
    );
    event BundleProposalExecuted(uint256 id, uint256[] executedProposalIds);
    event Upgraded(address newImplementation);
    event RewardClaimed(address claimer, uint256 amount);

    enum ProposalType {
        Basic,
        Funding,
        Governance,
        Bundle,
        Upgrade
    }
    enum ProposalCategory {
        Budget,
        Policy,
        Membership
    }

    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 voteCount;
        uint256 startTime;
        uint256 endTime;
        uint256 executionTime;
        bool executed;
        ProposalType proposalType;
        ProposalCategory proposalCategory;
        bytes parameters; // Dynamic parameters for governance or funding proposal execution
    }

    struct FundingProposalParameters {
        address payable recipient;
        uint256 amount;
        address token; // Address of the ERC20 token, or address(0) for native cryptocurrency (e.g., ETH)
        string purpose;
    }

    struct BundleProposalParameters {
        uint256[] proposalIds;
    }

    struct UpgradeProposalParameters {
        address newImplementation;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => FundingProposalParameters) public fundingProposals;
    mapping(uint256 => BundleProposalParameters) private bundleProposals; // FIXME: public mapping to struct of array not allowed
    mapping(uint256 => UpgradeProposalParameters) public upgradeProposals;
    mapping(uint256 => mapping(address => uint256)) public votes;
    mapping(address => address) public delegation;
    mapping(address => uint256) public delegatedVotes;
    mapping(address => uint256) public activityScore;
    mapping(address => uint256) public participationRewards;
    mapping(address => uint256) public reputationScore;
    mapping(address => uint256) public lastActive;

    uint256 public constant MIN_LOCK_AMOUNT = 10000 * 10 ** 18; // 10,000 Nuvo tokens
    uint256 public constant MIN_LOCK_DURATION = 3 days;

    INuvoLock public nuvoLock;
    address public proxyAddress;
    address public multisigWallet;

    uint256 public quorumPercentage;
    uint256 public proposalFee;
    uint256 public proposalId;
    uint256 public executionDelay;
    uint256 public fundingThreshold;
    uint256 public reputationDecayRate; // Rate at which reputation decays over time

    function initialize(
        address _owner,
        INuvoLock _nuvoLock,
        address _multisigWallet,
        uint256 _quorumPercentage,
        uint256 _proposalFee,
        uint256 _executionDelay,
        uint256 _fundingThreshold,
        uint256 _reputationDecayRate,
        address _proxyAddress
    ) public initializer {
        __Ownable_init(_owner);
        nuvoLock = _nuvoLock;
        multisigWallet = _multisigWallet;
        quorumPercentage = _quorumPercentage;
        proposalFee = _proposalFee;
        executionDelay = _executionDelay;
        fundingThreshold = _fundingThreshold;
        reputationDecayRate = _reputationDecayRate;
        proxyAddress = _proxyAddress;
    }

    modifier onlyMember() {
        require(
            nuvoLock.lockedBalanceOf(msg.sender) >= MIN_LOCK_AMOUNT &&
                nuvoLock.lockedTime(msg.sender) >= MIN_LOCK_DURATION,
            "You must lock at least 10,000 Nuvo tokens for 3 days to participate."
        );
        _;
    }

    modifier proposalFeePaid() {
        require(msg.value >= proposalFee, "Proposal fee must be paid");
        _;
    }

    function getVotingPower(address _member) public view returns (uint256) {
        uint256 timeWeightedPower = nuvoLock.lockedBalanceOf(_member) *
            (block.timestamp - nuvoLock.lockedTime(_member));
        uint256 reputationBonus = reputationScore[_member] * 1e18; // Apply a multiplier to the reputation score
        return
            timeWeightedPower + reputationBonus + delegatedVotes[_member] + activityScore[_member];
    }

    function delegateVote(address _delegate) external onlyMember {
        require(_delegate != msg.sender, "You cannot delegate to yourself");
        require(
            nuvoLock.lockedBalanceOf(_delegate) >= MIN_LOCK_AMOUNT,
            "Delegate must be a valid DAO member"
        );

        // Revoke previous delegation if it exists
        address previousDelegate = delegation[msg.sender];
        if (previousDelegate != address(0)) {
            delegatedVotes[previousDelegate] -= getVotingPower(msg.sender);
        }

        // Set new delegation
        delegation[msg.sender] = _delegate;
        delegatedVotes[_delegate] += getVotingPower(msg.sender);
    }

    function removeDelegation() external onlyMember {
        address previousDelegate = delegation[msg.sender];
        require(previousDelegate != address(0), "No delegation to remove");

        delegatedVotes[previousDelegate] -= getVotingPower(msg.sender);
        delegation[msg.sender] = address(0);
    }

    function decayReputation(address _member) public {
        uint256 lastActiveTime = lastActive[_member];
        uint256 timeInactive = block.timestamp - lastActiveTime;
        uint256 decayAmount = timeInactive * reputationDecayRate;

        if (reputationScore[_member] > decayAmount) {
            reputationScore[_member] = reputationScore[_member] - decayAmount;
        } else {
            reputationScore[_member] = 0;
        }

        lastActive[_member] = block.timestamp;
    }

    function createProposal(
        string memory _description,
        uint256 _votingPeriod,
        ProposalType _proposalType,
        ProposalCategory _proposalCategory,
        bytes memory _parameters
    ) external payable onlyMember proposalFeePaid {
        uint256 newProposalId = ++proposalId;

        proposals[newProposalId] = Proposal({
            id: newProposalId,
            proposer: msg.sender,
            description: _description,
            voteCount: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + _votingPeriod,
            executionTime: block.timestamp + _votingPeriod + executionDelay,
            executed: false,
            proposalType: _proposalType,
            proposalCategory: _proposalCategory,
            parameters: _parameters
        });
        if (_proposalType == ProposalType.Funding) {
            FundingProposalParameters memory params = abi.decode(
                _parameters,
                (FundingProposalParameters)
            );
            fundingProposals[newProposalId] = params;
        } else if (_proposalType == ProposalType.Bundle) {
            BundleProposalParameters memory params = abi.decode(
                _parameters,
                (BundleProposalParameters)
            );
            bundleProposals[newProposalId] = params;
        } else if (_proposalType == ProposalType.Upgrade) {
            UpgradeProposalParameters memory params = abi.decode(
                _parameters,
                (UpgradeProposalParameters)
            );
            upgradeProposals[newProposalId] = params;
        }
        emit ProposalCreated(
            newProposalId,
            msg.sender,
            _description,
            _proposalType,
            _proposalCategory
        );
    }

    function vote(uint256 _proposalId, uint256 _voteCount) external onlyMember {
        decayReputation(msg.sender);

        Proposal storage proposal = proposals[_proposalId];

        require(block.timestamp >= proposal.startTime, "Voting hasn't started yet");
        require(block.timestamp <= proposal.endTime, "Voting period has ended");
        require(votes[_proposalId][msg.sender] == 0, "You have already voted on this proposal");

        uint256 votingPower = getVotingPower(msg.sender);
        require(_voteCount <= votingPower, "Insufficient voting power");

        // Quadratic Voting: Square the number of votes cast to calculate the cost
        uint256 quadraticVotes = _voteCount * _voteCount;
        require(quadraticVotes <= votingPower, "Quadratic vote exceeds voting power");

        proposal.voteCount = proposal.voteCount + quadraticVotes;
        votes[_proposalId][msg.sender] = quadraticVotes;

        // Increase activity score based on participation
        activityScore[msg.sender] = activityScore[msg.sender] + 1;

        // Reward participation
        participationRewards[msg.sender] = participationRewards[msg.sender] + quadraticVotes;

        // Increase reputation score
        reputationScore[msg.sender] = reputationScore[msg.sender] + 1;

        lastActive[msg.sender] = block.timestamp;

        emit Voted(_proposalId, msg.sender, votingPower, quadraticVotes);
    }

    function executeProposal(uint256 _proposalId) public onlyOwner {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp > proposal.endTime, "Voting period is not over yet");
        require(block.timestamp >= proposal.executionTime, "Execution delay not met");
        require(!proposal.executed, "Proposal already executed");

        uint256 totalLockedTokens = nuvoLock.totalLocked();
        uint256 quorum = (totalLockedTokens * quorumPercentage) / 100;

        bool passed = proposal.voteCount > (totalLockedTokens / 2) && proposal.voteCount >= quorum;
        if (passed) {
            if (proposal.proposalType == ProposalType.Funding) {
                _executeFundingProposal(_proposalId);
            } else if (proposal.proposalType == ProposalType.Governance) {
                _executeGovernanceProposal(_proposalId, proposal.parameters);
            } else if (proposal.proposalType == ProposalType.Bundle) {
                _executeBundleProposal(_proposalId);
            } else if (proposal.proposalType == ProposalType.Upgrade) {
                _executeUpgradeProposal(_proposalId);
            } else {
                _executeBasicProposal(_proposalId);
            }
        }
        proposal.executed = true;

        emit ProposalExecuted(_proposalId, passed);
    }

    function _executeBasicProposal(uint256 _proposalId) internal {
        // Logic for basic proposal execution
    }

    function _executeFundingProposal(uint256 _proposalId) internal {
        FundingProposalParameters memory params = fundingProposals[_proposalId];
        require(params.amount > 0, "Invalid funding amount");
        // FIXME: this can only be called by owner, is multisigWallet also the owner?
        // if (params.amount >= fundingThreshold) {
        //     require(msg.sender == multisigWallet, "Multisig approval required for large funding proposals");
        // }
        if (params.token == address(0)) {
            // Handle native cryptocurrency (e.g., ETH)
            require(address(this).balance >= params.amount, "Insufficient balance");
            params.recipient.transfer(params.amount);
        } else {
            // Handle ERC20 tokens
            IERC20(params.token).transfer(params.recipient, params.amount);
        }

        emit FundingProposalExecuted(
            _proposalId,
            params.recipient,
            params.amount,
            params.token,
            params.purpose
        );
    }

    function _executeGovernanceProposal(uint256 _proposalId, bytes memory _parameters) internal {
        // Decode the parameters and adjust the DAO settings accordingly
        (
            uint256 newQuorumPercentage,
            uint256 newProposalFee,
            uint256 newExecutionDelay,
            uint256 newFundingThreshold,
            uint256 newReputationDecayRate
        ) = abi.decode(_parameters, (uint256, uint256, uint256, uint256, uint256));

        if (newQuorumPercentage > 0 && newQuorumPercentage <= 100) {
            quorumPercentage = newQuorumPercentage;
        }

        if (newProposalFee > 0) {
            proposalFee = newProposalFee;
        }

        if (newExecutionDelay > 0) {
            executionDelay = newExecutionDelay;
        }

        if (newFundingThreshold > 0) {
            fundingThreshold = newFundingThreshold;
        }

        if (newReputationDecayRate > 0) {
            reputationDecayRate = newReputationDecayRate;
        }
    }

    function _executeBundleProposal(uint256 _proposalId) internal {
        BundleProposalParameters memory params = bundleProposals[_proposalId];
        uint256[] memory executedProposalIds = new uint256[](params.proposalIds.length);

        for (uint256 i = 0; i < params.proposalIds.length; i++) {
            uint256 bundleProposalId = params.proposalIds[i];
            Proposal storage bundleProposal = proposals[bundleProposalId];

            if (!bundleProposal.executed) {
                executeProposal(bundleProposalId);
                executedProposalIds[i] = bundleProposalId;
            }
        }

        emit BundleProposalExecuted(_proposalId, executedProposalIds);
    }

    function _executeUpgradeProposal(uint256 _proposalId) internal {
        UpgradeProposalParameters memory params = upgradeProposals[_proposalId];
        IProxy(proxyAddress).upgrade(params.newImplementation);
        emit Upgraded(params.newImplementation);
    }

    function claimRewards() external {
        uint256 reward = participationRewards[msg.sender];
        require(reward > 0, "No rewards available");

        participationRewards[msg.sender] = 0;
        payable(msg.sender).transfer(reward);

        emit RewardClaimed(msg.sender, reward);
    }

    function receiveRevenue() external payable {
        // Function to receive native cryptocurrency (e.g., ETH)
    }

    function receiveERC20(address token, uint256 amount) external {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }

    function getProposal(uint256 _proposalId) external view returns (Proposal memory) {
        return proposals[_proposalId];
    }

    // Automated Reporting and Visualization

    function generateParticipationReport()
        public
        view
        returns (
            uint256 totalMembers,
            uint256 totalProposals,
            uint256 totalVotes,
            uint256 totalReputation
        )
    {
        totalMembers = proposalId; // Number of members who have created proposals
        totalProposals = proposalId;
        totalVotes = 0;
        totalReputation = 0;

        for (uint256 i = 1; i <= proposalId; i++) {
            Proposal memory proposal = proposals[i];
            totalVotes = totalVotes + proposal.voteCount;
        }

        for (uint256 i = 1; i <= proposalId; i++) {
            Proposal memory proposal = proposals[i];
            totalReputation = totalReputation + reputationScore[proposal.proposer];
        }
    }

    function visualizeMetrics() external view returns (string memory) {
        // This function would return a string representation of key metrics.
        // For example, it could return a JSON or CSV format of metrics data.
        // For simplicity, we assume it returns a basic string with comma-separated values.
        uint256 totalMembers;
        uint256 totalProposals;
        uint256 totalVotes;
        uint256 totalReputation;

        (totalMembers, totalProposals, totalVotes, totalReputation) = generateParticipationReport();

        return
            string(
                abi.encodePacked(
                    "Total Members: ",
                    uint2str(totalMembers),
                    ", Total Proposals: ",
                    uint2str(totalProposals),
                    ", Total Votes: ",
                    uint2str(totalVotes),
                    ", Total Reputation: ",
                    uint2str(totalReputation)
                )
            );
    }

    // Utility function to convert uint to string
    function uint2str(uint _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    // Governance control functions (can only be executed via governance proposals)
    function setQuorumPercentage(uint256 _quorumPercentage) external onlyOwner {
        quorumPercentage = _quorumPercentage;
    }

    function setProposalFee(uint256 _proposalFee) external onlyOwner {
        proposalFee = _proposalFee;
    }

    function setExecutionDelay(uint256 _executionDelay) external onlyOwner {
        executionDelay = _executionDelay;
    }

    function setFundingThreshold(uint256 _fundingThreshold) external onlyOwner {
        fundingThreshold = _fundingThreshold;
    }

    function setMultisigWallet(address _multisigWallet) external onlyOwner {
        multisigWallet = _multisigWallet;
    }

    function setReputationDecayRate(uint256 _reputationDecayRate) external onlyOwner {
        reputationDecayRate = _reputationDecayRate;
    }
}
