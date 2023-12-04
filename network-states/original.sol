/*
 * [SPDX-License-Identifier: MIT]
 * 
 * A demo for Network States without fog of war. 
 */
pragma solidity ^0.8.0;

contract NetworkStates {
    struct Tile {
        address owner;
        uint256 numTroops;
    }

    mapping(uint256 => mapping(uint256 => Tile)) public tiles;

    // users can pick where they spawn
    function spawn(Tile memory landing) public {
        require(
            landing.owner == address(0),
            "Cannot spawn onto an owned tile"
        );
        landing.numTroops = 10;
        landing.owner = msg.sender;
    }

    modifier isOwnedBySender(Tile memory t) {
        require(
            t.owner == msg.sender,
            "Tile must be owned by sender of the tx"
        );
        _;
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

    modifier sufficientResources(
        Tile memory t,
        uint256 amount
    ) {
        require(
            amount >= t.numTroops,
            "Insufficient number of troops at the tile"
        );
        _;
    }

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
            // moving onto unowned tile
            to.owner = msg.sender;
            to.numTroops = amount;
        } else if (to.owner != msg.sender) {
            // moving onto enemy tile
            if (amount > to.numTroops) {
                // conquer tile
                to.owner = msg.sender;
                to.numTroops = amount - to.numTroops;
            } else {
                // did not conquer tile
                to.numTroops -= amount;
            }
        } else {
            // moving onto own tile
            to.numTroops += amount;
        }
        from.numTroops -= amount;
    }
}
