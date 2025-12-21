/**
 * Firebase Cloud Functions for KHOI App Push Notifications
 * 
 * SETUP:
 * 1. Run: firebase init functions (if not done)
 * 2. Copy this file to: functions/index.js
 * 3. Run: cd functions && npm install
 * 4. Run: firebase deploy --only functions
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ============================================
// MAIN TRIGGER: Send push notification when 
// a new document is created in 'notifications' collection
// ============================================
exports.sendPushNotification = functions.firestore
    .document('notifications/{notificationId}')
    .onCreate(async (snap, context) => {
        const notification = snap.data();
        const recipientId = notification.recipientId;
        
        console.log('📬 New notification for user:', recipientId);
        console.log('📬 Type:', notification.type);
        
        try {
            // Get recipient's FCM token from their user document
            const userDoc = await db.collection('users').doc(recipientId).get();
            
            if (!userDoc.exists) {
                console.log('❌ User not found:', recipientId);
                return null;
            }
            
            const userData = userDoc.data();
            const fcmToken = userData.fcmToken;
            
            if (!fcmToken) {
                console.log('❌ No FCM token for user:', recipientId);
                return null;
            }
            
            console.log('📱 Sending to token:', fcmToken.substring(0, 20) + '...');
            
            // Build the push notification payload
            const payload = {
                token: fcmToken,
                notification: {
                    title: notification.title,
                    body: notification.body,
                },
                data: {
                    type: notification.type || 'general',
                    notificationId: context.params.notificationId,
                    // Convert all data values to strings (FCM requirement)
                    ...Object.fromEntries(
                        Object.entries(notification.data || {}).map(([k, v]) => [k, String(v)])
                    )
                },
                apns: {
                    payload: {
                        aps: {
                            badge: 1,
                            sound: 'default',
                            'mutable-content': 1,
                            category: getCategoryForType(notification.type)
                        }
                    }
                }
            };
            
            // Send the notification
            const response = await messaging.send(payload);
            console.log('✅ Notification sent:', response);
            
            // Update the notification document with sent status
            await snap.ref.update({
                sentAt: admin.firestore.FieldValue.serverTimestamp(),
                fcmMessageId: response
            });
            
            return response;
            
        } catch (error) {
            console.error('❌ Error sending notification:', error);
            
            // If token is invalid, remove it from user document
            if (error.code === 'messaging/invalid-registration-token' ||
                error.code === 'messaging/registration-token-not-registered') {
                console.log('🗑️ Removing invalid token for user:', recipientId);
                await db.collection('users').doc(recipientId).update({
                    fcmToken: admin.firestore.FieldValue.delete()
                });
            }
            
            // Log the error in the notification document
            await snap.ref.update({
                error: error.message,
                errorCode: error.code || 'unknown'
            });
            
            return null;
        }
    });

// ============================================
// HELPER: Map notification type to iOS category
// ============================================
function getCategoryForType(type) {
    const categoryMap = {
        'new_message': 'CHAT_MESSAGE',
        'new_comment': 'NEW_COMMENT',
        'new_booking_request': 'NEW_BOOKING',
        'booking_confirmed': 'BOOKING_UPDATE',
        'booking_cancelled': 'BOOKING_UPDATE',
        'appointment_reminder': 'APPOINTMENT_REMINDER',
        'pro_application_approved': 'PRO_APPLICATION',
        'pro_application_rejected': 'PRO_APPLICATION',
        'post_saved': 'SOCIAL',
        'new_follower': 'SOCIAL'
    };
    return categoryMap[type] || 'DEFAULT';
}

// ============================================
// SCHEDULED: Clean up old notifications (30+ days)
// Runs daily at midnight PST
// ============================================
exports.cleanupOldNotifications = functions.pubsub
    .schedule('0 0 * * *')
    .timeZone('America/Los_Angeles')
    .onRun(async (context) => {
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
        
        try {
            const oldNotifications = await db.collection('notifications')
                .where('createdAt', '<', admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
                .limit(500)
                .get();
            
            if (oldNotifications.empty) {
                console.log('No old notifications to delete');
                return null;
            }
            
            const batch = db.batch();
            oldNotifications.docs.forEach(doc => {
                batch.delete(doc.ref);
            });
            
            await batch.commit();
            console.log(`🗑️ Deleted ${oldNotifications.size} old notifications`);
            
            return null;
        } catch (error) {
            console.error('Error cleaning up notifications:', error);
            return null;
        }
    });

// ============================================
// OPTIONAL: Update badge count when notification is read
// ============================================
exports.updateBadgeOnRead = functions.firestore
    .document('notifications/{notificationId}')
    .onUpdate(async (change, context) => {
        const before = change.before.data();
        const after = change.after.data();
        
        // Only trigger if notification was just marked as read
        if (before.isRead || !after.isRead) {
            return null;
        }
        
        const recipientId = after.recipientId;
        
        try {
            // Count remaining unread notifications
            const unreadSnapshot = await db.collection('notifications')
                .where('recipientId', '==', recipientId)
                .where('isRead', '==', false)
                .count()
                .get();
            
            const unreadCount = unreadSnapshot.data().count;
            
            // Get user's FCM token
            const userDoc = await db.collection('users').doc(recipientId).get();
            const fcmToken = userDoc.data()?.fcmToken;
            
            if (fcmToken) {
                // Send silent notification to update badge
                await messaging.send({
                    token: fcmToken,
                    apns: {
                        payload: {
                            aps: {
                                badge: unreadCount,
                                'content-available': 1
                            }
                        }
                    }
                });
                console.log(`📛 Updated badge to ${unreadCount} for user ${recipientId}`);
            }
            
            return null;
        } catch (error) {
            console.error('Error updating badge:', error);
            return null;
        }
    });

// ============================================
// TEST FUNCTION: Manually trigger a test notification
// Call via: firebase functions:shell > sendTestNotification({userId: 'USER_ID'})
// ============================================
exports.sendTestNotification = functions.https.onCall(async (data, context) => {
    const userId = data.userId;
    
    if (!userId) {
        throw new functions.https.HttpsError('invalid-argument', 'userId is required');
    }
    
    // Create a test notification document
    const testNotification = {
        recipientId: userId,
        type: 'test',
        title: '🎉 Test Notification',
        body: 'Push notifications are working!',
        data: {},
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    const docRef = await db.collection('notifications').add(testNotification);
    
    return { success: true, notificationId: docRef.id };
});
