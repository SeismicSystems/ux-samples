pragma solidity ^0.8.0;

contract NetworkStates {
    struct Tile {
        address owner;
        uint256 resources;
    }

    uint256 constant GRID_SIZE = 20;
    Tile[GRID_SIZE][GRID_SIZE] public tiles;

    function spawn(uint256 x, uint256 y) external {
        tiles[y][x].owner = msg.sender;
        tiles[y][x].resources = 10;
    }

    modifier isOwnedBySender(uint256 x, uint256 y) {
        require(tiles[y][x].owner == msg.sender, "Tile not owned by sender");
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
            amount <= tiles[fromY][fromX].resources,
            "Not enough resources"
        );

        require(
            (fromX == toX && (fromY == toY + 1 || fromY == toY - 1)) ||
                (fromY == toY && (fromX == toX + 1 || fromX == toX - 1)),
            "Not an adjacent tile"
        );

        if (tiles[toY][toX].owner == address(0)) {
            tiles[toY][toX].owner = msg.sender;
            tiles[toY][toX].resources = amount;
            tiles[fromY][fromX].resources -= amount;
        }
        else if (tiles[toY][toX].owner != msg.sender) {
            if (amount > tiles[toY][toX].resources) {
                tiles[toY][toX].owner = msg.sender;
                tiles[toY][toX].resources = amount - tiles[toY][toX].resources;
            } else {
                tiles[toY][toX].resources -= amount;
            }
            tiles[fromY][fromX].resources -= amount;
        }
        else {
            tiles[toY][toX].resources += amount;
            tiles[fromY][fromX].resources -= amount;
        }
    }
}