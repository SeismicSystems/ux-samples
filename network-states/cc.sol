/*
 * [TODO]
 */
pragma solidity ^0.8.0;

contract NetworkStates {

    /*
     * - owner is a reserved attribute of any sstruct
     * - sstructs can have members variables of type suint, shielded ints
     * - this sstruct only has suint members, but that doesn't always need
     *   to be the case, can have uint256 too
     * - any variable that interacts with suint must also be suint
     */
    sstruct Tile {
        suint resources;
        suint r;
        suint c;
    }

    /*
     * sstructs are stored in unordered set (actually a map beind the scenes), 
     * so location must be an attribute (can't index)
     */
    Tile{} tiles;

    /*
     * - landing is consumed
     */
    function spawn(Tile consume landing) external {
        require(
            landing.owner == address(0),
            "Cannot spawn on an owned tile"
        );
        Tile memory updatedLanding = Tile({
            resources: 10,
            r: landing.r,
            c: landing.c,
        };
        tiles.insert(updatedLanding)
    }

    modifier isNeighbor(
        uint256 r1,
        uint256 c1,
        uint256 r2,
        uint256 c2
    ) {
        require(
            (r1 == r2 && (c1 == c2 + 1 || c1 == c2 - 1)) ||
                (c1 == c2 && (r1 == r2 + 1 || r1 == r2 - 1)),
            "Given points are not neighbors"
        );
        _;
    }

    modifier isOwnedBySender(Tile memory t) {
        require(
            t.owner == msg.sender,
            "Tile must be owned by sender"
        );
        _;
    }

    /*
     * - any function that uses find() is a shielded function
     * - shielded functions are sent to Seismic
     * - any function called by a shielded function is also sent to Seismic
     * - does NOT consume Q bc view function
     */
    function getTile(Tile memory anchor, suint queryR, suint queryC) 
        view isNeighbor(anchor.r, anchor.c, queryR, queryC) 
        isOwnedBySender(owned)
        returns(Tile memory) {

        // linear scan, can improve 
        return tiles.find((t) => t.r == queryR  && t.c == queryC);
    }

    modifier sufficientResources(
        Tile memory t,
        uint256 amount
    ) {
        require(
            amount >= t.resources,
            "Insufficient resources"
        );
        _;
    }

    /*
     * 
     */
    function move(
        Tile consume from,
        Tile consume to,
        suint amount
    ) 
        external 
        isNeighbor(from.r, from.c, to.r, to.c) 
        isOwnedBySender(from)
        sufficientResources(from, amount) 
    {
        Tile memory updatedFrom = from;
        Tile memory updatedTo = to;
        if (to.owner == address(0)) {
            // moving onto unowned tile
            updatedTo.owner = msg.sender;
            updatedTo.numTroops = amount;
        } else if (to.owner != msg.sender) {
            // moving onto enemy tile
            if (amount > to.numTroops) {
                // conquer tile
                updatedTo.owner = msg.sender;
                updatedTo.numTroops = amount - to.numTroops;
            } else {
                // did not conquer tile
                updatedTo.numTroops -= amount;
            }
        } else {
            // moving onto own tile
            updatedTo.numTroops += amount;
        }
        updatedFrom.numTroops -= amount;
        
        tiles.insert(updatedFrom);
        tiles.insert(updatedTo);
    }
}
