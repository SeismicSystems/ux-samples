/*
 * [SPDX-License-Identifier: MIT]
 *
 * Game loop introduced in original.sol with fog of war added via Seismic's 
 * construction. Logic should look fairly similar with some shuffling around of
 * data types and extra functions for conditional reveals.
 *
 */
pragma solidity ^0.8.0;

contract NetworkStates {

    /*
     * We introduce a new data type <suint>. Every number of type suint will be 
     * shielded on-chain (only readable to some parties). The bound for these 
     * numbers are a bit smaller than uint256's because they need to be put into 
     * ZK circuits. 
     *
     * These <suint> variables are represented as hiding commitments on-chain. 
     * The pre-images of these variables are stored with shielding providers 
     * and can be fetched via auxiliary functions.
     *
     * The below structs only include suint values now due to how Network States 
     * works, but suint variables and uint256 variables are typically free to 
     * mix and match within a single struct. 
     *
     * Any struct with an suint variable has an implicit <owner> attribute, the 
     * address of the last wallet to edit it. The outermost struct is what 
     * carries this owner attribute. Below, the Location struct does not have a 
     * separate owner from Tile. In a sense, the layering is just syntactic
     * sugar to add two suint attributes <r> and <c> to a Tile. 
     *
     * You can no longer index on <r> and <c> since they are of type suint 
     * (otherwise you'd leak information). For these cases, where the natural
     * index of a data structure is a shielded variable, you can instead store 
     * them in an unordered set (we implement using a map behind the scenes). 
     * The indices (<r> and <c>) can be included as attributes in the object
     * itself now.
     *
     * There's a new reserved word here called <virt>. This is used whenever 
     * the state of your protocol needs to be initialized. We need that in this
     * case because unowned tiles exist even before anyone moves onto them. 
     * The <virt> word next to <loc> below initializes unowned Tiles with 0
     * resources at every (<r>, <c>).
     *
     */
    struct Location {
        suint r,
        suint c
    }
    struct Tile {
        suint resources;
        Location virt loc;
    }
    Tile{} tiles;

    /*
     * Tracks whether some address has paid the buy-in to spawn. 
     */
    mapping(address => bool) spawnPaymentTracker;

    /*
     * Store latest spawn coordinate queried by address. Only used for 
     * auxiliary function, so does not have corresponding on-chain 
     * representation.
     */
    mapping(address => Location) spawnCoord;

    /*
     * Players now need to request to spawn prior to actually spawning. Prevents
     * sybil attacks where a malicious party spins up infinite wallets to feign
     * spawning at every Tile.
     */
    function requestSpawn() external payable sentSpawnEth() {
        spawnPaymentTracker[msg.sender] = true;
    }

    /*
     * Spawns player at the <landing> Tile by consuming (invalidating) its old
     * value and replacing it with a new Tile with 10 resources owned by the
     * player.
     */
    function spawn(Tile consume landing) external {
        Tile memory updatedLanding = Tile({
            resources: 10,
            loc: Location({r: landing.r, c: landing.c})
        });
        tiles.insert(updatedLanding)
    }

    /*
     * To move is to transfer troops from one tile (the "from" tile) to a 
     * neighboring tile (the "to" tile) by consuming the old values of both 
     * tiles and replacing them with the updated values after running the 
     * conquering logic.
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
            // Moving onto an unowned tile captures it
            updatedTo.owner = msg.sender;
            updatedTo.numTroops = amount;
        } else if (to.owner != msg.sender) {
            // Moving onto an enemy tile leads to a battle
            if (amount > to.numTroops) {
                // You conquer the enemy tile if you bring more troops than 
                // they currently have on there
                updatedTo.owner = msg.sender;
                updatedTo.numTroops = amount - to.numTroops;
            } else {
                // You do not conquer the enemy tile if you have less
                updatedTo.numTroops -= amount;
            }
        } else {
            // Moving onto an owned tile is additive
            updatedTo.numTroops += amount;
        }
        updatedFrom.numTroops -= amount;
        
        tiles.insert(updatedFrom);
        tiles.insert(updatedTo);
    }

    /*
     * Auxiliary functions are can call find() on data structures with shielded 
     * variables. It searches over pre-images stored with the shielding 
     * provider and returns an array of all objects that satisfy the input
     * function. 
     *
     * This auxiliary function is used for fetching a candidate spawn Tile. As
     * with all auxiliary functions, must be <view>.
     */
    function getTileSpawn(suint spawnR, suint spawnC) 
        view 
        eligibleForLanding() 
    {
        // Currently a linear scan, but can open up API for advanced users for
        // custom data structures + search algorithms. 
        Tile result[] = tiles.find((t) => t.r == spawnR && tiles.c == spawnC);
        require(
            result.length === 1,
            "Requested location doesn't have unique match."
        )
        return result[0];
    }

    /*
     * Auxiliary function for fetching a Tile that neighbors the player's state.
     * Access is gated via owning an anchor Tile that is next to the requested
     * Tile. 
     *
     * Auxiliary functions cannot consume anchor Tile since it's a view
     * function (you wouldn't want to anyway).
     */
    function getNeighbor(Tile memory anchor, suint query) 
        view 
        isNeighbor(anchor.r, anchor.c, queryR, queryC) 
        isOwnedBySender(anchor)
        returns(Tile memory) 
    {
        return fetchUniqueLoc(query);
    }

    function fetchUniqueLoc(Location loc) internal view {
        Tile result[] = tiles.find((t) => t.r == loc.r  && t.c == loc.c)
        require(
            result.length === 1,
            "Requested location doesn't have unique match."
        )
        return result[0];
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
     * Players are only eligible to request for a spawn tile if they 1) have 
     * bought in at a previous block and 2) either hasn't requested a 
     * spawn tile before or was previously given a spawn tile that is still 
     * unowned. 
     */
    modifier eligibleForLanding() {
        require(
            spawnPaymentTracker[msg.sender],
            "Must request to spawn prior to receiving a landing Tile"
        );

        bool isPreInit = spawnCoord[msg.sender].r == 0 &&
                           spawnCoord[msg.sender].c == 0;
        Tile currentSpawn = fetchUniqueLoc(spawnCoord[msg.sender])
        require(
            isPreInit || (currentSpawn.owner == address(0)),
            "Previously requested spawn tile still valid"
        );
        _;
    }

    /*
     * Assert that a tile <t> is owned by the tx sender.
     */
    modifier isOwnedBySender(Tile memory t) {
        require(
            t.owner == msg.sender,
            "Tile must be owned by sender"
        );
        _;
    }

    /*
     * Assert that tx was sent with 0.01 ETH.
     */
    modifier sentSpawnEth() {
        require(
            msg.value == 0.01 ether,
            "Must send 0.01 ETH with the spawn request"
        );
        _;
    }

    /*
     * Assert that a tile <t> contains enough troops to move <amount> off.
     */
    modifier sufficientResources(
        Tile memory t,
        uint256 amount
    ) {
        require(
            amount <= t.resources,
            "Insufficient number of troops at the tile"
        );
        _;
    }
}
