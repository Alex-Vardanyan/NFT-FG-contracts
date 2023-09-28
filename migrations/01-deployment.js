const ForestGuardians = artifacts.require('ForestGuardians');
const FGCertificate = artifacts.require('FGCertificate');

module.exports = async function(deployer) {
    await deployer.deploy(FGCertificate).then(function() {
        return deployer.deploy(ForestGuardians, FGCertificate.address);
    });
    CertInstance = await FGCertificate.deployed();
    FGInstance = await ForestGuardians.deployed();
    await CertInstance.grantRole("0x6d5c9827c1f410bbb61d3b2a0a34b6b30492d9a1fd38588edca7ec4562ab9c9b", FGInstance.address);
    await CertInstance.unpause();
    await FGInstance.setMintPrice(20);
    await FGInstance.setSpecialPrice(100);
    await FGInstance.setUpgradePrice(10);
    await FGInstance.unpause();
}