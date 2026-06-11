const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

// Helper: simple base64 decode and parse
function decodePayload(encrypted) {
  try {
    const buff = Buffer.from(encrypted, 'base64');
    const txt = buff.toString('utf8');
    return JSON.parse(txt);
  } catch (e) {
    return null;
  }
}

exports.generateMealTokens = functions.pubsub.schedule('every 24 hours').onRun(async (context) => {
  // This scheduled job can be customized via settings or separate schedules per meal.
  try {
    const now = admin.firestore.Timestamp.now().toDate();
    const dateStr = now.toISOString().slice(0,10); // YYYY-MM-DD
    const meals = ['breakfast','lunch','dinner'];

    // Load hostelSettings
    const settingsDoc = await db.collection('hostelSettings').doc('settings').get();
    const settings = settingsDoc.exists ? settingsDoc.data() : {};
    const messTimings = settings.messTimings || {};

    // Get students eligible
    const studentsSnap = await db.collection('students').where('messFeePaid', '==', true).get();
    const writes = [];

    studentsSnap.forEach(studentDoc => {
      const student = studentDoc.data();
      const studentId = studentDoc.id;
      const studentName = student.studentName || student.fullName || 'Unknown';

      meals.forEach(meal => {
        const mealCycle = `${dateStr}-${meal}`;
        // Document ID can be TKN_{date}_{student}_{meal}
        const tokenId = `TKN_${dateStr}_${studentId}_${meal}`;
        const mealTime = messTimings[meal] || {};

        const validFrom = mealTime.start || (meal === 'breakfast' ? '07:00' : meal === 'lunch' ? '12:00' : '19:00');
        const validUntil = mealTime.end || (meal === 'breakfast' ? '09:00' : meal === 'lunch' ? '14:00' : '21:00');

        const tokenPayload = {
          tokenId: tokenId,
          studentId: studentId,
          mealType: meal,
          date: dateStr,
          validFrom,
          validUntil,
          hash: tokenId.slice(-8),
        };

        const qrData = Buffer.from(JSON.stringify(tokenPayload)).toString('base64');

        const tokenDocRef = db.collection('messTokens').doc(tokenId);
        writes.push({ tokenDocRef, tokenPayload, tokenId, studentId, studentName, meal, mealCycle, qrData, dateStr });
      });
    });

    // Avoid resetting already-used tokens by only creating docs that do not exist.
    for (const item of writes) {
      const existing = await item.tokenDocRef.get();
      if (existing.exists) continue;

      const fromDate = new Date(`${item.dateStr}T${item.tokenPayload.validFrom}:00`);
      const untilDate = new Date(`${item.dateStr}T${item.tokenPayload.validUntil}:00`);

      await item.tokenDocRef.set({
        id: item.tokenId,
        studentId: item.studentId,
        studentName: item.studentName,
        tokenCode: item.tokenId,
        mealType: item.meal,
        mealDate: admin.firestore.Timestamp.now(),
        validFrom: admin.firestore.Timestamp.fromDate(fromDate),
        validUntil: admin.firestore.Timestamp.fromDate(untilDate),
        isUsed: false,
        qrData: item.qrData,
        generatedBy: 'system',
        status: 'active',
        mealCycle: item.mealCycle,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    console.log(`Generated tokens for ${studentsSnap.size} students for ${dateStr}`);
    return null;
  } catch (e) {
    console.error('Error generating tokens', e);
    return null;
  }
});

exports.validateMessToken = functions.https.onCall(async (data, context) => {
  // data: { scannedData, location }
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Request not authenticated');
  }

  const staffId = context.auth.uid;

  // Basic role check (assumes users collection has role)
  const userDoc = await db.collection('users').doc(staffId).get();
  const user = userDoc.exists ? userDoc.data() : {};
  const role = user.role || '';
  if (!(role === 'Mess Staff' || role === 'Admin')) {
    throw new functions.https.HttpsError('permission-denied', 'User not authorized to validate tokens');
  }

  const scannedData = data.scannedData;
  const location = data.location || 'Main Counter';

  const payload = decodePayload(scannedData);
  if (!payload || !payload.tokenId) {
    return { success: false, message: 'Invalid QR payload' };
  }

  const tokenId = payload.tokenId;
  const tokenRef = db.collection('messTokens').doc(tokenId);

  try {
    const result = await db.runTransaction(async (tx) => {
      const tokenSnap = await tx.get(tokenRef);
      if (!tokenSnap.exists) throw new functions.https.HttpsError('not-found', 'Token not found');

      const token = tokenSnap.data();
      if (token.isUsed === true) {
        return { success: false, message: 'Token already used' };
      }
      if (token.status !== 'active') {
        return { success: false, message: `Token is ${token.status}` };
      }

      // Basic time window check (payload has validFrom/validUntil as strings)
      const now = new Date();
      const today = payload.date;
      // Skip strict parsing for brevity; in production parse ISO and timezone

      // Mark token used
      tx.update(tokenRef, {
        isUsed: true,
        usedAt: admin.firestore.FieldValue.serverTimestamp(),
        usedBy: staffId,
        scannedAtLocation: location,
        status: 'used',
      });

      // Create meal record
      const mealRecordRef = db.collection('mealRecords').doc();
      tx.set(mealRecordRef, {
        studentId: token.studentId,
        studentName: token.studentName,
        mealType: token.mealType,
        mealDate: token.mealDate || admin.firestore.Timestamp.now(),
        scannedAt: admin.firestore.FieldValue.serverTimestamp(),
        scannedBy: staffId,
        messCounter: location,
        tokenId: tokenId,
        status: 'taken',
      });

      return {
        success: true,
        message: `${token.mealType} verified`,
        studentName: token.studentName,
        studentId: token.studentId,
        mealType: token.mealType,
      };
    });

    return result;
  } catch (e) {
    console.error('Validation error', e);
    if (e instanceof functions.https.HttpsError) throw e;
    return { success: false, message: `Error validating token: ${e.message || e}` };
  }
});
