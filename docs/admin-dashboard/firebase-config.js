// IMPORTANT: Replace these values with your Firebase project credentials
// Get these from: Firebase Console > Project Settings > Copy the config object

const firebaseConfig = {
    apiKey: "AIzaSyCelAjPZ6zSujfIi_V2K5FX2_XV8ILIMsk",
    authDomain: "drivora-adas.firebaseapp.com",
    projectId: "drivora-adas",
    storageBucket: "drivora-adas.firebasestorage.app",
    messagingSenderId: "467697098105",
    appId: "1:467697098105:web:a8ef7c2243179f1b6c23a8",
    measurementId: "G-MPVH5J3XWL"
};

// Initialize Firebase
firebase.initializeApp(firebaseConfig);

// Get references
const auth = firebase.auth();
const db = firebase.firestore();

console.log('✓ Firebase initialized successfully');
