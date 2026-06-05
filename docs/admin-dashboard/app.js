// ============================================================================
// DRIVORA ADMIN DASHBOARD - MAIN APPLICATION
// ============================================================================

let currentUser = null;
let allUsers = [];
let filteredUsers = [];
let currentPage = 1;
const itemsPerPage = 10;
let sortMode = 'date';

// ============================================================================
// INITIALIZATION
// ============================================================================

document.addEventListener('DOMContentLoaded', () => {
    console.log('🚀 Dashboard loading...');
    
    // Check Firebase initialization
    if (typeof firebase === 'undefined') {
        showError('Firebase SDK not loaded. Check firebase-config.js');
        return;
    }

    // Setup event listeners
    setupEventListeners();
    
    // Setup authentication
    setupAuthentication();
});

// ============================================================================
// AUTHENTICATION
// ============================================================================

function setupAuthentication() {
    const googleSignInBtn = document.getElementById('googleSignInBtn');
    const signInBtn = document.getElementById('signInBtn');
    const signOutBtn = document.getElementById('signOutBtn');

    // Google Sign-In
    googleSignInBtn?.addEventListener('click', signInWithGoogle);
    signInBtn?.addEventListener('click', signInWithGoogle);
    signOutBtn?.addEventListener('click', signOut);

    // Monitor authentication state
    firebase.auth().onAuthStateChanged(user => {
        if (user) {
            console.log('✓ User authenticated:', user.email);
            currentUser = user;
            showDashboard(user);
            loadUsersData();
        } else {
            console.log('⚠ No user authenticated');
            currentUser = null;
            showLoginScreen();
        }
    });
}

async function signInWithGoogle() {
    try {
        const provider = new firebase.auth.GoogleAuthProvider();
        
        // Allow user to select account
        provider.setCustomParameters({
            prompt: 'select_account'
        });

        const result = await firebase.auth().signInWithPopup(provider);
        console.log('✓ Google sign-in successful:', result.user.email);
        
        // Check if user is admin (optional: verify email domain or Firestore role)
        await checkAdminAccess(result.user);
        
    } catch (error) {
        console.error('✗ Google sign-in failed:', error);
        showError(`Sign-in failed: ${error.message}`);
    }
}

async function signOut() {
    try {
        await firebase.auth().signOut();
        console.log('✓ Signed out');
        showLoginScreen();
    } catch (error) {
        console.error('✗ Sign-out failed:', error);
        showError(`Sign-out failed: ${error.message}`);
    }
}

async function checkAdminAccess(user) {
    try {
        // Optional: Check Firestore for admin role
        const adminDoc = await firebase.firestore()
            .collection('admins')
            .doc(user.email)
            .get();

        if (adminDoc.exists) {
            console.log('✓ Admin access verified');
            return true;
        } else {
            // For now, allow any authenticated user (modify this for security)
            console.log('⚠ Not in admin list, but allowing access');
            return true;
        }
    } catch (error) {
        console.error('✗ Admin check failed:', error);
        return true; // Allow access anyway
    }
}

// ============================================================================
// UI STATE MANAGEMENT
// ============================================================================

function showLoginScreen() {
    document.getElementById('loginContainer').style.display = 'flex';
    document.getElementById('dashboardContent').style.display = 'none';
    document.getElementById('signInBtn').style.display = 'none';
    document.getElementById('signOutBtn').style.display = 'none';
}

function showDashboard(user) {
    document.getElementById('loginContainer').style.display = 'none';
    document.getElementById('dashboardContent').style.display = 'block';
    document.getElementById('signInBtn').style.display = 'none';
    document.getElementById('signOutBtn').style.display = 'block';
    document.getElementById('authStatus').innerHTML = 
        `👤 Logged in as: <strong>${user.email}</strong>`;
}

// ============================================================================
// DATA LOADING
// ============================================================================

async function loadUsersData() {
    try {
        console.log('📊 Loading users from Firestore...');
        
        const snapshot = await firebase.firestore()
            .collection('users')
            .orderBy('registeredAt', 'desc')
            .get();

        allUsers = snapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data(),
            registeredAt: doc.data().registeredAt?.toDate() || new Date()
        }));

        console.log(`✓ Loaded ${allUsers.length} users`);
        
        filteredUsers = [...allUsers];
        updateStatistics();
        renderUsersTable();
        
    } catch (error) {
        console.error('✗ Failed to load users:', error);
        showError(`Failed to load user data: ${error.message}`);
    }
}

// ============================================================================
// STATISTICS
// ============================================================================

function updateStatistics() {
    // Total users
    document.getElementById('totalUsers').textContent = allUsers.length;
    
    // Total vehicles
    document.getElementById('totalVehicles').textContent = allUsers.length;
    
    // Today's registrations
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const todayCount = allUsers.filter(u => 
        new Date(u.registeredAt).getTime() >= today.getTime()
    ).length;
    document.getElementById('todayRegistrations').textContent = todayCount;
    
    // Synced users
    const syncedCount = allUsers.filter(u => 
        u.email && u.email.trim() !== ''
    ).length;
    document.getElementById('syncedUsers').textContent = syncedCount;
}

// ============================================================================
// SEARCH & FILTER
// ============================================================================

function setupEventListeners() {
    document.getElementById('searchInput')?.addEventListener('input', handleSearch);
    document.getElementById('sortBy')?.addEventListener('change', handleSort);
    document.getElementById('refreshBtn')?.addEventListener('click', () => {
        loadUsersData();
        showSuccess('Data refreshed');
    });
    document.getElementById('exportBtn')?.addEventListener('click', exportToCSV);
    
    // Modal
    document.querySelector('.close')?.addEventListener('click', closeModal);
    document.getElementById('userModal')?.addEventListener('click', (e) => {
        if (e.target.id === 'userModal') closeModal();
    });
}

function handleSearch(e) {
    const query = e.target.value.toLowerCase();
    filteredUsers = allUsers.filter(user => 
        (user.name || '').toLowerCase().includes(query) ||
        (user.email || '').toLowerCase().includes(query) ||
        (user.carModel || '').toLowerCase().includes(query)
    );
    currentPage = 1;
    renderUsersTable();
}

function handleSort(e) {
    sortMode = e.target.value;
    
    if (sortMode === 'date') {
        filteredUsers.sort((a, b) => 
            new Date(b.registeredAt) - new Date(a.registeredAt)
        );
    } else if (sortMode === 'name') {
        filteredUsers.sort((a, b) => 
            (a.name || 'Z').localeCompare(b.name || 'Z')
        );
    } else if (sortMode === 'vehicle') {
        filteredUsers.sort((a, b) => 
            (a.carModel || 'Z').localeCompare(b.carModel || 'Z')
        );
    }
    
    currentPage = 1;
    renderUsersTable();
}

// ============================================================================
// TABLE RENDERING
// ============================================================================

function renderUsersTable() {
    const tbody = document.getElementById('usersTableBody');
    
    if (filteredUsers.length === 0) {
        tbody.innerHTML = '<tr class="loading-row"><td colspan="8">No users found</td></tr>';
        return;
    }

    // Pagination
    const start = (currentPage - 1) * itemsPerPage;
    const end = start + itemsPerPage;
    const pageUsers = filteredUsers.slice(start, end);

    tbody.innerHTML = pageUsers.map(user => `
        <tr onclick="showUserDetails('${user.id}')">
            <td><strong>${user.name || 'N/A'}</strong></td>
            <td>${user.email || 'N/A'}</td>
            <td>${user.carModel || 'N/A'}</td>
            <td>H: ${(user.calibration?.height || 0).toFixed(2)}m × W: ${(user.calibration?.width || 0).toFixed(2)}m</td>
            <td>
                Sens: ${user.onboarding?.alertSensitivity || 0}/10<br>
                Vol: ${user.onboarding?.audioVolume || 0}/10
            </td>
            <td>${formatDate(user.registeredAt)}</td>
            <td>
                <span class="status-badge ${user.email ? 'status-synced' : 'status-pending'}">
                    ${user.email ? '✓ SYNCED' : '⏳ PENDING'}
                </span>
            </td>
            <td>
                <button class="btn-icon" onclick="event.stopPropagation(); showUserDetails('${user.id}')">👁️</button>
                <button class="btn-icon" onclick="event.stopPropagation(); deleteUser('${user.id}')">🗑️</button>
            </td>
        </tr>
    `).join('');

    renderPagination();
}

function renderPagination() {
    const totalPages = Math.ceil(filteredUsers.length / itemsPerPage);
    const paginationDiv = document.getElementById('paginationControls');
    
    if (totalPages <= 1) {
        paginationDiv.innerHTML = '';
        return;
    }

    let html = '<button onclick="previousPage()">← PREV</button>';
    
    for (let i = 1; i <= totalPages; i++) {
        const activeClass = i === currentPage ? 'active' : '';
        html += `<button class="${activeClass}" onclick="goToPage(${i})">${i}</button>`;
    }
    
    html += '<button onclick="nextPage()">NEXT →</button>';
    paginationDiv.innerHTML = html;
}

function previousPage() {
    if (currentPage > 1) {
        currentPage--;
        renderUsersTable();
    }
}

function nextPage() {
    const totalPages = Math.ceil(filteredUsers.length / itemsPerPage);
    if (currentPage < totalPages) {
        currentPage++;
        renderUsersTable();
    }
}

function goToPage(page) {
    currentPage = page;
    renderUsersTable();
}

// ============================================================================
// USER DETAILS
// ============================================================================

function showUserDetails(userId) {
    const user = allUsers.find(u => u.id === userId);
    if (!user) return;

    const content = document.getElementById('userDetailsContent');
    content.innerHTML = `
        <div class="user-detail">
            <div class="user-detail-label">FULL NAME</div>
            <div class="user-detail-value">${user.name || 'N/A'}</div>
        </div>
        <div class="user-detail">
            <div class="user-detail-label">EMAIL ADDRESS</div>
            <div class="user-detail-value">${user.email || 'N/A'}</div>
        </div>
        <div class="user-detail">
            <div class="user-detail-label">FIREBASE UID</div>
            <div class="user-detail-value">${user.uid || 'N/A'}</div>
        </div>
        <div class="user-detail">
            <div class="user-detail-label">VEHICLE TYPE</div>
            <div class="user-detail-value">${user.onboarding?.vehicleType || 'N/A'}</div>
        </div>
        <div class="user-detail">
            <div class="user-detail-label">VEHICLE MODEL</div>
            <div class="user-detail-value">${user.carModel || 'N/A'}</div>
        </div>
        <div class="user-detail">
            <div class="user-detail-label">DRIVER EXPERIENCE</div>
            <div class="user-detail-value">${user.onboarding?.driverExperience || 'N/A'}</div>
        </div>
        <div class="user-detail">
            <div class="user-detail-label">VEHICLE HEIGHT</div>
            <div class="user-detail-value">${(user.calibration?.height || 0).toFixed(2)} meters</div>
        </div>
        <div class="user-detail">
            <div class="user-detail-label">VEHICLE WIDTH</div>
            <div class="user-detail-value">${(user.calibration?.width || 0).toFixed(2)} meters</div>
        </div>
        <div class="user-detail">
            <div class="user-detail-label">ALERT SENSITIVITY</div>
            <div class="user-detail-value">${user.onboarding?.alertSensitivity || 0}/10</div>
        </div>
        <div class="user-detail">
            <div class="user-detail-label">AUDIO VOLUME</div>
            <div class="user-detail-value">${user.onboarding?.audioVolume || 0}/10</div>
        </div>
        <div class="user-detail">
            <div class="user-detail-label">REGISTRATION DATE</div>
            <div class="user-detail-value">${formatDate(user.registeredAt)}</div>
        </div>
        <div class="user-detail">
            <div class="user-detail-label">LAST SYNCED</div>
            <div class="user-detail-value">${formatDate(user.lastSyncedAt || user.registeredAt)}</div>
        </div>
    `;

    document.getElementById('userModal').style.display = 'block';
}

function closeModal() {
    document.getElementById('userModal').style.display = 'none';
    document.getElementById('confirmModal').style.display = 'none';
}

// ============================================================================
// DATA MANAGEMENT
// ============================================================================

function deleteUser(userId) {
    const user = allUsers.find(u => u.id === userId);
    if (!user) return;

    showConfirmation(
        `Delete user "${user.name}"? This cannot be undone.`,
        async () => {
            try {
                await firebase.firestore()
                    .collection('users')
                    .doc(userId)
                    .delete();

                console.log('✓ User deleted:', userId);
                showSuccess(`User "${user.name}" deleted successfully`);
                loadUsersData();
                closeModal();
            } catch (error) {
                console.error('✗ Delete failed:', error);
                showError(`Delete failed: ${error.message}`);
            }
        }
    );
}

function showConfirmation(message, onConfirm) {
    document.getElementById('confirmMessage').textContent = message;
    document.getElementById('confirmYesBtn').onclick = () => {
        closeModal();
        onConfirm();
    };
    document.getElementById('confirmNoBtn').onclick = closeModal;
    document.getElementById('confirmModal').style.display = 'block';
}

// ============================================================================
// EXPORT
// ============================================================================

function exportToCSV() {
    if (allUsers.length === 0) {
        showError('No data to export');
        return;
    }

    let csv = 'Driver Name,Email,Vehicle Type,Vehicle Model,Height (m),Width (m),Alert Sensitivity,Audio Volume,Registration Date\n';
    
    allUsers.forEach(user => {
        csv += `"${user.name || ''}","${user.email || ''}","${user.onboarding?.vehicleType || ''}","${user.carModel || ''}",${user.calibration?.height || 0},${user.calibration?.width || 0},${user.onboarding?.alertSensitivity || 0},${user.onboarding?.audioVolume || 0},"${formatDate(user.registeredAt)}"\n`;
    });

    const blob = new Blob([csv], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `drivora-users-${new Date().toISOString().split('T')[0]}.csv`;
    a.click();
    window.URL.revokeObjectURL(url);

    showSuccess(`Exported ${allUsers.length} users to CSV`);
}

// ============================================================================
// UTILITIES
// ============================================================================

function formatDate(date) {
    if (!date) return 'N/A';
    const d = new Date(date);
    return d.toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}

function showSuccess(message) {
    console.log('✓', message);
    // Can be enhanced with toast notifications
}

function showError(message) {
    console.error('✗', message);
    alert(`Error: ${message}`);
}

// ============================================================================
// UTILITY: Check Firebase Connection
// ============================================================================

window.testFirebaseConnection = async function() {
    try {
        const testDoc = await firebase.firestore()
            .collection('_test')
            .doc('connection')
            .get();
        console.log('✓ Firebase Firestore is accessible');
        return true;
    } catch (error) {
        console.error('✗ Firebase Firestore error:', error);
        return false;
    }
};

console.log('✓ Admin Dashboard script loaded');
