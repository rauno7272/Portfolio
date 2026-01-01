const { useState, useEffect, useCallback } = React;

// --- Helper Functions ---
const post = (event, data = {}) => {
    fetch(`https://clappy_race/${event}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(error => console.error(`[clappy_race] Error posting ${event}:`, error));
};

function formatTime(ms) {
    if (!ms || ms <= 0 || typeof ms !== 'number') return '--:--.---';
    try {
        const date = new Date(ms);
        if (isNaN(date.getTime())) return '--:--.---'; // Check for invalid date
        const minutes = date.getUTCMinutes().toString().padStart(2, '0');
        const seconds = date.getUTCSeconds().toString().padStart(2, '0');
        const milliseconds = date.getUTCMilliseconds().toString().padStart(3, '0');
        return `${minutes}:${seconds}.${milliseconds}`;
    } catch (error) {
        // console.error("Error formatting time:", ms, error); // Removed for cleanup
        return '--:--.---';
    }
}

function getOrdinalSuffix(i) {
    if (i == null || typeof i !== 'number' || isNaN(i)) return '';
    const j = i % 10, k = i % 100;
    if (j === 1 && k !== 11) return "st";
    if (j === 2 && k !== 12) return "nd";
    if (j === 3 && k !== 13) return "rd";
    return "th";
}


// --- Utility Hook for NUI ---
const useNuiEvent = (action, handler) => {
    useEffect(() => {
        const eventListener = (event) => {
            const message = event.data;
            if (message && message.action === action) {
                // console.log(`NUI Received [${action}]:`, JSON.stringify(message)); // Removed for cleanup
                handler(message);
            }
        };
        window.addEventListener('message', eventListener);
        return () => window.removeEventListener('message', eventListener);
    }, [action, handler]);
};

// --- Modal Component ---
const Modal = ({ children, title, onClose, visible, className = '', titleIcon }) => {
    if (!visible) return null;

    return (
        <div className={`fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50`}>
            <div className={`modal-container bg-[rgba(28,30,39,0.9)] border border-[rgba(255,255,255,0.08)] rounded-xl overflow-hidden shadow-lg ${className}`}>
                <div className="modal-header flex justify-between items-center px-6 py-4 border-b border-[rgba(255,255,255,0.08)]">
                    <h1 className="text-xl font-semibold text-white flex items-center">
                        {titleIcon && <i className={`${titleIcon} mr-3 text-blue-400`}></i>}
                        {title}
                    </h1>
                    {onClose && (
                        <button
                            onClick={onClose}
                            className="close-button text-2xl text-gray-400 hover:text-red-500 hover:rotate-90 transition-all duration-200"
                        >
                            &times;
                        </button>
                    )}
                </div>
                {children}
            </div>
        </div>
    );
};

// --- Button Component ---
const Button = ({ children, onClick, variant = 'primary', className = '', icon }) => {
    const variants = {
        primary: 'bg-blue-500 hover:bg-blue-600',
        danger: 'bg-red-500 hover:bg-red-600',
        success: 'bg-green-500 hover:bg-green-600',
        secondary: 'bg-gray-600 hover:bg-gray-700',
    };

    return (
        <button
            onClick={onClick}
            className={`btn px-5 py-3 rounded-lg text-sm font-semibold text-white uppercase tracking-wider transition-all duration-200 flex items-center justify-center ${variants[variant]} ${className}`}
        >
            {icon && <i className={`${icon} mr-2`}></i>}
            {children}
        </button>
    );
};

// --- Name Prompt Component ---
const NamePrompt = ({ visible, defaultName = '' }) => {
    const [name, setName] = useState(defaultName);

    useEffect(() => {
        setName(defaultName);
    }, [defaultName]);

    const handleConfirm = useCallback(() => {
        post('submitName', { name });
    }, [name]);

    const handleClose = () => post('closeMenu');

    if (!visible) return null;

    return (
        <Modal title="Enter Your Race Name" onClose={handleClose} visible={visible} className="w-full max-w-md">
            <div className="p-6 text-center">
                <p className="text-gray-400 mb-5">This name will be shown to other racers.</p>
                <input
                    type="text"
                    id="name-input"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    placeholder="e.g., Clappy"
                    maxLength={25}
                    className="w-full px-4 py-3 bg-black/20 border border-white/10 rounded-lg text-white text-center mb-5 transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent hover:shadow-[0_0_15px_rgba(52,155,219,0.5)] hover:border-blue-400/80 focus:shadow-[0_0_15px_rgba(52,155,219,0.5)] focus:border-blue-400/80"
                    autoFocus
                />
                <Button onClick={handleConfirm} className="w-full">Confirm</Button>
            </div>
        </Modal>
    );
};

// --- Lobby Component ---
const Lobby = ({ visible, lobbyData }) => {
    const { players = [], vehicles = [], laps = 3, leader = null, self = null, isLeader = false } = lobbyData || {};

    const handleLeave = () => post('leaveLobby');
    const handleStart = () => post('startRace');
    const handleClose = () => post('closeMenu');
    const handleLapsChange = (e) => post('setLaps', { laps: e.target.value });
    const handleVehicleChange = (e) => post('setVehicle', { vehicle: e.target.value });

    const selfData = players.find(p => p.source === self);

    return (
        <Modal title="Race Lobby" titleIcon="fas fa-flag-checkered" onClose={handleClose} visible={visible} className="w-full max-w-2xl">
            <div className="lobby-content grid grid-cols-1 md:grid-cols-2 gap-6 p-6">
                {/* Players Section */}
                <div className="lobby-section bg-black/10 p-5 rounded-lg">
                    <h2 className="text-lg font-medium text-gray-300 border-b border-white/10 pb-3 mb-4 flex items-center">
                        <i className="fas fa-users w-5 text-center mr-3"></i> Players ({players.length})
                    </h2>
                    <ul id="player-list" className="list-none p-0 m-0 max-h-40 overflow-y-auto space-y-2">
                        {players.map(p => (
                            <li key={p.source} className="text-sm border-b border-white/5 pb-2 last:border-b-0">
                                {p.name || 'Unknown'}
                                {p.source === leader && <i className="fas fa-star text-yellow-400 ml-2"></i>}
                                <span className="text-gray-400 text-xs block">{p.vehicle}</span>
                            </li>
                        ))}
                    </ul>
                </div>
                {/* Settings Section */}
                <div className="lobby-section bg-black/10 p-5 rounded-lg">
                    <h2 className="text-lg font-medium text-gray-300 border-b border-white/10 pb-3 mb-4 flex items-center">
                        <i className="fas fa-cog w-5 text-center mr-3"></i> Settings
                    </h2>
                    <div className="setting-item mb-4">
                        <label htmlFor="vehicle-select" className="block mb-2 font-medium text-xs text-gray-400 flex items-center">
                            <i className="fas fa-car w-4 text-center mr-2"></i> Your Vehicle
                        </label>
                        <select
                            id="vehicle-select"
                            value={selfData?.vehicle || ''}
                            onChange={handleVehicleChange}
                            className="w-full p-3 bg-black/20 border border-white/10 rounded-lg text-white text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent hover:shadow-[0_0_15px_rgba(52,155,219,0.5)] hover:border-blue-400/80"
                        >
                             {vehicles.map(v => <option key={v.spawncode} value={v.spawncode}>{v.label}</option>)}
                        </select>
                    </div>
                    {isLeader && (
                        <div id="leader-settings">
                            <div className="setting-item mb-4">
                                <label htmlFor="laps-input" className="block mb-2 font-medium text-xs text-gray-400 flex items-center">
                                    <i className="fas fa-arrows-spin w-4 text-center mr-2"></i> Race Laps
                                </label>
                                <input
                                    type="number"
                                    id="laps-input"
                                    min="1" max="20"
                                    value={laps}
                                    onChange={handleLapsChange}
                                    className="w-24 p-3 bg-black/20 border border-white/10 rounded-lg text-white text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent hover:shadow-[0_0_15px_rgba(52,155,219,0.5)] hover:border-blue-400/80 focus:shadow-[0_0_15px_rgba(52,155,219,0.5)] focus:border-blue-400/80"
                                />
                            </div>
                        </div>
                    )}
                </div>
            </div>
            {/* Footer Buttons */}
            <div className="lobby-footer flex justify-end gap-3 p-5 bg-black/5 border-t border-white/10">
                <Button onClick={handleLeave} variant="danger" icon="fas fa-right-from-bracket">Leave</Button>
                {isLeader && <Button onClick={handleStart} variant="success" icon="fas fa-play">Start Race</Button>}
            </div>
        </Modal>
    );
};

// --- History Component ---
const History = ({ visible, historyData = [] }) => {
    const [detailViewData, setDetailViewData] = useState(null);

    const handleClose = () => post('closeHistory');
    const handleShowDetail = (race) => setDetailViewData(race);
    const handleBackToList = () => setDetailViewData(null);

    return (
        <Modal title="Race History" onClose={handleClose} visible={visible} className="w-full max-w-xl">
            {!detailViewData ? (
                // List View
                <div id="history-list-view" className="p-6 max-h-[60vh] overflow-y-auto">
                    {historyData.length === 0 ? (
                         <p className="text-center text-gray-400">No race history available.</p>
                    ) : (
                        <ul id="history-list" className="list-none p-0 m-0 space-y-3">
                            {historyData.map((race, index) => (
                                <li
                                    key={index}
                                    onClick={() => handleShowDetail(race)}
                                    className="bg-black/10 p-4 rounded-lg cursor-pointer transition-all duration-200 border border-transparent hover:bg-black/20 hover:shadow-[0_0_15px_rgba(52,155,219,0.5)] hover:border-blue-400/80"
                                >
                                    <div className="history-track font-semibold text-lg">{race.trackName || 'Unknown Track'}</div>
                                    <div className="history-details text-xs text-gray-400 mt-1">{race.date} - {race.laps} Laps - {race.results?.length || 0} Racers</div>
                                </li>
                            ))}
                        </ul>
                     )}
                </div>
            ) : (
                // Detail View
                <div id="history-detail-view" className="p-6">
                    <h2 id="history-track-name" className="text-xl font-semibold mb-4">{detailViewData.trackName} ({detailViewData.laps} Laps)</h2>
                    <table id="history-detail-table" className="w-full border-collapse mb-4">
                        <thead>
                            <tr>
                                <th className="p-3 text-center text-gray-400 border-b border-white/10 w-12">#</th>
                                <th className="p-3 text-left text-gray-400 border-b border-white/10">Name</th>
                                <th className="p-3 text-left text-gray-400 border-b border-white/10">Total Time</th>
                                <th className="p-3 text-left text-gray-400 border-b border-white/10">Best Lap</th>
                            </tr>
                        </thead>
                        <tbody>
                             {detailViewData.results?.map((p, i) => (
                                <tr key={i}>
                                    <td className="p-3 text-center border-b border-white/5">{i + 1}</td>
                                    <td className="p-3 text-left border-b border-white/5">{p.name}</td>
                                    <td className="p-3 text-left border-b border-white/5">{p.totalTime === 'DNF' ? 'DNF' : formatTime(p.totalTime)}</td>
                                    <td className="p-3 text-left border-b border-white/5">{formatTime(p.bestLap)}</td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                    <Button onClick={handleBackToList} variant="secondary">Back to List</Button>
                </div>
            )}
        </Modal>
    );
};


// --- HUD Component ---
const Hud = ({ visible, hudData }) => {
    const { place = 0, totalPlayers = 0, lap = 0, totalLaps = 0, checkpoint = 0, totalCheckpoints = 0, bestLap = 0, totalTime = 0, dnfTime = null } = hudData || {};

    if (!visible) return null;

    return (
        <div id="hud-container" className="absolute bottom-8 left-1/2 -translate-x-1/2 flex gap-4 bg-[rgba(28,30,39,0.9)] px-6 py-4 rounded-xl border border-white/10 shadow-lg">
            <div className="hud-item text-center min-w-[100px]">
                <span className="hud-label block text-xs text-gray-400 uppercase font-medium tracking-widest">Time</span>
                <span id="hud-time" className="hud-value block text-2xl font-bold text-white mt-1">{formatTime(totalTime)}</span>
            </div>
            <div className="hud-item text-center min-w-[100px]">
                <span className="hud-label block text-xs text-gray-400 uppercase font-medium tracking-widest">Best Lap</span>
                <span id="hud-best" className="hud-value block text-2xl font-bold text-white mt-1">{formatTime(bestLap)}</span>
            </div>
            <div className="hud-item text-center min-w-[100px]">
                <span className="hud-label block text-xs text-gray-400 uppercase font-medium tracking-widest">Position</span>
                <span id="hud-pos" className="hud-value block text-2xl font-bold text-white mt-1">{place}/{totalPlayers}</span>
            </div>
            <div className="hud-item text-center min-w-[100px]">
                <span className="hud-label block text-xs text-gray-400 uppercase font-medium tracking-widest">Lap</span>
                <span id="hud-lap" className="hud-value block text-2xl font-bold text-white mt-1">{lap}/{totalLaps}</span>
            </div>
            <div className="hud-item text-center min-w-[100px]">
                <span className="hud-label block text-xs text-gray-400 uppercase font-medium tracking-widest">Checkpoint</span>
                <span id="hud-cp" className="hud-value block text-2xl font-bold text-white mt-1">{checkpoint}/{totalCheckpoints}</span>
            </div>
             {dnfTime != null && dnfTime > 0 && (
                <div className="hud-item text-center min-w-[100px]">
                    <span className="hud-label block text-xs text-red-400 uppercase font-medium tracking-widest">Time Left</span>
                    <span id="hud-dnf" className="hud-value block text-2xl font-bold text-red-400 mt-1">{formatTime(dnfTime)}</span>
                </div>
            )}
        </div>
    );
};

// --- Center Text Component ---
const CenterText = ({ textData }) => {
    const { value, type, main, sub } = textData || {};
    const [isVisible, setIsVisible] = useState(true); // Start visible
    
    // console.log('Rendering CenterText with data:', JSON.stringify(textData)); // Removed for cleanup

    const textToShow = type === 'finish' ? (main || '') : (value || '');
    const subTextToShow = type === 'finish' ? (sub || '') : '';
    
    if (!textToShow || textToShow === false) { 
         // console.log('CenterText rendering null (no text or value is false)'); // Removed for cleanup
         return null;
    }
    
    // Determine styles based on type
    let textColor = 'rgba(255, 255, 255, 0.8)'; // Default: white with opacity
    let textShadow = '0 0 15px rgba(0,0,0,0.7)'; // Default shadow
    if (type === 'countdown' && value === 'GO!') {
        textColor = 'rgb(74, 222, 128)'; // Green color for GO!
        textShadow = '0 0 30px rgba(74, 222, 128, 0.9)'; // Green shadow for GO!
    }

    // Determine font size based on type (using inline style)
    const mainFontSize = type === 'finish' ? '6em' : '6em'; 

    // Re-add auto-hide for countdown
    useEffect(() => {
        if (type === 'countdown') {
            const duration = (value === 'GO!') ? 950 : 900;
            const timer = setTimeout(() => {
                setIsVisible(false);
            }, duration);
            return () => clearTimeout(timer);
        }
        // Make sure finish text also eventually hides or gets cleared
        else if (type === 'finish') {
             const timer = setTimeout(() => {
                setIsVisible(false); // Hide finish text after a longer delay
            }, 4000); // e.g., 4 seconds
            return () => clearTimeout(timer);
        }
    }, [type, value]); // Re-run if type/value change

    const opacity = isVisible ? 1 : 0; // Control opacity for fade-out

    // Container style
     const containerStyle = {
        position: 'absolute',
        top: '35%',
        left: '50%',
        transform: 'translateX(-50%)',
        zIndex: 999,     
        width: '800px',   
        textAlign: 'center',
        pointerEvents: 'none',
        overflow: 'hidden',
        whiteSpace: 'nowrap'
    };

    // Main text style
    const textStyle = {
        fontSize: mainFontSize,
        color: textColor,
        fontWeight: 'bold',
        textShadow: textShadow,
        opacity: opacity,
        transition: 'opacity 0.3s ease-out' // Keep fade out transition
    };

     // Style for sub-parts of finish text
    const finishSubStyle1 = { display: 'block', fontSize: '0.7em' };
    const finishSubStyle2 = { display: 'block', fontSize: '1em' };


    return (
        <div style={containerStyle}> 
            {/* Main Text Only */}
            <div style={textStyle}>
                 {type === 'finish' ? (
                     <>
                       <span style={finishSubStyle1}>{textToShow}</span>
                       <span style={finishSubStyle2}>{subTextToShow}</span>
                    </>
                ) : textToShow}
            </div>
        </div>
    );
};


// --- Main App Component ---
function App() {
    const [uiState, setUiState] = useState({
        showNamePrompt: false,
        showLobby: false,
        showHistory: false,
        showHud: false,
    });
    const [namePromptData, setNamePromptData] = useState({});
    const [lobbyData, setLobbyData] = useState({});
    const [historyData, setHistoryData] = useState([]);
    const [hudData, setHudData] = useState({});
    const [centerTextData, setCenterTextData] = useState({ value: '', type: '', animate: false, main: '', sub: '' });
    const [teleportCountdown, setTeleportCountdown] = useState(null);
    const [centerTextKey, setCenterTextKey] = useState(0); // Key to force remount

    // NUI Event Handlers
    const handleUpdateLobby = useCallback((data) => {
        setLobbyData(data);
        setUiState(prev => ({ ...prev, showLobby: data.visible, showNamePrompt: false }));
    }, []);
    const handleUpdateHUD = useCallback((data) => {
        setHudData(prev => ({ ...prev, ...data.data }));
        setUiState(prev => ({ ...prev, showHud: data.visible }));
        
        if (data.visible === false) {
             // Clear center text when HUD hides
            setCenterTextData({ value: '', type: '', animate: false, main: '', sub: '' });
             setCenterTextKey(k => k + 1); // Force remount to clear it
        }
    }, []);
     const handleCountdown = useCallback((data) => { // Accept full data object
        // console.log('NUI MESSAGE RECEIVED - handleCountdown:', data.value); // Removed for cleanup
        setCenterTextData({ value: data.value, type: 'countdown', animate: false }); 
        setCenterTextKey(k => k + 1); // Increment key to force remount
    }, []);
    const handleShowResultText = useCallback((data) => {
        // console.log('NUI MESSAGE RECEIVED - handleShowResultText:', JSON.stringify(data)); // Removed for cleanup
        setCenterTextData({ main: data.main, sub: data.sub, type: 'finish', animate: false });
        setCenterTextKey(k => k + 1); // Increment key to force remount
    }, []);
     const handleShowNamePrompt = useCallback((data) => {
        setNamePromptData({ defaultName: data.defaultName });
        setUiState(prev => ({ ...prev, showNamePrompt: data.visible }));
    }, []);
     const handleShowHistory = useCallback((data) => {
        setHistoryData(data.history || []);
        setUiState(prev => ({ ...prev, showHistory: data.visible }));
    }, []);
    const handleHardResetUI = useCallback(() => {
        setUiState({ showNamePrompt: false, showLobby: false, showHistory: false, showHud: false });
        setCenterTextData({ value: '', type: '', animate: false, main: '', sub: '' });
        setTeleportCountdown(null);
        setCenterTextKey(0); // Reset key
    }, []);
    const handleUpdateTime = useCallback((data) => {
        setHudData(prev => ({ ...prev, totalTime: data.time }));
    }, []);
    const handleUpdateDnfTime = useCallback((data) => {
        setHudData(prev => ({ ...prev, dnfTime: data.time }));
    }, []);
    const handleStartTeleportCountdown = useCallback((data) => {
        let count = data.duration;
        setTeleportCountdown(count);
        const intervalId = setInterval(() => { 
            count--;
            setTeleportCountdown(prevCount => {
                 if (prevCount !== null && prevCount > 1) {
                     return prevCount - 1;
                 } else {
                     clearInterval(intervalId); 
                     return null;
                 }
            });
        }, 1000);
    }, []);


    // Register NUI Event Listeners
    useNuiEvent('updateLobby', handleUpdateLobby);
    useNuiEvent('updateHUD', handleUpdateHUD);
    useNuiEvent('countdown', handleCountdown); 
    useNuiEvent('showResultText', handleShowResultText);
    useNuiEvent('showNamePrompt', handleShowNamePrompt);
    useNuiEvent('showHistory', handleShowHistory);
    useNuiEvent('hardResetUI', handleHardResetUI);
    useNuiEvent('updateTime', handleUpdateTime);
    useNuiEvent('updateDnfTime', handleUpdateDnfTime);
    useNuiEvent('startTeleportCountdown', handleStartTeleportCountdown);


    // Handle Escape Key Press
    useEffect(() => {
        const handleKeyDown = (e) => {
            if (e.key === 'Escape') {
                if (uiState.showLobby) post('closeMenu');
                else if (uiState.showNamePrompt) post('closeMenu');
                else if (uiState.showHistory) post('closeHistory');
            }
        };
        document.addEventListener('keydown', handleKeyDown);
        return () => document.removeEventListener('keydown', handleKeyDown);
    }, [uiState]);

    // console.log('Rendering App - centerTextData:', JSON.stringify(centerTextData)); // Removed for cleanup

    return (
        <div className="relative w-full h-full text-gray-200">
            <NamePrompt visible={uiState.showNamePrompt} {...namePromptData} />
            <Lobby visible={uiState.showLobby} lobbyData={lobbyData} />
            <History visible={uiState.showHistory} historyData={historyData} />
            <Hud visible={uiState.showHud} hudData={hudData} />
             {/* Use the dedicated key state */}
             <CenterText key={centerTextKey} textData={centerTextData} />

             {/* Display Teleport Countdown separately */}
             {teleportCountdown !== null && teleportCountdown > 0 && (
                <div className="absolute top-[35%] left-1/2 -translate-x-1/2 w-[800px] text-center pointer-events-none whitespace-nSowrap">
                     {/* Main Text (MODIFIED) - Made larger and fully white */}
                     <div className="center-text-container text-[6.5em] font-bold text-white absolute w-full left-0 top-1/2 -translate-y-1/2 z-10" style={{opacity: 1, textShadow: '0 0 15px rgba(0,0,0,0.7)' }}>
                        Teleporting in {teleportCountdown}...
                    </div>
                 </div>
             )}
        </div>
    );
}

// Safer React root creation
if (typeof App !== 'undefined') {
    const container = document.getElementById('root');
    if (container && !container._reactRootContainer) { 
        const root = ReactDOM.createRoot(container);
        root.render(<App />);
    } else if (container && container._reactRootContainer) {
        container._reactRootContainer.render(<App />);
    }
}

