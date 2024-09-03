const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("NuDexOperations - Task Management", function () {
  let nuDexOperations, participantManager, owner, addr1, addr2, address1;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();
    address1 = await addr1.getAddress();

    // Deploy mock ParticipantManager
    const MockParticipantManager = await ethers.getContractFactory("MockParticipantManager");
    participantManager = await MockParticipantManager.deploy();
    await participantManager.waitForDeployment();

    // Deploy NuDexOperations
    const NuDexOperations = await ethers.getContractFactory("NuDexOperations");
    nuDexOperations = await upgrades.deployProxy(
      NuDexOperations,
      [await participantManager.getAddress(), await owner.getAddress()],
      {
        initializer: "initialize",
      }
    );
    await nuDexOperations.waitForDeployment();

    // Assume addr1 is a participant
    await participantManager.mockSetParticipant(address1, true);
  });

  it("Should allow a participant to submit a task", async function () {
    const description = "Task 1";

    await expect(nuDexOperations.connect(addr1).submitTask(description))
      .to.emit(nuDexOperations, "TaskSubmitted")
      .withArgs(0, description, address1);

    const latestTask = await nuDexOperations.connect(addr1).getLatestTask();
    expect(latestTask.description).to.equal(description);
    expect(latestTask.isCompleted).to.be.false;
  });

  it("Should revert if a non-participant tries to submit a task", async function () {
    const description = "Task 2";

    await expect(nuDexOperations.connect(addr2).submitTask(description)).to.be.revertedWith(
      "Not a participant"
    );
  });

  it("Should allow the owner to mark a task as completed", async function () {
    const description = "Task 3";
    const result = "0x1234";

    await nuDexOperations.connect(addr1).submitTask(description);
    const taskId = (await nuDexOperations.connect(addr1).getLatestTask()).id;

    await expect(nuDexOperations.markTaskCompleted(taskId, result))
      .to.emit(nuDexOperations, "TaskCompleted")
      .withArgs(taskId, address1, (await ethers.provider.getBlock("latest")).timestamp);

    const completedTask = await nuDexOperations.tasks(taskId);
    expect(completedTask.isCompleted).to.be.true;
    expect(completedTask.result).to.equal(result);
  });

  // FIXME: check not implemented in contract
  // it('Should revert if trying to mark a non-existing task as completed', async function () {
  //   const invalidTaskId = 999;
  //   const result = '0x1234';

  //   await expect(nuDexOperations.markTaskCompleted(invalidTaskId, result)).to.be.revertedWith(
  //     'Task does not exist'
  //   );
  // });

  it("Should allow retrieval of all uncompleted tasks", async function () {
    await nuDexOperations.connect(addr1).submitTask("Task 1");
    await nuDexOperations.connect(addr1).submitTask("Task 2");

    const uncompletedTasks = await nuDexOperations.getUncompletedTasks();
    expect(uncompletedTasks.length).to.equal(2);
    expect(uncompletedTasks[0].description).to.equal("Task 1");
    expect(uncompletedTasks[1].description).to.equal("Task 2");

    // Mark the first task as completed
    const taskId = uncompletedTasks[0].id;
    await nuDexOperations.markTaskCompleted(taskId, "0x1234");

    const updatedUncompletedTasks = await nuDexOperations.getUncompletedTasks();
    expect(updatedUncompletedTasks.length).to.equal(1);
    expect(updatedUncompletedTasks[0].description).to.equal("Task 2");
  });
});
