# Message Board — CSC 4360 Homework 02

**Brandon Walker**

I built a message board in Flutter using Firebase Authentication and Cloud Firestore. Users can create an account with an email and password, complete their profile, and post messages. The board updates live when someone posts, edits, or deletes a message.

## User profiles and messages

After a user creates an account, the app asks for their first and last name. Before opening the board, the app checks that the user has a saved profile.

- `users/{uid}` stores the user's UID, first name, last name, role, and registration time.
- `messages/{messageId}` stores the message text, author name, author UID, and creation time. Editing a message also saves the edit time.

Firestore rules let signed-in users read the board. Each user can read their own profile, and only the author can edit or delete their message.



## Choice spices

### Spice #1 — Emulator Explorer

I used the local Firebase emulators to test Authentication and Firestore. Start them from the project folder:


firebase.cmd emulators:start --only "auth,firestore" --project homework2-11


In a second terminal, run:


flutter run --dart-define=USE_FIREBASE_EMULATORS=true




### Spice #2 — Rules Unit Tester

The automated tests check signed-out reads, edits and deletes by another user, posting with someone else's author UID, and whether the author can create, read, edit, and delete their own message.

With the Firestore emulator running, run these commands from the project folder:


`

### Spice #4 — Preventing duplicate posts

Each post attempt uses one message ID. If the app retries and Firestore already has a message with that ID, it skips creating another one.

Run this from the project folder to test two attempts with the same ID:


flutter run --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=TEST_DUPLICATE_POST=true


Tap Post once, check the message ID in the Flutter terminal, and verify that local Firestore shows one document for that test post.


