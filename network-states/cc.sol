/*
 * [TODO]
 */
pragma solidity ^0.8.0;

contract NetworkStates {

    /*
     * - owner is a reserved attribute of any sstruct
     * - sstructs must be stored in unordered set, so location must be an 
     *   attribute
     * - sstructs can have members variables of type suint, shielded ints
     * - this sstruct only has suint members, but that doesn't always need
     *   to be the case
     */
    sstruct Tile {
        suint resources;
        suint x;
        suint y;
    }

    /*
     * - any variable that interacts with suint must also be suint
     * - sstructs in unordered set
     * - [TODO] need to initialize all 20x20 tiles
     */
    suint constant GRID_SIZE = 20;
    Tile{} tiles;

    /*
     * - must restrict to board size now since not automatically done with 
     *   array indexing
     */
    function spawn(suint x_, suint y_) external {
        require(
            x_ < GRID_SIZE && y_ < GRID_SIZE, 
            "Location out of bounds"
        );

        // insert owner & tile pair to set
        tiles.insert(msg.sender: Tile({
            resources: 10,
            x: x_,
            y: y_,
        }))
    }

    /*
     * - any function that uses find() is a shielded function
     * - shielded functions are sent to Elliptic
     * - any function called by a shielded function is also sent to Elliptic
     */
    function query(Tile Q, suint xA, suint yA) view 
        returns(Tile memory) {

        // linear scan rn, can improve 
        Tile memory tA = tiles.find((t) => t.x == xA  && t.y == yA);

        require(
            tA.owner == msg.sender, 
            "Sender doesn't own claimed tile"
        );

        require(
            isNeighbor(tQ, tA),
            "Claimed tile is not adjacent to query target"
        )

        return tQ;
    }

    /*
     * - open ownership model, owner of each instantiation of sstruct is known
     */
    modifier isOwnedBySender(Tile t) {
        require(t.owner == msg.sender, "Tile not owned by sender");
        _;
    }

    /*
     * - isNeighbor() is called by both shielded & regular funcs, so it's
     *   deployed to both chain & Elliptic
     */
    function move(
        Tile from,
        Tile to,
        suint amount
    ) external isOwnedBySender(fromX, fromY) {
        require(
            amount >= from.resources,
            "Not enough resources"
        );

        require(
            isNeighbor(from, to),
            "Not an adjacent tile"
        );

        if (to.owner == address(0)) {
            // Moving onto an unowned tile
            to.owner = msg.sender;
            to.resources = amount;
            from.resources -= amount;
        }
        else if (to.owner != msg.sender) {
            // Moving onto an enemy tile
            if (amount > grid[toX][toY].resources) {
                // Conquered successfully
                grid[toX][toY].owner = msg.sender;
                grid[toX][toY].resources = amount - grid[toX][toY].resources;
            } else {
                // Not enough to conquer 
                grid[toX][toY].resources -= amount;
            }
            grid[fromX][fromY].resources -= amount;
        }
        else {
            // Moving onto your own tile
            grid[toX][toY].resources += amount;
            grid[fromX][fromY].resources -= amount;
        }
    }
}
