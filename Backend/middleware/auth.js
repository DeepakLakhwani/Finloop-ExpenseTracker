const admin = require('firebase-admin');
const path = require('path');
require('dotenv').config();

const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;

if (serviceAccountPath) {
    try {
        const absolutePath = path.resolve(process.cwd(), serviceAccountPath);
        const serviceAccount = require(absolutePath);
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
        });
        console.log('Firebase Admin initialized successfully.');
    } catch (error) {
        console.error('Error initializing Firebase Admin:', error.message);
    }
} else {
    console.warn('FIREBASE_SERVICE_ACCOUNT_JSON not found in .env. Auth middleware will not function correctly.');
}

const verifyToken = async (req, res, next) => {
    console.log(`Incoming request: ${req.method} ${req.originalUrl}`);
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Unauthorized: No token provided' });
    }

    const idToken = authHeader.split('Bearer ')[1];

    try {
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        req.user = decodedToken;
        next();
    } catch (error) {
        console.error('Error verifying Firebase ID token:', error.message);
        res.status(403).json({ error: 'Unauthorized: Invalid token' });
    }
};

module.exports = { verifyToken };
