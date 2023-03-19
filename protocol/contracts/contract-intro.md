Hello Chat-GPT! I am attempting to begin a smart contract implementation. 

Storage bounties can bring down prices for clients by creating competition among storage providers to win storage deals. When a client wants to store data on the Filecoin network, they can submit a storage deal with a certain amount of storage capacity and a specified duration to the network.
Storage providers can then bid on these storage deals by offering their own price for the same amount of storage capacity and duration. The storage provider with the lowest bid wins the deal and is then responsible for storing the client's data. 

By allowing storage providers to compete for storage deals, storage bounties create a marketplace for storage capacity on the Filecoin network, which can drive down prices for clients. Providers may offer lower prices to win deals and outcompete other providers, ultimately benefiting the clients who can obtain storage services at a lower cost.

In addition, the existence of storage bounties may encourage new storage providers to enter the market, which can further increase competition and drive prices down over time.

These are some of the initial features that may be added to the smart contract:
- Bounties 
- Publish Bounty (UI)
- Bid on bounty (UI)
- Accept Bounty bid (UI)
- Search and find bounties to accept (UI)
- Release responsibility over bounty (ui) 
- Publish bounty (Smart contract)
- Accept bounty bid (Smart contract) 
- Release responsibility over bounty (UI)
- Release responsibility over data (Smart contract)

I am hoping you - Chat-GPT, will assist me in being able to understand smart contract interactivity. 

Also these are some of the methods/functions I would like to include in the design of the smart contract (functions/flow) for storage bounty:
- addBounty()
- releaseBounty()
- addBid()
- removeBid()
- updateBid()
- addCid()
- fund()

- policyOK()
- authorizeData
- acceptBid() -> was claimBounty 
- authorizeData()
- disputeClaimedBounty()
Feel free to include these methods, but they may be deleted. My teammate and I are not yet if we plan to implement them:
- placeBid()
- releaseBids()
- releaseBid()

Here are some of me and my teammate's observations:
DataBountyContract should handle bids for storage deals. Clients submit storage deals (escrow) and providers submit bids. Client (bounty hunter) can approve any bids with claimBounty (DEALID, CID, ..other parameters based on criteria? -- future work)

Firstly, it lacks a mechanism to ensure that the storage provider stores the content for a specified duration, which is critical for storage bounties. 

Secondly, there is no way to ensure that the storage provider has not tampered with the content.
Finally, there is no mechanism to deal with disputes that may arise when a storage provider claims a bounty.

The contract has three constants defined:
CALL_ACTOR_ID: This is the address of the Filecoin actor that the contract will interact with when sending rewards to bounty hunters.
DEFAULT_FLAG: This is a default value used in the contract for some function calls.
METHOD_SEND: This is a method used to send FIL to the Filecoin actor defined in CALL_ACTOR_ID.

Here are some other specifics regarding the implementation of both the frontend UI as well as the protocols for the smart contract. Individual stands for the features that will be available to the client while Smart Contract will be the defined features for the protocols within the smart contract:

Individual: Selects and uploads to a decentralized hosting service and gets the CID. 
Use IPFS or Web3.Storage 

[Individual]: Posts a storage deal on the smart contract.

addBounty() - storage deal is posted. (struct DealStruct)

Struct DataBounty[A POSSIBLE CHANGE IN NAME] -> { epoch time until update bid end  }

addCID() - add the cid of the stored data → internal

Add max amount willing to pay to escrow

[Storage providers]: Review available storage deals. (User Interface Action)

[Storage providers]: Place a bid on the desired storage deal on the smart contract.

addBid(Bid bid)

We need to update a mapping [bidId -> address] (assumption that user is not using different ethereum addresses)

Mapping [deaLid -> bidId]

event NewBid(indexed uint bid_id) 

[Individual]: Compares all received bids and selects the best one 

(User Interface Action): Go to the UI and accept bid

acceptBid(uint256 bid_id)

event BidAccepted(indexed uint bid_id)
Notifies the winning storage provider about the successful bid. (User Interface Action)
[Individual]: Reviews the winning bid and accepts the bid on the smart contract. 

claimBounty(deal_id)

Storage provider should have already stored the file here and authorizeAction() method should check that…

Wont be able to check the size.. Because of counter offers

Smart contract should check with filecoin api to make sure the right person is claiming(authorizeAction).

Also we should check that the [dealid] -> bidId == bidId [address] == caller

[Storage provider]: Stores the file and provides proof of storage on possibly another smart contract.

[ smart contract]: Records the proof of storage and notifies the individual about successful storage.

Would you mind giving me some pointers on how to begin this implementation. Feel free to list out any bit of advice as well as any example implementations with comments.
