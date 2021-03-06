include "../circomlib/circuits/mimc.circom";
include "../circomlib/circuits/eddsamimc.circom";
include "../circomlib/circuits/bitify.circom";
include "../circomlib/circuits/comparators.circom";
include "./leaf.circom";
include "./hash2.circom";
include "./tree_segment.circom";
include "./treeWithSegment.circom";

template Main() {
    signal input fromPubKey_x;
    signal input fromPubKey_y;
    signal input oldRootHash;
    signal input newRootHash;
    signal input indexFrom; // Start frame with tree segment 0-7
    signal input indexTo; // Transfer up to this frame number 0-7
    signal input toPubKey_x; // Public key parts for the transferee
    signal input toPubKey_y;
    signal input segmentAssets[8]; // Hashes of the frame data for each leaf in the segment
    signal input segmentOwners[8,2]; // Owner pub key x, y
    signal input pathToSegment[3]; // Sibling hashes along the path
    // EdDSA verifier params
    signal input R8x;
    signal input R8y;
    signal input S;

    //signal input segRoot; // For debugging

    signal output out;


    // Assemble leaves for the segment.
    var i;
    component leaves[8];
    for (i=0; i<8; i++) {
        leaves[i] = Leaf();
        leaves[i].pubkey_x <== segmentOwners[i,0];
        leaves[i].pubkey_y <== segmentOwners[i,1];
        leaves[i].asset <== segmentAssets[i];
    }

    // Build segment
    component oldSegment = TreeSegment8();
    for (i=0; i<8; i++) {
      oldSegment.leafHashes[i] <-- leaves[i].hash;
    }

    // Assemble full tree (path + segment)
    // Build full path including the segment. Calculate old root hash.
    component old_tree = TreeWithSegment6();
    for (i=0; i<3; i++) {
      old_tree.pathToSegment[i] <== pathToSegment[i];
    }
    old_tree.segmentRootHash <-- oldSegment.rootHash;
    oldRootHash === old_tree.rootHash;

    // Confirm signatures
    component verifier = EdDSAMiMCVerifier();
    verifier.enabled <-- 1;
    verifier.Ax <-- fromPubKey_x;
    verifier.Ay <-- fromPubKey_y;
    verifier.R8x <-- R8x
    verifier.R8y <-- R8y
    verifier.S <-- S;

    component msgHash = MultiMiMC7(3,91);
    msgHash.in[0] <-- oldRootHash;
    msgHash.in[1] <-- indexFrom;
    msgHash.in[2] <-- indexTo;
    verifier.M <== msgHash.out;

    // Confirm ownership & Replace owner

    for (i=0; i<8; i++) {
        if (i>=indexFrom && i<=indexTo) {
            fromPubKey_x === segmentOwners[i,0];
            fromPubKey_y === segmentOwners[i,1];
        }
    }

    component newLeaves[8];

    for (i=0; i<8; i++) {
        newLeaves[i] = Leaf();
        if (i>=indexFrom && i<=indexTo) {
            newLeaves[i].pubkey_x <-- toPubKey_x;
            newLeaves[i].pubkey_y <-- toPubKey_y;
        } else {
            newLeaves[i].pubkey_x <-- segmentOwners[i,0];
            newLeaves[i].pubkey_y <-- segmentOwners[i,1];
        }
        newLeaves[i].asset <-- segmentAssets[i];
    }

    // Calculate new segment
    component newSegment = TreeSegment8();
    for (i=0; i<8; i++) {
        newSegment.leafHashes[i] <== newLeaves[i].hash;
    }

    component new_tree = TreeWithSegment6();
    for (i=0; i<3; i++) {
      new_tree.pathToSegment[i] <== pathToSegment[i];
    }
    new_tree.segmentRootHash <== newSegment.rootHash;

    new_tree.rootHash --> out;
    newRootHash === new_tree.rootHash;
}

component main = Main();
