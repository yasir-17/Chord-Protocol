# Team Members
1) Sivaramakrishnan S
2) Yasir Khan

# What is Working?
1) Chord Ring Setup: Successful creation and configuration of the Chord ring based on the specified number of nodes.
2) Finger Table Initialization: Each node accurately constructs its finger table according to the formulation provided in the research paper.
3) Network Join and Routing: Network joining and message routing are implemented as outlined in Section 4 of the paper.
4) Efficient Distributed Key Lookup: Key-based search operates with logarithmic time complexity in the worst case and achieves about half the logarithmic complexity on average, making lookups scalable with larger nodes
Actor-Based Node Implementation: Each node in the peer network is represented as an independent actor, enabling scalable, concurrent processing across the network.

# Network Behaviour:
We tested the average hops with varying the number of nodes as [16, 32, 64, 128, 256, 512, 1024, 2048, 4096] with 16 requests by each node.
The average hop is about half the logarithmic number of nodes. 
This corroborates with the outcome of the paper as discussed in sec 5.D


# Largest Network Tested
The largest network tested is 32,000 nodes with 8 requests. 
Average Hops for this network: 7.488
The only limitation is hardware constraints; the algorithm itself is optimized to handle larger numbers of nodes and requests efficiently.

# Instructions to run
Unzip the project3 file.
To compile run ponyc 
Then use the following command to run the code
project3 <number of nodes> <number of requests>
