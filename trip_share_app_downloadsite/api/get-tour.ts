import type { VercelRequest, VercelResponse } from '@vercel/node';
import * as admin from 'firebase-admin';

// Initialize Firebase Admin
const getFirebaseApp = () => {
  if (admin.apps.length > 0) {
    return admin.app();
  }

  // Get credentials from environment variables
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;

  if (!privateKey || !projectId || !clientEmail) {
    throw new Error('Firebase credentials not configured in environment variables');
  }

  admin.initializeApp({
    credential: admin.credential.cert({
      projectId,
      clientEmail,
      privateKey,
    }),
    databaseURL: `https://${projectId}.firebaseio.com`,
  });

  return admin.app();
};

export default async function handler(
  req: VercelRequest,
  res: VercelResponse
) {
  // Only allow GET requests
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { tourId } = req.query;

    if (!tourId || typeof tourId !== 'string') {
      return res.status(400).json({
        error: 'Tour ID is required',
        example: '/api/get-tour?tourId=ABC123'
      });
    }

    // Get Firebase app
    const app = getFirebaseApp();
    const db = admin.firestore(app);

    // Fetch tour from Firestore
    const tourDoc = await db.collection('tours').doc(tourId).get();

    if (!tourDoc.exists) {
      return res.status(404).json({
        error: 'Tour not found',
        tourId
      });
    }

    const tourData = tourDoc.data();

    // Format the response
    const tour = {
      id: tourDoc.id,
      name: tourData?.name || 'Unknown Tour',
      imageUrl: tourData?.imageUrl || '',
      price: tourData?.price || 0,
      startLocation: tourData?.startLocation || '',
      endLocation: tourData?.endLocation || '',
      description: tourData?.description || '',
      category: tourData?.category || '',
      totalSeats: tourData?.totalSeats || 0,
      remainingSeats: tourData?.remainingSeats || 0,
      startDate: tourData?.startDate ? new Date(tourData.startDate.toDate()).toISOString() : new Date().toISOString(),
      endTime: tourData?.endTime || '',
      lastJoiningTime: tourData?.lastJoiningTime ? new Date(tourData.lastJoiningTime.toDate()).toISOString() : null,
      photos: tourData?.photos || [],
      route: tourData?.route || [],
      operatorName: tourData?.operatorName || '',
      whatsIncluded: tourData?.whatsIncluded || [],
      tourFeatures: tourData?.tourFeatures || [],
    };

    return res.status(200).json(tour);

  } catch (error) {
    console.error('Error fetching tour:', error);
    
    // Check if it's a Firebase credentials error
    if (error instanceof Error && error.message.includes('not configured')) {
      return res.status(500).json({
        error: 'Server configuration error',
        message: 'Firebase credentials are not set up. Please add environment variables to Vercel.',
        details: error.message
      });
    }

    return res.status(500).json({
      error: 'Failed to fetch tour',
      message: error instanceof Error ? error.message : 'Unknown error'
    });
  }
}
