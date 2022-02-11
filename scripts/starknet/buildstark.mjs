import pkg from 'hardhat'
import { shortString } from 'starknet';

const { starknet } = pkg;

const parseResponse = (response) => {
  // console.log(`Raw: ${response}`)
  console.log('Raw: ');
  console.log(response);
  // console.log(`Name: ${shortString.decodeShortString(response.result[4])}`)
}

const stringToFelt = (input) => {
  const encoded = shortString.encodeShortString(input)
  return(BigInt(encoded).toString(10));
}

let cairoDungeon;

const cairoDungeonFactory = await starknet.getContractFactory("dungeon");
cairoDungeon = await cairoDungeonFactory.deploy();
console.log("Cairo Dungeon deployed at ", cairoDungeon.address);

const TOKEN_ID = 5;
const OWNER_ADDRESS = BigInt("0x062cdb5f547735b352813397a5d2621c950cd98c6ac606d6d8898b11d7bd7e96").toString(10);
const ENVIRONMENT = 3;
const SIZE = 20;
const NAME = stringToFelt("Gremp's Dunes");

// Set tokenId for #5
console.log('set address for #5')
const setTokenResponse = await cairoDungeon.invoke("set_dungeon", {
  token_id: TOKEN_ID,
  owner_address: OWNER_ADDRESS,
  environment: ENVIRONMENT,
  size: SIZE,
  name: NAME
});

// console.log(parseResponse(setTokenResponse))

// Read dungeon metadata
const getMetadata = await cairoDungeon.call('get_dungeon', {token_id: TOKEN_ID})
console.log(getMetadata)

// Get Environment
const getEnvironment = await cairoDungeon.call('get_environment', {token_id: TOKEN_ID})
console.log(getEnvironment)

// Get Name
const getName = await cairoDungeon.call('get_name', {token_id: TOKEN_ID})
console.log(getName)

// Get Size
const getSize = await cairoDungeon.call('get_size', {token_id: TOKEN_ID})
console.log(getSize)

// console.log(`get_dungeon(): ${getTokenResponse.result}`); 

/*
// Read Owner
const getOwnerResponse = await provider.callContract({
  contract_address: CONTRACT_ADDRESS,
  entry_point_selector: getSelectorFromName("get_owner"),
  calldata: [TOKEN_ID]
}) 

console.log(`get_owner(): ${getOwnerResponse.result}`); 

// Read Environment
const getEnvironmentResponse = await provider.callContract({
  contract_address: CONTRACT_ADDRESS,
  entry_point_selector: getSelectorFromName("get_environment"),
  calldata: [TOKEN_ID]
}) 

console.log(`get_environment(): ${getEnvironmentResponse.result}`); 

// Read Size
const getSizeResponse = await provider.callContract({
  contract_address: CONTRACT_ADDRESS,
  entry_point_selector: getSelectorFromName("get_size"),
  calldata: [TOKEN_ID]
}) 

console.log(`get_size(): ${getSizeResponse.result}`); 

// Read Name
const getNameResponse = await provider.callContract({
  contract_address: CONTRACT_ADDRESS,
  entry_point_selector: getSelectorFromName("get_name"),
  calldata: [TOKEN_ID]
}) 
console.log(shortString.decodeShortString(getNameResponse.result[0]))
*/