# Trackmania Next Predictor Server

A Fastify-based server for the Trackmania Next Predictor plugin that handles saving and managing player split data.

## Features

-   🔐 **Openplanet Authentication**: Secure authentication using Openplanet's auth API
-   🗄️ **MongoDB Integration**: Normalized database schema for efficient data management
-   📊 **Split Management**: Track player checkpoint times and best runs
-   🏆 **Leaderboard Support**: Automatically tracks personal best times
-   🚀 **Fastify Server**: High-performance HTTP server
-   ✅ **TypeScript**: Full type safety throughout the codebase

## Database Schema

The database uses normalized collections:

### Players Collection (`players`)

Stores player information.

-   `accountId`: Openplanet account ID (unique)
-   `displayName`: Player display name
-   `createdAt`, `updatedAt`: Timestamps

### Maps Collection (`maps`)

Stores map information.

-   `mapId`: Trackmania map ID (unique)
-   `createdAt`, `updatedAt`: Timestamps

### Splits Collection (`splits`)

Stores player run data.

-   `playerId`: Reference to player
-   `mapId`: Reference to map
-   `checkpointTimes`: Array of cumulative checkpoint times in milliseconds
-   `totalTime`: Final finish time in milliseconds
-   `isBest`: Whether this is the player's personal best
-   `runDate`: Date of the run
-   `createdAt`, `updatedAt`: Timestamps

## Environment Variables

Create a `.env` file in the `server-src` directory with the following variables:

```bash
# MongoDB Configuration
MONGO_HOST=localhost
MONGO_PORT=27017
MONGO_USERNAME=
MONGO_PASSWORD=
MONGO_DATABASE=predictor

# Openplanet Authentication
OPENPLANET_SECRET=your_unique_plugin_secret_here
OPENPLANET_VALIDATION_URL=https://api.openplanet.dev/auth/validate

# Server Configuration
PORT=3000
HOST=0.0.0.0
```

## Installation

```bash
npm install
```

## Development

```bash
npm run dev
```

## Building

```bash
npm run build
```

## Production

```bash
npm start
```

## API Endpoints

### `POST /splits`

Save a new player split.

**Authentication**: Required (Bearer token)

**Request Body**:

```json
{
	"mapId": "your_map_id",
	"checkpointTimes": [1000, 2000, 3000, 5000],
	"totalTime": 5000,
	"runDate": "2024-01-01T00:00:00.000Z"
}
```

**Response**:

```json
{
	"success": true,
	"data": {
		"id": "split_id",
		"mapId": "your_map_id",
		"checkpointTimes": [1000, 2000, 3000, 5000],
		"totalTime": 5000,
		"isBest": true,
		"runDate": "2024-01-01T00:00:00.000Z"
	}
}
```

### `GET /health`

Health check endpoint.

**Response**:

```json
{
	"status": "ok",
	"timestamp": "2024-01-01T00:00:00.000Z"
}
```

## Authentication

The server automatically handles Openplanet authentication. To get a token:

1. The plugin calls `Auth::GetToken()` to get an intermediate token
2. The token is sent in the `Authorization: Bearer <token>` header
3. The server validates the token with Openplanet's API
4. If valid, the request is authenticated with the player's account ID

## Database Normalization

The database follows normalization principles:

-   **Players** are stored separately to avoid duplication
-   **Maps** are stored separately to avoid duplication
-   **Splits** reference players and maps via ObjectId
-   Indexes are created for efficient queries on player/map combinations

## License

MIT
