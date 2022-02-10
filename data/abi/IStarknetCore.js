export default [
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "fromAddress",
        "type": "uint256"
      },
      {
        "internalType": "uint256[]",
        "name": "payload",
        "type": "uint256[]"
      }
    ],
    "name": "consumeMessageFromL2",
    "outputs": [
      {
        "internalType": "bytes32",
        "name": "",
        "type": "bytes32"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "to_address",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "selector",
        "type": "uint256"
      },
      {
        "internalType": "uint256[]",
        "name": "payload",
        "type": "uint256[]"
      }
    ],
    "name": "sendMessageToL2",
    "outputs": [
      {
        "internalType": "bytes32",
        "name": "",
        "type": "bytes32"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  }
];
