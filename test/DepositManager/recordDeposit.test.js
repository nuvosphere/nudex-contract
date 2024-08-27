const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DepositManager - Recording Deposits", function () {
  let depositManager, addr1, addr2;

  beforeEach(async function () {
    [addr1, addr2] = await ethers.getSigners();

    // Deploy DepositManager
    const DepositManager = await ethers.getContractFactory("DepositManager");
    depositManager = await DepositManager.deploy();
    await depositManager.deployed();
  });

  it("Should allow recording a deposit", async function () {
    const targetAddress = addr1.address;
    const amount = ethers.utils.parseUnits("100", 18);
    const txInfo = "0x1234";
    const chainId = 1;
    const extraInfo = "0x5678";

    await expect(depositManager.recordDeposit(targetAddress, amount, txInfo, chainId, extraInfo))
      .to.emit(depositManager, "DepositRecorded")
      .withArgs(targetAddress, amount, txInfo, chainId, extraInfo);

    const deposits = await depositManager.getDeposits(targetAddress);
    expect(deposits.length).to.equal(1);
    expect(deposits[0].amount).to.equal(amount);
    expect(deposits[0].txInfo).to.equal(txInfo);
    expect(deposits[0].chainId).to.equal(chainId);
    expect(deposits[0].extraInfo).to.equal(extraInfo);
  });

  it("Should allow multiple deposits for the same address", async function () {
    const targetAddress = addr1.address;
    const amount1 = ethers.utils.parseUnits("100", 18);
    const txInfo1 = "0x1234";
    const chainId1 = 1;
    const extraInfo1 = "0x5678";

    const amount2 = ethers.utils.parseUnits("200", 18);
    const txInfo2 = "0x9876";
    const chainId2 = 2;
    const extraInfo2 = "0x5432";

    await depositManager.recordDeposit(targetAddress, amount1, txInfo1, chainId1, extraInfo1);
    await depositManager.recordDeposit(targetAddress, amount2, txInfo2, chainId2, extraInfo2);

    const deposits = await depositManager.getDeposits(targetAddress);
    expect(deposits.length).to.equal(2);
    expect(deposits[0].amount).to.equal(amount1);
    expect(deposits[0].txInfo).to.equal(txInfo1);
    expect(deposits[0].chainId).to.equal(chainId1);
    expect(deposits[0].extraInfo).to.equal(extraInfo1);
    expect(deposits[1].amount).to.equal(amount2);
    expect(deposits[1].txInfo).to.equal(txInfo2);
    expect(deposits[1].chainId).to.equal(chainId2);
    expect(deposits[1].extraInfo).to.equal(extraInfo2);
  });
});
