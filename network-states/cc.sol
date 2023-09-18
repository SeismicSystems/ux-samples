/*
 * [TODO]
 */
pragma solidity ^0.8.0;

contract NetworkStates {
    /*
     * Stores relevant values for one cell on the grid. Information stored here
     * is shielded from unauthorized parties.
     */
    shield struct Tile {
        saddress owner;
        suint resources;
    }

    /*
     * Game state represented as a 20x20 grid of shielded tiles. Defaults to 
     * capacity of 2^32 lifetime modifications to grid. 
     */
    suint constant GRID_SIZE = 20;
    Tile[GRID_SIZE][GRID_SIZE] shield grid;

    /*
     * Spawn player onto the grid with 10 troops.
     */
    function spawn(suint x, suint y) external {
        grid[x][y].owner = shield(msg.sender);
        grid[x][y].resources = 10;
    }

    /*
     * Check if tile is owned by sender.
     */
    modifier isOwnedBySender(suint x, suint y) {
        require(grid[x][y].owner == shield(msg.sender), 
            "Tile not owned by sender");
        _;
    }

    /*
     * Move troops at a tile to a neighboring tile.
     */
    function move(
        suint fromX,
        suint fromY,
        suint toX,
        suint toY,
        suint amount
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

        if (grid[toX][toY].owner == shield(address(0))) {
            // Moving onto an unowned tile
            grid[toX][toY].owner = shield(msg.sender);
            grid[toX][toY].resources = amount;
            grid[fromX][fromY].resources -= amount;
        }
        else if (grid[toX][toY].owner != shield(msg.sender)) {
            // Moving onto an enemy tile
            if (amount > grid[toX][toY].resources) {
                // Conquered successfully
                grid[toX][toY].owner = shield(msg.sender);
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

    /*
     * Players now need to query for the state of a tile at (xQ, yQ). Permission
     * to view is gated by owning an adjacent tile (xA, yA).
     */
    function query(suint xQ, suint yQ, suint xA, suint yA) view 
        returns(Tile memory) {

        require(
            grid[xA][yA].owner == shield(msg.sender), 
            "Sender doesn't own claimed tile"
        );

        require(
            isNeighbor(xQ, yQ, xA, yA), 
            "Claimed tile is not adjacent to query target"
        );

        return grid[xQ][yQ];
    }

    /*
     * Whether (x2, y2) is a neighbor of (x1, y1). Concretely, this means that
     * (x2, y2) is in the 3x3 grid centered at (x1, y1). 
     */
    function isNeighbor(uint8 x1, uint8 y1, uint8 x2, uint8 y2) pure 
        returns(bool) {
            
        uint8 dx = x1 > x2 ? x1 - x2 : x2 - x1;
        uint8 dy = y1 > y2 ? y1 - y2 : y2 - y1;

        return dx <= 1 && dy <= 1;
    }
}
