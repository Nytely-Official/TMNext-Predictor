/**
 * Predictor Settings and Enums
 * 
 * This file contains all the plugin settings and configuration options
 * that can be modified by the user through the Openplanet settings interface.
 * 
 * @namespace Predictor
 */
namespace Predictor {

    // ============================================================================
    // DISPLAY SETTINGS
    // ============================================================================
    
    /** Whether to show the prediction overlay on screen */
    [Setting name="Show Predictor Overlay"]
    bool showOverlay = true;

    /** Whether to hide the overlay when the game interface is hidden */
    [Setting name="Hide when interface is hidden"]
    bool hideWithInterface = false;

    /** Horizontal position of the overlay (0.0 = left, 1.0 = right) */
    [Setting name="X Position" min=0.0 max=1.0]
    float overlayX = 0.5;

    /** Vertical position of the overlay (0.0 = top, 1.0 = bottom) */
    [Setting name="Y Position" min=0.0 max=1.0]
    float overlayY = 0.85;

    /** Width of the overlay as percentage of screen width (0.1 = 10%, 1.0 = 100%) */
    [Setting name="Overlay Width" min=0.1 max=1.0]
    float overlayWidth = 0.2;

    /** Height of the overlay as percentage of screen height (0.1 = 10%, 1.0 = 100%) */
    [Setting name="Overlay Height" min=0.1 max=1.0]
    float overlayHeight = 0.15;

    /** Font size for the overlay text */
    [Setting name="Font Size" min=12 max=48]
    uint fontSize = 24;

    /** Whether to show the background behind the overlay text */
    [Setting name="Show Background"]
    bool showBackground = true;

    /** Whether the settings window is visible */
    [Setting hidden]
    bool showSettingsWindow = true;

    // ============================================================================
    // COLOR SETTINGS
    // ============================================================================
    
    /** Color of the main prediction text */
    [Setting color name="Text Color"]
    vec4 textColor = vec4(1.0, 1.0, 1.0, 1.0);

    /** Color of the background behind the overlay */
    [Setting color name="Background Color"]
    vec4 backgroundColor = vec4(0.0, 0.0, 0.0, 0.7);

    /** Color of the shadow behind the main text */
    [Setting color name="Text Shadow Color"]
    vec4 textShadowColor = vec4(0.0, 0.0, 0.0, 0.8);

    /** Color of the delta time text (shows difference from best time) */
    [Setting color name="Delta Text Color"]
    vec4 deltaTextColor = vec4(1.0, 1.0, 1.0, 1.0);

    /** Color of the shadow behind the delta time text */
    [Setting color name="Delta Shadow Color"]
    vec4 deltaShadowColor = vec4(0.0, 0.0, 0.0, 0.8);

    /** Color of the checkpoint information text */
    [Setting color name="Checkpoint Text Color"]
    vec4 checkpointTextColor = vec4(1.0, 1.0, 1.0, 1.0);

    /** Color of the shadow behind the checkpoint text */
    [Setting color name="Checkpoint Shadow Color"]
    vec4 checkpointShadowColor = vec4(0.0, 0.0, 0.0, 0.8);

    // ============================================================================
    // DATABASE SETTINGS
    // ============================================================================
    
    /** Whether to save splits to the server */
    [Setting name="Save Splits to Server"]
    bool saveToServer = true;
    
    /** Whether to fetch and use server splits for prediction */
    [Setting name="Use Server Splits for Prediction"]
    bool useServerSplits = true;
    
    /** Which type of server splits to use for prediction */
    [Setting name="Server Split Type"]
    SplitSourceType splitSourceType = SplitSourceType::PersonalBest;

    // ============================================================================
    // FUNCTIONALITY SETTINGS
    // ============================================================================
    
    /** Which prediction method to use for calculating finish times */
    [Setting name="Prediction Method"]
    PredictorMethod predictionMethod = PredictorMethod::Hybrid;

    /** Whether to show the delta time (difference from best time) */
    [Setting name="Show Delta Time"]
    bool showDeltaTime = true;

    /** Whether to show current checkpoint information */
    [Setting name="Show Checkpoint Splits"]
    bool showCheckpointSplits = false;

    /** Whether to allow dragging and resizing the overlay window */
    [Setting name="Enable Resize/Drag"]
    bool enableResizeDrag = true;

    // ============================================================================
    // ENUMS
    // ============================================================================
    
    /**
     * Available prediction methods for calculating finish times
     * 
     * @enum PredictorMethod
     */
    enum PredictorMethod {
        /** Basic linear extrapolation based on average time per checkpoint */
        LinearExtrapolation,
        
        /** Compare current run to personal best checkpoint times */
        BestSplitsComparison,
        
        /** Hybrid approach combining linear and best splits methods */
        Hybrid
    }
    
    /**
     * Source type for server splits
     * 
     * @enum SplitSourceType
     */
    enum SplitSourceType {
        /** Use personal best split from server */
        PersonalBest,
        
        /** Use global best split from server */
        GlobalBest
    }
}