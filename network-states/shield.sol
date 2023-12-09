/*
 * [SPDX-License-Identifier: MIT]
 *
 * [TODO]
 *
 */
pragma solidity ^0.8.0;

contract NetworkStates {

    sstruct Location {
        suint r,
        suint c
    }

    /*
     * - owner is a reserved attribute of any sstruct
     * - sstructs can have members variables of type suint, shielded ints
     * - this sstruct only has suint members, but that doesn't always need
     *   to be the case, can have uint256 too
     * - any variable that interacts with suint must also be suint
     */
    sstruct Tile {
        suint resources;
        Location virt loc;
    }

    Tile EMPTY_TL = Tile({
        resources: 0,
        loc: Loc({
            r: 0,
            c: 0
        })
    })

    /*
     * sstructs are stored in unordered set (actually a map beind the scenes), 
     * so location must be an attribute (can't index)
     */
    Tile{} tiles;

    mapping(address => bool) spawnPaymentTracker;
    mapping(address => Location) spawnCoord;

    modifier isUnowned(Tile memory t) {
        require(
            t.owner == address(0),
            "Cannot spawn onto an owned tile"
        );
        _;
    }

    /*
     * - landing is consumed
     */
    function spawn(Tile consume landing) external payable isUnowned(tiles[r][c]) {
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

    modifier sentSpawnEth() {
        require(
            msg.value == 0.01 ether,
            "Must send 0.01 ETH with the spawn request"
        );
        _;
    }

    function requestSpawn() payable sentSpawnEth() {
        spawnPaymentTracker[msg.sender] = true;
    }

    modifier eligibleForLanding(suint r, suint c) {
        require(
            spawnPaymentTracker[msg.sender],
            "Must request to spawn prior to receiving a landing Tile"
        );

        suint spawnR = spawnCoord[msg.sender].r;
        suint spawnC = spawnCoord[msg.sender].c;
        require(
            (spawnR == 0 && spawnC == 0) || 
            (tiles.find((t) => t.r == spawnR  && t.c == spawnC) !== EMPTY_TL),
            ""
        );
        _;
    }

    /*
     * - any function that uses find() is a shielded function
     * - shielded functions are sent to Seismic
     * - any function called by a shielded function is also sent to Seismic
     * - does NOT consume Q bc view function
     */
    function getTileMove(Tile memory anchor, suint queryR, suint queryC) 
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
