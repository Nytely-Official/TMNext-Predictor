// Plugin Info
const string pluginName = Meta::ExecutingPlugin().Name;
const string menuIconColor = "\\$5fa";
const string menuTitle = menuIconColor + "\\$z " + pluginName;

// Global variables
Predictor::PredictorCore@ predictorCore;

/**
 * Main function (Runs once when the plugin is loaded)
 */
void Main() {
    @predictorCore = Predictor::PredictorCore();
    predictorCore.Initialize();

    startnew(ServerAuthenticationCoroutine);
}

/**
 * Update function (Runs every frame)
 */
void Update(float millisecondsSinceLastFrame) {
    
    
    if (predictorCore !is null) predictorCore.Update(millisecondsSinceLastFrame);  
}

/**
 * Render function for overlay
 */
void Render() {
    if (predictorCore !is null) predictorCore.Render();
}

/**
 * Render interface for settings menu
 */
void RenderInterface() {
    if (predictorCore !is null) predictorCore.RenderInterface();
}

/**
 * Render menu items
 */
void RenderMenu() {
    if (UI::BeginMenu(Icons::Clock + " Predictor")) {
        predictorCore.RenderMenu();
        UI::EndMenu();
    }
}

void ServerAuthenticationCoroutine() {
    while (predictorCore is null) yield();

    while (!predictorCore.AuthenticateWithServer()) {
        print("Predictor: server authentication failed, retrying in 60 seconds...");
        sleep(60000);
        while (predictorCore is null) yield();
    }
}