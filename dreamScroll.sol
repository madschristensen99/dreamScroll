// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Dreamscroll is ERC721, Ownable {
    using Strings for uint256;
    
    uint256 private _nextMovieId;
    uint256 private _nextSeriesId;

    struct Movie {
        string prompt;
        string link;
        address creator;
        address producer;
        uint256 seriesId;
        uint256 sequenceNumber;
        uint256 likes;
    }

    struct Comment {
        address commenter;
        string content;
        uint256 timestamp;
    }

    struct Series {
        string name;
        address creator;
        address producer;
        uint256[] movieIds;
        mapping(uint256 => string[]) userChoices;
        bool isActive;
    }

    mapping(uint256 => Movie) public movies;
    mapping(uint256 => Series) public series;
    mapping(address => uint256[]) public creatorMovies;
    mapping(uint256 => Comment[]) public movieComments;
    mapping(uint256 => mapping(address => bool)) public hasLiked;
    mapping(address => uint256[]) public videosSeenByUser;
    mapping(address => mapping(uint256 => bool)) public hasSeenVideo;

    event MovieCreated(uint256 indexed movieId, address creator, string prompt, uint256 seriesId, uint256 sequenceNumber);
    event MovieLinkUpdated(uint256 indexed movieId, string newLink);
    event SeriesCreated(uint256 indexed seriesId, address creator, string name);
    event UserChoiceMade(uint256 indexed seriesId, uint256 sequenceNumber, string choice);
    event SeriesEnded(uint256 indexed seriesId);
    event MovieLiked(uint256 indexed movieId, address liker);
    event CommentAdded(uint256 indexed movieId, address commenter, string content);
    event VideoSeen(uint256 indexed movieId, address viewer);
    event ProducerAssigned(uint256 indexed movieId, address producer);

    constructor() ERC721("Dreamscroll", "DREAM") Ownable(msg.sender) {}

    function createSeries(string memory name) public returns (uint256) {
        uint256 newSeriesId = _nextSeriesId++;
        Series storage newSeries = series[newSeriesId];
        newSeries.name = name;
        newSeries.creator = msg.sender;
        newSeries.producer = address(0);
        newSeries.isActive = true;
        emit SeriesCreated(newSeriesId, msg.sender, name);
        return newSeriesId;
    }

    function createMovie(string memory prompt, uint256 seriesId) public returns (uint256) {
        if (seriesId == type(uint256).max) {
            seriesId = createSeries(string(abi.encodePacked("Series for Movie ", _nextMovieId.toString())));
        }
        require(series[seriesId].creator == msg.sender, "Not series creator");
        require(series[seriesId].isActive, "Series is not active");
    
        uint256 newMovieId = _nextMovieId++;
        uint256 sequenceNumber = series[seriesId].movieIds.length;
        series[seriesId].movieIds.push(newMovieId);

        _safeMint(msg.sender, newMovieId);

        movies[newMovieId] = Movie(prompt, "", msg.sender, address(0), seriesId, sequenceNumber, 0);
        creatorMovies[msg.sender].push(newMovieId);
    
        emit MovieCreated(newMovieId, msg.sender, prompt, seriesId, sequenceNumber);

        return newMovieId;
    }

    function createMovieWithNewSeries(string memory prompt, string memory seriesName) public returns (uint256) {
        uint256 newSeriesId = createSeries(seriesName);
        return createMovie(prompt, newSeriesId);
    }

    function updateMovieLink(uint256 movieId, string memory newLink) public {
        require(_exists(movieId), "Movie does not exist");
        movies[movieId].link = newLink;
        movies[movieId].producer = msg.sender;
        
        uint256 seriesId = movies[movieId].seriesId;
        if (seriesId != type(uint256).max) {
            series[seriesId].producer = msg.sender;
        }
        
        emit MovieLinkUpdated(movieId, newLink);
        emit ProducerAssigned(movieId, msg.sender);
    }

    function makeUserChoice(uint256 seriesId, string memory choice, uint256 sequenceNumber) public {
        require(series[seriesId].creator == msg.sender, "Not series creator");
        require(series[seriesId].isActive, "Series is not active");
        require(series[seriesId].movieIds.length > 0, "No movies in the series");

        uint256 latestSequenceNumber = series[seriesId].movieIds.length - 1;
    
        if (sequenceNumber == 0 && latestSequenceNumber > 0) {
            sequenceNumber = latestSequenceNumber;
        }

        require(sequenceNumber <= latestSequenceNumber, "Invalid sequence number");

        series[seriesId].userChoices[sequenceNumber].push(choice);
        emit UserChoiceMade(seriesId, sequenceNumber, choice);
    }

    function endSeries(uint256 seriesId) public {
        require(series[seriesId].creator == msg.sender || series[seriesId].producer == msg.sender, "Not authorized to end series");
        require(series[seriesId].isActive, "Series is already ended");
        series[seriesId].isActive = false;
        emit SeriesEnded(seriesId);
    }

    function likeMovie(uint256 movieId) public {
        require(_exists(movieId), "Movie does not exist");
        require(!hasLiked[movieId][msg.sender], "Already liked this movie");
        
        movies[movieId].likes++;
        hasLiked[movieId][msg.sender] = true;
        emit MovieLiked(movieId, msg.sender);
    }

    function addComment(uint256 movieId, string memory content) public {
        require(_exists(movieId), "Movie does not exist");
        require(bytes(content).length > 0, "Comment cannot be empty");
        
        Comment memory newComment = Comment({
            commenter: msg.sender,
            content: content,
            timestamp: block.timestamp
        });
        
        movieComments[movieId].push(newComment);
        emit CommentAdded(movieId, msg.sender, content);
    }

    function getMovie(uint256 movieId) public view returns (string memory, string memory, address, address, uint256, uint256, uint256) {
        require(_exists(movieId), "Movie does not exist");
        Movie storage movie = movies[movieId];
        return (movie.prompt, movie.link, movie.creator, movie.producer, movie.seriesId, movie.sequenceNumber, movie.likes);
    }

    function getSeriesMovies(uint256 seriesId) public view returns (uint256[] memory) {
        return series[seriesId].movieIds;
    }

    function getUserChoices(uint256 seriesId, uint256 sequenceNumber) public view returns (string[] memory) {
        return series[seriesId].userChoices[sequenceNumber];
    }
    
    function getAllSeriesChoices(uint256 seriesId) public view returns (string[][] memory) {
        require(series[seriesId].movieIds.length > 0, "No movies in the series");

        uint256 movieCount = series[seriesId].movieIds.length;
        string[][] memory allChoices = new string[][](movieCount);

        for (uint256 i = 0; i < movieCount; i++) {
            allChoices[i] = series[seriesId].userChoices[i];
        }

        return allChoices;
    }

    function getCreatorMovies(address creator) public view returns (uint256[] memory) {
        return creatorMovies[creator];
    }

    function isSeriesActive(uint256 seriesId) public view returns (bool) {
        return series[seriesId].isActive;
    }

    function getMovieLikes(uint256 movieId) public view returns (uint256) {
        require(_exists(movieId), "Movie does not exist");
        return movies[movieId].likes;
    }

    function getMovieComments(uint256 movieId) public view returns (Comment[] memory) {
        require(_exists(movieId), "Movie does not exist");
        return movieComments[movieId];
    }

    function markVideoAsSeen(uint256 movieId) public {
        require(_exists(movieId), "Movie does not exist");
        require(!hasSeenVideo[msg.sender][movieId], "Video already marked as seen");

        videosSeenByUser[msg.sender].push(movieId);
        hasSeenVideo[msg.sender][movieId] = true;
        emit VideoSeen(movieId, msg.sender);
    }

    function getVideosSeenByUser(address user) public view returns (uint256[] memory) {
        return videosSeenByUser[user];
    }

    function hasUserSeenVideo(address user, uint256 movieId) public view returns (bool) {
        return hasSeenVideo[user][movieId];
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
    
    function getNextUnwatchedMovie(address user) public view returns (uint256) {
        uint256 latestValidMovie = type(uint256).max;
        uint256 latestValidSeriesMovie = type(uint256).max;
    
        // Iterate backwards from most recent movies
        for (uint256 i = _nextMovieId; i > 0; i--) {
            uint256 movieId = i - 1;
        
            // Skip if movie doesn't exist or user has seen it
            if (!_exists(movieId) || hasSeenVideo[user][movieId]) {
                continue;
            }
        
            // Skip if movie doesn't have a link
            if (bytes(movies[movieId].link).length == 0) {
                continue;
            }
        
            // If this is a series movie
            if (movies[movieId].seriesId != type(uint256).max) {
                // Check if series is active
                if (series[movies[movieId].seriesId].isActive) {
                    // For series, we want the earliest unwatched episode
                    uint256 seriesId = movies[movieId].seriesId;
                    uint256[] memory seriesMovies = series[seriesId].movieIds;
                
                    // Find the first unwatched episode in this series
                    for (uint256 j = 0; j < seriesMovies.length; j++) {
                        uint256 episodeId = seriesMovies[j];
                        if (!hasSeenVideo[user][episodeId] && 
                            bytes(movies[episodeId].link).length > 0) {
                            latestValidSeriesMovie = episodeId;
                            // Break as we want the first unwatched episode
                            break;
                        }
                    }
                
                    // If we found a valid series movie, we can stop searching
                    if (latestValidSeriesMovie != type(uint256).max) {
                        break;
                    }
                }
            } else {
                // For non-series movies, just take the most recent unwatched one
                if (latestValidMovie == type(uint256).max) {
                    latestValidMovie = movieId;
                }
            }
        }
    
        // Prefer series content over standalone movies
        if (latestValidSeriesMovie != type(uint256).max) {
            return latestValidSeriesMovie;
        }
    
        // Fall back to standalone movie if no series content is available
        if (latestValidMovie != type(uint256).max) {
            return latestValidMovie;
        }
    
        // If no valid movies found, revert
        revert("No unwatched movies available");
    }
}
