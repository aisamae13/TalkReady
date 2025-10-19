import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

const firestore = admin.firestore();

/**
 * Checks and updates the user's study streak and handles streak freezes.
 * Must be called securely after a user completes a practice activity.
 */
export const recordPracticeActivity = onCall(async (request) => {
  // 1. Basic Validation
  const uid = request.auth?.uid;

  // If request.auth or uid is missing (unauthenticated)
  if (!uid) {
    throw new HttpsError(
      "unauthenticated",
      "User must be logged in."
    );
  }

  // 2. Setup References and Dates
  const userProgressRef = firestore.collection("userProgress").doc(uid);
  const today = new Date();
  // Normalize date to local midnight for consistent day-over-day checks
  const todayMidnight = new Date(
    today.getFullYear(),
    today.getMonth(),
    today.getDate()
  );

  // --- Core Transaction ---
  return firestore.runTransaction(async (transaction) => {
    const progressDoc = await transaction.get(userProgressRef);

    const userData = progressDoc.data() || {};
    let currentStreak = userData.currentStreak || 0;
    let longestStreak = userData.longestStreak || 0;
    let streakFreezes = userData.streakFreezes || 0;
    const lastActiveDateTimestamp = userData.lastActiveDate;

    // Determine the previous active date (or null if none)
    const lastActiveDate =
      lastActiveDateTimestamp instanceof admin.firestore.Timestamp ?
        lastActiveDateTimestamp.toDate() :
        null;

    let daysDiff = 0; // Difference in calendar days

    if (lastActiveDate) {
      // Normalize last active date to midnight as well
      const lastActiveMidnight = new Date(
        lastActiveDate.getFullYear(),
        lastActiveDate.getMonth(),
        lastActiveDate.getDate()
      );

      // Calculate difference in days
      const msDiff = todayMidnight.getTime() -
        lastActiveMidnight.getTime();
      daysDiff = Math.floor(msDiff / (1000 * 60 * 60 * 24));
    }

    // 3. Streak Logic
    let status = "Streak unchanged";

    if (daysDiff === 0) {
      // Case 1: Already practiced today. Streak remains the same.
      status = "Activity already recorded today. Streak maintained.";
      // No changes needed to currentStreak/freezes
    } else if (daysDiff === 1 || daysDiff < 0 || !lastActiveDate) {
      // Case 2: Practiced yesterday or first activity
      currentStreak += 1;
      status = "Streak continued.";
    } else if (daysDiff === 2) {
      // Case 3: Missed exactly one day (daysDiff=2).

      if (streakFreezes > 0) {
        // Apply Streak Freeze: Save the streak.
        streakFreezes -= 1;
        // Streak is maintained at yesterday's level + 1 (today)
        currentStreak += 1;
        status = "Streak saved using 1 Streak Freeze. " +
          `${streakFreezes} remaining.`;
      } else {
        // No freeze available. Reset streak.
        currentStreak = 1;
        status = "Streak reset to 1 due to missed day (no freeze).";
      }
    } else if (daysDiff > 2) {
      // Case 4: Missed two or more days. Reset streak.
      currentStreak = 1;
      status = "Streak reset to 1 due to multiple missed days.";
    }

    // 4. Update Longest Streak
    if (currentStreak > longestStreak) {
      longestStreak = currentStreak;
    }

    // 🆕 NEW: Award Streak Freeze every 30 days
    const MAX_FREEZES = 5; // Cap at 5 freezes
    let bonusMessage = "";

    if (
      currentStreak > 0 &&
  currentStreak % 30 === 0 &&
  streakFreezes < MAX_FREEZES
    ) {
      streakFreezes += 1;
      bonusMessage =
    " 🎉 Bonus: Earned 1 Streak Freeze for " +
    `reaching ${currentStreak}-day milestone!`;
      status += bonusMessage;
    }

    // 5. Commit Transaction
    transaction.set(
      userProgressRef,
      {
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        streakFreezes: streakFreezes,
        lastActiveDate: today,
      },
      {merge: true}
    );

    // 6. Return Result
    return {
      success: true,
      message: status,
      currentStreak: currentStreak,
      streakFreezes: streakFreezes,
    };
  }); // end transaction
});
