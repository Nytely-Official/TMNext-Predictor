#include "Settings.as"
#include "Database.as"

/**
 * Main Predictor Plugin Namespace
 * 
 * Contains the core prediction logic, UI rendering, and data management
 * for the Trackmania 2020 finish time predictor plugin.
 * 
 * @namespace Predictor
 */
namespace Predictor {
    
    /**
     * Main PredictorCore class that handles all prediction functionality
     * 
     * This class manages:
     * - Race data collection from MLFeedRaceData
     * - Time prediction calculations using various methods
     * - Overlay rendering and user interaction
     * - Settings management and data persistence
     * - DID (Display Information Display) integration
     * 
     * @class PredictorCore
     */
    class PredictorCore {
        // ============================================================================
        // INITIALIZATION STATE
        // ============================================================================
        
        /** Whether the plugin has been successfully initialized */
        private bool isInitialized = false;
        
        /** Current map ID for tracking map changes */
        private string currentMapId = "";
        
        /** Race start time from MLFeedRaceData */
        private uint startTime = 0;
        
        /** Time of the last checkpoint passed */
        private uint lastCheckpointTime = 0;
        
        /** Current checkpoint number (0-based) */
        private int currentCheckpoint = 0;
        
        /** Total number of checkpoints in the current map */
        private int totalCheckpoints = 0;
        
        /** Whether we're currently in a race */
        private bool isInGame = false;
        
        /** Whether the race has started */
        private bool hasStarted = false;
        
        // ============================================================================
        // PREDICTION DATA
        // ============================================================================
        
        /** Predicted finish time in milliseconds */
        private uint predictedTime = 0;
        
        /** Formatted predicted time string (MM:SS.mmm) */
        private string predictedTimeString = "00:00.000";
        
        /** Formatted delta time string (+/-MM:SS.mmm) */
        private string deltaTimeString = "+00:00.000";
        
        /** Array storing checkpoint times for current run */
        private array<uint> checkpointSplits;
        
        /** Array storing best checkpoint times for current map */
        private array<uint> bestSplits;
        
        /** Array storing last completed run for comparison */
        private array<uint> lastRunSplits;
        
        /** Current race time for restart detection */
        private uint currentRaceTime = 0;
        
        /** Current settings tab (0 = General, 1 = Data) */
        private int settingsTab = 0;
        
        /** Array of editable split times for manual editing */
        private array<string> editableSplits;
        
        // ============================================================================
        // WINDOW MANAGEMENT
        // ============================================================================
        
        /** Current position of the overlay window */
        private vec2 overlayPosition = vec2(50, 50);
        /** Whether we've initialized overlay position from settings yet */
        private bool overlayInitialized = false;
        
        /** Current size of the overlay window */
        private vec2 overlaySize = vec2(300, 150);
        
        /** Whether the overlay is currently being dragged */
        private bool isDraggingOverlay = false;
        
        /** Whether the overlay is currently being resized */
        private bool isResizingOverlay = false;
        
        /** Offset from mouse position when dragging started */
        private vec2 dragOffset = vec2(0, 0);
        
        /** Which edge is being resized (0=none, 1=left, 2=right, 3=top, 4=bottom) */
        private int resizeEdge = 0;
        
        // ============================================================================
        // PUBLIC GETTERS FOR DID SUPPORT
        // ============================================================================
        
        /** @returns {string} Current predicted time string */
        string get_PredictedTimeString() const { return predictedTimeString; }
        
        /** @returns {string} Current delta time string */
        string get_DeltaTimeString() const { return deltaTimeString; }
        
        /** @returns {int} Current checkpoint number */
        int get_CurrentCheckpoint() const { return currentCheckpoint; }
        
        /** @returns {int} Total number of checkpoints */
        int get_TotalCheckpoints() const { return totalCheckpoints; }
        
        // ============================================================================
        // UI STATE
        // ============================================================================
        
        /** Font handle for text rendering */
        private nvg::Font font;
        
        /** Database manager for server communication */
        private DatabaseManager@ databaseManager;
        
        /** Server URL fetched from remote config */
        private string serverUrl = "";
        
        /** HTTP request for fetching config */
        private Net::HttpRequest@ configRequest = null;
        
        /** Whether config fetch is in progress */
        private bool fetchingConfig = false;
        
        /** Whether config has been successfully loaded */
        private bool configLoaded = false;
        
        /** Whether server splits are being used */
        private bool serverSplitsEnabled = false;
        
        /** Array storing server-sourced best checkpoint times for current map */
        private array<uint> serverBestSplits;
        
        /** Whether server splits are currently being fetched */
        private bool fetchingServerSplits = false;

        /**
         * Initialize the predictor plugin
         * 
         * Sets up fonts, reserves memory for checkpoint data, and registers
         * DID providers if available. This method should be called once
         * when the plugin is loaded.
         * 
         * @method Initialize
         */
        void Initialize() {
            if (isInitialized) return;
            
            // Load the font for text rendering
            font = nvg::LoadFont("DroidSans.ttf");
            
            // Reserve space for checkpoint data arrays
            checkpointSplits.Resize(100);
            bestSplits.Resize(100);
            
            // Initialize database manager
            @databaseManager = InitializeDatabase();
            
            // Fetch remote config for API URL
            FetchRemoteConfig();
            
#if DEPENDENCY_DID
            // Register DID providers for external overlay integration
            DID::registerLaneProviderAddon(PredictorProvider());
            DID::registerLaneProviderAddon(PredictorDeltaProvider());
            DID::registerLaneProviderAddon(PredictorCheckpointProvider());
#endif
            
            isInitialized = true;
            print("Predictor initialized successfully");
        }

        /**
         * Set the authentication token for the database manager
         * 
         * @method SetDatabaseAuthToken
         * @param {string} token - The authentication token
         */
        void SetDatabaseAuthToken(const string &in token) {
            if (databaseManager !is null) databaseManager.SetAuthToken(token);
        }

        /**
         * Get the authentication token for the database manager
         * 
         * @method GetDatabaseAuthToken
         * @returns {string} The authentication token
         */
        string GetDatabaseAuthToken() {
            if (databaseManager !is null) return databaseManager.GetAuthToken();
            return "";
        }

        /**
         * Authenticate with the backend server by exchanging the Openplanet token
         * for a reusable JWT issued by our server.
         *
         * This method must be called from a coroutine (startnew) so it can yield
         * while waiting for async operations to finish.
         *
         * @returns {bool} True when authentication succeeds
         */
        bool AuthenticateWithServer() {
            if (databaseManager is null) return false;
            if (databaseManager.GetAuthToken().Length > 0) return true;

            // Wait for remote config fetch to complete so we know the server URL
            while (fetchingConfig) yield();

            if (!configLoaded || serverUrl.Length == 0) {
                if (!fetchingConfig) FetchRemoteConfig();
                print("Predictor: server configuration unavailable, retrying soon...");
                return false;
            }

            if (!IsPredictorServerHealthy()) return false;

            print("Predictor: requesting Openplanet token for server authentication...");
            auto tokenTask = Auth::GetToken();
            while (!tokenTask.Finished()) yield();

            string openplanetToken = tokenTask.Token();
            if (openplanetToken.Length == 0) {
                print("Predictor: received empty Openplanet token");
                return false;
            }

            return ExchangeOpenplanetToken(openplanetToken);
        }

        /**
         * Fetch remote configuration from Openplanet plugin config endpoint
         * 
         * Retrieves the API URL from the plugin's configuration server
         * 
         * @method FetchRemoteConfig
         * @private
         */
        private void FetchRemoteConfig() {
            if (fetchingConfig) return;
            
            fetchingConfig = true;
            @configRequest = Net::HttpRequest();
            configRequest.Method = Net::HttpMethod::Get;
            configRequest.Url = "https://openplanet.dev/plugin/predictor/config/config";
            configRequest.Start();
            
            print("Fetching remote config...");
        }

        /**
         * Check if the config fetch has completed
         * 
         * @method CheckConfigFetch
         * @private
         */
        private void CheckConfigFetch() {
            // If the config fetch is not in progress or the config request is null, return
            if (!fetchingConfig || configRequest is null) return;
            
            // If the config request is not finished, return
            if (!configRequest.Finished()) return;

            // Set the fetching config to false
            fetchingConfig = false;

            // If the config request is not successful, return
            bool success = configRequest.ResponseCode() >= 200 && configRequest.ResponseCode() < 300;

            // If the config request is not successful, return
            if (!success) {
                // Log the error
                print("Failed to fetch remote config: " + configRequest.ResponseCode());

                // Set the config request to null
                @configRequest = null;

                // Set the config loaded to false
                configLoaded = false;

                // Return
                return;
            }

            // Get the response body
            Json::Value responseBody = configRequest.Json();

            // Set the server url
            serverUrl = responseBody["apiUrl"];

            // Log the server url
            print("Server URL: " + serverUrl);

            // Set the config loaded to true
            configLoaded = true;
        }

        /**
         * Exchange the Openplanet token for a backend-issued JWT
         *
         * @param openplanetToken The single-use Openplanet authentication token
         * @returns {bool} True if the exchange succeeded
         * @private
         */
        private bool ExchangeOpenplanetToken(const string &in openplanetToken) {
            string authUrl = BuildServerUrl("auth");
            if (authUrl.Length == 0) return false;

            Net::HttpRequest@ authRequest = Net::HttpRequest();
            authRequest.Method = Net::HttpMethod::Post;
            authRequest.Url = authUrl;
            authRequest.Headers.Set("Content-Type", "application/json");
            authRequest.Body = "{\"openplanetToken\":\"" + openplanetToken + "\"}";
            authRequest.Start();

            while (!authRequest.Finished()) yield();

            bool success = authRequest.ResponseCode() >= 200 && authRequest.ResponseCode() < 300;
            if (!success) {
                string responseBody = authRequest.String();
                print("Predictor: server auth failed (" + authRequest.ResponseCode() + "): " + responseBody);
                return false;
            }

            try {
                Json::Value responseBody = authRequest.Json();
                bool hasToken = responseBody.HasKey("data") && responseBody["data"].HasKey("token");
                if (!hasToken) {
                    print("Predictor: server auth response missing token field");
                    return false;
                }

                string serverToken = responseBody["data"]["token"];
                databaseManager.SetAuthToken(serverToken);
                print("Predictor: server authentication successful");
                return true;
            } catch {
                print("Predictor: failed to parse server auth response JSON");
                return false;
            }
        }

        /**
         * Utility helper that produces a full API URL for a specific endpoint.
         *
         * @param endpoint Relative endpoint name (e.g. "auth")
         * @returns {string} Fully-qualified URL or empty string if serverUrl missing
         * @private
         */
        private string BuildServerUrl(const string &in endpoint) const {
            if (serverUrl.Length == 0) return "";
            string url = serverUrl;
            if (!url.EndsWith("/")) url += "/";
            return url + endpoint;
        }

        /**
         * GET /health on the predictor API before Auth::GetToken(), so we do not
         * hammer Openplanet's auth when our backend is unreachable.
         *
         * @returns {bool} True when health responds with 2xx
         * @private
         */
        private bool IsPredictorServerHealthy() {
            // Build the health URL
            string healthUrl = BuildServerUrl("health");
            if (healthUrl.Length == 0) return false;

            // Create the health request
            Net::HttpRequest@ healthRequest = Net::HttpRequest();
            healthRequest.Method = Net::HttpMethod::Get;
            healthRequest.Url = healthUrl;
            healthRequest.Start();

            // Wait for the health request to finish
            while (!healthRequest.Finished()) yield();

            // Get the response code
            int code = healthRequest.ResponseCode();

            // Check if the response code is 2xx
            bool ok = code >= 200 && code < 300;
            if (!ok) print("Predictor: server health check failed (HTTP " + code + "), skipping Openplanet token request");

            // Return the result
            return ok;
        }

        /**
         * Main update method called every frame
         * 
         * Checks game state, updates race data, and calculates predictions.
         * This is the main loop that keeps the predictor running.
         * 
         * @method Update
         * @param {float} millisecondsSinceLastFrame - Time elapsed since last frame
         */
        void Update(float millisecondsSinceLastFrame) {
            if (!isInitialized) return;

            // Check for config fetch completion
            CheckConfigFetch();
            
            // Update database manager to process pending saves and fetches
            if (databaseManager !is null) {
                databaseManager.UpdateAll();
                
                // Check if server splits fetch completed
                if (fetchingServerSplits) {
                    if (!databaseManager.IsFetching()) {
                        fetchingServerSplits = false;
                        if (databaseManager.GetFetchSuccess()) {
                            Json::Value fetchedData = databaseManager.GetFetchedData();
                            ParseServerSplits(fetchedData);
                        } else {
                            print("Server splits fetch failed: " + databaseManager.GetLastError());
                            // Clear splits since server fetch failed
                            ClearBestSplits();
                        }
                    }
                }
            }
            
            // Check if we're currently in a race
            CheckGameState();
            
            // If we're not in a game, reset the race state
            if (!isInGame) {
                hasStarted = false;
                return;
            }

            // Get latest race data from MLFeedRaceData
            UpdateRaceData();
            
            // Calculate prediction based on current progress
            CalculatePrediction();
        }

        /**
         * Check if we're currently in a valid game state for prediction
         * 
         * Validates that we're in a race (not editor), have a valid playground,
         * and are actually playing. Also checks interface visibility settings.
         * 
         * @method CheckGameState
         * @private
         */
        private void CheckGameState() {
            auto app = GetApp();
            auto playground = cast<CSmArenaClient>(app.CurrentPlayground);
            
            // Check if we have a valid playground and map
            if (playground is null || playground.Arena is null || playground.Map is null) {
                isInGame = false;
                return;
            }

            // Don't run in the editor
            if (app.Editor !is null) {
                isInGame = false;
                return;
            }

            // Check if we have game terminals (players)
            if (playground.GameTerminals.Length <= 0) {
                isInGame = false;
                return;
            }

            auto terminal = playground.GameTerminals[0];
            // Check if we're actually playing (not in menu, etc.)
            if (terminal.UISequence_Current != CGamePlaygroundUIConfig::EUISequence::Playing) {
                isInGame = false;
                return;
            }

            auto player = cast<CSmPlayer>(terminal.GUIPlayer);
            if (player is null) {
                isInGame = false;
                return;
            }

            // Check interface visibility setting
            if (hideWithInterface) {
                if (playground.Interface is null || !UI::IsGameUIVisible()) {
                    isInGame = false;
                    return;
                }
            }

            isInGame = true;
        }

        /**
         * Update race data from MLFeedRaceData
         * 
         * Gets the latest race information including map changes, race starts,
         * checkpoint progress, and total checkpoint count.
         * 
         * @method UpdateRaceData
         * @private
         */
        private void UpdateRaceData() {
            // Get latest race data from MLFeedRaceData
            auto raceData = MLFeed::GetRaceData_V4();
            if (raceData is null) return;

            // Check for map changes
            string mapId = raceData.Map;
            if (mapId != currentMapId) OnMapChange(mapId);
            

            // Get local player data
            auto localPlayer = raceData.LocalPlayer;
            if (localPlayer is null) return;

            // Check if race has started or restarted
            if (localPlayer.StartTime > 0 && (!hasStarted || localPlayer.StartTime != startTime)) OnRaceStart(localPlayer.StartTime, raceData.CPsToFinish);

            // Update checkpoint progress
            int newCheckpoint = localPlayer.CpCount;
            if (newCheckpoint != currentCheckpoint) OnCheckpointPassed(newCheckpoint, localPlayer.StartTime);

            // Update total checkpoints from race data
            totalCheckpoints = raceData.CPsToFinish;
        }

        /**
         * Handle map change event
         * 
         * Resets all race state when entering a new map and loads
         * the best splits for that map.
         * 
         * @method OnMapChange
         * @param {string} mapId - The new map ID
         * @private
         */
        private void OnMapChange(const string &in mapId) {
            currentMapId = mapId;
            hasStarted = false;
            currentCheckpoint = 0;
            startTime = 0;
            lastCheckpointTime = 0;
            
            // Check if server splits should be used
            serverSplitsEnabled = useServerSplits && configLoaded;
            
            // Load best splits for this map from server
            if (serverSplitsEnabled && databaseManager !is null && serverUrl != "") {
                // Fetch server splits
                string type = splitSourceType == SplitSourceType::PersonalBest ? "personalBest" : "globalBest";
                string splitSourceName = splitSourceType == SplitSourceType::PersonalBest ? "Personal Best" : "Global Best";
                print("Fetching " + splitSourceName + " splits from server for map: " + mapId);
                
                if (databaseManager.FetchSplits(mapId, serverUrl, type)) {
                    fetchingServerSplits = true;
                } else {
                    print("Failed to start server splits fetch: " + databaseManager.GetLastError());
                    ClearBestSplits();
                }
            } else {
                // Server splits disabled or not configured
                if (!serverSplitsEnabled) {
                    print("Server splits disabled in settings");
                } else if (databaseManager is null) {
                    print("Database manager not initialized");
                } else if (serverUrl == "") {
                    print("Server URL not configured");
                }
                ClearBestSplits();
            }
        }

        /**
         * Handle race start event
         * 
         * Resets prediction state when a race starts or restarts.
         * 
         * @method OnRaceStart
         * @param {uint} raceStartTime - The race start time
         * @private
         */
        private void OnRaceStart(uint raceStartTime, uint totalCheckpoints) {
            startTime = raceStartTime;
            hasStarted = true;
            currentCheckpoint = 0;
            lastCheckpointTime = 0;
            
            // Reset prediction strings
            predictedTimeString = "00:00.000";
            deltaTimeString = "+00:00.000";
            
            // Reset checkpoint splits array
            for (uint i = 0; i < checkpointSplits.Length; i++) checkpointSplits[i] = 0;
            

            // Resize the best splits and last run splits array to the total number of checkpoints
            bestSplits.Resize(totalCheckpoints + 1);
            checkpointSplits.Resize(totalCheckpoints + 1);
            lastRunSplits.Resize(totalCheckpoints + 1);

            // Log the start of the race
            print("Race started - checkpoint counter reset");
        }

        /**
         * Handle checkpoint passed event
         * 
         * Updates checkpoint data when a new checkpoint is reached and
         * saves best splits if the race is finished.
         * 
         * @method OnCheckpointPassed
         * @param {int} checkpoint - The checkpoint number that was passed
         * @param {uint} raceStartTime - The race start time
         * @private
         */
        private void OnCheckpointPassed(int checkpoint, uint raceStartTime) {
            if (!hasStarted) return;
            
            if (checkpoint > currentCheckpoint) {
                // Get race data to access checkpoint times
                auto raceData = MLFeed::GetRaceData_V4();
                if (raceData is null) return;
                
                auto localPlayer = raceData.LocalPlayer;
                if (localPlayer is null) return;
                
                // Use MLFeedRaceData's checkpoint times
                if (checkpoint < localPlayer.cpTimes.Length) {
                    checkpointSplits[checkpoint] = localPlayer.cpTimes[checkpoint];
                    lastCheckpointTime = localPlayer.cpTimes[checkpoint];
                    currentCheckpoint = checkpoint;
                    
                    // Check if race is finished and save run data
                    if (checkpoint == totalCheckpoints && localPlayer.IsFinished) SaveRunData(currentMapId);
                    
                }
            }
        }

        /**
         * Calculate the predicted finish time
         * 
         * Gets current race time and calculates prediction using the selected method.
         * Also formats the time strings for display.
         * 
         * @method CalculatePrediction
         * @private
         */
        private void CalculatePrediction() {
            if (!hasStarted) {
                predictedTime = 0;
                predictedTimeString = "00:00.000";
                deltaTimeString = "+00:00.000";
                return;
            }

            // Get current race time from MLFeedRaceData
            auto raceData = MLFeed::GetRaceData_V4();
            if (raceData is null) return;
            
            auto localPlayer = raceData.LocalPlayer;
            if (localPlayer is null) return;
            
            uint currentTime = localPlayer.lastCpTime;
            currentRaceTime = currentTime;
            
            // Calculate prediction using selected method
            CalculateStandardPrediction(currentTime);

            // Format time strings for display
            predictedTimeString = FormatTime(predictedTime);
            
            // Calculate delta time if enabled and we have best splits
            if (showDeltaTime && bestSplits.Length > totalCheckpoints) {
                int delta = int(predictedTime) - int(bestSplits[totalCheckpoints]);
                deltaTimeString = FormatDeltaTime(delta);
            }
        }

        /**
         * Route to the appropriate prediction calculation method
         * 
         * @method CalculateStandardPrediction
         * @param {uint} currentTime - Current race time in milliseconds
         * @private
         */
        private void CalculateStandardPrediction(uint currentTime) {
            switch (predictionMethod) {
                case PredictorMethod::LinearExtrapolation:
                    CalculateLinearPrediction(currentTime);
                    break;
                case PredictorMethod::BestSplitsComparison:
                    CalculateBestSplitsPrediction(currentTime);
                    break;
                case PredictorMethod::Hybrid:
                    CalculateHybridPrediction(currentTime);
                    break;
            }
        }

        /**
         * Calculate prediction using linear extrapolation
         * 
         * Assumes constant pace throughout the race based on average time per checkpoint.
         * Simple but not very accurate method.
         * 
         * @method CalculateLinearPrediction
         * @param {uint} currentTime - Current race time in milliseconds
         * @private
         */
        private void CalculateLinearPrediction(uint currentTime) {
            if (currentCheckpoint == 0) {
                predictedTime = currentTime;
                return;
            }

            // Calculate average time per checkpoint
            uint avgTimePerCheckpoint = currentTime / currentCheckpoint;
            
            // Predict remaining time
            uint remainingCheckpoints = totalCheckpoints - currentCheckpoint;
            uint predictedRemainingTime = avgTimePerCheckpoint * remainingCheckpoints;
            
            predictedTime = currentTime + predictedRemainingTime;
        }

        /**
         * Calculate prediction using best splits comparison
         * 
         * Compares current run to personal best checkpoint times for more accurate prediction.
         * Falls back to linear method if no best splits are available.
         * 
         * @method CalculateBestSplitsPrediction
         * @param {uint} currentTime - Current race time in milliseconds
         * @private
         */
        private void CalculateBestSplitsPrediction(uint currentTime) {
            if (bestSplits.Length <= totalCheckpoints) {
                // Fallback to linear if no best splits available
                CalculateLinearPrediction(currentTime);
                return;
            }

            if (currentCheckpoint == 0) {
                predictedTime = bestSplits[totalCheckpoints];
                return;
            }

            // Use best splits to predict
            uint bestTimeToCurrentCheckpoint = bestSplits[currentCheckpoint];
            uint bestTotalTime = bestSplits[totalCheckpoints];
            
            // Calculate how much faster/slower we are compared to best
            // Prevent division by zero
            if (bestTimeToCurrentCheckpoint > 0) {
                float paceRatio = float(currentTime) / float(bestTimeToCurrentCheckpoint);
                predictedTime = uint(float(bestTotalTime) * paceRatio);
            } else {
                // Fall back to linear prediction
                CalculateLinearPrediction(currentTime);
            }
        }

        /**
         * Calculate prediction using hybrid method
         * 
         * Combines linear extrapolation and best splits comparison with weighted average.
         * Uses 70% best splits + 30% linear extrapolation for balanced accuracy.
         * 
         * @method CalculateHybridPrediction
         * @param {uint} currentTime - Current race time in milliseconds
         * @private
         */
        private void CalculateHybridPrediction(uint currentTime) {
            // Calculate linear prediction
            uint linearPrediction = 0;
            if (currentCheckpoint > 0) {
                uint avgTimePerCheckpoint = currentTime / currentCheckpoint;
                uint remainingCheckpoints = totalCheckpoints - currentCheckpoint;
                linearPrediction = currentTime + (avgTimePerCheckpoint * remainingCheckpoints);
            } else {
                linearPrediction = currentTime;
            }
            
            // Calculate best splits prediction
            uint bestSplitsPrediction = 0;
            if (bestSplits.Length > totalCheckpoints && currentCheckpoint > 0) {
                uint bestTimeToCurrentCheckpoint = bestSplits[currentCheckpoint];
                uint bestTotalTime = bestSplits[totalCheckpoints];
                
                // Prevent division by zero
                if (bestTimeToCurrentCheckpoint > 0) {
                    float paceRatio = float(currentTime) / float(bestTimeToCurrentCheckpoint);
                    bestSplitsPrediction = uint(float(bestTotalTime) * paceRatio);
                } else {
                    bestSplitsPrediction = linearPrediction;
                }
            } else {
                bestSplitsPrediction = linearPrediction;
            }
            
            // Weight the predictions (70% best splits, 30% linear)
            predictedTime = uint(0.7 * float(bestSplitsPrediction) + 0.3 * float(linearPrediction));
        }

        /**
         * Format time in milliseconds to MM:SS.mmm or HH:MM:SS.mmm format
         * 
         * @method FormatTime
         * @param {uint} timeMs - Time in milliseconds
         * @returns {string} Formatted time string
         * @private
         */
        private string FormatTime(uint timeMs) {
            uint totalMs = timeMs;
            uint seconds = totalMs / 1000;
            uint minutes = seconds / 60;
            uint hours = minutes / 60;
            
            uint ms = totalMs % 1000;
            seconds = seconds % 60;
            minutes = minutes % 60;
            
            if (hours > 0) {
                string hourStr = hours < 10 ? "0" + hours : "" + hours;
                string minStr = minutes < 10 ? "0" + minutes : "" + minutes;
                string secStr = seconds < 10 ? "0" + seconds : "" + seconds;
                string msStr = ms < 10 ? "00" + ms : (ms < 100 ? "0" + ms : "" + ms);
                return hourStr + ":" + minStr + ":" + secStr + "." + msStr;
            } else {
                string minStr = minutes < 10 ? "0" + minutes : "" + minutes;
                string secStr = seconds < 10 ? "0" + seconds : "" + seconds;
                string msStr = ms < 10 ? "00" + ms : (ms < 100 ? "0" + ms : "" + ms);
                return minStr + ":" + secStr + "." + msStr;
            }
        }

        /**
         * Format delta time with +/- sign
         * 
         * @method FormatDeltaTime
         * @param {int} deltaMs - Delta time in milliseconds (can be negative)
         * @returns {string} Formatted delta time string with sign
         * @private
         */
        private string FormatDeltaTime(int deltaMs) {
            string sign = deltaMs >= 0 ? "+" : "-";
            uint absMs = Math::Abs(deltaMs);
            
            uint seconds = absMs / 1000;
            uint minutes = seconds / 60;
            
            uint ms = absMs % 1000;
            seconds = seconds % 60;
            
            string minStr = minutes < 10 ? "0" + minutes : "" + minutes;
            string secStr = seconds < 10 ? "0" + seconds : "" + seconds;
            string msStr = ms < 10 ? "00" + ms : (ms < 100 ? "0" + ms : "" + ms);
            
            return sign + minStr + ":" + secStr + "." + msStr;
        }

        /**
         * Clear best splits for the current map
         * 
         * @method ClearBestSplits
         * @private
         */
        private void ClearBestSplits() {
            // Clear all best splits
            for (uint i = 0; i < bestSplits.Length; i++) {
                bestSplits[i] = 0;
            }
        }
        
        /**
         * Parse server splits from JSON response
         * 
         * @method ParseServerSplits
         * @param {Json::Value} jsonData - JSON response from server
         * @private
         */
        private void ParseServerSplits(Json::Value jsonData) {
            try {
                // Expected format: {"success":true,"data":[{"checkpointTimes":[...],...}]}
                
                // Check if response has success field
                if (jsonData.HasKey("success")) {
                    bool success = jsonData["success"];
                    if (!success) {
                        throw("Server returned success: false");
                    }
                }
                
                // Get the data array
                if (!jsonData.HasKey("data")) {
                    throw("No data key found");
                }
                
                Json::Value dataArray = jsonData["data"];
                
                if (dataArray.GetType() != Json::Type::Array) {
                    throw("data is not an array");
                }
                
                // Check if array is empty
                uint arrayLength = dataArray.Length;
                
                if (arrayLength == 0) {
                    print("No splits found on server for this map");
                    // Clear best splits
                    ClearBestSplits();
                    return;
                }
                
                // Get the first split
                Json::Value firstSplit = dataArray[0];
                
                // Extract checkpoint times array
                if (!firstSplit.HasKey("checkpointTimes")) {
                    throw("No checkpointTimes key found");
                }
                
                Json::Value cpTimesArray = firstSplit["checkpointTimes"];
                
                if (cpTimesArray.GetType() != Json::Type::Array) {
                    throw("checkpointTimes is not an array");
                }
                
                // Get the length of checkpoint times
                uint cpLength = cpTimesArray.Length;
                
                if (cpLength == 0) {
                    throw("Empty checkpointTimes array");
                }
                
                // Extract checkpoint times from the array
                array<uint> tempSplits;
                tempSplits.Resize(cpLength);
                
                for (uint i = 0; i < cpLength; i++) {
                    Json::Value cpTime = cpTimesArray[i];
                    
                    if (cpTime.GetType() == Json::Type::Number) {
                        tempSplits[i] = uint(cpTime);
                    }
                }
                
                // Copy to server best splits
                serverBestSplits.Resize(cpLength);
                for (uint i = 0; i < cpLength; i++) {
                    serverBestSplits[i] = tempSplits[i];
                }
                
                // Copy server splits to bestSplits for use in predictions
                bestSplits.Resize(serverBestSplits.Length);
                for (uint i = 0; i < serverBestSplits.Length; i++) {
                    bestSplits[i] = serverBestSplits[i];
                }
                
                print("Successfully loaded " + serverBestSplits.Length + " server splits for predictions");
                
            } catch {
                print("Failed to parse server splits");
                // Clear best splits since we couldn't load from server
                ClearBestSplits();
            }
        }

        /**
         * Save run data after finishing
         * 
         * Saves the run to the server (always saves all completed runs)
         * 
         * @method SaveRunData
         * @param {string} mapId - The map ID to save splits for
         * @private
         */
        private void SaveRunData(const string &in mapId) {
            if (currentCheckpoint != totalCheckpoints) return; // Only save if race is finished
            
            // Get final checkpoint times from MLFeedRaceData
            auto raceData = MLFeed::GetRaceData_V4();
            if (raceData is null) return;
            
            auto localPlayer = raceData.LocalPlayer;
            if (localPlayer is null) return;
            
            // Store current run as last run for comparison
            lastRunSplits.Resize(localPlayer.cpTimes.Length);
            for (uint i = 0; i < localPlayer.cpTimes.Length; i++) {
                lastRunSplits[i] = localPlayer.cpTimes[i];
            }
            
            // Save to server if enabled
            if (saveToServer && databaseManager !is null && configLoaded && serverUrl != "") {
                SaveToServer(mapId, localPlayer);
            }
        }
        
        /**
         * Save split data to the server
         * 
         * Converts the current run data into SplitData format and sends it to the server
         * 
         * @method SaveToServer
         * @param {string} mapId - The current map ID
         * @param {MLFeed::PlayerCpInfo_V4@} localPlayer - The local player data with checkpoint times
         * @private
         */
        private void SaveToServer(const string &in mapId, const MLFeed::PlayerCpInfo_V4@ localPlayer) {
            if (localPlayer is null) return;
            
            // Create array of checkpoint times
            array<uint> checkpointTimes;
            checkpointTimes.Resize(localPlayer.cpTimes.Length);
            for (uint i = 0; i < localPlayer.cpTimes.Length; i++) {
                checkpointTimes[i] = localPlayer.cpTimes[i];
            }
            
            // Get the total time (last checkpoint time)
            uint totalTime = checkpointTimes.Length > 0 ? checkpointTimes[checkpointTimes.Length - 1] : 0;
            
            // Create split data
            SplitData@ splitData = SplitData(mapId, checkpointTimes, totalTime, "");
            
            // Save to server (returns true if successful or queued)
            bool success = databaseManager.SaveSplit(splitData, serverUrl);
            if (success) {
                print("Split data queued for server (total time: " + FormatTime(totalTime) + ")");
            } else {
                print("Failed to queue split for server: " + databaseManager.GetLastError());
            }
        }

        /**
         * Main render method for the overlay
         * 
         * Renders the prediction overlay if conditions are met.
         * 
         * @method Render
         */
        void Render() {
            if (!isInGame || !hasStarted) return;
            
            vec2 screenSize = vec2(Draw::GetWidth(), Draw::GetHeight());
            // Initialize overlay position and size from settings once per session (persist across restarts)
            if (!overlayInitialized) {
                // Initialize position from normalized settings
                overlayPosition.x = Math::Clamp(overlayX * screenSize.x, 0.0f, screenSize.x - overlaySize.x);
                overlayPosition.y = Math::Clamp(overlayY * screenSize.y, 0.0f, screenSize.y - overlaySize.y);
                
                // Initialize size from normalized settings
                overlaySize.x = Math::Clamp(overlayWidth * screenSize.x, 200.0f, screenSize.x);
                overlaySize.y = Math::Clamp(overlayHeight * screenSize.y, 100.0f, screenSize.y);
                
                // Ensure position is still valid with new size
                overlayPosition.x = Math::Clamp(overlayPosition.x, 0.0f, screenSize.x - overlaySize.x);
                overlayPosition.y = Math::Clamp(overlayPosition.y, 0.0f, screenSize.y - overlaySize.y);
                
                overlayInitialized = true;
            }
            
            // Render main overlay if enabled
            if (showOverlay) RenderMoveableOverlay(screenSize);
            
        }
        
        /**
         * Draw text with shadow effect
         * 
         * @method DrawTextWithShadow
         * @param {vec2} position - Position to draw text at
         * @param {string} text - Text to draw
         * @param {vec4} textColor - Color of the main text
         * @param {vec4} shadowColor - Color of the shadow
         * @param {float} fontSize - Size of the font
         * @private
         */
        private void DrawTextWithShadow(vec2 position, const string &in text, vec4 textColor, vec4 shadowColor, float fontSize) {
            // Draw shadow
            nvg::FontSize(fontSize);
            nvg::FillColor(shadowColor);
            nvg::TextBox(position.x + 2, position.y + 2, overlaySize.x * 0.8f, text);
            
            // Draw main text
            nvg::FillColor(textColor);
            nvg::TextBox(position.x, position.y, overlaySize.x * 0.8f, text);
        }
        
        /**
         * Render the moveable and resizable overlay
         * 
         * Handles mouse interaction for dragging and resizing the overlay window.
         * Also renders the background, resize handles, and text content.
         * 
         * @method RenderMoveableOverlay
         * @param {vec2} screenSize - Current screen dimensions
         * @private
         */
        private void RenderMoveableOverlay(vec2 screenSize) {
            // Get mouse input state
            vec2 mousePos = UI::GetMousePos();
            bool mousePressed = UI::IsMouseDown(UI::MouseButton::Left);
            bool mouseClicked = UI::IsMouseClicked(UI::MouseButton::Left);
            
            // Check if mouse is over the overlay area
            bool mouseOverOverlay = (mousePos.x >= overlayPosition.x && 
                                   mousePos.x <= overlayPosition.x + overlaySize.x &&
                                   mousePos.y >= overlayPosition.y && 
                                   mousePos.y <= overlayPosition.y + overlaySize.y);
            
            // Determine resize edge (only when resize/drag is enabled)
            int newResizeEdge = 0;
            if (enableResizeDrag && mouseOverOverlay) {
                float edgeSize = 8.0f;
                bool leftEdge = mousePos.x <= overlayPosition.x + edgeSize;
                bool rightEdge = mousePos.x >= overlayPosition.x + overlaySize.x - edgeSize;
                bool topEdge = mousePos.y <= overlayPosition.y + edgeSize;
                bool bottomEdge = mousePos.y >= overlayPosition.y + overlaySize.y - edgeSize;
                
                if (leftEdge) newResizeEdge = 1; // left
                else if (rightEdge) newResizeEdge = 2; // right
                else if (topEdge) newResizeEdge = 3; // top
                else if (bottomEdge) newResizeEdge = 4; // bottom
            }
            
            // Set cursor based on interaction state
            if (enableResizeDrag) {
                if (newResizeEdge > 0) {
                    if (newResizeEdge == 1 || newResizeEdge == 2) UI::SetMouseCursor(UI::MouseCursor::ResizeEW); 
                    else if (newResizeEdge == 3 || newResizeEdge == 4) UI::SetMouseCursor(UI::MouseCursor::ResizeNS);
                } else if (mouseOverOverlay) {
                    UI::SetMouseCursor(UI::MouseCursor::Hand);
                } else {
                    UI::SetMouseCursor(UI::MouseCursor::Arrow);
                }
            } else {
                UI::SetMouseCursor(UI::MouseCursor::Arrow);
            }
            
            // Handle drag start (only when resize/drag is enabled)
            if (enableResizeDrag && mouseClicked && mouseOverOverlay && newResizeEdge == 0 && !isDraggingOverlay && !isResizingOverlay) {
                isDraggingOverlay = true;
                dragOffset = mousePos - overlayPosition;
            }
            
            // Handle resize start (only when resize/drag is enabled)
            if (enableResizeDrag && mouseClicked && newResizeEdge > 0 && !isDraggingOverlay && !isResizingOverlay) {
                isResizingOverlay = true;
                resizeEdge = newResizeEdge;
            }
            
            // Handle dragging (only when resize/drag is enabled)
            if (enableResizeDrag && isDraggingOverlay && mousePressed) {
                overlayPosition = mousePos - dragOffset;
                // Clamp to screen bounds
                overlayPosition.x = Math::Clamp(overlayPosition.x, 0, screenSize.x - overlaySize.x);
                overlayPosition.y = Math::Clamp(overlayPosition.y, 0, screenSize.y - overlaySize.y);
            } else {
                // Drag ended, persist normalized position to settings so it survives restarts
                if (isDraggingOverlay) {
                    overlayX = Math::Clamp(overlayPosition.x / screenSize.x, 0.0f, 1.0f);
                    overlayY = Math::Clamp(overlayPosition.y / screenSize.y, 0.0f, 1.0f);
                }
                isDraggingOverlay = false;
            }
            
            // Handle resizing (only when resize/drag is enabled)
            if (enableResizeDrag && isResizingOverlay && mousePressed) {
                switch (resizeEdge) {
                    case 1: { // left
                        float newWidth = overlayPosition.x + overlaySize.x - mousePos.x;
                        if (newWidth >= 200.0f) {
                            overlaySize.x = newWidth;
                            overlayPosition.x = mousePos.x;
                        }
                        break;
                    }
                    case 2: { // right
                        float newWidth2 = mousePos.x - overlayPosition.x;
                        if (newWidth2 >= 200.0f) {
                            overlaySize.x = newWidth2;
                        }
                        break;
                    }
                    case 3: { // top
                        float newHeight = overlayPosition.y + overlaySize.y - mousePos.y;
                        if (newHeight >= 100.0f) {
                            overlaySize.y = newHeight;
                            overlayPosition.y = mousePos.y;
                        }
                        break;
                    }
                    case 4: { // bottom
                        float newHeight2 = mousePos.y - overlayPosition.y;
                        if (newHeight2 >= 100.0f) {
                            overlaySize.y = newHeight2;
                        }
                        break;
                    }
                }
                
                // Clamp to screen bounds
                overlayPosition.x = Math::Clamp(overlayPosition.x, 0, screenSize.x - overlaySize.x);
                overlayPosition.y = Math::Clamp(overlayPosition.y, 0, screenSize.y - overlaySize.y);
                overlaySize.x = Math::Clamp(overlaySize.x, 200, screenSize.x - overlayPosition.x);
                overlaySize.y = Math::Clamp(overlaySize.y, 100, screenSize.y - overlayPosition.y);
            } else {
                // Resize ended, persist normalized size to settings so it survives restarts
                if (isResizingOverlay) {
                    overlayWidth = Math::Clamp(overlaySize.x / screenSize.x, 0.1f, 1.0f);
                    overlayHeight = Math::Clamp(overlaySize.y / screenSize.y, 0.1f, 1.0f);
                }
                isResizingOverlay = false;
                resizeEdge = 0;
            }
            
            // Render the overlay content
            vec2 position = overlayPosition + overlaySize * 0.5f;
            
            nvg::FontSize(fontSize);
            nvg::FontFace(font);
            nvg::TextAlign(nvg::Align::Center | nvg::Align::Middle);
            
            // Draw background (show when enabled OR when drag/resize is enabled)
            if (showBackground || enableResizeDrag) {
                nvg::FillColor(backgroundColor);
                nvg::BeginPath();
                nvg::RoundedRect(overlayPosition.x, overlayPosition.y, overlaySize.x, overlaySize.y, 8);
                nvg::Fill();
            }
            
            // Draw resize edge highlights (only when resize/drag is enabled)
            if (enableResizeDrag && newResizeEdge > 0) {
                nvg::FillColor(vec4(0.2, 0.5, 1.0, 0.6)); // Blue with transparency
                nvg::BeginPath();
                
                switch (newResizeEdge) {
                    case 1: // left edge
                        nvg::Rect(overlayPosition.x, overlayPosition.y, 8, overlaySize.y);
                        break;
                    case 2: // right edge
                        nvg::Rect(overlayPosition.x + overlaySize.x - 8, overlayPosition.y, 8, overlaySize.y);
                        break;
                    case 3: // top edge
                        nvg::Rect(overlayPosition.x, overlayPosition.y, overlaySize.x, 8);
                        break;
                    case 4: // bottom edge
                        nvg::Rect(overlayPosition.x, overlayPosition.y + overlaySize.y - 8, overlaySize.x, 8);
                        break;
                }
                nvg::Fill();
            }
            
            // Calculate vertical positioning based on enabled elements
            float currentY = position.y;
            
            // Adjust position based on what elements are shown
            if (showDeltaTime && deltaTimeString != "+00:00.000") currentY -= fontSize * 0.4; // Move up to make room for delta time below
            
            if (showCheckpointSplits && currentCheckpoint > 0) currentY -= fontSize * 0.2; // Move up slightly more for checkpoint info
            
            
            // Draw prediction text with shadow
            DrawTextWithShadow(vec2(position.x - overlaySize.x * 0.4f, currentY), predictedTimeString, textColor, textShadowColor, fontSize);
            
            // Draw delta time if enabled
            if (showDeltaTime && deltaTimeString != "+00:00.000") {
                vec4 deltaColor = deltaTextColor;

                if (deltaTimeString.StartsWith("+")) deltaColor = vec4(0.2, 1.0, 0.2, deltaTextColor.w); // Green for positive 
                else deltaColor = vec4(1.0, 0.2, 0.2, deltaTextColor.w); // Red for negative
                
                
                float deltaY = currentY + fontSize + 10;
                DrawTextWithShadow(vec2(position.x - overlaySize.x * 0.4f, deltaY), deltaTimeString, deltaColor, deltaShadowColor, fontSize * 0.8f);
            }
            
            // Draw checkpoint splits if enabled
            if (showCheckpointSplits && currentCheckpoint > 0) {
                string splitsText = "CP: " + currentCheckpoint + "/" + totalCheckpoints;
                
                float checkpointY = currentY + fontSize + 10;
                if (showDeltaTime && deltaTimeString != "+00:00.000") checkpointY += fontSize * 0.8 + 10; // Add space for delta time
                
                
                DrawTextWithShadow(vec2(position.x - overlaySize.x * 0.4f, checkpointY), splitsText, checkpointTextColor, checkpointShadowColor, fontSize * 0.6f);
            }
        }
        
        /**
         * Render the settings interface
         * 
         * Creates a tabbed interface with General and Data tabs for configuring
         * the predictor settings and editing split times.
         * 
         * @method RenderInterface
         */
        void RenderInterface() {
            if (!showSettingsWindow) return;
            // Create closable settings window
            if (UI::Begin("Predictor Settings", showSettingsWindow)) {
                // Setup the Separator
                UI::Separator();
                
                // Tab buttons
                if (UI::Button("General")) settingsTab = 0;
                
                // Setup the SameLine
                UI::SameLine();

                // Setup the Button
                if (UI::Button("Data")) settingsTab = 1;
                
                // Setup the Separator
                UI::Separator();
                
                // Render appropriate tab content
                if (settingsTab == 0) RenderGeneralSettings();

                // Render the Data tab
                if (settingsTab == 1) RenderDataTab();
                
            }

            // End the window
            UI::End();
        }
        
        /**
         * Render the General settings tab
         * 
         * Provides controls for overlay visibility, colors, prediction methods,
         * and other general configuration options.
         * 
         * @method RenderGeneralSettings
         * @private
         */
        private void RenderGeneralSettings() {
            // Setup the Separator
            UI::Separator();
            
            // Display settings
            showOverlay = UI::Checkbox("Show Overlay", showOverlay);
            hideWithInterface = UI::Checkbox("Hide with Interface", hideWithInterface);
            enableResizeDrag = UI::Checkbox("Enable Resize/Drag", enableResizeDrag);
            showBackground = UI::Checkbox("Show Background", showBackground);
            showDeltaTime = UI::Checkbox("Show Delta Time", showDeltaTime);
            showCheckpointSplits = UI::Checkbox("Show Checkpoint Splits", showCheckpointSplits);
            
            UI::Separator();
            
            // Position and size settings
            overlayX = UI::SliderFloat("X Position", overlayX, 0.0, 1.0);
            overlayY = UI::SliderFloat("Y Position", overlayY, 0.0, 1.0);
            overlayWidth = UI::SliderFloat("Overlay Width", overlayWidth, 0.1, 1.0);
            overlayHeight = UI::SliderFloat("Overlay Height", overlayHeight, 0.1, 1.0);
            fontSize = UI::SliderInt("Font Size", fontSize, 12, 48);
            
            UI::Separator();
            
            // Color settings
            UI::Text("Colors:");
            textColor = UI::InputColor4("Text Color", textColor);
            textShadowColor = UI::InputColor4("Text Shadow Color", textShadowColor);
            backgroundColor = UI::InputColor4("Background Color", backgroundColor);
            
            UI::Separator();
            
            // Delta time colors
            UI::Text("Delta Time Colors:");
            deltaTextColor = UI::InputColor4("Delta Text Color", deltaTextColor);
            deltaShadowColor = UI::InputColor4("Delta Shadow Color", deltaShadowColor);
            
            UI::Separator();
            
            // Checkpoint colors
            UI::Text("Checkpoint Colors:");
            checkpointTextColor = UI::InputColor4("Checkpoint Text Color", checkpointTextColor);
            checkpointShadowColor = UI::InputColor4("Checkpoint Shadow Color", checkpointShadowColor);
            
            UI::Separator();
            
            // Prediction method selection
            UI::Text("Prediction Method:");
            UI::Text("Select one method for time prediction:");
            
            // Linear Extrapolation
            bool linearSelected = (predictionMethod == PredictorMethod::LinearExtrapolation);
            if (UI::Checkbox("Linear Extrapolation", linearSelected)) predictionMethod = PredictorMethod::LinearExtrapolation;
            
            UI::Text("  • Basic prediction based on average time per checkpoint");
            UI::Text("  • Not very accurate - assumes constant pace throughout race");
            UI::Text("  • Works immediately without previous runs");
            
            UI::Separator();
            
            // Best Splits Comparison
            bool bestSplitsSelected = (predictionMethod == PredictorMethod::BestSplitsComparison);
            if (UI::Checkbox("Best Splits Comparison", bestSplitsSelected)) predictionMethod = PredictorMethod::BestSplitsComparison;
            
            UI::Text("  • Uses your personal best checkpoint times for prediction");
            UI::Text("  • Most accurate method when you have previous runs");
            UI::Text("  • IMPORTANT: You need to finish a run first to save best splits");
            UI::Text("  • Falls back to Linear Extrapolation if no best splits available");
            
            UI::Separator();
            
            // Hybrid
            bool hybridSelected = (predictionMethod == PredictorMethod::Hybrid);
            if (UI::Checkbox("Hybrid Method", hybridSelected)) predictionMethod = PredictorMethod::Hybrid;
            
            UI::Text("  • Combines Linear Extrapolation and Best Splits Comparison");
            UI::Text("  • Uses 70% Best Splits + 30% Linear Extrapolation weighting");
            UI::Text("  • Will use the inaccurate Linear prediction if map not finished before");
            UI::Text("  • Provides balanced accuracy between methods");
            
            UI::Separator();
            
            // Database settings
            UI::Text("Database Settings:");
            saveToServer = UI::Checkbox("Save Splits to Server", saveToServer);
            
            UI::Separator();
            
            // Server split settings
            UI::Text("Server Split Settings:");
            useServerSplits = UI::Checkbox("Use Server Splits for Prediction", useServerSplits);
            
            if (useServerSplits) {
                UI::Indent();
                UI::Text("Split Source:");
                
                bool usePersonal = (splitSourceType == SplitSourceType::PersonalBest);
                if (UI::Checkbox("Use Personal Best", usePersonal)) {
                    splitSourceType = SplitSourceType::PersonalBest;
                }
                
                bool useGlobal = (splitSourceType == SplitSourceType::GlobalBest);
                if (UI::Checkbox("Use Global Best", useGlobal)) {
                    splitSourceType = SplitSourceType::GlobalBest;
                }
                
                UI::Unindent();
            }
        }
        
        /**
         * Render the Data tab for manual split editing
         * 
         * Provides interface for manually editing checkpoint times and
         * managing best splits data for the current map.
         * 
         * @method RenderDataTab
         * @private
         */
        private void RenderDataTab() {   
            UI::Separator();
            
            UI::Text("Manual Split Data Editor");
            UI::Text("Edit checkpoint times manually for the current map");
            
            if (totalCheckpoints == 0) {
                UI::Text("No map loaded. Start a race to see checkpoint data.");
                return;
            }
            
            UI::Separator();
            
            // Initialize editable splits if needed
            if (editableSplits.Length != uint(totalCheckpoints + 1)) {
                editableSplits.Resize(uint(totalCheckpoints + 1));
                for (uint i = 0; i <= totalCheckpoints; i++) {
                    if (i < bestSplits.Length) editableSplits[i] = FormatTime(bestSplits[i]);
                    else editableSplits[i] = "00:00.000"; 
                }
            }
            
            // Show editable checkpoint times
            UI::Text("Checkpoint Times (Cumulative):");
            
            bool dataChanged = false;
            
            for (uint i = 1; i <= totalCheckpoints; i++) {
                string cpLabel = (i == totalCheckpoints) ? "Finish:" : ("CP " + i + ":");
                UI::Text(cpLabel);
                UI::SameLine();
                
                if (i == totalCheckpoints) {
                    // Finish time is read-only (auto-calculated)
                    UI::Text(editableSplits[i]);
                } else {
                    string oldTime = editableSplits[i];
                    string newTime = UI::InputText("##cp" + i, editableSplits[i]);
                    if (newTime != editableSplits[i]) {
                        editableSplits[i] = newTime;
                        dataChanged = true;
                        // Update all subsequent checkpoint times to maintain cumulative nature
                        UpdateSubsequentCheckpoints(i, oldTime, newTime);
                    }
                }
            }
            
            UI::Separator();
            
            // Show total time (read-only, auto-calculated)
            UI::Text("Total Time (Auto-calculated):");
            UI::SameLine();
            UI::Text(editableSplits[totalCheckpoints]);
            
            UI::Separator();
            
            // Action buttons
            if (UI::Button("Save Changes")) SaveManualSplits();
            
            UI::SameLine();
            
            if (UI::Button("Reset to Best Splits")) ResetToBestSplits();
            
            UI::SameLine();
            
            if (UI::Button("Clear All")) ClearAllSplits();  
        }
        
        /**
         * Save manually edited splits
         * 
         * Converts string times back to uint values and updates the best splits in memory.
         * Note: This only updates the local prediction data, not server data.
         * 
         * @method SaveManualSplits
         * @private
         */
        private void SaveManualSplits() {
            if (editableSplits.Length <= totalCheckpoints) return;
            
            // Convert string times back to uint and update bestSplits
            bestSplits.Resize(editableSplits.Length);
            
            for (uint i = 0; i < editableSplits.Length; i++) {
                uint timeMs = ParseTimeString(editableSplits[i]);
                bestSplits[i] = timeMs;
            }
            
            print("Manual splits updated in memory for current session");
        }
        
        /**
         * Reset editable splits to current best splits
         * 
         * @method ResetToBestSplits
         * @private
         */
        private void ResetToBestSplits() {
            if (bestSplits.Length <= totalCheckpoints) return;
            
            // Reset editable splits to current best splits
            editableSplits.Resize(totalCheckpoints + 1);
            for (uint i = 0; i <= totalCheckpoints && i < bestSplits.Length; i++) {
                editableSplits[i] = FormatTime(bestSplits[i]);
            }
        }
        
        /**
         * Clear all editable splits
         * 
         * @method ClearAllSplits
         * @private
         */
        private void ClearAllSplits() {
            // Clear all editable splits
            editableSplits.Resize(totalCheckpoints + 1);
            for (uint i = 0; i <= totalCheckpoints; i++) {
                editableSplits[i] = "00:00.000";
            }
        }
        
        /**
         * Parse time string in MM:SS.mmm format to milliseconds
         * 
         * @method ParseTimeString
         * @param {string} timeStr - Time string to parse
         * @returns {uint} Time in milliseconds
         * @private
         */
        private uint ParseTimeString(const string &in timeStr) {
            // Parse time string in format "MM:SS.mmm" to milliseconds
            array<string> parts = timeStr.Split(":");
            if (parts.Length != 2) return 0;
            
            uint minutes = Text::ParseUInt(parts[0]);
            
            array<string> secondsParts = parts[1].Split(".");
            if (secondsParts.Length != 2) return 0;
            
            uint seconds = Text::ParseUInt(secondsParts[0]);
            uint milliseconds = Text::ParseUInt(secondsParts[1]);
            
            return (minutes * 60 + seconds) * 1000 + milliseconds;
        }
        
        /**
         * Update subsequent checkpoints when a split time is manually changed
         * 
         * Maintains the cumulative nature of checkpoint times by updating
         * all subsequent checkpoints by the same time difference.
         * 
         * @method UpdateSubsequentCheckpoints
         * @param {uint} changedIndex - Index of the checkpoint that was changed
         * @param {string} oldTime - Previous time value
         * @param {string} newTime - New time value
         * @private
         */
        private void UpdateSubsequentCheckpoints(uint changedIndex, const string &in oldTime, const string &in newTime) {
            // When a checkpoint time changes, update all subsequent checkpoints
            // to maintain the cumulative nature of the times
            
            uint oldTimeMs = ParseTimeString(oldTime);
            uint newTimeMs = ParseTimeString(newTime);
            
            // Calculate the time difference
            int timeDiff = int(newTimeMs) - int(oldTimeMs);
            
            // Update all checkpoints after the changed one by the same amount
            for (uint i = changedIndex + 1; i <= totalCheckpoints; i++) {
                if (i < editableSplits.Length) {
                    uint currentTimeMs = ParseTimeString(editableSplits[i]);
                    uint updatedTimeMs = currentTimeMs + uint(timeDiff);
                    editableSplits[i] = FormatTime(updatedTimeMs);
                }
            }
        }
        
        /**
         * Render menu items for the plugin
         * 
         * @method RenderMenu
         */
        void RenderMenu() {
            if (UI::MenuItem("Settings", "", showSettingsWindow)) showSettingsWindow = !showSettingsWindow;
        }
    }

    // ============================================================================
    // DID SUPPORT FUNCTIONS
    // ============================================================================
    
    /**
     * Get the current predicted time string for DID integration
     * 
     * @function GetPredictedTimeString
     * @returns {string} Current predicted time string
     */
    string GetPredictedTimeString() {
        if (predictorCore !is null) return predictorCore.PredictedTimeString;
        
        return "00:00.000";
    }

    /**
     * Get the current delta time string for DID integration
     * 
     * @function GetDeltaTimeString
     * @returns {string} Current delta time string
     */
    string GetDeltaTimeString() {
        if (predictorCore !is null) return predictorCore.DeltaTimeString;
        
        return "+00:00.000";
    }

    /**
     * Get the current checkpoint info string for DID integration
     * 
     * @function GetCheckpointInfoString
     * @returns {string} Current checkpoint information string
     */
    string GetCheckpointInfoString() {
        if (predictorCore !is null) return "CP: " + predictorCore.CurrentCheckpoint + "/" + predictorCore.TotalCheckpoints;
        
        return "CP: 0/0";
    }
}