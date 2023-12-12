/*
 * [SPDX-License-Identifier: MIT]
 *
 * A demo for Network States without fog of war. Players can choose to spawn at
 * any unowned tile for 0.01 ETH. They land with 10 troops, which they can use
 * to conquer surrounding land.
 *
 */
pragma solidity ^0.8.0;

contract NetworkStates {

    /*
     * Infinite grid that can be indexed with tiles[row][col]. Each element 
     * stores the owner of the tile at that location and the number of troops 
     * they have there.
     */
    struct Tile {
        address owner;
        uint256 numTroops;
    }
    mapping(uint256 => mapping(uint256 => Tile)) public tiles;

    /*
     * Players can spawn onto any unowned tile by staking ETH. 
     */
    function spawn(
        uint256 r,
        uint256 c
    ) external payable isUnowned(tiles[r][c]) sentSpawnEth() {
        Tile storage landing = tiles[r][c];
        landing.numTroops = 10;
        landing.owner = msg.sender;
    }

    /*
     * To move is to transfer troops from one tile (the "from" tile) to a 
     * neighboring tile (the "to" tile).
     */
    function move(
        uint256 fromR,
        uint256 fromC,
        uint256 toR,
        uint256 toC,
        uint256 amount
    )
        external
        isNeighbor(fromR, fromC, toR, toC)
        isOwnedBySender(tiles[fromR][fromC])
        sufficientResources(tiles[fromR][fromC], amount)
    {
        Tile storage from = tiles[fromR][fromC];
        Tile storage to = tiles[toR][toC];
        if (to.owner == address(0)) {
            // Moving onto an unowned tile captures it
            to.owner = msg.sender;
            to.numTroops = amount;
        } else if (to.owner != msg.sender) {
            // Moving onto an enemy tile leads to a battle
            if (amount > to.numTroops) {
                // You conquer the enemy tile if you bring more troops than 
                // they currently have on there
                to.owner = msg.sender;
                to.numTroops = amount - to.numTroops;
            } else {
                // You do not conquer the enemy tile if you have less
                to.numTroops -= amount;
            }
        } else {
            // Moving onto an owned tile is additive
            to.numTroops += amount;
        }
        from.numTroops -= amount;
    }

    /*
     * Assert tile <t> is unowned.
     */
    modifier isUnowned(Tile memory t) {
        require(t.owner == address(0), "Cannot spawn onto an owned tile");
        _;
    }

    /*
     * Assert transaction was sent with the buy-in amount.
     */
    modifier sentSpawnEth() {
        require(msg.value == 0.01 ether, "Must send 0.01 ETH to spawn");
        _;
    }

    /*
     * Assert tile <t> is owned by the sender of the tx.
     */
    modifier isOwnedBySender(Tile memory t) {
        require(
            t.owner == msg.sender,
            "Tile must be owned by sender of the tx"
        );
        _;
    }

    /*
     * Assert that two (row, col) locations are adjacent, i.e. one step away
     * on the cardinal plane.
     */
    modifier isNeighbor(
        uint256 r1,
        uint256 c1,
        uint256 r2,
        uint256 c2
    ) {
        bool isVerticalNeighbor = c1 == c2 && (r1 == r2 + 1 || r1 == r2 - 1);
        bool isHorizontalNeighbor = r1 == r2 && (c1 == c2 + 1 || c1 == c2 - 1);
        require(
            isVerticalNeighbor || isHorizontalNeighbor,
            "Given points are not neighbors"
        );
        _;
    }

    /*
     * Asserts that <amount> troops are available to be moved from tile <t>. 
     */
    modifier sufficientResources(Tile memory t, uint256 amount) {
        require(
            amount <= t.numTroops,
            "Insufficient number of troops at the tile"
        );
        _;
    }
}
