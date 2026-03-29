import { initializeApp } from "firebase/app";
import { getAnalytics } from "firebase/analytics";
import { getFirestore } from "firebase/firestore"; // Example: adding database
import { getStorage } from "firebase/storage";
import { getAuth } from "firebase/auth";

const firebaseConfig = {
  apiKey: "AIzaSyBOzgFYjNzqDBVzDRQ7aFl0fIKpHYdGuNQ",
  authDomain: "ceylon-share-tour.firebaseapp.com",
  projectId: "ceylon-share-tour",
  storageBucket: "ceylon-share-tour.firebasestorage.app",
  messagingSenderId: "230136178640",
  appId: "1:230136178640:web:cddd00c55fe29e571bfbd5",
  measurementId: "G-M6END067JX"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const analytics = getAnalytics(app);

// Export services to use them in other files
export const db = getFirestore(app);
export const storage = getStorage(app);
export const auth = getAuth(app);
export default app;
