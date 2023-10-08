/*
 * [TODO]
 */
pragma solidity ^0.8.0;

contract NetworkStates {

    /*
     * - owner is a reserved attribute of any sstruct
     * - sstructs must be stored in unordered set, so location must be an 
     *   attribute
     * - sstructs can only have members variables of type suint
     */
    sstruct Tile {
        suint resources;
        suint x;
        suint y;
    }

    /*
     * - any variable that interacts with suint must also be suint
     * - sstructs in unordered set
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

        tiles.insert(Tile({
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
    function query(suint xQ, suint yQ, suint xA, suint yA) view 
        returns(Tile memory) {

        // linear scan rn, can improve 
        Tile memory tQ = tiles.find((t) => t.x == xQ  && t.y == yQ);
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
     * - nothing changes
     */
    modifier isOwnedBySender(uint256 x, uint256 y) {
        require(grid[x][y].owner == msg.sender, "Tile not owned by sender");
        _;
    }

    function move(
        uint256 fromX,
        uint256 fromY,
        uint256 toX,
        uint256 toY,
        uint256 amount
    ) external isOwnedBySender(fromX, fromY) {
        require(
            amount <= grid[fromX][fromY].resources,
            "Not enough resources"
        );

        require(
            (fromX == toX && (fromY == toY + 1 || fromY == toY - 1)) ||
                (fromY == toY && (fromX == toX + 1 || fromX == toX - 1)),
            "Not an adjacent tile"
        );

        if (grid[toX][toY].owner == address(0)) {
            // Moving onto an unowned tile
            grid[toX][toY].owner = msg.sender;
            grid[toX][toY].resources = amount;
            grid[fromX][fromY].resources -= amount;
        }
        else if (grid[toX][toY].owner != msg.sender) {
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
