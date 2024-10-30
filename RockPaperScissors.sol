// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RockPaperScissors {
    enum Move { None, Rock, Paper, Scissors }

    struct Player {
        bytes32 commitment;
        Move move;
        address addr;
    }

    address public owner;
    uint256 public betAmount;
    mapping(address => Player) public players;
    address[] public playerAddresses;

    // Events
    event GameStarted(address indexed player1, address indexed player2, uint256 betAmount);
    event PlayerCommitted(address indexed player);
    event PlayerRevealed(address indexed player, Move move);
    event GameResult(address indexed winner, address indexed loser, string result);

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    modifier onlyPlayers() {
        require(players[msg.sender].addr == msg.sender, "You are not a registered player");
        _;
    }

    constructor(uint256 _betAmount) {
        owner = msg.sender;
        betAmount = _betAmount;
    }

    // Function to register players
    function register() external payable {
        require(playerAddresses.length < 2, "Two players have already registered");
        require(msg.value == betAmount, "Incorrect bet amount");
        require(players[msg.sender].addr != msg.sender, "You are already registered");

        players[msg.sender] = Player({
            commitment: bytes32(0),
            move: Move.None,
            addr: msg.sender
        });
        playerAddresses.push(msg.sender);

        if (playerAddresses.length == 2) {
            emit GameStarted(playerAddresses[0], playerAddresses[1], betAmount);
        }
    }

    // Function to submit the commitment of a move
    function commitMove(bytes32 _commitment) external onlyPlayers {
        require(players[msg.sender].commitment == bytes32(0), "You have already committed your move");
        players[msg.sender].commitment = _commitment;
        emit PlayerCommitted(msg.sender);
    }

    // Function to reveal the move
    function revealMove(Move _move, string calldata _secret) external onlyPlayers {
        require(players[msg.sender].commitment != bytes32(0), "You have not committed your move");
        require(players[msg.sender].move == Move.None, "You have already revealed your move");

        // Verify the hash
        bytes32 hash = keccak256(abi.encodePacked(_move, _secret));
        require(hash == players[msg.sender].commitment, "Hash does not match commitment");

        players[msg.sender].move = _move;
        emit PlayerRevealed(msg.sender, _move);

        // If both players have revealed their moves, determine the winner
        if (players[playerAddresses[0]].move != Move.None && players[playerAddresses[1]].move != Move.None) {
            _determineWinner();
        }
    }

    // Internal function to determine the winner
    function _determineWinner() internal {
        Move move1 = players[playerAddresses[0]].move;
        Move move2 = players[playerAddresses[1]].move;
        address payable player1 = payable(playerAddresses[0]);
        address payable player2 = payable(playerAddresses[1]);

        if (move1 == move2) {
            // Draw, return bets
            player1.transfer(betAmount);
            player2.transfer(betAmount);
            emit GameResult(player1, player2, "Draw");
        } else if (
            (move1 == Move.Rock && move2 == Move.Scissors) ||
            (move1 == Move.Paper && move2 == Move.Rock) ||
            (move1 == Move.Scissors && move2 == Move.Paper)
        ) {
            // Player 1 wins
            player1.transfer(address(this).balance);
            emit GameResult(player1, player2, "Player 1 wins");
        } else {
            // Player 2 wins
            player2.transfer(address(this).balance);
            emit GameResult(player2, player1, "Player 2 wins");
        }

        // Reset the game
        _resetGame();
    }

    // Internal function to reset the game
    function _resetGame() internal {
        delete players[playerAddresses[0]];
        delete players[playerAddresses[1]];
        delete playerAddresses;
    }

    // Function for the owner to withdraw funds (in case the game is stuck)
    function withdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
