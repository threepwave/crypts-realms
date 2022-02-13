import pkg from 'hardhat'
import { shortString } from 'starknet';

const { starknet } = pkg;

const STAKER_ADDRESS = "0x062cdb5f547735b352813397a5d2621c950cd98c6ac606d6d8898b11d7bd7e96"

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

// Initialize main dungeon contract
const dungeonFactory = await starknet.getContractFactory("dungeon");
let dungeon = await dungeonFactory.deploy();
console.log("Dungeon contract deployed at ", dungeon.address);

// Initialize L1_Bridge contract
const bridgeFactory = await starknet.getContractFactory("l1bridge");
let bridge = await bridgeFactory.deploy({
  _l1_address: BigInt(STAKER_ADDRESS).toString(10), 
  _starknet_address: BigInt(dungeon.address).toString(10)
});
console.log("Bridge contract deployed at ", bridge.address);


const TOKEN_ID = 5;
const OWNER_ADDRESS = BigInt("0x062cdb5f547735b352813397a5d2621c950cd98c6ac606d6d8898b11d7bd7e96").toString(10);
const ENVIRONMENT = 3;
const SIZE = 20;
const NAME = stringToFelt("Gremp's Dunes");


console.log('Spoof message from L1 to Bridge contract');

// Message should create dungeon 
const response = await bridge.invoke("receive_message", {
  from_address: BigInt(STAKER_ADDRESS).toString(10),
  token_id: TOKEN_ID,
  staked: 1,
  user_address: BigInt(OWNER_ADDRESS).toString(10),
  environment: ENVIRONMENT,
  size: SIZE,
  name: NAME
});

/*
// Set tokenId for #5
console.log('set address for #5')
const setTokenResponse = await dungeon.invoke("set_dungeon", {
  token_id: TOKEN_ID,
  owner_address: OWNER_ADDRESS,
  environment: ENVIRONMENT,
  size: SIZE,
  name: NAME
}); */

// Read dungeon metadata
const getMetadata = await dungeon.call('get_dungeon', {token_id: TOKEN_ID})
console.log(getMetadata)